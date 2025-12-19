`timescale 1ns/1ps
// ============================================================================
// Module: rdma_ip_encap_integrated
// ============================================================================
module rdma_ip_encap_integrated #(
    parameter [47:0] SRC_MAC = 48'h123456789ABC,
    parameter [47:0] DST_MAC = 48'h000A35010203
)(
    input  wire        iClk,
    input  wire        iRst,
    
    // Metadata Input (from PS or test logic)
    input  wire [15:0] i_meta_payload_len,
    input  wire [31:0] i_meta_src_ip,
    input  wire [31:0] i_meta_dst_ip,
    input  wire [15:0] i_meta_src_port,
    input  wire [15:0] i_meta_dst_port,
    input  wire [7:0]  i_meta_flags,
    input  wire [7:0]  i_meta_endpoint_id,
    input  wire        i_meta_valid,
    output wire        o_meta_ready,
    
    // Payload Input (AXI-Stream 32-bit)
    input  wire [31:0] i_payload_axis_tdata,
    input  wire [3:0]  i_payload_axis_tkeep,
    input  wire        i_payload_axis_tvalid,
    output wire        o_payload_axis_tready,
    input  wire        i_payload_axis_tlast,
    input  wire        i_payload_axis_tuser,

    // Ethernet Frame Output (AXI-Stream 32-bit)
    output wire [31:0] o_axis_tdata,
    output wire [3:0]  o_axis_tkeep,
    output wire        o_axis_tvalid,
    input  wire        i_axis_tready,
    output wire        o_axis_tlast,
    output wire        o_axis_tuser,
    
    // Status
    output wire        o_error,
    output wire [3:0]  o_error_code,
    output wire        o_busy,

    // Debug
    output wire [2:0]  o_debug_state
);

// Internal Signals: Validator → Streaming TX
wire [15:0] w_val_payload_len;
wire [31:0] w_val_src_ip;
wire [31:0] w_val_dst_ip;
wire [15:0] w_val_src_port;
wire [15:0] w_val_dst_port;
wire [7:0]  w_val_flags;
wire [7:0]  w_val_endpoint_id;
wire        w_val_valid;
wire        w_val_ready;

//Metadata Validator
rdma_meta_validator u_validator (
    .iClk(iClk),
    .iRst(iRst),
    
    // Raw metadata input
    .i_payload_len(i_meta_payload_len),
    .i_src_ip(i_meta_src_ip),
    .i_dst_ip(i_meta_dst_ip),
    .i_src_port(i_meta_src_port),
    .i_dst_port(i_meta_dst_port),
    .i_flags(i_meta_flags),
    .i_endpoint_id(i_meta_endpoint_id),
    .i_valid(i_meta_valid),
    .o_ready(o_meta_ready),
    
    // Validated metadata output
    .o_payload_len(w_val_payload_len),
    .o_src_ip(w_val_src_ip),
    .o_dst_ip(w_val_dst_ip),
    .o_src_port(w_val_src_port),
    .o_dst_port(w_val_dst_port),
    .o_flags(w_val_flags),
    .o_endpoint_id(w_val_endpoint_id),
    .o_valid(w_val_valid),
    .i_ready(w_val_ready),
    
    // Error signaling
    .o_error(o_error),
    .o_error_code(o_error_code)
);

//Streaming IP/UDP/Ethernet Transmitter
ip_eth_tx_64_rdma #(
    .SRC_MAC(SRC_MAC),
    .DST_MAC(DST_MAC)
) u_streaming_tx (
    .iClk(iClk),
    .iRst(iRst),
    
    // Validated header input
    .s_hdr_valid(w_val_valid),
    .s_hdr_ready(w_val_ready),
    .s_payload_len(w_val_payload_len),
    .s_src_ip(w_val_src_ip),
    .s_dst_ip(w_val_dst_ip),
    .s_src_port(w_val_src_port),
    .s_dst_port(w_val_dst_port),
    
    // Payload input (direct from top-level)
    .s_payload_tdata(i_payload_axis_tdata),
    .s_payload_tkeep(i_payload_axis_tkeep),
    .s_payload_tvalid(i_payload_axis_tvalid),
    .s_payload_tready(o_payload_axis_tready),
    .s_payload_tlast(i_payload_axis_tlast),
    .s_payload_tuser(i_payload_axis_tuser),
    
    // Ethernet output
    .m_eth_tdata(o_axis_tdata),
    .m_eth_tkeep(o_axis_tkeep),
    .m_eth_tvalid(o_axis_tvalid),
    .m_eth_tready(i_axis_tready),
    .m_eth_tlast(o_axis_tlast),
    .m_eth_tuser(o_axis_tuser),
    
    // Status
    .busy(o_busy),
    .error_payload_early_termination(),

    // Debug
    .o_debug_state(o_debug_state)
);

endmodule