`timescale 1ns/1ps

// Testbench for rdma_registers_slave_lite_v1_0_S00_AXI
// - Drives AXI4-Lite writes and reads to test write protections, doorbell pulses, and HW-driven RO registers.
// Note: Add the DUT source to the Vivado simulation project (or use `\include` with the correct path).

module tb_rdma_registers();

  // Clock and reset
  reg S_AXI_ACLK = 0;
  reg S_AXI_ARESETN = 0;
  always #5 S_AXI_ACLK = ~S_AXI_ACLK; // 100 MHz

  // AXI4-Lite master signals
  reg [6:0] S_AXI_AWADDR;
  reg [2:0] S_AXI_AWPROT = 3'b000;
  reg S_AXI_AWVALID;
  wire S_AXI_AWREADY;

  reg [31:0] S_AXI_WDATA;
  reg [3:0] S_AXI_WSTRB;
  reg S_AXI_WVALID;
  wire S_AXI_WREADY;

  wire [1:0] S_AXI_BRESP;
  wire S_AXI_BVALID;
  reg S_AXI_BREADY;

  reg [6:0] S_AXI_ARADDR;
  reg [2:0] S_AXI_ARPROT = 3'b000;
  reg S_AXI_ARVALID;
  wire S_AXI_ARREADY;

  wire [31:0] S_AXI_RDATA;
  wire [1:0] S_AXI_RRESP;
  wire S_AXI_RVALID;
  reg S_AXI_RREADY;

  // RDMA core-facing ports (connect to DUT)
  wire [31:0] SQ_BASE_LO;
  wire [31:0] SQ_BASE_HI;
  wire [31:0] SQ_SIZE;
  wire [31:0] SQ_TAIL;
  wire [31:0] SQ_FLAGS;
  wire [31:0] SQ_STRIDE;
  wire [31:0] CQ_BASE_LO;
  wire [31:0] CQ_BASE_HI;
  wire [31:0] CQ_SIZE;
  wire [31:0] CQ_HEAD_SW;
  wire [31:0] CQ_FLAGS;
  wire SQ_DOORBELL_PULSE;
  wire CQ_DOORBELL_PULSE;
  wire GLOBAL_ENABLE;
  wire SOFT_RESET;
  wire PAUSE;
  wire [3:0] MODE;
  wire GLOBAL_IRQ_EN;
  wire IRQ_OUT;

  // HW status inputs to the register module (we'll drive these from TB later)
  reg [31:0] HW_SQ_HEAD = 0;
  reg [31:0] HW_CQ_TAIL = 0;
  reg [31:0] HW_STATUS_WORD = 0;
  reg [31:0] HW_BYTES_LO = 0;
  reg [31:0] HW_BYTES_HI = 0;
  reg [31:0] HW_WQE_PROCESSED = 0;
  reg [31:0] HW_CQE_WRITTEN = 0;
  reg [31:0] HW_CYCLES_BUSY_LO = 0;
  reg [31:0] HW_CYCLES_BUSY_HI = 0;

  // Instantiate DUT (assumes DUT source is in simulation set)
  rdma_registers_slave_lite_v1_0_S00_AXI #(
    .C_S_AXI_DATA_WIDTH(32),
    .C_S_AXI_ADDR_WIDTH(7)
  ) dut (
    .S_AXI_ACLK(S_AXI_ACLK),
    .S_AXI_ARESETN(S_AXI_ARESETN),
    .S_AXI_AWADDR(S_AXI_AWADDR),
    .S_AXI_AWPROT(S_AXI_AWPROT),
    .S_AXI_AWVALID(S_AXI_AWVALID),
    .S_AXI_AWREADY(S_AXI_AWREADY),
    .S_AXI_WDATA(S_AXI_WDATA),
    .S_AXI_WSTRB(S_AXI_WSTRB),
    .S_AXI_WVALID(S_AXI_WVALID),
    .S_AXI_WREADY(S_AXI_WREADY),
    .S_AXI_BRESP(S_AXI_BRESP),
    .S_AXI_BVALID(S_AXI_BVALID),
    .S_AXI_BREADY(S_AXI_BREADY),
    .S_AXI_ARADDR(S_AXI_ARADDR),
    .S_AXI_ARPROT(S_AXI_ARPROT),
    .S_AXI_ARVALID(S_AXI_ARVALID),
    .S_AXI_ARREADY(S_AXI_ARREADY),
    .S_AXI_RDATA(S_AXI_RDATA),
    .S_AXI_RRESP(S_AXI_RRESP),
    .S_AXI_RVALID(S_AXI_RVALID),
    .S_AXI_RREADY(S_AXI_RREADY),

    // RDMA ports
    .SQ_BASE_LO(SQ_BASE_LO),
    .SQ_BASE_HI(SQ_BASE_HI),
    .SQ_SIZE(SQ_SIZE),
    .SQ_TAIL(SQ_TAIL),
    .SQ_FLAGS(SQ_FLAGS),
    .SQ_STRIDE(SQ_STRIDE),
    .CQ_BASE_LO(CQ_BASE_LO),
    .CQ_BASE_HI(CQ_BASE_HI),
    .CQ_SIZE(CQ_SIZE),
    .CQ_HEAD_SW(CQ_HEAD_SW),
    .CQ_FLAGS(CQ_FLAGS),
    .SQ_DOORBELL_PULSE(SQ_DOORBELL_PULSE),
    .CQ_DOORBELL_PULSE(CQ_DOORBELL_PULSE),
    .GLOBAL_ENABLE(GLOBAL_ENABLE),
    .SOFT_RESET(SOFT_RESET),
    .PAUSE(PAUSE),
    .MODE(MODE),
    .GLOBAL_IRQ_EN(GLOBAL_IRQ_EN),
    .IRQ_OUT(IRQ_OUT),

    .HW_SQ_HEAD(HW_SQ_HEAD),
    .HW_CQ_TAIL(HW_CQ_TAIL),
    .HW_STATUS_WORD(HW_STATUS_WORD),
    .HW_BYTES_LO(HW_BYTES_LO),
    .HW_BYTES_HI(HW_BYTES_HI),
    .HW_WQE_PROCESSED(HW_WQE_PROCESSED),
    .HW_CQE_WRITTEN(HW_CQE_WRITTEN),
    .HW_CYCLES_BUSY_LO(HW_CYCLES_BUSY_LO),
    .HW_CYCLES_BUSY_HI(HW_CYCLES_BUSY_HI)
  );

  // Simple AXI4-Lite master tasks
  task axi_write(input [6:0] addr, input [31:0] data);
  begin
    @(posedge S_AXI_ACLK);
    S_AXI_AWADDR <= addr;
    S_AXI_AWVALID <= 1'b1;
    S_AXI_WDATA <= data;
    S_AXI_WSTRB <= 4'hF;
    S_AXI_WVALID <= 1'b1;
    S_AXI_BREADY <= 1'b1;

    // wait for AWREADY & WREADY handshake
    wait (S_AXI_AWREADY == 1'b1 && S_AXI_WREADY == 1'b1);
    @(posedge S_AXI_ACLK);
    S_AXI_AWVALID <= 1'b0;
    S_AXI_WVALID <= 1'b0;

    // wait for BVALID
    wait (S_AXI_BVALID == 1'b1);
    @(posedge S_AXI_ACLK);
    S_AXI_BREADY <= 1'b0;
  end
  endtask

  task axi_read(input [6:0] addr, output [31:0] data_out);
  begin
    @(posedge S_AXI_ACLK);
    S_AXI_ARADDR <= addr;
    S_AXI_ARVALID <= 1'b1;
    S_AXI_RREADY <= 1'b1;

    wait (S_AXI_ARREADY == 1'b1);
    @(posedge S_AXI_ACLK);
    S_AXI_ARVALID <= 1'b0;

    wait (S_AXI_RVALID == 1'b1);
    @(posedge S_AXI_ACLK);
    data_out = S_AXI_RDATA;
    S_AXI_RREADY <= 1'b0;
  end
  endtask

  // Monitor doorbell pulses and print when they occur
  always @(posedge S_AXI_ACLK) begin
    if (SQ_DOORBELL_PULSE) $display("%0t: SQ_DOORBELL_PULSE asserted", $time);
    if (CQ_DOORBELL_PULSE) $display("%0t: CQ_DOORBELL_PULSE asserted", $time);
  end

  // Test sequence
  initial begin
    // Initialize signals
    S_AXI_AWADDR = 0;
    S_AXI_AWVALID = 0;
    S_AXI_WDATA = 0;
    S_AXI_WSTRB = 0;
    S_AXI_WVALID = 0;
    S_AXI_BREADY = 0;
    S_AXI_ARADDR = 0;
    S_AXI_ARVALID = 0;
    S_AXI_RREADY = 0;

    // Wait a bit and release reset
    #100;
    S_AXI_ARESETN = 1'b1;
    #20;

    $display("\n---- Starting AXI-Lite register tests ----\n");

    // Write SQ_BASE_LO (0x08) and SQ_SIZE (0x0A)
    axi_write(7'h08, 32'h8000_0000);
    axi_write(7'h09, 32'h0);
    axi_write(7'h0A, 32'd64);

    // Write SQ_TAIL (0x0C) to trigger doorbell
    axi_write(7'h0C, 32'd1);
    // Wait a few cycles
    #20;

    // Simulate HW updating SQ_HEAD -> should be visible on RO register 0x0B
    HW_SQ_HEAD = 32'd5;
    #20;

    // Read SQ_HEAD (RO)
    reg [31:0] readv;
    axi_read(7'h0B, readv);
    $display("Read SQ_HEAD (0x0B) = 0x%08h (expected 5)", readv);

    // Test explicit SQ_DOORBELL (0x0D)
    axi_write(7'h0D, 32'h1);
    #10;

    // Test CQ doorbell (0x15)
    axi_write(7'h15, 32'h1);
    #10;

    // Update HW counters and read them back
    HW_BYTES_LO = 32'hDEAD_BEEF;
    HW_BYTES_HI = 32'h0000_0001;
    #10;
    axi_read(7'h18, readv); $display("HW_BYTES_LO = 0x%08h", readv);
    axi_read(7'h19, readv); $display("HW_BYTES_HI = 0x%08h", readv);

    $display("\n---- Tests complete ----\n");
    #50;
    $finish;
  end

endmodule
