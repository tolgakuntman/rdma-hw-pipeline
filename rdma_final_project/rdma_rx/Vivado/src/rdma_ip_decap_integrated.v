`timescale 1ns/1ps
// ============================================================================
// Module: rdma_ip_decap_integrated
// Description: Receives Ethernet frames and extracts payload + headers
//              Mirrors TX rdma_ip_encap_integrated architecture:
//              [Streaming RX] -> [Header Validator] -> outputs
// ============================================================================
module rdma_ip_decap_integrated #(
    parameter [47:0] LOCAL_MAC  = 48'h000A35010203,
    parameter [15:0] LOCAL_PORT = 16'd5005
)(
    input  wire        iClk,
    input  wire        iRst,        // Active-low reset

    // Ethernet Frame Input (AXI-Stream 32-bit, from MAC or loopback)
    input  wire [31:0] i_eth_axis_tdata,
    input  wire [3:0]  i_eth_axis_tkeep,
    input  wire        i_eth_axis_tvalid,
    output wire        o_eth_axis_tready,
    input  wire        i_eth_axis_tlast,
    input  wire        i_eth_axis_tuser,

    // Payload Output (AXI-Stream 32-bit, to DMA or processing)
    output wire [31:0] o_payload_axis_tdata,
    output wire [3:0]  o_payload_axis_tkeep,
    output wire        o_payload_axis_tvalid,
    input  wire        i_payload_axis_tready,
    output wire        o_payload_axis_tlast,
    output wire        o_payload_axis_tuser,

    // Validated Header Output (active with o_hdr_valid pulse)
    output wire [31:0] o_hdr_src_ip,
    output wire [31:0] o_hdr_dst_ip,
    output wire [15:0] o_hdr_src_port,
    output wire [15:0] o_hdr_dst_port,
    output wire [15:0] o_hdr_payload_len,
    output wire        o_hdr_valid,

    // Status
    output wire        o_busy,
    output wire        o_error,
    output wire [3:0]  o_error_code,

    // Statistics
    output wire        o_stat_pkt_received,
    output wire        o_stat_pkt_dropped,

    // Debug
    output wire [2:0]  o_debug_state
);

// ============================================================================
// Internal Signals: Streaming RX -> Validator
// ============================================================================

// Raw extracted headers from streaming RX
wire [47:0] w_raw_dst_mac;
wire [47:0] w_raw_src_mac;
wire [15:0] w_raw_ethertype;
wire [3:0]  w_raw_ip_version;
wire [3:0]  w_raw_ip_ihl;
wire [7:0]  w_raw_ip_protocol;
wire [15:0] w_raw_ip_total_len;
wire [31:0] w_raw_src_ip;
wire [31:0] w_raw_dst_ip;
wire [15:0] w_raw_src_port;
wire [15:0] w_raw_dst_port;
wire [15:0] w_raw_udp_len;
wire [31:0] w_raw_checksum_accum;
wire [15:0] w_raw_payload_len;
wire        w_raw_hdr_valid;
wire        w_raw_hdr_ready;

// Validator -> Streaming RX control
wire        w_packet_accept;
wire        w_packet_drop;

// Validator outputs
wire [31:0] w_val_src_ip;
wire [31:0] w_val_dst_ip;
wire [15:0] w_val_src_port;
wire [15:0] w_val_dst_port;
wire [15:0] w_val_payload_len;
wire        w_val_valid;
wire        w_val_error;
wire [3:0]  w_val_error_code;

// ============================================================================
// Streaming RX: Extracts headers and payload from Ethernet frames
// ============================================================================
ip_eth_rx_64_rdma u_streaming_rx (
    .iClk(iClk),
    .iRst(iRst),

    // Ethernet frame input
    .s_eth_tdata(i_eth_axis_tdata),
    .s_eth_tkeep(i_eth_axis_tkeep),
    .s_eth_tvalid(i_eth_axis_tvalid),
    .s_eth_tready(o_eth_axis_tready),
    .s_eth_tlast(i_eth_axis_tlast),
    .s_eth_tuser(i_eth_axis_tuser),

    // Payload output
    .m_payload_tdata(o_payload_axis_tdata),
    .m_payload_tkeep(o_payload_axis_tkeep),
    .m_payload_tvalid(o_payload_axis_tvalid),
    .m_payload_tready(i_payload_axis_tready),
    .m_payload_tlast(o_payload_axis_tlast),
    .m_payload_tuser(o_payload_axis_tuser),

    // Raw extracted headers to validator
    .m_hdr_dst_mac(w_raw_dst_mac),
    .m_hdr_src_mac(w_raw_src_mac),
    .m_hdr_ethertype(w_raw_ethertype),
    .m_hdr_ip_version(w_raw_ip_version),
    .m_hdr_ip_ihl(w_raw_ip_ihl),
    .m_hdr_ip_protocol(w_raw_ip_protocol),
    .m_hdr_ip_total_len(w_raw_ip_total_len),
    .m_hdr_src_ip(w_raw_src_ip),
    .m_hdr_dst_ip(w_raw_dst_ip),
    .m_hdr_src_port(w_raw_src_port),
    .m_hdr_dst_port(w_raw_dst_port),
    .m_hdr_udp_len(w_raw_udp_len),
    .m_hdr_checksum_accum(w_raw_checksum_accum),
    .m_hdr_payload_len(w_raw_payload_len),
    .m_hdr_valid(w_raw_hdr_valid),
    .m_hdr_ready(w_raw_hdr_ready),

    // Control signals from validator
    .i_packet_accept(w_packet_accept),
    .i_packet_drop(w_packet_drop),

    // Status
    .busy(o_busy),
    .o_debug_state(o_debug_state),

    // Statistics
    .stat_pkt_received(o_stat_pkt_received),
    .stat_pkt_dropped(o_stat_pkt_dropped)
);

// ============================================================================
// Header Validator: Validates extracted headers (mirrors TX meta_validator)
// ============================================================================
rdma_hdr_validator #(
    .LOCAL_MAC(LOCAL_MAC),
    .LOCAL_PORT(LOCAL_PORT)
) u_validator (
    .clk(iClk),
    .rst_n(iRst),

    // Raw extracted headers from streaming RX
    .i_dst_mac(w_raw_dst_mac),
    .i_src_mac(w_raw_src_mac),
    .i_ethertype(w_raw_ethertype),
    .i_ip_version(w_raw_ip_version),
    .i_ip_ihl(w_raw_ip_ihl),
    .i_ip_protocol(w_raw_ip_protocol),
    .i_ip_total_len(w_raw_ip_total_len),
    .i_ip_checksum(16'd0),  // Not used directly, checksum_accum used instead
    .i_src_ip(w_raw_src_ip),
    .i_dst_ip(w_raw_dst_ip),
    .i_src_port(w_raw_src_port),
    .i_dst_port(w_raw_dst_port),
    .i_udp_len(w_raw_udp_len),
    .i_checksum_accum(w_raw_checksum_accum),
    .i_hdr_valid(w_raw_hdr_valid),
    .o_hdr_ready(w_raw_hdr_ready),

    // Validated header output (to control logic)
    .o_src_ip(w_val_src_ip),
    .o_dst_ip(w_val_dst_ip),
    .o_src_port(w_val_src_port),
    .o_dst_port(w_val_dst_port),
    .o_payload_len(w_val_payload_len),
    .o_valid(w_val_valid),
    .i_ready(1'b1),  // Always ready to accept validated headers

    // Error signaling
    .o_error(w_val_error),
    .o_error_code(w_val_error_code)
);

// ============================================================================
// Control Signal Generation
// ============================================================================

// Generate accept/drop signals from validator state
// Accept when validator outputs valid headers
// Drop when validator signals error
assign w_packet_accept = w_val_valid;
assign w_packet_drop   = w_val_error;

// Output validated headers
assign o_hdr_src_ip      = w_val_src_ip;
assign o_hdr_dst_ip      = w_val_dst_ip;
assign o_hdr_src_port    = w_val_src_port;
assign o_hdr_dst_port    = w_val_dst_port;
assign o_hdr_payload_len = w_val_payload_len;
assign o_hdr_valid       = w_val_valid;

// Error outputs from validator
assign o_error      = w_val_error;
assign o_error_code = w_val_error_code;

endmodule
