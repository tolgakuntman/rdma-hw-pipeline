`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Testbench: tb_rx_header_parser
// 
// Description:
//   Tests the rx_header_parser module by sending RDMA packets with headers
//   matching the format from tx_header_inserter
//
////////////////////////////////////////////////////////////////////////////////

module tb_rx_header_parser();

    // Clock and reset
    reg aclk;
    reg aresetn;
    
    // Parameters
    localparam C_AXIS_TDATA_WIDTH = 32;
    localparam C_AXIS_TKEEP_WIDTH = 4;
    localparam RDMA_OPCODE_WIDTH  = 8;
    localparam RDMA_PSN_WIDTH     = 24;
    localparam RDMA_QPN_WIDTH     = 24;
    localparam RDMA_ADDR_WIDTH    = 64;
    localparam RDMA_RKEY_WIDTH    = 32;
    localparam RDMA_LENGTH_WIDTH  = 32;
    
    // Slave interface (input to parser)
    reg  [C_AXIS_TDATA_WIDTH-1:0]   s_axis_tdata;
    reg  [C_AXIS_TKEEP_WIDTH-1:0]   s_axis_tkeep;
    reg                             s_axis_tvalid;
    wire                            s_axis_tready;
    reg                             s_axis_tlast;
    
    // Master interface (output from parser)
    wire [C_AXIS_TDATA_WIDTH-1:0]   m_axis_tdata;
    wire [C_AXIS_TKEEP_WIDTH-1:0]   m_axis_tkeep;
    wire                            m_axis_tvalid;
    reg                             m_axis_tready;
    wire                            m_axis_tlast;
    
    // Status signals
    wire                            rx_busy;
    wire                            header_valid;
    
    // Parsed RDMA Header Fields
    wire [RDMA_OPCODE_WIDTH-1:0]    rdma_opcode;
    wire [RDMA_PSN_WIDTH-1:0]       rdma_psn;
    wire [RDMA_QPN_WIDTH-1:0]       rdma_dest_qp;
    wire [RDMA_ADDR_WIDTH-1:0]      rdma_remote_addr;
    wire [RDMA_RKEY_WIDTH-1:0]      rdma_rkey;
    wire [RDMA_LENGTH_WIDTH-1:0]    rdma_length;
    wire [15:0]                     rdma_partition_key;
    wire [7:0]                      rdma_service_level;
    wire [15:0]                     fragment_id;
    wire                            more_fragments;
    wire [15:0]                     fragment_offset;
    
    // Test data - RDMA header fields to send
    reg [7:0]   test_opcode;
    reg [23:0]  test_psn;
    reg [23:0]  test_dest_qp;
    reg [31:0]  test_remote_addr;
    reg [15:0]  test_fragment_offset;
    reg [31:0]  test_length;
    reg [15:0]  test_partition_key;
    reg [7:0]   test_service_level;
    
    // Payload data
    reg [31:0]  payload_data [0:255];
    integer     payload_length;
    
    // Instantiate DUT
    rx_header_parser #(
        .C_AXIS_TDATA_WIDTH(C_AXIS_TDATA_WIDTH),
        .C_AXIS_TKEEP_WIDTH(C_AXIS_TKEEP_WIDTH),
        .RDMA_OPCODE_WIDTH(RDMA_OPCODE_WIDTH),
        .RDMA_PSN_WIDTH(RDMA_PSN_WIDTH),
        .RDMA_QPN_WIDTH(RDMA_QPN_WIDTH),
        .RDMA_ADDR_WIDTH(RDMA_ADDR_WIDTH),
        .RDMA_RKEY_WIDTH(RDMA_RKEY_WIDTH),
        .RDMA_LENGTH_WIDTH(RDMA_LENGTH_WIDTH)
    ) dut (
        .aclk(aclk),
        .aresetn(aresetn),
        
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tkeep(m_axis_tkeep),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),
        
        .header_valid(header_valid),
        
        .rdma_opcode(rdma_opcode),
        .rdma_psn(rdma_psn),
        .rdma_dest_qp(rdma_dest_qp),
        .rdma_remote_addr(rdma_remote_addr),
        .rdma_rkey(rdma_rkey),
        .rdma_length(rdma_length),
        .rdma_partition_key(rdma_partition_key),
        .rdma_service_level(rdma_service_level),
        .fragment_id(fragment_id),
        .more_fragments(more_fragments),
        .fragment_offset(fragment_offset)
    );
    
    // Clock generation (100MHz)
    initial begin
        aclk = 0;
        forever #5 aclk = ~aclk;
    end
    
    // Task to send RDMA packet with header + payload
    task send_rdma_packet;
        input [7:0]   opcode;
        input [23:0]  psn;
        input [23:0]  dest_qp;
        input [31:0]  remote_addr;
        input [15:0]  frag_offset;
        input [31:0]  length;
        input [15:0]  partition_key;
        input [7:0]   service_level;
        input integer num_payload_beats;
        
        integer i;
        begin
            $display("[%0t] Sending RDMA packet: opcode=0x%02h, addr=0x%08h, offset=0x%04h, length=%0d", 
                     $time, opcode, remote_addr, frag_offset, length);
            
            // Wait for ready
            @(posedge aclk);
            while (!s_axis_tready) @(posedge aclk);
            
//            s_axis_tdata  = {32'd0};
//            s_axis_tkeep  = 4'hF;
//            s_axis_tvalid = 1;
//            s_axis_tlast  = 0;
//            @(posedge aclk);
            while (!s_axis_tready) @(posedge aclk);
            // Beat 0: {PSN[23:0], Opcode[7:0]}
            s_axis_tdata  = {psn, opcode};
            s_axis_tkeep  = 4'hF;
            s_axis_tvalid = 1;
            s_axis_tlast  = 0;
            @(posedge aclk);
            while (!s_axis_tready) @(posedge aclk);
            
            // Beat 1: {8'h00, Dest_QP[23:0]}
            s_axis_tdata  = {8'h00, dest_qp};
            @(posedge aclk);
            while (!s_axis_tready) @(posedge aclk);
            
            // Beat 2: Remote_Addr[31:0]
            s_axis_tdata  = remote_addr;
            @(posedge aclk);
            while (!s_axis_tready) @(posedge aclk);
            
            // Beat 3: {16'h0000, fragment_offset[15:0]}
            s_axis_tdata  = {16'h0000, frag_offset};
            @(posedge aclk);
            while (!s_axis_tready) @(posedge aclk);
            
            // Beat 4: Length[31:0]
            s_axis_tdata  = length;
            @(posedge aclk);
            while (!s_axis_tready) @(posedge aclk);
            
            // Beat 5: {16'h0000, Partition_Key[15:0]}
            s_axis_tdata  = {16'h0000, partition_key};
            @(posedge aclk);
            while (!s_axis_tready) @(posedge aclk);
            
            // Beat 6: {24'hababab, Service_Level[7:0]}
            s_axis_tdata  = {24'hababab, service_level};
            @(posedge aclk);
            while (!s_axis_tready) @(posedge aclk);
            
            // Send payload data
            for (i = 0; i < num_payload_beats; i = i + 1) begin
                s_axis_tdata  = payload_data[i];
                s_axis_tlast  = (i == num_payload_beats - 1);
                @(posedge aclk);
                while (!s_axis_tready) @(posedge aclk);
            end
            
            // De-assert valid
            s_axis_tvalid = 0;
            s_axis_tlast  = 0;
            @(posedge aclk);
            
            $display("[%0t] Packet sent", $time);
        end
    endtask
    
    // Task to check parsed header values
    task check_header;
        input [7:0]   exp_opcode;
        input [23:0]  exp_psn;
        input [23:0]  exp_dest_qp;
        input [31:0]  exp_remote_addr;
        input [15:0]  exp_frag_offset;
        input [31:0]  exp_length;
        input [15:0]  exp_partition_key;
        input [7:0]   exp_service_level;
        
        integer errors;
        begin
            errors = 0;
            
            $display("[%0t] Checking parsed header values:", $time);
            
            if (rdma_opcode !== exp_opcode) begin
                $display("  ERROR: Opcode mismatch! Expected=0x%02h, Got=0x%02h", exp_opcode, rdma_opcode);
                errors = errors + 1;
            end else begin
                $display("  PASS: Opcode = 0x%02h", rdma_opcode);
            end
            
            if (rdma_psn !== exp_psn) begin
                $display("  ERROR: PSN mismatch! Expected=0x%06h, Got=0x%06h", exp_psn, rdma_psn);
                errors = errors + 1;
            end else begin
                $display("  PASS: PSN = 0x%06h", rdma_psn);
            end
            
            if (rdma_dest_qp !== exp_dest_qp) begin
                $display("  ERROR: Dest QP mismatch! Expected=0x%06h, Got=0x%06h", exp_dest_qp, rdma_dest_qp);
                errors = errors + 1;
            end else begin
                $display("  PASS: Dest QP = 0x%06h", rdma_dest_qp);
            end
            
            if (rdma_remote_addr[31:0] !== exp_remote_addr) begin
                $display("  ERROR: Remote Addr mismatch! Expected=0x%08h, Got=0x%08h", exp_remote_addr, rdma_remote_addr[31:0]);
                errors = errors + 1;
            end else begin
                $display("  PASS: Remote Addr = 0x%08h", rdma_remote_addr[31:0]);
            end
            
            if (fragment_offset !== exp_frag_offset) begin
                $display("  ERROR: Fragment Offset mismatch! Expected=0x%04h, Got=0x%04h", exp_frag_offset, fragment_offset);
                errors = errors + 1;
            end else begin
                $display("  PASS: Fragment Offset = 0x%04h", fragment_offset);
            end
            
            if (rdma_length !== exp_length) begin
                $display("  ERROR: Length mismatch! Expected=%0d (0x%08h), Got=%0d (0x%08h)", 
                         exp_length, exp_length, rdma_length, rdma_length);
                errors = errors + 1;
            end else begin
                $display("  PASS: Length = %0d bytes", rdma_length);
            end
            
            if (rdma_partition_key !== exp_partition_key) begin
                $display("  ERROR: Partition Key mismatch! Expected=0x%04h, Got=0x%04h", exp_partition_key, rdma_partition_key);
                errors = errors + 1;
            end else begin
                $display("  PASS: Partition Key = 0x%04h", rdma_partition_key);
            end
            
            if (rdma_service_level !== exp_service_level) begin
                $display("  ERROR: Service Level mismatch! Expected=0x%02h, Got=0x%02h", exp_service_level, rdma_service_level);
                errors = errors + 1;
            end else begin
                $display("  PASS: Service Level = 0x%02h", rdma_service_level);
            end
            
            if (errors == 0) begin
                $display("  === ALL CHECKS PASSED ===");
            end else begin
                $display("  === %0d ERRORS FOUND ===", errors);
            end
        end
    endtask
    
    // Main test
    integer i;
    initial begin
        // Initialize signals
        aresetn = 0;
        s_axis_tdata = 0;
        s_axis_tkeep = 0;
        s_axis_tvalid = 0;
        s_axis_tlast = 0;
        m_axis_tready = 1;  // Always ready to accept data
        
        // Initialize test data
        test_opcode = 0;
        test_psn = 0;
        test_dest_qp = 0;
        test_remote_addr = 0;
        test_fragment_offset = 0;
        test_length = 0;
        test_partition_key = 0;
        test_service_level = 0;
        
        // Initialize payload
        for (i = 0; i < 256; i = i + 1) begin
            payload_data[i] = 32'hA0A0A0A0 + i;
        end
        
        // Reset
        $display("========================================");
        $display("Starting RX Header Parser Testbench");
        $display("========================================");
        #100;
        aresetn = 1;
        #50;
        
        //----------------------------------------------------------------------
        // Test 1: Small packet with offset 0
        //----------------------------------------------------------------------
        $display("\n[TEST 1] Small packet: 256 bytes at 0x40000000 + offset 0x0000");
        send_rdma_packet(
            .opcode(8'h01),              // RDMA_OPCODE_WRITE_TEST
            .psn(24'h000111),
            .dest_qp(24'h000100),
            .remote_addr(32'h40000000),
            .frag_offset(16'h0000),
            .length(32'd256),
            .partition_key(16'hFFFF),
            .service_level(8'h05),
            .num_payload_beats(64)       // 256 bytes / 4 bytes per beat
        );
        
        // Wait for header_valid pulse
        @(posedge aclk);
        
        #10;
        
        //----------------------------------------------------------------------
        // Test 2: Packet with non-zero offset
        //----------------------------------------------------------------------
        $display("\n[TEST 2] Packet with offset: 512 bytes at 0x40000000 + offset 0x1000");
        send_rdma_packet(
            .opcode(8'h01),
            .psn(24'h000002),
            .dest_qp(24'h000100),
            .remote_addr(32'h40000000),
            .frag_offset(16'h1000),
            .length(32'd512),
            .partition_key(16'h1234),
            .service_level(8'h03),
            .num_payload_beats(128)
        );
        
        
        #10;
        
        //----------------------------------------------------------------------
        // Test 3: Another packet with different offset
        //----------------------------------------------------------------------
        $display("\n[TEST 3] Third packet: 128 bytes at 0x40000000 + offset 0x3000");
        send_rdma_packet(
            .opcode(8'h0A),              // RDMA_OPCODE_WRITE_ONLY
            .psn(24'h000003),
            .dest_qp(24'h000100),
            .remote_addr(32'h40000000),
            .frag_offset(16'h3000),
            .length(32'd128),
            .partition_key(16'h5678),
            .service_level(8'h07),
            .num_payload_beats(32)
        );
        
        @(posedge aclk);
        while (!header_valid) @(posedge aclk);
        @(posedge aclk);
        
        check_header(
            .exp_opcode(8'h0A),
            .exp_psn(24'h000003),
            .exp_dest_qp(24'h000100),
            .exp_remote_addr(32'h40000000),
            .exp_frag_offset(16'h3000),
            .exp_length(32'd128),
            .exp_partition_key(16'h5678),
            .exp_service_level(8'h07)
        );
        
        @(posedge aclk);
        while (rx_busy) @(posedge aclk);
        #100;
        
        //----------------------------------------------------------------------
        // Test complete
        //----------------------------------------------------------------------
        $display("\n========================================");
        $display("All tests completed!");
        $display("========================================");
        #500;
        $finish;
    end
    
    // Monitor header_valid pulses
    always @(posedge aclk) begin
        if (header_valid) begin
            $display("[%0t] *** HEADER_VALID pulse detected ***", $time);
        end
    end
    
    // Timeout watchdog
    initial begin
        #100000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
