`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench for ip_encapsulator.v
// Simulates clock, reset, models the external BRAM lookup table, and drives
// AXIS streams for meta and payload.
//////////////////////////////////////////////////////////////////////////////////

module ip_encapsulator_tb;

    // =========================================================================
    // 1. PARAMETERS (MUST MATCH ip_encapsulator.v)
    // =========================================================================
    localparam DATA_WIDTH = 64;
    localparam KEEP_WIDTH = DATA_WIDTH/8;
    localparam META_WIDTH = 128;
    localparam BRAM_ADDR_WIDTH = 4;      // Address width of the BRAM in the BD (4-bit -> 16 entries)
    localparam BRAM_DATA_WIDTH = 256;    // Data width of the BRAM in the BD (256-bit wide entry)
    localparam CLK_PERIOD = 10;          // 10ns = 100MHz clock

    // BRAM Lookup Table Constants (Matches BRAM_DATA_WIDTH=256 bits)
    // Example Entry Structure (BRAM_DATA_WIDTH = 256 bits):
    // Bits [255:192] | Bits [191:144] | Bits [143:96] | Bits [95:64] | Bits [63:32] | Bits [31:0]
    // -----------------------------------------------------------------------------------------
    // Reserved (64) | SRC_MAC (48) | DST_MAC (48) | DST_IP (32) | SRC_IP (32) | Reserved (32)
    //
    // The BRAM is indexed by a 4-bit address, so it has 16 entries (0 to 15).

    // --- Entry 0: Known Good Endpoint ---
    localparam [31:0]   EP0_IP_ADDR = 32'h0A000101;         // 10.0.1.1
    localparam [47:0]   EP0_DST_MAC = 48'h000A11223344;
    localparam [47:0]   EP0_SRC_MAC = 48'h000B55667788;
    localparam [BRAM_DATA_WIDTH-1:0] EP0_ENTRY =
        {64'h0, EP0_SRC_MAC, EP0_DST_MAC, EP0_IP_ADDR, 32'h0};

    // =========================================================================
    // 2. SIGNALS
    // =========================================================================
    reg                           clk;
    reg                           rstn;

    // s_axis (payload input)
    reg  [DATA_WIDTH-1:0]   s_axis_tdata;
    reg  [KEEP_WIDTH-1:0]   s_axis_tkeep;
    reg                     s_axis_tvalid;
    wire                    s_axis_tready;
    reg                     s_axis_tlast;
    reg                     s_axis_tuser;

    // meta_axis (sideband metadata)
    reg  [META_WIDTH-1:0]   meta_tdata;
    reg                     meta_tvalid;
    wire                    meta_tready;

    // m_axis (frame output) - Connected to a simple dummy sink
    wire [DATA_WIDTH-1:0]   m_axis_tdata;
    wire [KEEP_WIDTH-1:0]   m_axis_tkeep;
    wire                    m_axis_tvalid;
    reg                     m_axis_tready; // Driven by testbench sink logic
    wire                    m_axis_tlast;
    wire                    m_axis_tuser;

    // BRAM Port B (outputs from ip_encapsulator)
    wire [BRAM_ADDR_WIDTH-1:0] bram_addr_b;
    wire                       bram_en_b;
    wire                       bram_clk_b;
    reg  [BRAM_DATA_WIDTH-1:0] bram_dout_b; // Driven by the testbench BRAM model

    // AXI-Lite Slave (stubbed for now, only connecting the signals)
    reg  [31:0] s_axi_awaddr, s_axi_wdata, s_axi_araddr;
    reg         s_axi_awvalid, s_axi_wvalid, s_axi_bready, s_axi_arvalid, s_axi_rready;
    reg  [3:0]  s_axi_wstrb;
    wire        s_axi_awready, s_axi_wready, s_axi_bvalid, s_axi_arready, s_axi_rvalid;
    wire [1:0]  s_axi_bresp, s_axi_rresp;
    wire [31:0] s_axi_rdata;


    // =========================================================================
    // 3. BRAM MODEL
    // =========================================================================

    // In a full system, this BRAM would be connected to blk_mem_gen_0.
    // Here, we model it with a simple array.
    reg [BRAM_DATA_WIDTH-1:0] bram_memory [0:(2**BRAM_ADDR_WIDTH)-1];

    // Initialize BRAM memory
    initial begin
        // Set the known good endpoint in address 1
        bram_memory[4'd1] = EP0_ENTRY;
        // All other entries are 0 (e.g., a lookup miss)
        bram_memory[4'd0] = {BRAM_DATA_WIDTH{1'b0}};
        bram_memory[4'd2] = {BRAM_DATA_WIDTH{1'b0}};
        // ... fill others if needed ...
    end

    // Combinational lookup logic (models the BRAM's read behavior instantly)
    always @(*) begin
        if (bram_en_b) begin
            bram_dout_b = bram_memory[bram_addr_b];
        end else begin
            bram_dout_b = {BRAM_DATA_WIDTH{1'b0}};
        end
    end

    // =========================================================================
    // 4. INSTANTIATION
    // =========================================================================
    ip_encapsulator #(
        .DATA_WIDTH(DATA_WIDTH),
        .KEEP_WIDTH(KEEP_WIDTH),
        .META_WIDTH(META_WIDTH),
        .BRAM_ADDR_WIDTH(BRAM_ADDR_WIDTH),
        .BRAM_DATA_WIDTH(BRAM_DATA_WIDTH)
    ) u_ip_encapsulator (
        .clk(clk),
        .rstn(rstn),

        // s_axis (payload input)
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tuser(s_axis_tuser),

        // meta_axis (sideband metadata)
        .meta_tdata(meta_tdata),
        .meta_tvalid(meta_tvalid),
        .meta_tready(meta_tready),

        // m_axis (frame output)
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tkeep(m_axis_tkeep),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),
        .m_axis_tuser(m_axis_tuser),

        // BRAM Port B
        .bram_addr_b(bram_addr_b),
        .bram_en_b(bram_en_b),
        .bram_clk_b(bram_clk_b),
        .bram_dout_b(bram_dout_b),

        // AXI4-Lite slave (stubbed connections)
        .s_axi_awaddr(s_axi_awaddr), .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),   .s_axi_wstrb(s_axi_wstrb),   .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),   .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr), .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),   .s_axi_rresp(s_axi_rresp), .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready)
    );

    // =========================================================================
    // 5. CLOCK AND RESET GENERATION
    // =========================================================================

    // Clock generation
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Reset sequence
    initial begin
        // Initialize all inputs
        rstn = 1'b0; // Active HIGH reset, so start low (reset active)
        s_axis_tdata  = {DATA_WIDTH{1'b0}};
        s_axis_tkeep  = {KEEP_WIDTH{1'b0}};
        s_axis_tvalid = 1'b0;
        s_axis_tlast  = 1'b0;
        s_axis_tuser  = 1'b0;
        meta_tdata    = {META_WIDTH{1'b0}};
        meta_tvalid   = 1'b0;
        m_axis_tready = 1'b1; // The sink is always ready to receive
        // Stub AXI-Lite
        s_axi_awaddr  = 32'h0; s_axi_awvalid = 1'b0; s_axi_wdata = 32'h0;
        s_axi_wstrb   = 4'h0; s_axi_wvalid = 1'b0; s_axi_bready = 1'b0;
        s_axi_araddr  = 32'h0; s_axi_arvalid = 1'b0; s_axi_rready = 1'b0;

        // Apply reset for 5 clock cycles
        repeat (5) @(posedge clk);
        rstn = 1'b1; // Release reset
        $display("------------------------------------");
        $display("Simulation Started. Reset released.");
        $display("------------------------------------");
    end

    // =========================================================================
    // 6. PACKET INJECTION TASK
    // =========================================================================

    // Define the bit slices for the META_WIDTH=128 structure
    // This must match the bitfield mapping in ip_encapsulator.v
    localparam META_PAYLEN_MSB = META_WIDTH - 1;
    localparam META_PAYLEN_LSB = META_WIDTH - 16;
    localparam META_SRCIP_MSB  = META_PAYLEN_LSB - 1;
    localparam META_SRCIP_LSB  = META_SRCIP_MSB - 31;
    localparam META_DSTIP_MSB  = META_SRCIP_LSB - 1;
    localparam META_DSTIP_LSB  = META_DSTIP_MSB - 31;
    localparam META_SRCP_MSB   = META_DSTIP_LSB - 1;
    localparam META_SRCP_LSB   = META_SRCP_MSB - 15;
    localparam META_DSTP_MSB   = META_SRCP_LSB - 1;
    localparam META_DSTP_LSB   = META_DSTP_MSB - 15;
    localparam META_FLAGS_MSB  = META_DSTP_LSB - 1;
    localparam META_FLAGS_LSB  = META_FLAGS_MSB - 7;
    localparam META_EP_ID_MSB  = META_FLAGS_LSB - 1;
    localparam META_EP_ID_LSB  = META_EP_ID_MSB - 7;

    task send_packet;
        input [15:0] payload_len;
        input [31:0] src_ip;
        input [31:0] dst_ip;
        input [15:0] src_port;
        input [15:0] dst_port;
        input [31:0] endpoint_id_or_flags; // Use the lower bits for endpoint ID/Flags

        reg [DATA_WIDTH-1:0] current_tdata;
        reg [KEEP_WIDTH-1:0] current_tkeep;
        integer total_beats;
        integer i;
        reg done_sending; // New control flag to replace 'break'

        begin
            $display("\n--- Injecting New Packet (Payload Length: %0d) ---", payload_len);
            done_sending = 1'b0;

            // 1. Prepare and send META beat
            // Clear meta_tdata first to handle the reserved bits easily
            meta_tdata = {META_WIDTH{1'b0}};

            meta_tdata[META_PAYLEN_MSB:META_PAYLEN_LSB] = payload_len;
            meta_tdata[META_SRCIP_MSB:META_SRCIP_LSB]    = src_ip;
            meta_tdata[META_DSTIP_MSB:META_DSTIP_LSB]    = dst_ip;
            meta_tdata[META_SRCP_MSB:META_SRCP_LSB]      = src_port;
            meta_tdata[META_DSTP_MSB:META_DSTP_LSB]      = dst_port;
            
            // Fixed part-select issue: using bit indexes directly
            // Assign the low 8 bits of the input to the Endpoint ID field
            meta_tdata[META_EP_ID_MSB:META_EP_ID_LSB]    = endpoint_id_or_flags[7:0]; 

            meta_tvalid = 1'b1;
            @(posedge clk);
            wait (meta_tready) @(posedge clk);
            meta_tvalid = 1'b0;
            $display("Meta Beat Sent (Dst IP: %h)", dst_ip);

            // 2. Send PAYLOAD beats
            total_beats = (payload_len + (DATA_WIDTH/8) - 1) / (DATA_WIDTH/8); // Ceiling division by KEEP_WIDTH

            for (i = 0; i < total_beats; i = i + 1) begin
                
                if (done_sending) begin // Stop the loop if the last beat was sent
                    $display("Loop termination error: should not have reached here.");
                    //break; // Should be unreachable with 'if (done_sending)'
                end

                current_tdata = {DATA_WIDTH{(i[31:0]%2)}}; // Simple alternating pattern for data
                current_tkeep = {KEEP_WIDTH{1'b1}};

                // Check for the final beat
                if (i == total_beats - 1) begin
                    s_axis_tlast = 1'b1;
                    done_sending = 1'b1; // Set flag to stop the loop after this beat
                    // Calculate tkeep for the final beat
                    if (payload_len % (DATA_WIDTH/8) != 0) begin
                        // Tkeep should only cover the valid bytes in the last beat
                        current_tkeep = (1 << (payload_len % (DATA_WIDTH/8))) - 1;
                    end
                end else begin
                    s_axis_tlast = 1'b0;
                end

                s_axis_tdata = current_tdata;
                s_axis_tkeep = current_tkeep;
                s_axis_tvalid = 1'b1;

                @(posedge clk);
                wait (s_axis_tready) @(posedge clk);

                s_axis_tvalid = 1'b0;
                $display("  Payload Beat %0d Sent. TLAST: %0b, TKEEP: %h", i, s_axis_tlast, s_axis_tkeep);
            end // for loop
            
            // Wait a few cycles for the frame to propagate
            repeat (10) @(posedge clk);
            $display("--- Packet Injection Complete ---");

        end
    endtask

    // =========================================================================
    // 7. MAIN TEST SEQUENCE
    // =========================================================================
    initial begin
        @(posedge rstn); // Wait for reset to be released

        // ---------------------------------------------------------------------
        // TEST CASE 1: Lookup Hit (Dst IP 10.0.1.1 is in BRAM address 1)
        // Expected: Full frame emitted on m_axis_tdata with correct MACs.
        // ---------------------------------------------------------------------
        $display("\n=======================================================");
        $display("        TEST 1: Lookup HIT (Dst IP: 10.0.1.1)");
        $display("=======================================================");
        send_packet(
            .payload_len(16'd48),                // Payload size (48 bytes, 6 beats of 8 bytes)
            .src_ip(32'hC0A8010A),              // 192.168.1.10
            .dst_ip(EP0_IP_ADDR),               // 10.0.1.1 (Hit)
            .src_port(16'd1234),
            .dst_port(16'd5678),
            .endpoint_id_or_flags(32'd1)        // Use endpoint ID 1
        );

        // Wait for the resulting frame to be fully streamed out
        wait (!m_axis_tvalid) @(posedge clk);
        $display("TEST 1: Frame emitted. Check m_axis_tdata/tkeep for correct headers/payload.");


        // ---------------------------------------------------------------------
        // TEST CASE 2: Lookup Miss (Dst IP 10.0.2.2 is not initialized in BRAM)
        // Expected: The lookup should fail and the packet should be dropped.
        // ---------------------------------------------------------------------
        $display("\n=======================================================");
        $display("        TEST 2: Lookup MISS (Dst IP: 10.0.2.2)");
        $display("=======================================================");
        send_packet(
            .payload_len(16'd128),                // Payload size (128 bytes)
            .src_ip(32'hC0A8010A),              // 192.168.1.10
            .dst_ip(32'h0A000202),              // 10.0.2.2 (Miss)
            .src_port(16'd1234),
            .dst_port(16'd5678),
            .endpoint_id_or_flags(32'd0)
        );

        // Wait for the pipeline to clear
        repeat (20) @(posedge clk);
        $display("TEST 2: Pipeline clear. Check lookup_error signal status.");

        // ---------------------------------------------------------------------
        // Simulation End
        // ---------------------------------------------------------------------
        $display("\n------------------------------------");
        $display("Simulation Finished.");
        $display("------------------------------------");
        $finish;

    end

endmodule
