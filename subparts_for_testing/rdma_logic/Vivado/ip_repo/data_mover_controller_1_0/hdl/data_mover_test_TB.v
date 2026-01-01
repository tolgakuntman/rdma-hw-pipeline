`timescale 1ns / 1ps

module data_mover_test_tb();

    localparam T = 10;   // clock period = 10 ns (100 MHz)

    // Clock & reset
    reg clk;
    reg rst_n;

    // AXI-Lite signals
    wire        s_axi_arready;
    reg [6:0]   s_axi_araddr;
    reg [2:0]   s_axi_arprot;
    reg         s_axi_arvalid;

    wire        s_axi_awready;
    reg [6:0]   s_axi_awaddr;
    reg [2:0]   s_axi_awprot;
    reg         s_axi_awvalid;

    reg         s_axi_bready;
    wire [1:0]  s_axi_bresp;
    wire        s_axi_bvalid;

    reg         s_axi_rready;
    wire [31:0] s_axi_rdata;
    wire [1:0]  s_axi_rresp;
    wire        s_axi_rvalid;

    wire        s_axi_wready;
    reg [31:0]  s_axi_wdata;
    reg [3:0]   s_axi_wstrb;
    reg         s_axi_wvalid;

    // Debug outputs from DUT
    wire [3:0]  hw_sq_head;
    wire        cmd_ctrl_ready;
    wire [31:0] debug_status_word;

    // Control signal for DataMover completion simulation
    reg         mm2s_rd_xfer_cmplt;

    // DUT instantiation
    data_mover_test dut (
        .clk                (clk),
        .rst_n              (rst_n),

        .s_axi_awaddr       (s_axi_awaddr),
        .s_axi_awprot       (s_axi_awprot),
        .s_axi_awvalid      (s_axi_awvalid),
        .s_axi_awready      (s_axi_awready),
        .s_axi_wdata        (s_axi_wdata),
        .s_axi_wstrb        (s_axi_wstrb),
        .s_axi_wvalid       (s_axi_wvalid),
        .s_axi_wready       (s_axi_wready),
        .s_axi_bresp        (s_axi_bresp),
        .s_axi_bvalid       (s_axi_bvalid),
        .s_axi_bready       (s_axi_bready),
        .s_axi_araddr       (s_axi_araddr),
        .s_axi_arprot       (s_axi_arprot),
        .s_axi_arvalid      (s_axi_arvalid),
        .s_axi_arready      (s_axi_arready),
        .s_axi_rdata        (s_axi_rdata),
        .s_axi_rresp        (s_axi_rresp),
        .s_axi_rvalid       (s_axi_rvalid),
        .s_axi_rready       (s_axi_rready),

        .HW_SQ_HEAD         (hw_sq_head),
        .cmd_ctrl_ready     (cmd_ctrl_ready),
        .debug_status_word  (debug_status_word),
        .mm2s_rd_xfer_cmplt (mm2s_rd_xfer_cmplt)
    );

    // Clock generation: 100 MHz
    initial clk = 1'b0;
    always #(T/2) clk = ~clk;

    // Main stimulus
    initial begin
        // *** Initial values ***
        rst_n         = 1'b0;

        s_axi_awaddr  = 7'd0;
        s_axi_awprot  = 3'd0;
        s_axi_awvalid = 1'b0;
        s_axi_wstrb   = 4'd0;
        s_axi_wdata   = 32'd0;
        s_axi_wvalid  = 1'b0;
        s_axi_bready  = 1'b0;

        s_axi_araddr  = 7'd0;
        s_axi_arprot  = 3'd0;
        s_axi_arvalid = 1'b0;
        s_axi_rready  = 1'b0;

        mm2s_rd_xfer_cmplt = 1'b0;

        // *** Reset sequence ***
        #(T*5);
        rst_n = 1'b1;          // deassert reset
        #(T*5);

        $display("=== Start RDMA SQ Test ===");

        // Register offsets (word-aligned byte addresses)
        // REG[0] = 0x00 = CTRL (bit 0 = GLOBAL_ENABLE)
        // REG[8] = 0x20 = SQ_BASE_LO
        // REG[10] = 0x28 = SQ_SIZE
        // REG[11] = 0x2C = HW_SQ_HEAD (read-only)
        // REG[12] = 0x30 = SQ_TAIL
        // REG[1] = 0x04 = HW_STATUS_WORD (debug)

        // *** Configure SQ ***
        axi_write(7'h20, 32'h1000_0000);  // SQ_BASE_LO = 0x10000000
        axi_write(7'h28, 32'd8);          // SQ_SIZE = 8 entries
        axi_write(7'h30, 32'd0);          // SQ_TAIL = 0 (init)

        $display("\n--- Reading initial state ---");
        axi_read(7'h2C);                  // Read HW_SQ_HEAD (should be 0)
        axi_read(7'h04);                  // Read HW_STATUS_WORD

        // *** Enable RDMA controller ***
        $display("\n--- Enabling RDMA controller ---");
        axi_write(7'h00, 32'd1);          // GLOBAL_ENABLE = 1
        #(T*5);

        // *** Submit first SQ entry (increment tail) ***
        $display("\n--- Submitting SQ entry (TAIL=0->1) ---");
        axi_write(7'h30, 32'd1);          // SQ_TAIL = 1
        #(T*10);

        axi_read(7'h04);                  // Read status
        axi_read(7'h2C);                  // Read HW_SQ_HEAD (should still be 0)

        // *** Simulate DataMover read completion ***
        $display("\n--- Simulating MM2S read completion ---");
        @(negedge clk);
        mm2s_rd_xfer_cmplt = 1'b1;
        @(negedge clk);
        mm2s_rd_xfer_cmplt = 1'b0;
        #(T*10);

        axi_read(7'h2C);                  // Read HW_SQ_HEAD (should increment to 1)
        axi_read(7'h04);                  // Read status

        // *** Submit second SQ entry ***
        $display("\n--- Submitting second SQ entry (TAIL=1->2) ---");
        axi_write(7'h30, 32'd2);          // SQ_TAIL = 2
        #(T*10);

        axi_read(7'h04);                  // Read status

        // *** Simulate second completion ***
        $display("\n--- Simulating second MM2S completion ---");
        @(negedge clk);
        mm2s_rd_xfer_cmplt = 1'b1;
        @(negedge clk);
        mm2s_rd_xfer_cmplt = 1'b0;
        #(T*10);

        axi_read(7'h2C);                  // Read HW_SQ_HEAD (should be 2)
        axi_read(7'h04);                  // Read status

        // *** Read debug registers ***
        $display("\n--- Reading debug registers ---");
        axi_read(7'h60);                  // REG[24] = HW_BYTES_LO
        axi_read(7'h64);                  // REG[25] = HW_BYTES_HI
        axi_read(7'h68);                  // REG[26] = HW_WQE_PROCESSED
        axi_read(7'h6C);                  // REG[27] = mm2s_data[31:0]
        axi_read(7'h70);                  // REG[28] = mm2s_data[63:32]
        axi_read(7'h74);                  // REG[29] = mm2s_data[71:64]

        $display("\n=== End of simulation ===");
        #(T*20);
        $stop;
    end

    // =========================
    // AXI-Lite WRITE transaction
    // =========================
    task axi_write;
        input [6:0] awaddr;
        input [31:0] wdata;
    begin
        // Drive address & data on a clock edge
        @(negedge clk);
        s_axi_awaddr  <= awaddr;
        s_axi_awvalid <= 1'b1;

        s_axi_wdata   <= wdata;
        s_axi_wstrb   <= 4'hF;
        s_axi_wvalid  <= 1'b1;
        s_axi_bready  <= 1'b1;

        // Wait until slave accepts both address and data
        wait (s_axi_awready && s_axi_wready);
        @(negedge clk);
        s_axi_awvalid <= 1'b0;
        s_axi_wvalid  <= 1'b0;

        // Wait for write response
        wait (s_axi_bvalid);
        @(negedge clk);
        s_axi_bready  <= 1'b0;

        $display("[%0t] AXI WRITE  addr=0x%02h data=0x%08h bresp=%0d",
                  $time, awaddr, wdata, s_axi_bresp);
    end
    endtask

    // =========================
    // AXI-Lite READ transaction
    // =========================
    task axi_read;
        input [6:0] araddr;
        reg   [31:0] rdata;
    begin
        // Send read address
        @(negedge clk);
        s_axi_araddr  <= araddr;
        s_axi_arvalid <= 1'b1;
        s_axi_rready  <= 1'b1;

        // Wait for ARREADY
        wait (s_axi_arready);
        @(negedge clk);
        s_axi_arvalid <= 1'b0;

        // Wait for RVALID (data available)
        wait (s_axi_rvalid);
        rdata = s_axi_rdata;
        @(negedge clk);
        s_axi_rready <= 1'b0;

        $display("[%0t] AXI READ   addr=0x%02h data=0x%08h rresp=%0d",
                  $time, araddr, rdata, s_axi_rresp);
    end
    endtask

endmodule
