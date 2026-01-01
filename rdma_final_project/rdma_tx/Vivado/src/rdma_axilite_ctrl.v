`timescale 1ns/1ps
// ============================================================================
// Module: rdma_axilite_ctrl
// Description: AXI-Lite control/status register bridge for RDMA IP encapsulator
//              Converts register writes into  AXI-Stream handshaking
//
// Register Map:
//   0x00: CTRL      [0]=enable, [1]=start (auto-clear), [2]=soft_reset
//   0x04: STATUS    [0]=busy, [1]=error, [7:4]=error_code, [10:8]=fsm_state
//   0x08: META_LEN  [15:0]=payload length in bytes
//   0x0C: SRC_IP    [31:0]=source IPv4 address
//   0x10: DST_IP    [31:0]=destination IPv4 address
//   0x14: SRC_PORT  [15:0]=source UDP port
//   0x18: DST_PORT  [15:0]=destination UDP port
//   0x1C: PKT_CNT   [31:0]=transmitted packet count (read-only)
// ============================================================================
module rdma_axilite_ctrl #(
    parameter [47:0] SRC_MAC = 48'h0123456789AB,
    parameter [47:0] DST_MAC = 48'h000A35010203,
    parameter [31:0] SRC_IP = 32'hAC1F09CA,
    parameter [31:0] DST_IP = 32'hAC1F09C9,
    parameter [15:0] SRC_PORT = 16'hCE06,
    parameter [15:0] DST_PORT = 16'h138d
)(
    input  wire        clk,
    input  wire        rst_n,  // Active-low reset 
    
    input wire enable,
    input wire start,
    input wire [15:0] rdma_length,
    
    // AXI-Stream Slave: Payload Input (from DMA MM2S channel)
    input  wire [31:0] s_axis_payload_tdata,
    input  wire [3:0]  s_axis_payload_tkeep,
    input  wire        s_axis_payload_tvalid,
    output wire        s_axis_payload_tready,
    input  wire        s_axis_payload_tlast,

    // AXI-Stream Master: Packet Output (to DMA S2MM channel for capture)
    output wire [31:0] m_axis_packet_tdata,
    output wire [3:0]  m_axis_packet_tkeep,
    output wire        m_axis_packet_tvalid,
    input  wire        m_axis_packet_tready,
    output wire        m_axis_packet_tlast,
    output wire [31:0] reg_ctrl_deb
);
//internal reset
wire rst = ~rst_n;

// Register Definitions
reg [31:0] reg_ctrl;        // Control register
reg [15:0] reg_meta_len;    // Payload length
reg [31:0] reg_src_ip;      // Source IP
reg [31:0] reg_dst_ip;      // Destination IP
reg [15:0] reg_src_port;    // Source port
reg [15:0] reg_dst_port;    // Destination port
reg [31:0] reg_pkt_cnt;     // Packet counter (read-only)

wire [31:0] reg_status;     // Status register (directly from hardware)

// AXI-Lite State Machine
// handles write and read transactions

reg [1:0] axi_state;
localparam [1:0] AXI_IDLE  = 2'd0,
                 AXI_WRITE = 2'd1,
                 AXI_READ  = 2'd2,
                 AXI_RESP  = 2'd3;

reg        axi_awready_reg, axi_wready_reg;
reg        axi_bvalid_reg;
reg        axi_arready_reg;
reg        axi_rvalid_reg;
reg [31:0] axi_rdata_reg;
reg [5:0]  axi_addr_reg;    // Captures address[7:2] for word addressing

assign s_axi_awready = axi_awready_reg;
assign s_axi_wready  = axi_wready_reg;
assign s_axi_bresp   = 2'b00;  // OKAY response
assign s_axi_bvalid  = axi_bvalid_reg;
assign s_axi_arready = axi_arready_reg;
assign s_axi_rdata   = axi_rdata_reg;
assign s_axi_rresp   = 2'b00;  // OKAY response
assign s_axi_rvalid  = axi_rvalid_reg;

always @(posedge clk) begin
    if (rst) begin
        axi_state       <= AXI_IDLE;
        axi_awready_reg <= 1'b0;
        axi_wready_reg  <= 1'b0;
        axi_bvalid_reg  <= 1'b0;
        axi_arready_reg <= 1'b0;
        axi_rvalid_reg  <= 1'b0;
        axi_rdata_reg   <= 32'd0;
        axi_addr_reg    <= 6'd0;
        
        // Default register values
        reg_ctrl     <= 32'd0;
        reg_meta_len <= 16'd64;                 // Default 64-byte payload
        reg_src_ip   <= SRC_IP;           // 192.168.10.1
        reg_dst_ip   <= DST_IP;           // 192.168.10.2
        reg_src_port <= SRC_PORT;               // RoCEv2 default port
        reg_dst_port <= DST_PORT;
        
    end else begin
        reg_src_ip   <= SRC_IP;           // 192.168.10.1
        reg_dst_ip   <= DST_IP;           // 192.168.10.2
        reg_src_port <= SRC_PORT;               // RoCEv2 default port
        reg_dst_port <= DST_PORT;
        reg_meta_len <= rdma_length;
        reg_ctrl <= {30'h0, start, enable};
       
    end
end

// Sequence:
// 1. Software writes metadata registers (SRC_IP, DST_IP, etc.)
// 2. Software writes CTRL with bit[1]=1 (start)
// 3. start_pulse detects rising edge of bit[1]
// 4. meta_valid_reg asserts and STAYS HIGH
// 5. Encapsulator sees meta_valid, eventually asserts meta_ready
// 6. On meta_ready, meta_valid_reg deasserts (handshake complete)

reg        meta_valid_reg;
wire       meta_ready;
wire       dut_busy;
wire       dut_error;
wire [3:0] dut_error_code;
wire [2:0] dut_debug_state;

// Edge detection: capture previous start bit value
reg start_d;
wire start_pulse = reg_ctrl[1];

always @(posedge clk) begin
    start_d <= reg_ctrl[1];
end

always @(posedge clk) begin
    if (rst) begin
        meta_valid_reg <= 1'b0;
    end else begin
        if (start_pulse && reg_ctrl[0] && !dut_busy) begin
            // Rising edge of start, enable is set, not busy
            meta_valid_reg <= 1'b1;
        end else if (meta_ready) begin
            // Handshake completed - deassert
            meta_valid_reg <= 1'b0;
        end
    end
end

// [0]     = busy (transfer in progress)
// [1]     = error (validation failed)
// [7:4]   = error_code (specific error type)
// [10:8]  = debug_state (FSM state for debugging)
assign reg_status = {21'd0, dut_debug_state, dut_error_code, 2'd0, dut_error, dut_busy};
assign reg_ctrl_debug = reg_ctrl;

// Counts completed packets (tlast with tvalid && tready)
// Cleared by soft_reset (CTRL bit[2])
always @(posedge clk) begin
    if (rst || reg_ctrl[2]) begin
        reg_pkt_cnt <= 32'd0;
    end else if (m_axis_packet_tvalid && m_axis_packet_tready && m_axis_packet_tlast) begin
        reg_pkt_cnt <= reg_pkt_cnt + 32'd1;
    end
end


rdma_ip_encap_integrated #(
    .SRC_MAC(SRC_MAC),
    .DST_MAC(DST_MAC)
) u_encap (
    .iClk(clk),
    .iRst(rst_n),  

    
    // Metadata interface (from registers via handshake bridge)
    .i_meta_payload_len(reg_meta_len),
    .i_meta_src_ip(reg_src_ip),
    .i_meta_dst_ip(reg_dst_ip),
    .i_meta_src_port(reg_src_port),
    .i_meta_dst_port(reg_dst_port),
    .i_meta_flags(8'd0),
    .i_meta_endpoint_id(8'd0),
    .i_meta_valid(meta_valid_reg),
    .o_meta_ready(meta_ready),
    
    // Payload input (straight through from DMA)
    .i_payload_axis_tdata(s_axis_payload_tdata),
    .i_payload_axis_tkeep(s_axis_payload_tkeep),
    .i_payload_axis_tvalid(s_axis_payload_tvalid),
    .o_payload_axis_tready(s_axis_payload_tready),
    .i_payload_axis_tlast(s_axis_payload_tlast),
    .i_payload_axis_tuser(1'b0),
    
    // Packet output (straight through to DMA)
    .o_axis_tdata(m_axis_packet_tdata),
    .o_axis_tkeep(m_axis_packet_tkeep),
    .o_axis_tvalid(m_axis_packet_tvalid),
    .i_axis_tready(m_axis_packet_tready),
    .o_axis_tlast(m_axis_packet_tlast),
    .o_axis_tuser(),
    
    // Status
    .o_error(dut_error),
    .o_error_code(dut_error_code),
    .o_busy(dut_busy),
    .o_debug_state(dut_debug_state)
);

endmodule