`timescale 1ns / 1ps

// -----------------------------------------------------------------------------
// ip_encapsulator_simple.v - MODIFIED VERSION
//
// Metadata is now received as the first 5 words of the AXI stream:
//   Word 0: SRC_IP
//   Word 1: DST_IP
//   Word 2: PAYLOAD_LEN (lower 16 bits)
//   Word 3: SRC_PORT (lower 16 bits)
//   Word 4: DST_PORT (lower 16 bits)
//
// After receiving 5 metadata words, s_axis_tready goes low while headers
// are built. Once headers are ready, s_axis_tready goes high again to
// receive the payload.
// -----------------------------------------------------------------------------

module ip_encapsulator_simple #(
    parameter DATA_WIDTH = 32
)(
    input  wire                     clk,
    input  wire                     rstn,  // active-LOW reset

    // AXI-Stream input (32-bit) - first 5 words are metadata, then payload
    input  wire [DATA_WIDTH-1:0]    s_axis_tdata,
    input  wire [DATA_WIDTH/8-1:0]  s_axis_tkeep,
    input  wire                     s_axis_tvalid,
    output wire                     s_axis_tready,
    input  wire                     s_axis_tlast,

    // AXI-Stream frame output (32-bit)
    output wire [DATA_WIDTH-1:0]    m_axis_tdata,
    output wire [DATA_WIDTH/8-1:0]  m_axis_tkeep,
    output wire                     m_axis_tvalid,
    input  wire                     m_axis_tready,
    output wire                     m_axis_tlast,

    // External endpoint lookup interface
    output wire [31:0]              lookup_dst_ip,
    output wire                     lookup_valid,
    input  wire                     lookup_ready,
    input  wire                     lookup_done,
    input  wire                     lookup_hit,
    input  wire                     lookup_error,
    input  wire [47:0]              dst_mac,
    input  wire [47:0]              src_mac,
    output wire [159:0]             ipv4_w_debug
);

    localparam KEEP_WIDTH = DATA_WIDTH / 8;
    localparam META_WORDS = 5;

    // -------------------------------------------------------------------------
    // Registered metadata - extracted from first 5 stream words
    // -------------------------------------------------------------------------
    reg [31:0] meta_src_ip_r;
    reg [31:0] meta_dst_ip_r;
    reg [15:0] meta_src_port_r;
    reg [15:0] meta_dst_port_r;
    reg [15:0] meta_payload_len_r;


   // -------------------------------------------------------------------------
    // Payload handshake
    // -------------------------------------------------------------------------
    wire [DATA_WIDTH-1:0]  payload_tdata  = s_axis_tdata;
    wire [KEEP_WIDTH-1:0]  payload_tkeep  = s_axis_tkeep;
    wire                   payload_tlast  = s_axis_tlast;
    wire                   payload_tvalid;

    // -------------------------------------------------------------------------
    // Metadata word counter
    // -------------------------------------------------------------------------
    reg [2:0] meta_word_cnt;

    // -------------------------------------------------------------------------
    // Computed lengths (combinational)
    // -------------------------------------------------------------------------
    wire [15:0] ip_total_length = 16'd20 + 16'd8 + meta_payload_len_r;  // IP + UDP + payload
    wire [15:0] udp_length      = 16'd8 + meta_payload_len_r;           // UDP + payload

    // -------------------------------------------------------------------------
    // State machine for header generation
    // -------------------------------------------------------------------------
    localparam [2:0] ST_IDLE      = 3'd0;
    localparam [2:0] ST_RECV_META = 3'd1;  // Receive 5 metadata words
    localparam [2:0] ST_WAIT_HDR  = 3'd2;  // Wait for all headers valid
    localparam [2:0] ST_PACKING   = 3'd3;  // header_packer is outputting
    localparam [2:0] ST_PAYLOAD   = 3'd4;  // Streaming payload

    reg [2:0] state;

    // -------------------------------------------------------------------------
    // Header storage
    // -------------------------------------------------------------------------
    reg [159:0] ipv4_hdr;
    reg         ipv4_hdr_valid;
    wire        ipv4_hdr_ready;

    reg [63:0]  udp_hdr;
    reg         udp_hdr_valid;
    wire        udp_hdr_ready;

    reg [111:0] eth_hdr;
    reg         eth_hdr_valid;
    wire        eth_hdr_ready;

    // -------------------------------------------------------------------------
    // IPv4 checksum calculation (combinational)
    // -------------------------------------------------------------------------
    wire [15:0] ipv4_w [0:9];
    assign ipv4_w[0] = 16'h4500;                           // Version=4, IHL=5, TOS=0
    assign ipv4_w[1] = ip_total_length;
    assign ipv4_w[2] = 16'h0000;                           // ID
    assign ipv4_w[3] = 16'h0000;                           // Flags/Frag
    assign ipv4_w[4] = {8'd64, 8'd17};                     // TTL=64, Protocol=UDP
    assign ipv4_w[5] = 16'h0000;                           // Checksum placeholder
    assign ipv4_w[6] = meta_src_ip_r[31:16];
    assign ipv4_w[7] = meta_src_ip_r[15:0];
    assign ipv4_w[8] = meta_dst_ip_r[31:16];
    assign ipv4_w[9] = meta_dst_ip_r[15:0];
    assign ipv4_w_debug = {
    ipv4_w[0],
    ipv4_w[1],
    ipv4_w[2],
    ipv4_w[3],
    ipv4_w[4],
    ipv4_w[5],
    ipv4_w[6],
    ipv4_w[7],
    ipv4_w[8],
    ipv4_w[9]
};

    wire [31:0] ipv4_sum = ipv4_w[0] + ipv4_w[1] + ipv4_w[2] + ipv4_w[3] + ipv4_w[4] +
                           ipv4_w[5] + ipv4_w[6] + ipv4_w[7] + ipv4_w[8] + ipv4_w[9];
    wire [16:0] ipv4_sum_fold = {1'b0, ipv4_sum[15:0]} + {1'b0, ipv4_sum[31:16]};
    wire [15:0] ipv4_sum_final = ipv4_sum_fold[15:0] + {15'b0, ipv4_sum_fold[16]};
    wire [15:0] ipv4_checksum = ~ipv4_sum_final;

    // -------------------------------------------------------------------------
    // Lookup interface - triggered after metadata is received
    // -------------------------------------------------------------------------
    reg lookup_triggered;
    assign lookup_dst_ip = meta_dst_ip_r;
    assign lookup_valid  = (state == ST_WAIT_HDR) && !lookup_triggered && lookup_ready;

    // -------------------------------------------------------------------------
    // s_axis_tready logic
    // Ready during metadata reception and payload phases only
    // -------------------------------------------------------------------------
    wire meta_phase_ready = (state == ST_IDLE) || (state == ST_RECV_META);
    wire payload_window   = (state == ST_PACKING) || (state == ST_PAYLOAD);
    wire payload_tready;
    
    assign s_axis_tready = meta_phase_ready ? 1'b1 : (payload_window ? payload_tready : 1'b0);

    // -------------------------------------------------------------------------
    // Main state machine
    // -------------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rstn) begin
            state              <= ST_IDLE;
            meta_word_cnt      <= 3'd0;
            meta_src_ip_r      <= 32'h0;
            meta_dst_ip_r      <= 32'h0;
            meta_src_port_r    <= 16'h0;
            meta_dst_port_r    <= 16'h0;
            meta_payload_len_r <= 16'h0;
            ipv4_hdr           <= 160'h0;
            ipv4_hdr_valid     <= 1'b0;
            udp_hdr            <= 64'h0;
            udp_hdr_valid      <= 1'b0;
            eth_hdr            <= 112'h0;
            eth_hdr_valid      <= 1'b0;
            lookup_triggered   <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    ipv4_hdr_valid   <= 1'b0;
                    udp_hdr_valid    <= 1'b0;
                    eth_hdr_valid    <= 1'b0;
                    meta_word_cnt    <= 3'd0;
                    lookup_triggered <= 1'b0;

                    // Wait for first metadata word
                    if (s_axis_tvalid && s_axis_tready) begin
                        meta_src_ip_r <= s_axis_tdata;
                        meta_word_cnt <= 3'd1;
                        state <= ST_RECV_META;
                    end
                end

                ST_RECV_META: begin
                    // Receive remaining metadata words (words 1-4)
                    if (s_axis_tvalid && s_axis_tready) begin
                        case (meta_word_cnt)
                            3'd1: meta_dst_ip_r      <= s_axis_tdata;
                            3'd2: meta_payload_len_r <= s_axis_tdata[15:0];
                            3'd3: meta_src_port_r    <= s_axis_tdata[15:0];
                            3'd4: meta_dst_port_r    <= s_axis_tdata[15:0];
                            default: ;
                        endcase

                        if (meta_word_cnt == META_WORDS - 1) begin
                            // All metadata received, go build headers
                            state <= ST_WAIT_HDR;
                        end else begin
                            meta_word_cnt <= meta_word_cnt + 1'b1;
                        end
                    end
                end

                ST_WAIT_HDR: begin
                    // Trigger lookup once
                    if (lookup_valid && lookup_ready) begin
                        lookup_triggered <= 1'b1;
                    end

                    // Build IPv4 header
                    if (!ipv4_hdr_valid) begin
                        ipv4_hdr <= {
                            8'h45,                    // byte 0: Version/IHL
                            8'h00,                    // byte 1: DSCP/ECN
                            ip_total_length,          // bytes 2-3: Total Length
                            16'h0000,                 // bytes 4-5: ID
                            16'h0000,                 // bytes 6-7: Flags/FragOffset
                            8'd64,                    // byte 8: TTL
                            8'd17,                    // byte 9: Protocol (UDP)
                            ipv4_checksum,            // bytes 10-11: Checksum
                            meta_src_ip_r,            // bytes 12-15: Src IP
                            meta_dst_ip_r             // bytes 16-19: Dst IP
                        };
                        ipv4_hdr_valid <= 1'b1;
                    end

                    // Build UDP header
                    if (!udp_hdr_valid) begin
                        udp_hdr <= {
                            meta_src_port_r,          // bytes 0-1: Src Port
                            meta_dst_port_r,          // bytes 2-3: Dst Port
                            udp_length,               // bytes 4-5: Length
                            16'h0000                  // bytes 6-7: Checksum (0 = not used)
                        };
                        udp_hdr_valid <= 1'b1;
                    end

                    // Build Ethernet header when lookup completes
                    if (lookup_done && !eth_hdr_valid) begin
                        eth_hdr <= {dst_mac, src_mac, 16'h0800};  // EtherType = IPv4
                        eth_hdr_valid <= 1'b1;
                    end

                    // Transition when all headers ready
                    if (ipv4_hdr_valid && udp_hdr_valid && eth_hdr_valid) begin
                        state <= ST_PACKING;
                    end
                end

                ST_PACKING: begin
                    // header_packer will consume headers
                    if (ipv4_hdr_valid && ipv4_hdr_ready) begin
                        ipv4_hdr_valid <= 1'b0;
                    end
                    if (udp_hdr_valid && udp_hdr_ready) begin
                        udp_hdr_valid <= 1'b0;
                    end
                    if (eth_hdr_valid && eth_hdr_ready) begin
                        eth_hdr_valid <= 1'b0;
                    end

                    // Move to payload state once headers consumed
                    if (!ipv4_hdr_valid && !udp_hdr_valid && !eth_hdr_valid) begin
                        state <= ST_PAYLOAD;
                    end
                end

                ST_PAYLOAD: begin
                    // Wait for packet completion
                    if (payload_tvalid && payload_tready && payload_tlast) begin
                        state <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end
    

 
    assign payload_tvalid = s_axis_tvalid & payload_window;

    // -------------------------------------------------------------------------
    // header_packer
    // -------------------------------------------------------------------------
    header_packer #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_header_packer (
        .clk                  (clk),
        .rstn                 (rstn),

        .eth_header           (eth_hdr),
        .eth_header_valid     (eth_hdr_valid),
        .eth_header_ready     (eth_hdr_ready),

        .ip_header            (ipv4_hdr),
        .ip_header_valid      (ipv4_hdr_valid),
        .ip_header_ready      (ipv4_hdr_ready),

        .udp_header           (udp_hdr),
        .udp_header_valid     (udp_hdr_valid),
        .udp_header_ready     (udp_hdr_ready),

        .payload_length_bytes (meta_payload_len_r),
        .length_valid         (1'b1),
        .length_ready         (),

        .payload_in           (payload_tdata),
        .payload_in_keep      (payload_tkeep),
        .payload_valid        (payload_tvalid),
        .payload_ready        (payload_tready),
        .payload_last         (payload_tlast),

        .m_axis_tdata         (m_axis_tdata),
        .m_axis_tkeep         (m_axis_tkeep),
        .m_axis_tvalid        (m_axis_tvalid),
        .m_axis_tready        (m_axis_tready),
        .m_axis_tlast         (m_axis_tlast)
    );

endmodule