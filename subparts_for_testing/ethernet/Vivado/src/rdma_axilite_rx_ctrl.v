`timescale 1ns/1ps
// ============================================================================
// AXI-Lite control/status register bridge for RDMA IP decapsulator
//
// Register Map:
//   0x00: CTRL        [0]=enable, [2]=soft_reset (clears counters)
//   0x04: STATUS      [0]=busy, [1]=error, [7:4]=error_code, [10:8]=fsm_state
//   0x08: RX_SRC_IP   [31:0]=last received source IPv4 (read-only)
//   0x0C: RX_DST_IP   [31:0]=last received dest IPv4 (read-only)
//   0x10: RX_SRC_PORT [15:0]=last received source UDP port (read-only)
//   0x14: RX_DST_PORT [15:0]=last received dest UDP port (read-only)
//   0x18: RX_LEN      [15:0]=last received payload length (read-only)
//   0x1C: PKT_CNT     [31:0]=received packet count (read-only)
//   0x20: DROP_CNT    [31:0]=dropped packet count (read-only)
//   0x24: HDR_VALID   [0]=header valid flag, auto-clears on read
//   0x28: HEARTBEAT   [31:0]=debug counter (increments every clock)
// ============================================================================
module rdma_axilite_rx_ctrl #(
    parameter [47:0] LOCAL_MAC  = 48'h000A35010203,
    parameter [15:0] LOCAL_PORT = 16'd5005
)(
    input  wire        clk,
    input  wire        rst_n,  // Active-low reset

    // AXI-Lite Slave Interface (from PS via interconnect)
    input  wire [31:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [31:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,

    // AXI-Stream Slave: Ethernet Frame Input (from external MAC or loopback)
    input  wire [31:0] s_axis_eth_tdata,
    input  wire [3:0]  s_axis_eth_tkeep,
    input  wire        s_axis_eth_tvalid,
    output wire        s_axis_eth_tready,
    input  wire        s_axis_eth_tlast,
    input  wire        s_axis_eth_tuser,

    // AXI-Stream Master: Payload Output (to DMA S2MM channel)
    output wire [31:0] m_axis_payload_tdata,
    output wire [3:0]  m_axis_payload_tkeep,
    output wire        m_axis_payload_tvalid,
    input  wire        m_axis_payload_tready,
    output wire        m_axis_payload_tlast
);

// Internal reset
wire rst = ~rst_n;

// Register Definitions
reg [31:0] reg_ctrl;           // Control register
reg [31:0] reg_rx_src_ip;      // Last received source IP
reg [31:0] reg_rx_dst_ip;      // Last received dest IP
reg [15:0] reg_rx_src_port;    // Last received source port
reg [15:0] reg_rx_dst_port;    // Last received dest port
reg [15:0] reg_rx_len;         // Last received payload length
reg [31:0] reg_pkt_cnt;        // Received packet counter
reg [31:0] reg_drop_cnt;       // Dropped packet counter
reg        reg_hdr_valid;      // Header valid flag (sticky until read)

wire [31:0] reg_status;        // Status register (from hardware)

// AXI-Lite - Separate read and write channels for robustness
// This prevents writes from blocking reads and vice versa

// Write channel state
reg aw_ready_reg;
reg w_ready_reg;
reg b_valid_reg;
reg [5:0] aw_addr_reg;
reg aw_pending;  // Address received, waiting for data
reg w_pending;   // Data received, waiting for address

// Read channel state
reg ar_ready_reg;
reg r_valid_reg;
reg [31:0] r_data_reg;
reg [5:0] ar_addr_reg;

// Debug counter to verify clock is running
reg [31:0] debug_heartbeat;

assign s_axi_awready = aw_ready_reg;
assign s_axi_wready  = w_ready_reg;
assign s_axi_bresp   = 2'b00;
assign s_axi_bvalid  = b_valid_reg;
assign s_axi_arready = ar_ready_reg;
assign s_axi_rdata   = r_data_reg;
assign s_axi_rresp   = 2'b00;
assign s_axi_rvalid  = r_valid_reg;

// Decapsulator signals (directly from module)
wire        dut_busy;
wire        dut_error;
wire [3:0]  dut_error_code;
wire [2:0]  dut_debug_state;
wire [31:0] dut_hdr_src_ip;
wire [31:0] dut_hdr_dst_ip;
wire [15:0] dut_hdr_src_port;
wire [15:0] dut_hdr_dst_port;
wire [15:0] dut_hdr_payload_len;
wire        dut_hdr_valid;
wire        dut_stat_received;
wire        dut_stat_dropped;

// Registered status signals (to avoid combinational timing issues)
reg        reg_dut_busy;
reg        reg_dut_error;
reg [3:0]  reg_dut_error_code;
reg [2:0]  reg_dut_debug_state;

// Internal enable gate for RX path
wire rx_enable = reg_ctrl[0];

// Gated input ready - only accept frames when enabled
wire eth_tready_internal;
assign s_axis_eth_tready = rx_enable ? eth_tready_internal : 1'b0;

// ============================================================================
// AXI-Lite Write Channel - Independent of read channel
// ============================================================================
always @(posedge clk) begin
    if (rst) begin
        aw_ready_reg <= 1'b1;  // Ready to accept address immediately after reset
        w_ready_reg  <= 1'b1;  // Ready to accept data immediately after reset
        b_valid_reg  <= 1'b0;
        aw_addr_reg  <= 6'd0;
        aw_pending   <= 1'b0;
        w_pending    <= 1'b0;
        reg_ctrl     <= 32'd1;  // Enable by default
    end else begin
        // Write response handshake
        if (b_valid_reg && s_axi_bready) begin
            b_valid_reg <= 1'b0;
        end

        // Write address channel
        if (aw_ready_reg && s_axi_awvalid) begin
            aw_ready_reg <= 1'b0;  // Stop accepting addresses
            aw_addr_reg  <= s_axi_awaddr[7:2];
            aw_pending   <= 1'b1;
        end

        // Write data channel
        if (w_ready_reg && s_axi_wvalid) begin
            w_ready_reg <= 1'b0;  // Stop accepting data
            w_pending   <= 1'b1;
        end

        // When both address and data are received, perform write
        if (aw_pending && w_pending) begin
            // Only CTRL register is writable
            case (aw_addr_reg)
                6'd0: reg_ctrl <= s_axi_wdata;  // 0x00
            endcase
            b_valid_reg  <= 1'b1;  // Assert write response
            aw_pending   <= 1'b0;
            w_pending    <= 1'b0;
            aw_ready_reg <= 1'b1;  // Ready for next write
            w_ready_reg  <= 1'b1;
        end
    end
end

// ============================================================================
// AXI-Lite Read Channel - Completely independent of write channel
// ============================================================================
always @(posedge clk) begin
    if (rst) begin
        ar_ready_reg <= 1'b1;  // Ready to accept address immediately after reset
        r_valid_reg  <= 1'b0;
        r_data_reg   <= 32'd0;
        ar_addr_reg  <= 6'd0;
        debug_heartbeat <= 32'd0;
    end else begin
        // Heartbeat counter - proves clock is running
        debug_heartbeat <= debug_heartbeat + 32'd1;

        // Read response handshake
        if (r_valid_reg && s_axi_rready) begin
            r_valid_reg  <= 1'b0;
            ar_ready_reg <= 1'b1;  // Ready for next read
        end

        // Read address channel - accept address and return data
        if (ar_ready_reg && s_axi_arvalid && !r_valid_reg) begin
            ar_ready_reg <= 1'b0;  // Stop accepting addresses
            ar_addr_reg  <= s_axi_araddr[7:2];

            // Immediately prepare read data
            case (s_axi_araddr[7:2])
                6'd0:  r_data_reg <= reg_ctrl;                      // 0x00
                6'd1:  r_data_reg <= reg_status;                    // 0x04
                6'd2:  r_data_reg <= reg_rx_src_ip;                 // 0x08
                6'd3:  r_data_reg <= reg_rx_dst_ip;                 // 0x0C
                6'd4:  r_data_reg <= {16'd0, reg_rx_src_port};      // 0x10
                6'd5:  r_data_reg <= {16'd0, reg_rx_dst_port};      // 0x14
                6'd6:  r_data_reg <= {16'd0, reg_rx_len};           // 0x18
                6'd7:  r_data_reg <= reg_pkt_cnt;                   // 0x1C
                6'd8:  r_data_reg <= reg_drop_cnt;                  // 0x20
                6'd9:  r_data_reg <= {31'd0, reg_hdr_valid};        // 0x24
                6'd10: r_data_reg <= debug_heartbeat;               // 0x28 - Debug: heartbeat counter
                default: r_data_reg <= 32'hDEADBEEF;                // Debug: invalid address marker
            endcase
            r_valid_reg <= 1'b1;  // Assert read data valid
        end
    end
end

// Register status signals to avoid combinational timing issues on AXI read
always @(posedge clk) begin
    if (rst) begin
        reg_dut_busy        <= 1'b0;
        reg_dut_error       <= 1'b0;
        reg_dut_error_code  <= 4'd0;
        reg_dut_debug_state <= 3'd0;
    end else begin
        reg_dut_busy        <= dut_busy;
        reg_dut_error       <= dut_error;
        reg_dut_error_code  <= dut_error_code;
        reg_dut_debug_state <= dut_debug_state;
    end
end

// Status register (using registered signals for stability)
assign reg_status = {21'd0, reg_dut_debug_state, reg_dut_error_code, 2'd0, reg_dut_error, reg_dut_busy};

// Header capture - latch headers when valid pulse occurs
always @(posedge clk) begin
    if (rst || reg_ctrl[2]) begin
        reg_rx_src_ip   <= 32'd0;
        reg_rx_dst_ip   <= 32'd0;
        reg_rx_src_port <= 16'd0;
        reg_rx_dst_port <= 16'd0;
        reg_rx_len      <= 16'd0;
        reg_hdr_valid   <= 1'b0;
    end else begin
        // Capture headers on valid pulse
        if (dut_hdr_valid) begin
            reg_rx_src_ip   <= dut_hdr_src_ip;
            reg_rx_dst_ip   <= dut_hdr_dst_ip;
            reg_rx_src_port <= dut_hdr_src_port;
            reg_rx_dst_port <= dut_hdr_dst_port;
            reg_rx_len      <= dut_hdr_payload_len;
            reg_hdr_valid   <= 1'b1;
        end

        // Clear hdr_valid when software reads it (address 0x24)
        if (ar_addr_reg == 6'd9 && r_valid_reg && s_axi_rready) begin
            reg_hdr_valid <= 1'b0;
        end
    end
end

// Packet counters
always @(posedge clk) begin
    if (rst || reg_ctrl[2]) begin
        reg_pkt_cnt  <= 32'd0;
        reg_drop_cnt <= 32'd0;
    end else begin
        if (dut_stat_received)
            reg_pkt_cnt <= reg_pkt_cnt + 32'd1;
        if (dut_stat_dropped)
            reg_drop_cnt <= reg_drop_cnt + 32'd1;
    end
end

// Instantiate decapsulator
rdma_ip_decap_integrated #(
    .LOCAL_MAC(LOCAL_MAC),
    .LOCAL_PORT(LOCAL_PORT)
) u_decap (
    .iClk(clk),
    .iRst(rst_n),

    // Ethernet frame input
    .i_eth_axis_tdata(s_axis_eth_tdata),
    .i_eth_axis_tkeep(s_axis_eth_tkeep),
    .i_eth_axis_tvalid(s_axis_eth_tvalid && rx_enable),
    .o_eth_axis_tready(eth_tready_internal),
    .i_eth_axis_tlast(s_axis_eth_tlast),
    .i_eth_axis_tuser(s_axis_eth_tuser),

    // Payload output
    .o_payload_axis_tdata(m_axis_payload_tdata),
    .o_payload_axis_tkeep(m_axis_payload_tkeep),
    .o_payload_axis_tvalid(m_axis_payload_tvalid),
    .i_payload_axis_tready(m_axis_payload_tready),
    .o_payload_axis_tlast(m_axis_payload_tlast),
    .o_payload_axis_tuser(),

    // Extracted headers
    .o_hdr_src_ip(dut_hdr_src_ip),
    .o_hdr_dst_ip(dut_hdr_dst_ip),
    .o_hdr_src_port(dut_hdr_src_port),
    .o_hdr_dst_port(dut_hdr_dst_port),
    .o_hdr_payload_len(dut_hdr_payload_len),
    .o_hdr_valid(dut_hdr_valid),

    // Status
    .o_busy(dut_busy),
    .o_error(dut_error),
    .o_error_code(dut_error_code),

    // Statistics
    .o_stat_pkt_received(dut_stat_received),
    .o_stat_pkt_dropped(dut_stat_dropped),

    // Debug
    .o_debug_state(dut_debug_state)
);

endmodule
