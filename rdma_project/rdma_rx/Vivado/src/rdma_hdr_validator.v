`timescale 1ns/1ps
// ============================================================================
// Module: rdma_hdr_validator
// Description: Validates extracted RX headers (mirrors TX rdma_meta_validator)
//              Separates validation from streaming for cleaner architecture
//
// Flow: ip_eth_rx_64_rdma extracts headers -> rdma_hdr_validator validates
//       -> validated headers to control logic
// ============================================================================
module rdma_hdr_validator #(
    parameter [47:0] LOCAL_MAC  = 48'h000A35010203,
    parameter [15:0] LOCAL_PORT = 16'd5005
)(
    input  wire        clk,
    input  wire        rst_n,      // Active-low reset (matches TX convention)

    // Raw extracted headers from streaming RX (from ip_eth_rx_64_rdma)
    input  wire [47:0] i_dst_mac,
    input  wire [47:0] i_src_mac,
    input  wire [15:0] i_ethertype,
    input  wire [3:0]  i_ip_version,
    input  wire [3:0]  i_ip_ihl,
    input  wire [7:0]  i_ip_protocol,
    input  wire [15:0] i_ip_total_len,
    input  wire [15:0] i_ip_checksum,
    input  wire [31:0] i_src_ip,
    input  wire [31:0] i_dst_ip,
    input  wire [15:0] i_src_port,
    input  wire [15:0] i_dst_port,
    input  wire [15:0] i_udp_len,
    input  wire [31:0] i_checksum_accum,  // Pre-computed checksum accumulator
    input  wire        i_hdr_valid,       // Pulse when headers ready
    output reg         o_hdr_ready,       // Ready to accept headers

    // Validated header output (to control registers)
    output reg  [31:0] o_src_ip,
    output reg  [31:0] o_dst_ip,
    output reg  [15:0] o_src_port,
    output reg  [15:0] o_dst_port,
    output reg  [15:0] o_payload_len,
    output reg         o_valid,           // Validated headers available
    input  wire        i_ready,           // Downstream ready

    // Error signaling
    output reg         o_error,
    output reg  [3:0]  o_error_code
);

    // Internal reset (active high)
    wire rst = ~rst_n;

    // Error codes (matches TX convention)
    localparam [3:0] ERR_NONE           = 4'd0,
                     ERR_MAC_MISMATCH   = 4'd1,
                     ERR_NOT_IPV4       = 4'd2,
                     ERR_IP_VERSION     = 4'd3,
                     ERR_IP_OPTIONS     = 4'd4,
                     ERR_IP_CHECKSUM    = 4'd5,
                     ERR_NOT_UDP        = 4'd6,
                     ERR_PORT_MISMATCH  = 4'd7,
                     ERR_LENGTH         = 4'd8,
                     ERR_FRAME_ERROR    = 4'd9;

    // FSM States (mirrors TX rdma_meta_validator)
    localparam [1:0] IDLE     = 2'b00,
                     VALIDATE = 2'b01,
                     FORWARD  = 2'b10,
                     ERROR_ST = 2'b11;

    reg [1:0] state;

    // Latched input headers for validation
    reg [47:0] lat_dst_mac;
    reg [47:0] lat_src_mac;
    reg [15:0] lat_ethertype;
    reg [3:0]  lat_ip_version;
    reg [3:0]  lat_ip_ihl;
    reg [7:0]  lat_ip_protocol;
    reg [15:0] lat_ip_total_len;
    reg [31:0] lat_checksum_accum;
    reg [31:0] lat_src_ip;
    reg [31:0] lat_dst_ip;
    reg [15:0] lat_src_port;
    reg [15:0] lat_dst_port;
    reg [15:0] lat_udp_len;

    // Validation checks (combinational)
    wire mac_match      = (lat_dst_mac == LOCAL_MAC) || (lat_dst_mac == 48'hFFFFFFFFFFFF);
    wire ethertype_ok   = (lat_ethertype == 16'h0800);
    wire ip_version_ok  = (lat_ip_version == 4'd4);
    wire ip_ihl_ok      = (lat_ip_ihl == 4'd5);
    wire ip_protocol_ok = (lat_ip_protocol == 8'h11);  // UDP
    wire udp_port_ok    = (lat_dst_port == LOCAL_PORT);
    wire length_ok      = (lat_ip_total_len >= 16'd28);  // Min: 20 IP + 8 UDP

    // IP checksum validation (fold 32->16 with carry)
    wire [31:0] cksum_fold1 = lat_checksum_accum[15:0] + lat_checksum_accum[31:16];
    wire [15:0] cksum_final = cksum_fold1[15:0] + cksum_fold1[16];
    wire cksum_valid = (cksum_final == 16'hFFFF);

    wire all_valid = mac_match && ethertype_ok && ip_version_ok && ip_ihl_ok &&
                     ip_protocol_ok && cksum_valid && udp_port_ok && length_ok;

    // Payload length (UDP length - 8 byte header)
    wire [15:0] payload_len = lat_udp_len - 16'd8;

    // Error code determination
    function [3:0] get_error_code;
        input mac_ok, etype_ok, ipver_ok, ihl_ok, proto_ok, cksum_ok, port_ok, len_ok;
        begin
            if (!mac_ok)        get_error_code = ERR_MAC_MISMATCH;
            else if (!etype_ok) get_error_code = ERR_NOT_IPV4;
            else if (!ipver_ok) get_error_code = ERR_IP_VERSION;
            else if (!ihl_ok)   get_error_code = ERR_IP_OPTIONS;
            else if (!cksum_ok) get_error_code = ERR_IP_CHECKSUM;
            else if (!proto_ok) get_error_code = ERR_NOT_UDP;
            else if (!port_ok)  get_error_code = ERR_PORT_MISMATCH;
            else if (!len_ok)   get_error_code = ERR_LENGTH;
            else                get_error_code = ERR_NONE;
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            state           <= IDLE;
            o_hdr_ready     <= 1'b0;
            o_valid         <= 1'b0;
            o_error         <= 1'b0;
            o_error_code    <= ERR_NONE;
            o_src_ip        <= 32'd0;
            o_dst_ip        <= 32'd0;
            o_src_port      <= 16'd0;
            o_dst_port      <= 16'd0;
            o_payload_len   <= 16'd0;

            lat_dst_mac     <= 48'd0;
            lat_src_mac     <= 48'd0;
            lat_ethertype   <= 16'd0;
            lat_ip_version  <= 4'd0;
            lat_ip_ihl      <= 4'd0;
            lat_ip_protocol <= 8'd0;
            lat_ip_total_len <= 16'd0;
            lat_checksum_accum <= 32'd0;
            lat_src_ip      <= 32'd0;
            lat_dst_ip      <= 32'd0;
            lat_src_port    <= 16'd0;
            lat_dst_port    <= 16'd0;
            lat_udp_len     <= 16'd0;

        end else begin
            case (state)
                IDLE: begin
                    o_hdr_ready  <= 1'b1;
                    o_valid      <= 1'b0;
                    o_error      <= 1'b0;
                    o_error_code <= ERR_NONE;

                    if (i_hdr_valid && o_hdr_ready) begin
                        // Latch all input headers
                        lat_dst_mac     <= i_dst_mac;
                        lat_src_mac     <= i_src_mac;
                        lat_ethertype   <= i_ethertype;
                        lat_ip_version  <= i_ip_version;
                        lat_ip_ihl      <= i_ip_ihl;
                        lat_ip_protocol <= i_ip_protocol;
                        lat_ip_total_len <= i_ip_total_len;
                        lat_checksum_accum <= i_checksum_accum;
                        lat_src_ip      <= i_src_ip;
                        lat_dst_ip      <= i_dst_ip;
                        lat_src_port    <= i_src_port;
                        lat_dst_port    <= i_dst_port;
                        lat_udp_len     <= i_udp_len;

                        o_hdr_ready <= 1'b0;
                        state <= VALIDATE;
                    end
                end

                VALIDATE: begin
                    if (all_valid) begin
                        // Pass validated headers to output
                        o_src_ip      <= lat_src_ip;
                        o_dst_ip      <= lat_dst_ip;
                        o_src_port    <= lat_src_port;
                        o_dst_port    <= lat_dst_port;
                        o_payload_len <= payload_len;
                        o_valid       <= 1'b1;
                        state         <= FORWARD;
                    end else begin
                        o_error      <= 1'b1;
                        o_error_code <= get_error_code(mac_match, ethertype_ok, ip_version_ok,
                                                       ip_ihl_ok, ip_protocol_ok, cksum_valid,
                                                       udp_port_ok, length_ok);
                        state        <= ERROR_ST;
                    end
                end

                FORWARD: begin
                    if (i_ready && o_valid) begin
                        o_valid <= 1'b0;
                        state   <= IDLE;
                    end
                end

                ERROR_ST: begin
                    // Hold error for one cycle, then return to idle
                    o_error <= 1'b0;
                    state   <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
