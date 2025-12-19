`timescale 1ns/1ps
// ============================================================================
// Streaming IPv4/UDP/Ethernet receiver with 32-bit datapath
// Mirrors ip_eth_tx_64_rdma structure - pure extraction, no validation
// Validation is done by rdma_hdr_validator (same pattern as TX)
// ============================================================================
module ip_eth_rx_64_rdma (
    input  wire        iClk,
    input  wire        iRst,        // Active-low reset (same as TX)

    // Ethernet frame input (AXI-Stream 32-bit, from MAC)
    input  wire [31:0] s_eth_tdata,
    input  wire [3:0]  s_eth_tkeep,
    input  wire        s_eth_tvalid,
    output wire        s_eth_tready,
    input  wire        s_eth_tlast,
    input  wire        s_eth_tuser,  // Frame error from MAC

    // Payload output (AXI-Stream 32-bit, to RDMA logic)
    output wire [31:0] m_payload_tdata,
    output wire [3:0]  m_payload_tkeep,
    output wire        m_payload_tvalid,
    input  wire        m_payload_tready,
    output wire        m_payload_tlast,
    output wire        m_payload_tuser,  // Propagate errors

    // Extracted raw header fields (to validator)
    output wire [47:0] m_hdr_dst_mac,
    output wire [47:0] m_hdr_src_mac,
    output wire [15:0] m_hdr_ethertype,
    output wire [3:0]  m_hdr_ip_version,
    output wire [3:0]  m_hdr_ip_ihl,
    output wire [7:0]  m_hdr_ip_protocol,
    output wire [15:0] m_hdr_ip_total_len,
    output wire [31:0] m_hdr_src_ip,
    output wire [31:0] m_hdr_dst_ip,
    output wire [15:0] m_hdr_src_port,
    output wire [15:0] m_hdr_dst_port,
    output wire [15:0] m_hdr_udp_len,
    output wire [31:0] m_hdr_checksum_accum,  // For validator to verify
    output wire [15:0] m_hdr_payload_len,
    output wire        m_hdr_valid,           // Pulses when extraction complete
    input  wire        m_hdr_ready,           // Validator ready

    // Control signals (from validator)
    input  wire        i_packet_accept,  // Validator says packet is good
    input  wire        i_packet_drop,    // Validator says drop packet

    // Status
    output wire        busy,
    output wire [2:0]  o_debug_state,

    // Statistics (active-high pulse per event)
    output wire        stat_pkt_received,   // Valid packet processed
    output wire        stat_pkt_dropped     // Packet dropped
);

// ============================================================================
// State Machine (mirrors TX structure)
// ============================================================================
// With 32-bit datapath, 42-byte header takes 11 beats:
// Beat 0:  Bytes 0-3   (Dst MAC [0:3])
// Beat 1:  Bytes 4-7   (Dst MAC [4:5] + Src MAC [0:1])
// Beat 2:  Bytes 8-11  (Src MAC [2:5])
// Beat 3:  Bytes 12-15 (EtherType + IP Ver/IHL/DSCP)
// Beat 4:  Bytes 16-19 (IP Total Len + IP ID)
// Beat 5:  Bytes 20-23 (Flags/Frag + TTL + Protocol)
// Beat 6:  Bytes 24-27 (IP Checksum + Src IP [0:1])
// Beat 7:  Bytes 28-31 (Src IP [2:3])
// Beat 8:  Bytes 32-35 (Dst IP [0:3])
// Beat 9:  Bytes 36-39 (UDP Src Port + UDP Dst Port)
// Beat 10: Bytes 40-43 (UDP Len + UDP Checksum) <- header ends at byte 41, payload starts at 42
// Beat 11+: Payload (with 2-byte offset)

localparam [3:0]
    ST_IDLE       = 4'd0,   // Waiting for packet
    ST_HDR_0      = 4'd1,   // Capture beat 0
    ST_HDR_1      = 4'd2,   // Capture beat 1
    ST_HDR_2      = 4'd3,   // Capture beat 2
    ST_HDR_3      = 4'd4,   // Capture beat 3
    ST_HDR_4      = 4'd5,   // Capture beat 4
    ST_HDR_5      = 4'd6,   // Capture beat 5
    ST_HDR_6      = 4'd7,   // Capture beat 6
    ST_HDR_7      = 4'd8,   // Capture beat 7
    ST_HDR_8      = 4'd9,   // Capture beat 8
    ST_HDR_9      = 4'd10,  // Capture beat 9 + wait for validator
    ST_TRANSITION = 4'd11,  // Beat 10: UDP len/checksum + first 2 payload bytes
    ST_PAYLOAD    = 4'd12;  // Stream payload with left-shift

reg [3:0] state_reg;

// Drop mode: absorb remaining packet without output
reg drop_mode;
reg waiting_validator;  // Waiting for validator response

// ============================================================================
// Header Capture Registers (44 bytes = 11 beats worth for 32-bit datapath)
// ============================================================================
reg [31:0] hdr_beat0, hdr_beat1, hdr_beat2, hdr_beat3, hdr_beat4;
reg [31:0] hdr_beat5, hdr_beat6, hdr_beat7, hdr_beat8, hdr_beat9;

// Extract header fields from captured beats (32-bit aligned)
// Beat 0: Bytes 0-3 = Dst MAC [0:3]
// Beat 1: Bytes 4-7 = Dst MAC [4:5] + Src MAC [0:1]
// Beat 2: Bytes 8-11 = Src MAC [2:5]
wire [47:0] rx_dst_mac_w = {hdr_beat0[7:0],   hdr_beat0[15:8],  hdr_beat0[23:16],
                            hdr_beat0[31:24], hdr_beat1[7:0],   hdr_beat1[15:8]};

wire [47:0] rx_src_mac_w = {hdr_beat1[23:16], hdr_beat1[31:24], hdr_beat2[7:0],
                            hdr_beat2[15:8],  hdr_beat2[23:16], hdr_beat2[31:24]};

// Beat 3: Bytes 12-15 = EtherType + IP Ver/IHL/DSCP
wire [15:0] rx_ethertype = {hdr_beat3[7:0], hdr_beat3[15:8]};

// IPv4 Header (20 bytes, starts at byte 14)
wire [7:0]  rx_ip_ver_ihl = hdr_beat3[23:16];
wire [3:0]  rx_ip_version = rx_ip_ver_ihl[7:4];
wire [3:0]  rx_ip_ihl     = rx_ip_ver_ihl[3:0];
wire [7:0]  rx_ip_dscp_ecn = hdr_beat3[31:24];

// Beat 4: Bytes 16-19 = Total Length + Identification
wire [15:0] rx_ip_total_len = {hdr_beat4[7:0], hdr_beat4[15:8]};
wire [15:0] rx_ip_id = {hdr_beat4[23:16], hdr_beat4[31:24]};

// Beat 5: Bytes 20-23 = Flags/Frag + TTL + Protocol
wire [15:0] rx_ip_flags_frag = {hdr_beat5[7:0], hdr_beat5[15:8]};
wire [7:0]  rx_ip_ttl = hdr_beat5[23:16];
wire [7:0]  rx_ip_protocol = hdr_beat5[31:24];

// Beat 6: Bytes 24-27 = Header Checksum + Src IP [0:1]
wire [15:0] rx_ip_checksum = {hdr_beat6[7:0], hdr_beat6[15:8]};

// Beat 6-7: Bytes 26-29 = Source IP
wire [31:0] rx_src_ip = {hdr_beat6[23:16], hdr_beat6[31:24],
                         hdr_beat7[7:0],   hdr_beat7[15:8]};

// Beat 7-8: Bytes 30-33 = Dest IP (last 2 bytes of beat 7 + beat 8)
wire [31:0] rx_dst_ip = {hdr_beat7[23:16], hdr_beat7[31:24],
                         hdr_beat8[7:0],   hdr_beat8[15:8]};

// Beat 8-9: UDP Header (8 bytes, starts at byte 34)
// Beat 8 bytes 2-3 = UDP Src Port [0:1] (bytes 34-35)
// Beat 9 bytes 0-3 = UDP Src Port [not needed], UDP Dst Port (bytes 36-39)
wire [15:0] rx_udp_src_port = {hdr_beat8[23:16], hdr_beat8[31:24]};
wire [15:0] rx_udp_dst_port = {hdr_beat9[7:0], hdr_beat9[15:8]};
wire [15:0] rx_udp_len = {hdr_beat9[23:16], hdr_beat9[31:24]};

// Computed payload length
wire [15:0] rx_payload_len = rx_udp_len - 16'd8;  // UDP length - 8 byte header

// IP Checksum Accumulator (validator will verify)
// Sum all 16-bit words including the checksum field
// If valid, result will fold to 0xFFFF
wire [31:0] checksum_accum =
    {rx_ip_ver_ihl, rx_ip_dscp_ecn} +     // Ver/IHL + DSCP/ECN
    rx_ip_total_len +                      // Total length
    rx_ip_id +                             // Identification
    rx_ip_flags_frag +                     // Flags + Fragment offset
    {rx_ip_ttl, rx_ip_protocol} +          // TTL + Protocol
    rx_ip_checksum +                       // Header checksum (included for validation)
    rx_src_ip[31:16] + rx_src_ip[15:0] +   // Source IP
    rx_dst_ip[31:16] + rx_dst_ip[15:0];    // Destination IP

// ============================================================================
// Payload Shift Logic (left-shift for RX, opposite of TX right-shift)
// ============================================================================
// With 32-bit datapath:
// TX: 42-byte header means payload starts at offset 2, needs RIGHT shift
//     TX stores 2 bytes, outputs {new[15:0], stored[15:0]}
//
// RX: Payload starts at byte 42 (beat 10, offset 2), needs LEFT shift
//     RX stores 2 bytes from beat 10, outputs {new[15:0], stored[15:0]}

reg [15:0] shift_reg;       // Stores tdata[31:16] (2 payload bytes) from previous beat
reg [2:0]  shift_count;     // Valid bytes in shift register for final beat
reg        last_pending;    // tlast received, need to flush shift register

// Output registers
reg [31:0] m_payload_tdata_reg;
reg [3:0]  m_payload_tkeep_reg;
reg        m_payload_tvalid_reg;
reg        m_payload_tlast_reg;
reg        m_payload_tuser_reg;

reg        s_eth_tready_reg;
reg        busy_reg;

// Header output registers (active when hdr_valid pulses)
reg [47:0] hdr_dst_mac_reg;
reg [47:0] hdr_src_mac_reg;
reg [15:0] hdr_ethertype_reg;
reg [3:0]  hdr_ip_version_reg;
reg [3:0]  hdr_ip_ihl_reg;
reg [7:0]  hdr_ip_protocol_reg;
reg [15:0] hdr_ip_total_len_reg;
reg [31:0] hdr_src_ip_reg;
reg [31:0] hdr_dst_ip_reg;
reg [15:0] hdr_src_port_reg;
reg [15:0] hdr_dst_port_reg;
reg [15:0] hdr_udp_len_reg;
reg [31:0] hdr_checksum_accum_reg;
reg [15:0] hdr_payload_len_reg;
reg        hdr_valid_reg;

reg        stat_received_reg;
reg        stat_dropped_reg;

// Output Assignments
assign m_payload_tdata  = m_payload_tdata_reg;
assign m_payload_tkeep  = m_payload_tkeep_reg;
assign m_payload_tvalid = m_payload_tvalid_reg;
assign m_payload_tlast  = m_payload_tlast_reg;
assign m_payload_tuser  = m_payload_tuser_reg;

assign s_eth_tready = s_eth_tready_reg;
assign busy         = busy_reg;

assign m_hdr_dst_mac        = hdr_dst_mac_reg;
assign m_hdr_src_mac        = hdr_src_mac_reg;
assign m_hdr_ethertype      = hdr_ethertype_reg;
assign m_hdr_ip_version     = hdr_ip_version_reg;
assign m_hdr_ip_ihl         = hdr_ip_ihl_reg;
assign m_hdr_ip_protocol    = hdr_ip_protocol_reg;
assign m_hdr_ip_total_len   = hdr_ip_total_len_reg;
assign m_hdr_src_ip         = hdr_src_ip_reg;
assign m_hdr_dst_ip         = hdr_dst_ip_reg;
assign m_hdr_src_port       = hdr_src_port_reg;
assign m_hdr_dst_port       = hdr_dst_port_reg;
assign m_hdr_udp_len        = hdr_udp_len_reg;
assign m_hdr_checksum_accum = hdr_checksum_accum_reg;
assign m_hdr_payload_len    = hdr_payload_len_reg;
assign m_hdr_valid          = hdr_valid_reg;

assign o_debug_state     = state_reg[2:0];  // Output lower 3 bits for debug
assign stat_pkt_received = stat_received_reg;
assign stat_pkt_dropped  = stat_dropped_reg;


function [2:0] count_ones;
    input [3:0] keep;
    begin
        count_ones = keep[0] + keep[1] + keep[2] + keep[3];
    end
endfunction


always @(posedge iClk) begin
    if (!iRst) begin
        // Reset (active-low, same as TX)
        state_reg <= ST_IDLE;
        drop_mode <= 1'b0;
        waiting_validator <= 1'b0;

        hdr_beat0 <= 32'd0;
        hdr_beat1 <= 32'd0;
        hdr_beat2 <= 32'd0;
        hdr_beat3 <= 32'd0;
        hdr_beat4 <= 32'd0;
        hdr_beat5 <= 32'd0;
        hdr_beat6 <= 32'd0;
        hdr_beat7 <= 32'd0;
        hdr_beat8 <= 32'd0;
        hdr_beat9 <= 32'd0;

        m_payload_tdata_reg  <= 32'd0;
        m_payload_tkeep_reg  <= 4'd0;
        m_payload_tvalid_reg <= 1'b0;
        m_payload_tlast_reg  <= 1'b0;
        m_payload_tuser_reg  <= 1'b0;

        s_eth_tready_reg <= 1'b0;
        busy_reg         <= 1'b0;

        hdr_dst_mac_reg        <= 48'd0;
        hdr_src_mac_reg        <= 48'd0;
        hdr_ethertype_reg      <= 16'd0;
        hdr_ip_version_reg     <= 4'd0;
        hdr_ip_ihl_reg         <= 4'd0;
        hdr_ip_protocol_reg    <= 8'd0;
        hdr_ip_total_len_reg   <= 16'd0;
        hdr_src_ip_reg         <= 32'd0;
        hdr_dst_ip_reg         <= 32'd0;
        hdr_src_port_reg       <= 16'd0;
        hdr_dst_port_reg       <= 16'd0;
        hdr_udp_len_reg        <= 16'd0;
        hdr_checksum_accum_reg <= 32'd0;
        hdr_payload_len_reg    <= 16'd0;
        hdr_valid_reg          <= 1'b0;

        stat_received_reg <= 1'b0;
        stat_dropped_reg  <= 1'b0;

        shift_reg    <= 16'd0;
        shift_count  <= 3'd0;
        last_pending <= 1'b0;

    end else begin
        // Default: clear single-cycle pulses
        hdr_valid_reg     <= 1'b0;
        stat_received_reg <= 1'b0;
        stat_dropped_reg  <= 1'b0;

        // Output handshake: clear valid when ready
        if (m_payload_tvalid_reg && m_payload_tready) begin
            m_payload_tvalid_reg <= 1'b0;
            m_payload_tlast_reg  <= 1'b0;
        end

        case (state_reg)
            // ================================================================
            // ST_IDLE: Wait for incoming frame
            // ================================================================
            ST_IDLE: begin
                s_eth_tready_reg <= 1'b1;
                busy_reg         <= 1'b0;
                drop_mode        <= 1'b0;
                last_pending     <= 1'b0;
                waiting_validator <= 1'b0;

                if (s_eth_tvalid && s_eth_tready_reg) begin
                    busy_reg <= 1'b1;

                    // Check for frame error or early termination
                    if (s_eth_tuser) begin
                        stat_dropped_reg <= 1'b1;
                        if (s_eth_tlast) begin
                            state_reg <= ST_IDLE;
                        end else begin
                            drop_mode <= 1'b1;
                            state_reg <= ST_PAYLOAD;
                        end
                    end else if (s_eth_tlast) begin
                        stat_dropped_reg <= 1'b1;
                        state_reg        <= ST_IDLE;
                    end else begin
                        hdr_beat0 <= s_eth_tdata;
                        state_reg <= ST_HDR_0;
                    end
                end
            end

            // ================================================================
            // ST_HDR_0: Capture beat 1
            // ================================================================
            ST_HDR_0: begin
                if (s_eth_tvalid && s_eth_tready_reg) begin
                    hdr_beat1 <= s_eth_tdata;

                    if (s_eth_tlast || s_eth_tuser) begin
                        stat_dropped_reg <= 1'b1;
                        state_reg        <= ST_IDLE;
                    end else begin
                        state_reg <= ST_HDR_1;
                    end
                end
            end

            // ================================================================
            // ST_HDR_1: Capture beat 2
            // ================================================================
            ST_HDR_1: begin
                if (s_eth_tvalid && s_eth_tready_reg) begin
                    hdr_beat2 <= s_eth_tdata;

                    if (s_eth_tlast || s_eth_tuser) begin
                        stat_dropped_reg <= 1'b1;
                        state_reg        <= ST_IDLE;
                    end else begin
                        state_reg <= ST_HDR_2;
                    end
                end
            end

            // ================================================================
            // ST_HDR_2: Capture beat 3
            // ================================================================
            ST_HDR_2: begin
                if (s_eth_tvalid && s_eth_tready_reg) begin
                    hdr_beat3 <= s_eth_tdata;

                    if (s_eth_tlast || s_eth_tuser) begin
                        stat_dropped_reg <= 1'b1;
                        state_reg        <= ST_IDLE;
                    end else begin
                        state_reg <= ST_HDR_3;
                    end
                end
            end

            // ================================================================
            // ST_HDR_3: Capture beat 4
            // ================================================================
            ST_HDR_3: begin
                if (s_eth_tvalid && s_eth_tready_reg) begin
                    hdr_beat4 <= s_eth_tdata;

                    if (s_eth_tlast || s_eth_tuser) begin
                        stat_dropped_reg <= 1'b1;
                        state_reg        <= ST_IDLE;
                    end else begin
                        state_reg <= ST_HDR_4;
                    end
                end
            end

            // ================================================================
            // ST_HDR_4: Capture beat 5
            // ================================================================
            ST_HDR_4: begin
                if (s_eth_tvalid && s_eth_tready_reg) begin
                    hdr_beat5 <= s_eth_tdata;

                    if (s_eth_tlast || s_eth_tuser) begin
                        stat_dropped_reg <= 1'b1;
                        state_reg        <= ST_IDLE;
                    end else begin
                        state_reg <= ST_HDR_5;
                    end
                end
            end

            // ================================================================
            // ST_HDR_5: Capture beat 6
            // ================================================================
            ST_HDR_5: begin
                if (s_eth_tvalid && s_eth_tready_reg) begin
                    hdr_beat6 <= s_eth_tdata;

                    if (s_eth_tlast || s_eth_tuser) begin
                        stat_dropped_reg <= 1'b1;
                        state_reg        <= ST_IDLE;
                    end else begin
                        state_reg <= ST_HDR_6;
                    end
                end
            end

            // ================================================================
            // ST_HDR_6: Capture beat 7
            // ================================================================
            ST_HDR_6: begin
                if (s_eth_tvalid && s_eth_tready_reg) begin
                    hdr_beat7 <= s_eth_tdata;

                    if (s_eth_tlast || s_eth_tuser) begin
                        stat_dropped_reg <= 1'b1;
                        state_reg        <= ST_IDLE;
                    end else begin
                        state_reg <= ST_HDR_7;
                    end
                end
            end

            // ================================================================
            // ST_HDR_7: Capture beat 8
            // ================================================================
            ST_HDR_7: begin
                if (s_eth_tvalid && s_eth_tready_reg) begin
                    hdr_beat8 <= s_eth_tdata;

                    if (s_eth_tlast || s_eth_tuser) begin
                        stat_dropped_reg <= 1'b1;
                        state_reg        <= ST_IDLE;
                    end else begin
                        state_reg <= ST_HDR_8;
                    end
                end
            end

            // ================================================================
            // ST_HDR_8: Capture beat 9
            // ================================================================
            ST_HDR_8: begin
                if (s_eth_tvalid && s_eth_tready_reg) begin
                    hdr_beat9 <= s_eth_tdata;

                    if (s_eth_tlast || s_eth_tuser) begin
                        stat_dropped_reg <= 1'b1;
                        state_reg        <= ST_IDLE;
                    end else begin
                        // Deassert tready while waiting for validator
                        s_eth_tready_reg <= 1'b0;
                        state_reg <= ST_HDR_9;
                    end
                end
            end

            // ================================================================
            // ST_HDR_9: Extract headers, send to validator, wait for response
            // ================================================================
            ST_HDR_9: begin
                if (!waiting_validator) begin
                    // Output all extracted header fields to validator
                    hdr_dst_mac_reg        <= rx_dst_mac_w;
                    hdr_src_mac_reg        <= rx_src_mac_w;
                    hdr_ethertype_reg      <= rx_ethertype;
                    hdr_ip_version_reg     <= rx_ip_version;
                    hdr_ip_ihl_reg         <= rx_ip_ihl;
                    hdr_ip_protocol_reg    <= rx_ip_protocol;
                    hdr_ip_total_len_reg   <= rx_ip_total_len;
                    hdr_src_ip_reg         <= rx_src_ip;
                    hdr_dst_ip_reg         <= rx_dst_ip;
                    hdr_src_port_reg       <= rx_udp_src_port;
                    hdr_dst_port_reg       <= rx_udp_dst_port;
                    hdr_udp_len_reg        <= rx_udp_len;
                    hdr_checksum_accum_reg <= checksum_accum;
                    hdr_payload_len_reg    <= rx_payload_len;
                    hdr_valid_reg          <= 1'b1;
                    waiting_validator      <= 1'b1;
                end else begin
                    // Wait for validator response
                    if (i_packet_accept) begin
                        // Valid packet - proceed to payload streaming
                        s_eth_tready_reg  <= 1'b1;
                        drop_mode         <= 1'b0;
                        waiting_validator <= 1'b0;
                        state_reg         <= ST_TRANSITION;
                    end else if (i_packet_drop) begin
                        // Invalid packet - enter drop mode
                        s_eth_tready_reg  <= 1'b1;
                        drop_mode         <= 1'b1;
                        waiting_validator <= 1'b0;
                        stat_dropped_reg  <= 1'b1;
                        state_reg         <= ST_TRANSITION;
                    end
                    // Stay in ST_HDR_9 until validator responds
                end
            end

            // ================================================================
            // ST_TRANSITION: Beat 10 - UDP len/checksum + first 2 payload bytes
            // ================================================================
            ST_TRANSITION: begin
                if (s_eth_tvalid && s_eth_tready_reg) begin
                    if (drop_mode) begin
                        // Absorb beat 10 without output
                        if (s_eth_tlast) begin
                            drop_mode <= 1'b0;
                            state_reg <= ST_IDLE;
                        end else begin
                            state_reg <= ST_PAYLOAD;
                        end
                    end else begin
                        // Beat 10: [15:0] = UDP checksum, [31:16] = first 2 payload bytes
                        // Store the 2 payload bytes for combining with next beat
                        shift_reg <= s_eth_tdata[31:16];

                        if (s_eth_tlast) begin
                            // Entire payload fits in beat 10 (<=2 bytes)
                            s_eth_tready_reg <= 1'b0;  // No more input expected

                            if (!m_payload_tvalid_reg || m_payload_tready) begin
                                // Output ready - send directly
                                m_payload_tdata_reg  <= {16'd0, s_eth_tdata[31:16]};
                                m_payload_tkeep_reg  <= {2'b00, s_eth_tkeep[3:2]};
                                m_payload_tvalid_reg <= (s_eth_tkeep[3:2] != 2'd0);
                                m_payload_tlast_reg  <= 1'b1;
                                m_payload_tuser_reg  <= s_eth_tuser;
                                stat_received_reg    <= 1'b1;
                                state_reg            <= ST_IDLE;
                            end else begin
                                // Output not ready - defer to ST_PAYLOAD flush
                                last_pending <= 1'b1;
                                shift_count  <= {1'b0, s_eth_tkeep[3], s_eth_tkeep[2]};
                                state_reg    <= ST_PAYLOAD;
                            end
                        end else begin
                            state_reg <= ST_PAYLOAD;
                        end
                    end
                end
            end

            // ================================================================
            // ST_PAYLOAD: Stream payload with left-shift
            // ================================================================
            ST_PAYLOAD: begin
                if (drop_mode) begin
                    // Absorb remaining packet without output
                    s_eth_tready_reg <= 1'b1;  // Always accept when dropping
                    if (s_eth_tvalid && s_eth_tready_reg) begin
                        if (s_eth_tlast) begin
                            drop_mode <= 1'b0;
                            state_reg <= ST_IDLE;
                        end
                    end
                end else begin
                    // Backpressure: only accept input when we can output
                    s_eth_tready_reg <= !m_payload_tvalid_reg || m_payload_tready;

                    if (!m_payload_tvalid_reg || m_payload_tready) begin
                        if (last_pending) begin
                            // Flush remaining bytes from shift register
                            if (shift_count > 3'd0) begin
                                m_payload_tdata_reg  <= {16'd0, shift_reg};
                                m_payload_tkeep_reg  <= (4'hF >> (3'd4 - shift_count));
                                m_payload_tvalid_reg <= 1'b1;
                                m_payload_tlast_reg  <= 1'b1;
                                m_payload_tuser_reg  <= 1'b0;
                            end
                            stat_received_reg    <= 1'b1;
                            last_pending         <= 1'b0;
                            state_reg            <= ST_IDLE;

                        end else if (s_eth_tvalid) begin
                            // Normal payload: combine {new[15:0], stored[15:0]}
                            m_payload_tdata_reg  <= {s_eth_tdata[15:0], shift_reg};
                            m_payload_tkeep_reg  <= 4'hF;
                            m_payload_tvalid_reg <= 1'b1;
                            m_payload_tlast_reg  <= 1'b0;

                            // Update shift register with upper 2 bytes
                            shift_reg <= s_eth_tdata[31:16];

                            if (s_eth_tlast) begin
                                s_eth_tready_reg <= 1'b0;

                                if (count_ones(s_eth_tkeep) <= 3'd2) begin
                                    // <=2 valid bytes: all absorbed in current output
                                    // tkeep = {valid from new[1:0], all 2 stored bytes}
                                    m_payload_tkeep_reg <= {s_eth_tkeep[1:0], 2'b11};
                                    m_payload_tlast_reg <= 1'b1;
                                    m_payload_tuser_reg <= s_eth_tuser;
                                    stat_received_reg   <= 1'b1;
                                    state_reg           <= ST_IDLE;
                                end else begin
                                    // >2 bytes: output full beat, flush remainder
                                    last_pending <= 1'b1;
                                    shift_count  <= count_ones(s_eth_tkeep) - 3'd2;
                                end
                            end
                        end
                    end  // if (!m_payload_tvalid_reg || m_payload_tready)
                end  // else (not drop_mode)
            end  // ST_PAYLOAD

            // ================================================================
            default: state_reg <= ST_IDLE;
        endcase
    end
end

endmodule
