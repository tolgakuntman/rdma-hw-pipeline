`timescale 1ns/1ps
// ============================================================================
// Module: ip_eth_tx_64_rdma
// Description: Streaming IPv4/UDP/Ethernet transmitter with 32-bit datapath
//              Based on Alex Forencich verilog-ethernet (github)
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
// Beat 10: Bytes 40-43 (UDP Len + UDP Checksum + first 2 payload bytes)
// Beat 11+: Payload (with 2-byte offset)
// ============================================================================
module ip_eth_tx_64_rdma #(
    parameter [47:0] SRC_MAC = 48'h123456789ABC,
    parameter [47:0] DST_MAC = 48'h000A35010203
)(
    input  wire        iClk,
    input  wire        iRst,

    // Header input (validated metadata, single-cycle handshake)
    input  wire        s_hdr_valid,
    output wire        s_hdr_ready,
    input  wire [15:0] s_payload_len,
    input  wire [31:0] s_src_ip,
    input  wire [31:0] s_dst_ip,
    input  wire [15:0] s_src_port,
    input  wire [15:0] s_dst_port,

    // Payload input (AXI-Stream 32-bit)
    input  wire [31:0] s_payload_tdata,
    input  wire [3:0]  s_payload_tkeep,
    input  wire        s_payload_tvalid,
    output wire        s_payload_tready,
    input  wire        s_payload_tlast,
    input  wire        s_payload_tuser,

    // Ethernet frame output (AXI-Stream 32-bit)
    output wire [31:0] m_eth_tdata,
    output wire [3:0]  m_eth_tkeep,
    output wire        m_eth_tvalid,
    input  wire        m_eth_tready,
    output wire        m_eth_tlast,
    output wire        m_eth_tuser,

    // Status
    output wire        busy,
    output wire        error_payload_early_termination,

    // Debug
    output wire [2:0]  o_debug_state
);

// State Machine - 13 states for 32-bit datapath
localparam [3:0]
    ST_IDLE       = 4'd0,
    ST_HDR_0      = 4'd1,   // Bytes 0-3
    ST_HDR_1      = 4'd2,   // Bytes 4-7
    ST_HDR_2      = 4'd3,   // Bytes 8-11
    ST_HDR_3      = 4'd4,   // Bytes 12-15
    ST_HDR_4      = 4'd5,   // Bytes 16-19
    ST_HDR_5      = 4'd6,   // Bytes 20-23
    ST_HDR_6      = 4'd7,   // Bytes 24-27
    ST_HDR_7      = 4'd8,   // Bytes 28-31
    ST_HDR_8      = 4'd9,   // Bytes 32-35
    ST_HDR_9      = 4'd10,  // Bytes 36-39
    ST_TRANSITION = 4'd11,  // Bytes 40-43 (UDP len/checksum + first 2 payload bytes)
    ST_PAYLOAD    = 4'd12;  // Payload streaming

reg [3:0] state_reg;

// Latched Header Fields
reg [15:0] payload_len_reg;
reg [31:0] src_ip_reg, dst_ip_reg;
reg [15:0] src_port_reg, dst_port_reg;
reg [15:0] total_len_reg;   // IP total length
reg [15:0] udp_len_reg;     // UDP length
reg [15:0] ip_id_reg;       // IP identification (increments per packet)
reg [15:0] ip_checksum_reg; // Computed checksum

// Shift Register for 2-Byte Payload Alignment
// After 42-byte header, payload starts at byte 42 (offset 2 in beat 10)
// Need to shift payload by 2 bytes
reg [15:0] shift_reg;       // Holds 2 bytes from previous cycle
reg [2:0]  shift_count;     // Valid bytes in shift register for final beat
reg        shift_valid;     // Shift register has valid data
reg        last_pending;    // tlast received, need to flush shift register

// Output Registers
reg [31:0] m_eth_tdata_reg;
reg [3:0]  m_eth_tkeep_reg;
reg        m_eth_tvalid_reg;
reg        m_eth_tlast_reg;
reg        m_eth_tuser_reg;

reg        s_hdr_ready_reg;
reg        s_payload_tready_reg;
reg        busy_reg;
reg        error_reg;

// Output Assignments
assign m_eth_tdata  = m_eth_tdata_reg;
assign m_eth_tkeep  = m_eth_tkeep_reg;
assign m_eth_tvalid = m_eth_tvalid_reg;
assign m_eth_tlast  = m_eth_tlast_reg;
assign m_eth_tuser  = m_eth_tuser_reg;

assign s_hdr_ready     = s_hdr_ready_reg;
assign s_payload_tready = s_payload_tready_reg;
assign busy            = busy_reg;
assign error_payload_early_termination = error_reg;
assign o_debug_state   = state_reg[2:0];

// IP Checksum Calculation (Combinational)
wire [31:0] checksum_step1;
wire [31:0] checksum_step2;
wire [15:0] checksum_final;

assign checksum_step1 =
    16'h4500 +                              // Version, IHL, DSCP, ECN
    total_len_reg +                         // Total length
    ip_id_reg +                             // Identification
    16'h4000 +                              // Flags (DF) + Fragment offset
    16'h4011 +                              // TTL (64) + Protocol (UDP=17)
    // Checksum field = 0
    src_ip_reg[31:16] + src_ip_reg[15:0] +  // Source IP
    dst_ip_reg[31:16] + dst_ip_reg[15:0];   // Destination IP

// Fold 32-bit sum to 16-bit with carry
assign checksum_step2 = checksum_step1[15:0] + checksum_step1[31:16];
assign checksum_final = ~(checksum_step2[15:0] + checksum_step2[16]);

// ============================================================================
// Header Word Construction (32-bit words)
// ============================================================================
// Ethernet: bytes 0-13, IP: bytes 14-33, UDP: bytes 34-41

// Word 0: Bytes 0-3 (Dst MAC [0:3])
wire [31:0] hdr_word0 = {
    DST_MAC[23:16], DST_MAC[31:24],             // Bytes 3,2: Dst MAC [3:2]
    DST_MAC[39:32], DST_MAC[47:40]           // Bytes 1,0: Dst MAC [1:0]
};

// Word 1: Bytes 4-7 (Dst MAC [4:5] + Src MAC [0:1])
wire [31:0] hdr_word1 = {
    SRC_MAC[39:32], SRC_MAC[47:40],          // Bytes 7,6: Src MAC [1:0]
    DST_MAC[7:0], DST_MAC[15:8]           // Bytes 5,4: Dst MAC [5:4]
};

// Word 2: Bytes 8-11 (Src MAC [2:5])
wire [31:0] hdr_word2 = {
    SRC_MAC[7:0], SRC_MAC[15:8],             // Bytes 11,10: Src MAC [5:4]
    SRC_MAC[23:16], SRC_MAC[31:24]           // Bytes 9,8: Src MAC [3:2]
};

// Word 3: Bytes 12-15 (EtherType + IP Version/IHL + DSCP)
wire [31:0] hdr_word3 = {
    8'h00, 8'h45,                            // Bytes 15,14: DSCP/ECN, Version/IHL
    8'h00, 8'h08                             // Bytes 13,12: EtherType (0x0800)
};

// Word 4: Bytes 16-19 (IP Total Length + Identification)
wire [31:0] hdr_word4 = {
    ip_id_reg[7:0], ip_id_reg[15:8],         // Bytes 19,18: Identification
    total_len_reg[7:0], total_len_reg[15:8]  // Bytes 17,16: IP Total Length
};

// Word 5: Bytes 20-23 (Flags/Frag + TTL + Protocol)
wire [31:0] hdr_word5 = {
    8'h11, 8'h40,                            // Bytes 23,22: Protocol (UDP=17), TTL (64)
    8'h00, 8'h40                             // Bytes 21,20: Frag Offset, Flags (DF)
};

// Word 6: Bytes 24-27 (IP Checksum + Src IP [0:1])
wire [31:0] hdr_word6 = {
    src_ip_reg[23:16], src_ip_reg[31:24],    // Bytes 27,26: Src IP [1:0]
    ip_checksum_reg[7:0], ip_checksum_reg[15:8] // Bytes 25,24: IP Header Checksum
};

// Word 7: Bytes 28-31 (Src IP [2:3])
wire [31:0] hdr_word7 = {
    dst_ip_reg[23:16], dst_ip_reg[31:24],    // Bytes 31,30: Dst IP [1:0]
    src_ip_reg[7:0], src_ip_reg[15:8]        // Bytes 29,28: Src IP [3:2]
};

// Word 8: Bytes 32-35 (Dst IP [2:3] + UDP Src Port)
wire [31:0] hdr_word8 = {
    src_port_reg[7:0], src_port_reg[15:8],   // Bytes 35,34: Src Port
    dst_ip_reg[7:0], dst_ip_reg[15:8]        // Bytes 33,32: Dst IP [3:2]
};

// Word 9: Bytes 36-39 (UDP Dst Port + UDP Length)
wire [31:0] hdr_word9 = {
    udp_len_reg[7:0], udp_len_reg[15:8],     // Bytes 39,38: UDP Length
    dst_port_reg[7:0], dst_port_reg[15:8]    // Bytes 37,36: Dst Port
};

// Word 10 (transition): bytes 40-41 (UDP checksum) + first 2 payload bytes
// This is handled in ST_TRANSITION state

function [2:0] count_ones;
    input [3:0] keep;
    begin
        count_ones = keep[0] + keep[1] + keep[2] + keep[3];
    end
endfunction

always @(posedge iClk) begin
    if (!iRst) begin
        state_reg <= ST_IDLE;

        m_eth_tdata_reg  <= 32'd0;
        m_eth_tkeep_reg  <= 4'd0;
        m_eth_tvalid_reg <= 1'b0;
        m_eth_tlast_reg  <= 1'b0;
        m_eth_tuser_reg  <= 1'b0;

        s_hdr_ready_reg     <= 1'b0;
        s_payload_tready_reg <= 1'b0;
        busy_reg            <= 1'b0;
        error_reg           <= 1'b0;

        payload_len_reg <= 16'd0;
        src_ip_reg      <= 32'd0;
        dst_ip_reg      <= 32'd0;
        src_port_reg    <= 16'd0;
        dst_port_reg    <= 16'd0;
        total_len_reg   <= 16'd0;
        udp_len_reg     <= 16'd0;
        ip_id_reg       <= 16'd1;
        ip_checksum_reg <= 16'd0;

        shift_reg    <= 16'd0;
        shift_count  <= 3'd0;
        shift_valid  <= 1'b0;
        last_pending <= 1'b0;

    end else begin
        // Default: clear single-cycle signals
        error_reg <= 1'b0;

        // Output handshake: clear valid when ready
        if (m_eth_tvalid_reg && m_eth_tready) begin
            m_eth_tvalid_reg <= 1'b0;
            m_eth_tlast_reg  <= 1'b0;
        end

        case (state_reg)
            ST_IDLE: begin
                s_hdr_ready_reg <= 1'b1;
                s_payload_tready_reg <= 1'b0;
                busy_reg <= 1'b0;
                shift_valid <= 1'b0;
                last_pending <= 1'b0;

                if (s_hdr_valid && s_hdr_ready_reg) begin
                    payload_len_reg <= s_payload_len;
                    src_ip_reg      <= s_src_ip;
                    dst_ip_reg      <= s_dst_ip;
                    src_port_reg    <= s_src_port;
                    dst_port_reg    <= s_dst_port;

                    total_len_reg <= 16'd28 + s_payload_len;  // 20 IP + 8 UDP + payload
                    udp_len_reg   <= 16'd8 + s_payload_len;   // 8 UDP + payload

                    s_hdr_ready_reg <= 1'b0;
                    busy_reg <= 1'b1;
                    state_reg <= ST_HDR_0;
                end
            end

            ST_HDR_0: begin
                // Compute checksum (uses latched values)
                ip_checksum_reg <= checksum_final;

                // Output header word 0
                if (!m_eth_tvalid_reg || m_eth_tready) begin
                    m_eth_tdata_reg  <= hdr_word0;
                    m_eth_tkeep_reg  <= 4'hF;
                    m_eth_tvalid_reg <= 1'b1;
                    m_eth_tlast_reg  <= 1'b0;
                    state_reg <= ST_HDR_1;
                end
            end

            ST_HDR_1: begin
                if (!m_eth_tvalid_reg || m_eth_tready) begin
                    m_eth_tdata_reg  <= hdr_word1;
                    m_eth_tkeep_reg  <= 4'hF;
                    m_eth_tvalid_reg <= 1'b1;
                    state_reg <= ST_HDR_2;
                end
            end

            ST_HDR_2: begin
                if (!m_eth_tvalid_reg || m_eth_tready) begin
                    m_eth_tdata_reg  <= hdr_word2;
                    m_eth_tkeep_reg  <= 4'hF;
                    m_eth_tvalid_reg <= 1'b1;
                    state_reg <= ST_HDR_3;
                end
            end

            ST_HDR_3: begin
                if (!m_eth_tvalid_reg || m_eth_tready) begin
                    m_eth_tdata_reg  <= hdr_word3;
                    m_eth_tkeep_reg  <= 4'hF;
                    m_eth_tvalid_reg <= 1'b1;
                    state_reg <= ST_HDR_4;
                end
            end

            ST_HDR_4: begin
                if (!m_eth_tvalid_reg || m_eth_tready) begin
                    m_eth_tdata_reg  <= hdr_word4;
                    m_eth_tkeep_reg  <= 4'hF;
                    m_eth_tvalid_reg <= 1'b1;
                    state_reg <= ST_HDR_5;
                end
            end

            ST_HDR_5: begin
                if (!m_eth_tvalid_reg || m_eth_tready) begin
                    m_eth_tdata_reg  <= hdr_word5;
                    m_eth_tkeep_reg  <= 4'hF;
                    m_eth_tvalid_reg <= 1'b1;
                    state_reg <= ST_HDR_6;
                end
            end

            ST_HDR_6: begin
                if (!m_eth_tvalid_reg || m_eth_tready) begin
                    m_eth_tdata_reg  <= hdr_word6;
                    m_eth_tkeep_reg  <= 4'hF;
                    m_eth_tvalid_reg <= 1'b1;
                    state_reg <= ST_HDR_7;
                end
            end

            ST_HDR_7: begin
                if (!m_eth_tvalid_reg || m_eth_tready) begin
                    m_eth_tdata_reg  <= hdr_word7;
                    m_eth_tkeep_reg  <= 4'hF;
                    m_eth_tvalid_reg <= 1'b1;
                    state_reg <= ST_HDR_8;
                end
            end

            ST_HDR_8: begin
                if (!m_eth_tvalid_reg || m_eth_tready) begin
                    m_eth_tdata_reg  <= hdr_word8;
                    m_eth_tkeep_reg  <= 4'hF;
                    m_eth_tvalid_reg <= 1'b1;
                    state_reg <= ST_HDR_9;
                end
            end

            ST_HDR_9: begin
                if (!m_eth_tvalid_reg || m_eth_tready) begin
                    m_eth_tdata_reg  <= hdr_word9;
                    m_eth_tkeep_reg  <= 4'hF;
                    m_eth_tvalid_reg <= 1'b1;
                    s_payload_tready_reg <= 1'b1;  // Start accepting payload
                    state_reg <= ST_TRANSITION;
                end
            end

            ST_TRANSITION: begin
                // Output: [UDP checksum (bytes 40-41)] + [first 2 payload bytes]
                // Wait for payload to be available
                if ((!m_eth_tvalid_reg || m_eth_tready) && s_payload_tvalid) begin
                    // Combine last 2 header bytes (UDP checksum = 0) + first 2 payload bytes
                    m_eth_tdata_reg <= {
                        s_payload_tdata[15:0],   // First 2 payload bytes
                        8'h00, 8'h00             // UDP checksum = 0
                    };
                    m_eth_tkeep_reg  <= 4'hF;
                    m_eth_tvalid_reg <= 1'b1;

                    // Save top 2 bytes of payload for next cycle
                    shift_reg   <= s_payload_tdata[31:16];
                    shift_count <= 3'd2;
                    shift_valid <= 1'b1;

                    if (s_payload_tlast) begin
                        if (count_ones(s_payload_tkeep) <= 3'd2) begin
                            // Payload fits entirely in this beat
                            m_eth_tlast_reg <= 1'b1;
                            m_eth_tuser_reg <= s_payload_tuser;
                            m_eth_tkeep_reg <= {s_payload_tkeep[1:0], 2'b11};
                            s_payload_tready_reg <= 1'b0;
                            state_reg <= ST_IDLE;
                        end else begin
                            // Need one more cycle to flush shift register
                            last_pending <= 1'b1;
                            shift_count <= count_ones(s_payload_tkeep) - 3'd2;
                            s_payload_tready_reg <= 1'b0;
                            state_reg <= ST_PAYLOAD;
                        end
                    end else begin
                        state_reg <= ST_PAYLOAD;
                    end
                end
            end

            ST_PAYLOAD: begin
                if (!m_eth_tvalid_reg || m_eth_tready) begin
                    if (last_pending) begin
                        // Flush remaining bytes from shift register
                        m_eth_tdata_reg  <= {16'd0, shift_reg};
                        m_eth_tkeep_reg  <= (4'hF >> (3'd4 - shift_count));
                        m_eth_tvalid_reg <= 1'b1;
                        m_eth_tlast_reg  <= 1'b1;
                        m_eth_tuser_reg  <= 1'b0;
                        last_pending     <= 1'b0;
                        state_reg        <= ST_IDLE;

                    end else if (s_payload_tvalid) begin
                        // Normal payload: combine shift_reg + new data
                        m_eth_tdata_reg  <= {s_payload_tdata[15:0], shift_reg};
                        m_eth_tkeep_reg  <= 4'hF;
                        m_eth_tvalid_reg <= 1'b1;

                        // Update shift register
                        shift_reg <= s_payload_tdata[31:16];

                        if (s_payload_tlast) begin
                            s_payload_tready_reg <= 1'b0;

                            if (count_ones(s_payload_tkeep) <= 3'd2) begin
                                // Remaining payload fits in this word
                                m_eth_tkeep_reg <= {s_payload_tkeep[1:0], 2'b11};
                                m_eth_tlast_reg <= 1'b1;
                                m_eth_tuser_reg <= s_payload_tuser;
                                state_reg <= ST_IDLE;
                            end else begin
                                // Need one more cycle
                                last_pending <= 1'b1;
                                shift_count <= count_ones(s_payload_tkeep) - 3'd2;
                            end
                        end
                    end
                end
            end

            default: state_reg <= ST_IDLE;
        endcase

        // Increment IP ID after packet completes
        if (m_eth_tvalid_reg && m_eth_tready && m_eth_tlast_reg) begin
            ip_id_reg <= ip_id_reg + 16'd1;
        end
    end
end

endmodule
