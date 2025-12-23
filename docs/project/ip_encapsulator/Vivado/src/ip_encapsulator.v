`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// ip_encapsulator.v
// Top-level Part2 wrapper: Accepts meta + payload AXIS, builds ETH/IP/UDP headers,
// looks up MACs in BRAM, packs headers + payload onto m_axis, exposes BRAM Port B
// for Block Memory Generator, and exposes AXI-Lite for control/stats.
//
// Assumptions:
//  - meta_axis is 1-beat per-packet carrying payload_len, src_ip, dst_ip, src_port, dst_port, flags, endpoint_id
//  - BRAM port B is connected externally in the BD
//////////////////////////////////////////////////////////////////////////////////

module ip_encapsulator #(
    parameter DATA_WIDTH = 64,
    parameter KEEP_WIDTH = DATA_WIDTH/8,
    parameter META_WIDTH = 128,           // meta beat width in bits
    parameter BRAM_ADDR_WIDTH = 11,
    parameter BRAM_DATA_WIDTH = 256
)(
    input  wire                     clk,
    input  wire                     rstn,           // active HIGH reset deasserted = 1

    // s_axis (payload input)
    input  wire [DATA_WIDTH-1:0]    s_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]    s_axis_tkeep,
    input  wire                     s_axis_tvalid,
    output wire                     s_axis_tready,
    input  wire                     s_axis_tlast,

    // meta_axis (sideband metadata, 1-beat per packet)
    input  wire [META_WIDTH-1:0]    meta_tdata,
    input  wire                     meta_tvalid,
    output wire                     meta_tready,

    // m_axis (frame output)
    output wire [DATA_WIDTH-1:0]    m_axis_tdata,
    output wire [KEEP_WIDTH-1:0]    m_axis_tkeep,
    output wire                     m_axis_tvalid,
    input  wire                     m_axis_tready,
    output wire                     m_axis_tlast,

    // BRAM Port B (connect to Block Memory Generator port B)
    output wire [BRAM_ADDR_WIDTH-1:0] bram_addr_b,
    output wire                        bram_en_b,
    output wire                        bram_clk_b,
    input  wire [BRAM_DATA_WIDTH-1:0]  bram_dout_b,

    // AXI4-Lite slave (control/status)
    input  wire [31:0]               s_axi_awaddr,
    input  wire                      s_axi_awvalid,
    output wire                      s_axi_awready,
    input  wire [31:0]               s_axi_wdata,
    input  wire [3:0]                s_axi_wstrb,
    input  wire                      s_axi_wvalid,
    output wire                      s_axi_wready,
    output wire [1:0]                s_axi_bresp,
    output wire                      s_axi_bvalid,
    input  wire                      s_axi_bready,
    input  wire [31:0]               s_axi_araddr,
    input  wire                      s_axi_arvalid,
    output wire                      s_axi_arready,
    output wire [31:0]              s_axi_rdata,
    output wire [1:0]               s_axi_rresp,
    output wire                      s_axi_rvalid,
    input  wire                      s_axi_rready,
    
    // ack signals: 
    //first 8 bit = endpoint_id
    //9th bit = ack bit low default
    //from ethernet
    input wire[8:0] ack_in,
    output wire[8:0] ack_out,
    input wire ack_is_read,
    output wire ack_in_ready
);

// -----------------------------------------------------------------------------
// Meta bitfield mapping (example)
// META_WIDTH = 128 bits (MSB..LSB):
// [127:112] payload_len (16 bits)
// [111:80]  src_ip (32 bits)
// [79:48]   dst_ip (32 bits)
// [47:32]   src_port (16 bits)
// [31:16]   dst_port (16 bits)
// [15:8]    flags (8 bits)
// [7:0]     endpoint_id (8 bits) -- optional
// Adjust these indices if you use a different packing.
localparam integer META_PAYLEN_MSB = META_WIDTH - 1;
localparam integer META_PAYLEN_LSB = META_WIDTH - 16;
localparam integer META_SRCIP_MSB  = META_PAYLEN_LSB - 1;
localparam integer META_SRCIP_LSB  = META_SRCIP_MSB - 31;
localparam integer META_DSTIP_MSB  = META_SRCIP_LSB - 1;
localparam integer META_DSTIP_LSB  = META_DSTIP_MSB - 31;
localparam integer META_SRCP_MSB   = META_DSTIP_LSB - 1;
localparam integer META_SRCP_LSB   = META_SRCP_MSB - 15;
localparam integer META_DSTP_MSB   = META_SRCP_LSB - 1;
localparam integer META_DSTP_LSB   = META_DSTP_MSB - 15;
localparam integer META_FLAGS_MSB  = META_DSTP_LSB - 1;
localparam integer META_FLAGS_LSB  = META_FLAGS_MSB - 7;
localparam integer META_EP_ID_MSB  = META_FLAGS_LSB - 1;
localparam integer META_EP_ID_LSB  = META_EP_ID_MSB - 7;

// -----------------------------------------------------------------------------
// Internal streaming wires
// -----------------------------------------------------------------------------
wire [DATA_WIDTH-1:0] payload_tdata;
wire [KEEP_WIDTH-1:0] payload_tkeep;
wire                 payload_tvalid;
wire                 payload_tready;
wire                 payload_tlast;

wire [META_WIDTH-1:0] meta_aligned;
wire                  meta_aligned_valid;
wire                  meta_aligned_ready;

// length calc outputs
wire [15:0] ip_total_length;
wire [15:0] udp_length;
wire        length_valid;
wire        length_ready;
wire [15:0] payload_len_field;
wire        length_calc_ready_in; // <-- NEW: Ready signal output from length_calc

// endpoint lookup wires
wire [31:0] lookup_dst_ip;
wire        lookup_ready_in; // <-- NEW: Ready signal output from endpoint_lookup
wire        lookup_done;
wire        lookup_hit;
wire        lookup_error;
wire [47:0] lookup_dst_mac;
wire [47:0] lookup_src_mac;

// ipv4 header
wire [159:0] ipv4_hdr;
wire [15:0]  ipv4_checksum;
wire         ipv4_hdr_valid;
wire         ipv4_hdr_ready;
wire         ipv4_hdr_ready_in; // <-- NEW: Ready signal output from ipv4_header_builder

// udp header
wire [63:0]  udp_hdr_beats;
wire         udp_hdr_valid;
wire         udp_hdr_ready;
wire         udp_hdr_ready_in; // <-- NEW: Ready signal output from udp_header

// eth header
wire [111:0] eth_hdr_beats;
wire         eth_hdr_valid;
wire         eth_hdr_ready;

// stats wires
wire pkt_emit;
wire [15:0] pkt_bytes;

// signals for axi_lite_regs
wire [63:0] pkt_count_w;
wire [63:0] byte_count_w;
wire lookup_error_w;
wire irq_req_w; // if some internal logic raises interrupts
wire enable_w, loopback_w;
wire clear_counters_w;
wire [31:0] bram_base_w, bram_size_w;
wire [31:0] sq_head_w, sq_tail_w, cq_head_w, cq_tail_w;
wire irq_out_w;

// ack signal wires
reg [8:0] r_ack_out;

// The meta-aligned data is consumed by: length_calc, endpoint_lookup, ipv4_header_builder, and udp_header.
// We AND their ready_in signals together to generate the meta_aligned_ready signal.
assign meta_aligned_ready = length_calc_ready_in & lookup_ready_in & ipv4_hdr_ready_in & udp_hdr_ready_in;

// -----------------------------------------------------------------------------
// Instantiate meta_align
// -----------------------------------------------------------------------------
// meta_align: aligns metadata and payload; ensures meta delivered before first payload beat
meta_align #(
    .DATA_WIDTH(DATA_WIDTH),
    .META_WIDTH(META_WIDTH)
) u_meta_align (
    .clk(clk), .rstn(rstn),

    // AXIS payload input
    .s_axis_tdata(s_axis_tdata),
    .s_axis_tkeep(s_axis_tkeep),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tready(s_axis_tready),
    .s_axis_tlast(s_axis_tlast),

    // Metadata input (from meta_axis)
    .udp_meta_in(meta_tdata),
    .udp_meta_valid(meta_tvalid),
    .udp_meta_ready(meta_tready),

    // AXIS payload output (to pipeline)
    .m_axis_tdata(payload_tdata),
    .m_axis_tkeep(payload_tkeep),
    .m_axis_tvalid(payload_tvalid),
    .m_axis_tready(payload_tready),
    .m_axis_tlast(payload_tlast),

    // Metadata out (aligned with payload)
    .udp_meta_out(meta_aligned),
    .udp_meta_out_valid(meta_aligned_valid),
    .udp_meta_out_ready(meta_aligned_ready)
);

// -----------------------------------------------------------------------------
// Extract payload_len and dst_ip from meta_aligned (packed per mapping above)
// -----------------------------------------------------------------------------
assign payload_len_field = meta_aligned[META_PAYLEN_MSB:META_PAYLEN_LSB];
assign lookup_dst_ip = meta_aligned[META_DSTIP_MSB:META_DSTIP_LSB];

// -----------------------------------------------------------------------------
// length_calc: compute ip_total_length and udp_length
// -----------------------------------------------------------------------------
length_calc u_length_calc (
    .clk(clk), .rstn(rstn),
    .payload_len_in(payload_len_field),
    .payload_len_valid(meta_aligned_valid),
    .payload_len_ready(length_calc_ready_in),
    .ip_total_length(ip_total_length),
    .udp_length(udp_length),
    .length_valid(length_valid),
    .length_ready(length_ready)
);

// -----------------------------------------------------------------------------
// endpoint_lookup_bram: uses BRAM Port B (external) to return dst/src MACs
// -----------------------------------------------------------------------------
endpoint_lookup #(
    .ADDR_WIDTH(BRAM_ADDR_WIDTH),
    .BRAM_DATA_WIDTH(BRAM_DATA_WIDTH)
) u_endpoint_lookup (
    .clk(clk),
    .rstn(rstn),
    .dst_ip(lookup_dst_ip),
    .lookup_valid(meta_aligned_valid),
    .lookup_ready(lookup_ready_in),
    .lookup_done(lookup_done),
    .lookup_hit(lookup_hit),
    .lookup_error(lookup_error),
    .dst_mac(lookup_dst_mac),
    .src_mac(lookup_src_mac),

    // BRAM port B connect-through (wires are outputs of this top-level)
    .bram_addr_b(bram_addr_b),
    .bram_en_b(bram_en_b),
    .bram_dout_b(bram_dout_b)
);

// tie bram clock output to top-level clk (exported pin). BD should connect bram_clkb to same FCLK.
assign bram_clk_b = clk;

// -----------------------------------------------------------------------------
// ipv4_header_builder: build IPv4 header and checksum
// -----------------------------------------------------------------------------
ipv4_header_builder #(
    .TTL_DEFAULT(8'd64),
    .PROTOCOL(8'd17)
) u_ipv4_header_builder (
    .clk(clk), .rstn(rstn),
    .src_ip(meta_aligned[META_SRCIP_MSB:META_SRCIP_LSB]),
    .dst_ip(meta_aligned[META_DSTIP_MSB:META_DSTIP_LSB]),
    .ip_total_length(ip_total_length),
    .valid_in(meta_aligned_valid),
    .ready_in(ipv4_hdr_ready_in),
    .ipv4_header(ipv4_hdr),
    .checksum_out(ipv4_checksum),
    .valid_out(ipv4_hdr_valid),
    .ready_out(ipv4_hdr_ready)
);

// -----------------------------------------------------------------------------
// udp_header: build UDP header (checksum = 0 for POC)
// -----------------------------------------------------------------------------
udp_header u_udp_header (
    .clk(clk), .rstn(rstn),
    .src_port(meta_aligned[META_SRCP_MSB:META_SRCP_LSB]),
    .dst_port(meta_aligned[META_DSTP_MSB:META_DSTP_LSB]),
    .udp_length(udp_length),
    .valid_in(meta_aligned_valid),
    .ready_in(udp_hdr_ready_in),
    .udp_header(udp_hdr_beats),
    .valid_out(udp_hdr_valid),
    .ready_out(udp_hdr_ready)
);

// -----------------------------------------------------------------------------
// eth_header: build Ethernet header from lookup results
// -----------------------------------------------------------------------------
eth_header u_eth_header (
    .clk(clk), .rstn(rstn),
    .dst_mac(lookup_dst_mac),
    .src_mac(lookup_src_mac),
    .valid_in(lookup_done),
    .eth_header(eth_hdr_beats),
    .valid_out(eth_hdr_valid),
    .ready_in(eth_hdr_ready)
);

// -----------------------------------------------------------------------------
// header_packer: pack eth+ip+udp headers + payload into m_axis
//   header_packer is expected to consume header beats and payload stream and
//   output full AXIS frames with correct tkeep/tlast semantics.
// -----------------------------------------------------------------------------
header_packer #(
    .DATA_WIDTH(DATA_WIDTH)
) u_header_packer (
    .clk(clk),
    .rstn(rstn),

    .eth_header(eth_hdr_beats),
    .eth_header_valid(eth_hdr_valid),
    .eth_header_ready(eth_hdr_ready),

    .ip_header(ipv4_hdr),
    .ip_header_valid(ipv4_hdr_valid),
    .ip_header_ready(ipv4_hdr_ready),

    .udp_header(udp_hdr_beats),
    .udp_header_valid(udp_hdr_valid),
    .udp_header_ready(udp_hdr_ready),

    .payload_length_bytes(payload_len_field),
    .length_valid(length_valid),
    .length_ready(length_ready),

    .payload_in(payload_tdata),
    .payload_in_keep(payload_tkeep),
    .payload_valid(payload_tvalid),
    .payload_ready(payload_tready),
    .payload_last(payload_tlast),

    .m_axis_tdata(m_axis_tdata),
    .m_axis_tkeep(m_axis_tkeep),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tready(m_axis_tready),
    .m_axis_tlast(m_axis_tlast)
);

// -----------------------------------------------------------------------------
// stats_regs: count packets/bytes based on emitted frames
// -----------------------------------------------------------------------------
assign pkt_emit = m_axis_tvalid & m_axis_tready & m_axis_tlast;
assign pkt_bytes = ip_total_length[15:0]; // count ip total length as bytes per packet

stats_regs u_stats_regs (
    .clk(clk), .rstn(rstn),
    .pkt_valid(pkt_emit),
    .pkt_bytes(pkt_bytes),
    .clear_counters(clear_counters_w), // NEW: connect AXI CONTROL[2] pulse
    .pkt_count_out(pkt_count_w),       // 64-bit output for AXI
    .byte_count_out(byte_count_w)      // 64-bit output for AXI
);

// -----------------------------------------------------------------------------
// AXI-Lite regs
// -----------------------------------------------------------------------------
axi_lite_regs u_axi_lite (
  .clk(clk), .rstn(rstn),

  .s_axi_awaddr(s_axi_awaddr), .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
  .s_axi_wdata(s_axi_wdata),   .s_axi_wstrb(s_axi_wstrb),   .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
  .s_axi_bresp(s_axi_bresp),   .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
  .s_axi_araddr(s_axi_araddr), .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
  .s_axi_rdata(s_axi_rdata),   .s_axi_rresp(s_axi_rresp), .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready),

  .pkt_count_in(pkt_count_w),
  .byte_count_in(byte_count_w),
  .lookup_error_in(lookup_error_w),
  .irq_req_in(irq_req_w),
  .irq_out(irq_out_w),

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

assign lookup_error_w = lookup_error;
assign irq_req_w      = 1'b0;


// -----------------------------------------------------------------------
// ACK signal check
//------------------------------------------------------------------------
always @(posedge clk)
begin
    if (r_ack_out == 9'b0)
    begin
        if (ack_in[8] == 1'b1) 
        begin
            r_ack_out <= ack_in; 
        end
    end
    else
    begin
        if (ack_is_read == 1'b1)
        begin
            r_ack_out <= 9'b0; 
        end
    end
end

assign ack_in_ready = (r_ack_out == 9'b0);
assign ack_out = r_ack_out;

// -----------------------------------------------------------------------------
// End of module
// -----------------------------------------------------------------------------
endmodule
