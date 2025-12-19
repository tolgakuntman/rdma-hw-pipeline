`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// ip_decapsulator.v
// Top-level RX wrapper: Receives Ethernet frames, strips headers, outputs payload
//
// This is the receive counterpart to ip_encapsulator.v
//
// Features:
//  - Parse Ethernet/IP/UDP headers
//  - Validate packet structure
//  - Extract metadata (src/dst IP, ports)
//  - Forward pure UDP payload to RDMA layer
//  - Statistics via AXI-Lite
//////////////////////////////////////////////////////////////////////////////////

module ip_decapsulator #(
    parameter DATA_WIDTH = 64,
    parameter KEEP_WIDTH = DATA_WIDTH/8
)(
    input  wire                     clk,
    input  wire                     rstn,
    
    // AXI-Stream input (from Ethernet MAC RX)
    input  wire [DATA_WIDTH-1:0]    s_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]    s_axis_tkeep,
    input  wire                     s_axis_tvalid,
    output wire                     s_axis_tready,
    input  wire                     s_axis_tlast,
    
    // AXI-Stream output (payload to RDMA)
    output wire [DATA_WIDTH-1:0]    m_axis_tdata,
    output wire [KEEP_WIDTH-1:0]    m_axis_tkeep,
    output wire                     m_axis_tvalid,
    input  wire                     m_axis_tready,
    output wire                     m_axis_tlast,
    
    // Metadata output (to RDMA layer)
    /*
    output wire [META_WIDTH-1:0]    meta_out,
    output wire                     meta_valid,
    input  wire                     meta_ready,
    */
    
    // AXI4-Lite slave (control/status)
    input  wire [31:0]              s_axi_awaddr,
    input  wire                     s_axi_awvalid,
    output wire                     s_axi_awready,
    input  wire [31:0]              s_axi_wdata,
    input  wire [3:0]               s_axi_wstrb,
    input  wire                     s_axi_wvalid,
    output wire                     s_axi_wready,
    output wire [1:0]               s_axi_bresp,
    output wire                     s_axi_bvalid,
    input  wire                     s_axi_bready,
    input  wire [31:0]              s_axi_araddr,
    input  wire                     s_axi_arvalid,
    output wire                     s_axi_arready,
    output wire [31:0]              s_axi_rdata,
    output wire [1:0]               s_axi_rresp,
    output wire                     s_axi_rvalid,
    input  wire                     s_axi_rready
);

    // Internal signals
    wire [31:0] rx_pkt_count;
    wire [31:0] rx_error_count;
    wire [63:0] pkt_count_64;
    wire [63:0] byte_count_64;
    
    // Extend counters to 64-bit for AXI-Lite
    assign pkt_count_64 = {32'd0, rx_pkt_count};
    assign byte_count_64 = {32'd0, rx_error_count};  // Reuse byte_count for errors
    
    // Control signals
    wire enable_w, loopback_w;
    wire clear_counters_w;
    wire [31:0] bram_base_w, bram_size_w;
    wire [31:0] sq_head_w, sq_tail_w, cq_head_w, cq_tail_w;
    wire irq_out_w;
    
    // -----------------------------------------------------------------------------
    // Ethernet RX Parser
    // -----------------------------------------------------------------------------
    ethernet_rx_parser #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_rx_parser (
        .clk(clk),
        .rstn(rstn),
        
        // Input from Ethernet MAC
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        
        // Output payload to RDMA
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tkeep(m_axis_tkeep),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),
        
        // Metadata to RDMA
        /*
        .meta_out(meta_out),
        .meta_valid(meta_valid),
        .meta_ready(meta_ready),
        */
        
        // Statistics
        .rx_pkt_count(rx_pkt_count),
        .rx_error_count(rx_error_count)
    );
    
    // -----------------------------------------------------------------------------
    // AXI-Lite Registers
    // -----------------------------------------------------------------------------
    axi_lite_regs u_axi_lite (
        .clk(clk),
        .rstn(rstn),
        
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),
        
        // Statistics inputs
        .pkt_count_in(pkt_count_64),
        .byte_count_in(byte_count_64),
        .lookup_error_in(1'b0),  // No lookup on RX side
        .irq_req_in(1'b0),
        .irq_out(irq_out_w),
        
        // Control outputs
        .enable_out(enable_w),
        .loopback_out(loopback_w),
        .clear_counters_out(clear_counters_w),
        .bram_base_out(bram_base_w),
        .bram_size_out(bram_size_w),
        .sq_head_out(sq_head_w),
        .sq_tail_out(sq_tail_w),
        .cq_head_out(cq_head_w),
        .cq_tail_out(cq_tail_w)
    );

endmodule