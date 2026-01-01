`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Testbench: tb_tx_rx_loopback
// 
// Description:
//   Tests the tx_header_inserter and rx_header_parser modules together
//   by connecting them in a loopback configuration with an optional FIFO
//   in between to simulate real-world conditions.
//
////////////////////////////////////////////////////////////////////////////////

module tb_tx_rx_loopback();

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
    
    //--------------------------------------------------------------------------
    // TX Header Inserter Signals
    //--------------------------------------------------------------------------
    // TX data input (payload from data mover)
    reg  [C_AXIS_TDATA_WIDTH-1:0]   tx_s_axis_tdata;
    reg  [C_AXIS_TKEEP_WIDTH-1:0]   tx_s_axis_tkeep;
    reg                             tx_s_axis_tvalid;
    wire                            tx_s_axis_tready;
    reg                             tx_s_axis_tlast;
    
    // TX output (header + payload to network/FIFO)
    wire [C_AXIS_TDATA_WIDTH-1:0]   tx_m_axis_tdata;
    wire [C_AXIS_TKEEP_WIDTH-1:0]   tx_m_axis_tkeep;
    wire                            tx_m_axis_tvalid;
    wire                             tx_m_axis_tready;
    wire                            tx_m_axis_tlast;
    
    // TX control
    reg                             start_tx;
    wire                            tx_busy;
    wire                            tx_done;
    
    // TX header metadata
    reg [RDMA_OPCODE_WIDTH-1:0]     tx_rdma_opcode;
    reg [RDMA_PSN_WIDTH-1:0]        tx_rdma_psn;
    reg [RDMA_QPN_WIDTH-1:0]        tx_rdma_dest_qp;
    reg [RDMA_ADDR_WIDTH-1:0]       tx_rdma_remote_addr;
    reg [RDMA_RKEY_WIDTH-1:0]       tx_rdma_rkey;
    reg [RDMA_LENGTH_WIDTH-1:0]     tx_rdma_length;
    reg [15:0]                       tx_rdma_partition_key;
    reg [7:0]                        tx_rdma_service_level;
    reg [15:0]                       tx_fragment_id;
    reg                              tx_more_fragments;
    reg [15:0]                       tx_fragment_offset;
    
    //--------------------------------------------------------------------------
    // RX Header Parser Signals
    //--------------------------------------------------------------------------
    // RX input (from TX output / FIFO)
    wire [C_AXIS_TDATA_WIDTH-1:0]   rx_s_axis_tdata;
    wire [C_AXIS_TKEEP_WIDTH-1:0]   rx_s_axis_tkeep;
    wire                            rx_s_axis_tvalid;
    wire                            rx_s_axis_tready;
    wire                            rx_s_axis_tlast;
    
    // RX output (payload only, header stripped)
    wire [C_AXIS_TDATA_WIDTH-1:0]   rx_m_axis_tdata;
    wire [C_AXIS_TKEEP_WIDTH-1:0]   rx_m_axis_tkeep;
    wire                            rx_m_axis_tvalid;
    reg                             rx_m_axis_tready;
    wire                            rx_m_axis_tlast;
    
    // RX status
    wire                            rx_busy;
    wire                            header_valid;
    
    // RX parsed header
    wire [RDMA_OPCODE_WIDTH-1:0]    rx_rdma_opcode;
    wire [RDMA_PSN_WIDTH-1:0]       rx_rdma_psn;
    wire [RDMA_QPN_WIDTH-1:0]       rx_rdma_dest_qp;
    wire [RDMA_ADDR_WIDTH-1:0]      rx_rdma_remote_addr;
    wire [RDMA_RKEY_WIDTH-1:0]      rx_rdma_rkey;
    wire [RDMA_LENGTH_WIDTH-1:0]    rx_rdma_length;
    wire [15:0]                      rx_rdma_partition_key;
    wire [7:0]                       rx_rdma_service_level;
    wire [15:0]                      rx_fragment_id;
    wire                             rx_more_fragments;
    wire [15:0]                      rx_fragment_offset;
    wire [3:0]                       rx_beat_output;
    
    //--------------------------------------------------------------------------
    // Connect TX output directly to RX input (loopback)
    //--------------------------------------------------------------------------
    assign rx_s_axis_tdata  = tx_m_axis_tdata;
    assign rx_s_axis_tkeep  = tx_m_axis_tkeep;
    assign rx_s_axis_tvalid = tx_m_axis_tvalid;
    assign tx_m_axis_tready = rx_s_axis_tready;
    assign rx_s_axis_tlast  = tx_m_axis_tlast;
    
    //--------------------------------------------------------------------------
    // Instantiate TX Header Inserter
    //--------------------------------------------------------------------------
    tx_header_inserter #(
        .C_AXIS_TDATA_WIDTH(C_AXIS_TDATA_WIDTH),
        .C_AXIS_TKEEP_WIDTH(C_AXIS_TKEEP_WIDTH),
        .RDMA_OPCODE_WIDTH(RDMA_OPCODE_WIDTH),
        .RDMA_PSN_WIDTH(RDMA_PSN_WIDTH),
        .RDMA_QPN_WIDTH(RDMA_QPN_WIDTH),
        .RDMA_ADDR_WIDTH(RDMA_ADDR_WIDTH),
        .RDMA_RKEY_WIDTH(RDMA_RKEY_WIDTH),
        .RDMA_LENGTH_WIDTH(RDMA_LENGTH_WIDTH)
    ) tx_dut (
        .aclk(aclk),
        .aresetn(aresetn),
        
        .s_axis_tdata(tx_s_axis_tdata),
        .s_axis_tkeep(tx_s_axis_tkeep),
        .s_axis_tvalid(tx_s_axis_tvalid),
        .s_axis_tready(tx_s_axis_tready),
        .s_axis_tlast(tx_s_axis_tlast),
        
        .m_axis_tdata(tx_m_axis_tdata),
        .m_axis_tkeep(tx_m_axis_tkeep),
        .m_axis_tvalid(tx_m_axis_tvalid),
        .m_axis_tready(tx_m_axis_tready),
        .m_axis_tlast(tx_m_axis_tlast),
        
        .start_tx(start_tx),
        .tx_busy(tx_busy),
        .tx_done(tx_done),
        
        .rdma_opcode(tx_rdma_opcode),
        .rdma_psn(tx_rdma_psn),
        .rdma_dest_qp(tx_rdma_dest_qp),
        .rdma_remote_addr(tx_rdma_remote_addr),
        .rdma_rkey(tx_rdma_rkey),
        .rdma_length(tx_rdma_length),
        .rdma_partition_key(tx_rdma_partition_key),
        .rdma_service_level(tx_rdma_service_level),
        .fragment_id(tx_fragment_id),
        .more_fragments(tx_more_fragments),
        .fragment_offset(tx_fragment_offset)
    );
    
    //--------------------------------------------------------------------------
    // Instantiate RX Header Parser
    //--------------------------------------------------------------------------
    rx_header_parser #(
        .C_AXIS_TDATA_WIDTH(C_AXIS_TDATA_WIDTH),
        .C_AXIS_TKEEP_WIDTH(C_AXIS_TKEEP_WIDTH),
        .RDMA_OPCODE_WIDTH(RDMA_OPCODE_WIDTH),
        .RDMA_PSN_WIDTH(RDMA_PSN_WIDTH),
        .RDMA_QPN_WIDTH(RDMA_QPN_WIDTH),
        .RDMA_ADDR_WIDTH(RDMA_ADDR_WIDTH),
        .RDMA_RKEY_WIDTH(RDMA_RKEY_WIDTH),
        .RDMA_LENGTH_WIDTH(RDMA_LENGTH_WIDTH)
    ) rx_dut (
        .aclk(aclk),
        .aresetn(aresetn),
        
        .s_axis_tdata(rx_s_axis_tdata),
        .s_axis_tkeep(rx_s_axis_tkeep),
        .s_axis_tvalid(rx_s_axis_tvalid),
        .s_axis_tready(rx_s_axis_tready),
        .s_axis_tlast(rx_s_axis_tlast),
        
        .m_axis_tdata(rx_m_axis_tdata),
        .m_axis_tkeep(rx_m_axis_tkeep),
        .m_axis_tvalid(rx_m_axis_tvalid),
        .m_axis_tready(rx_m_axis_tready),
        .m_axis_tlast(rx_m_axis_tlast),
        
        .header_valid(header_valid),
        
        .rdma_opcode(rx_rdma_opcode),
        .rdma_psn(rx_rdma_psn),
        .rdma_dest_qp(rx_rdma_dest_qp),
        .rdma_remote_addr(rx_rdma_remote_addr),
        .rdma_rkey(rx_rdma_rkey),
        .rdma_length(rx_rdma_length),
        .rdma_partition_key(rx_rdma_partition_key),
        .rdma_service_level(rx_rdma_service_level),
        .fragment_id(rx_fragment_id),
        .more_fragments(rx_more_fragments),
        .fragment_offset(rx_fragment_offset)
    );
    
    //--------------------------------------------------------------------------
    // Clock generation (100MHz)
    //--------------------------------------------------------------------------
    initial begin
        aclk = 0;
        forever #5 aclk = ~aclk;
    end
    
    //--------------------------------------------------------------------------
    // Test data storage
    //--------------------------------------------------------------------------
    reg [31:0] tx_payload_data [0:255];
    reg [31:0] rx_payload_data [0:255];
    integer tx_payload_beats;
    integer rx_payload_count;
    
    //--------------------------------------------------------------------------
    // Task: Send payload data through TX
    //--------------------------------------------------------------------------
    task send_tx_payload;
        input integer num_beats;
        integer i;
        begin
            $display("[%0t] TX: Starting payload transmission (%0d beats)", $time, num_beats);
            
            for (i = 0; i < num_beats; i = i + 1) begin
                @(posedge aclk);
                tx_s_axis_tdata  = tx_payload_data[i];
                tx_s_axis_tkeep  = 4'hF;
                tx_s_axis_tvalid = 1;
                tx_s_axis_tlast  = (i == num_beats - 1);
                
                // Wait for ready
                while (!tx_s_axis_tready) begin
                    @(posedge aclk);
                end
            end
            
            @(posedge aclk);
            tx_s_axis_tvalid = 0;
            tx_s_axis_tlast  = 0;
            
            $display("[%0t] TX: Payload transmission complete", $time);
        end
    endtask
    
    //--------------------------------------------------------------------------
    // Task: Receive and verify payload data from RX
    //--------------------------------------------------------------------------
    task receive_rx_payload;
        input integer expected_beats;
        integer i;
        integer errors;
        begin
            errors = 0;
            rx_payload_count = 0;
            
            $display("[%0t] RX: Waiting for payload data (%0d beats expected)", $time, expected_beats);
            
            // Wait for first valid data
            while (!rx_m_axis_tvalid) @(posedge aclk);
            
            // Collect all payload beats
            while (1) begin
                @(posedge aclk);
                if (rx_m_axis_tvalid && rx_m_axis_tready) begin
                    rx_payload_data[rx_payload_count] = rx_m_axis_tdata;
                    
                    // Verify data matches
                    if (rx_m_axis_tdata !== tx_payload_data[rx_payload_count]) begin
                        $display("  ERROR: Payload mismatch at beat %0d! Expected=0x%08h, Got=0x%08h",
                                 rx_payload_count, tx_payload_data[rx_payload_count], rx_m_axis_tdata);
                        errors = errors + 1;
                    end
                    
                    rx_payload_count = rx_payload_count + 1;
                    
                    while (!rx_m_axis_tlast) begin
                    end
                end
            end
            
            $display("[%0t] RX: Received %0d payload beats", $time, rx_payload_count);
            
            if (rx_payload_count !== expected_beats) begin
                $display("  ERROR: Payload length mismatch! Expected=%0d, Got=%0d", 
                         expected_beats, rx_payload_count);
                errors = errors + 1;
            end
            
            if (errors == 0) begin
                $display("  PASS: All payload data verified");
            end else begin
                $display("  FAIL: %0d payload errors", errors);
            end
        end
    endtask
    
    //--------------------------------------------------------------------------
    // Task: Check RX parsed header
    //--------------------------------------------------------------------------
    task check_rx_header;
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
            
            $display("[%0t] RX: Checking parsed header values:", $time);
            
            if (rx_rdma_opcode !== exp_opcode) begin
                $display("  ERROR: Opcode mismatch! Expected=0x%02h, Got=0x%02h", exp_opcode, rx_rdma_opcode);
                errors = errors + 1;
            end else begin
                $display("  PASS: Opcode = 0x%02h", rx_rdma_opcode);
            end
            
            if (rx_rdma_psn !== exp_psn) begin
                $display("  ERROR: PSN mismatch! Expected=0x%06h, Got=0x%06h", exp_psn, rx_rdma_psn);
                errors = errors + 1;
            end else begin
                $display("  PASS: PSN = 0x%06h", rx_rdma_psn);
            end
            
            if (rx_rdma_dest_qp !== exp_dest_qp) begin
                $display("  ERROR: Dest QP mismatch! Expected=0x%06h, Got=0x%06h", exp_dest_qp, rx_rdma_dest_qp);
                errors = errors + 1;
            end else begin
                $display("  PASS: Dest QP = 0x%06h", rx_rdma_dest_qp);
            end
            
            if (rx_rdma_remote_addr[31:0] !== exp_remote_addr) begin
                $display("  ERROR: Remote Addr mismatch! Expected=0x%08h, Got=0x%08h", exp_remote_addr, rx_rdma_remote_addr[31:0]);
                errors = errors + 1;
            end else begin
                $display("  PASS: Remote Addr = 0x%08h", rx_rdma_remote_addr[31:0]);
            end
            
            if (rx_fragment_offset !== exp_frag_offset) begin
                $display("  ERROR: Fragment Offset mismatch! Expected=0x%04h, Got=0x%04h", exp_frag_offset, rx_fragment_offset);
                errors = errors + 1;
            end else begin
                $display("  PASS: Fragment Offset = 0x%04h", rx_fragment_offset);
            end
            
            if (rx_rdma_length !== exp_length) begin
                $display("  ERROR: Length mismatch! Expected=%0d, Got=%0d", exp_length, rx_rdma_length);
                errors = errors + 1;
            end else begin
                $display("  PASS: Length = %0d bytes", rx_rdma_length);
            end
            
            if (rx_rdma_partition_key !== exp_partition_key) begin
                $display("  ERROR: Partition Key mismatch! Expected=0x%04h, Got=0x%04h", exp_partition_key, rx_rdma_partition_key);
                errors = errors + 1;
            end else begin
                $display("  PASS: Partition Key = 0x%04h", rx_rdma_partition_key);
            end
            
            if (rx_rdma_service_level !== exp_service_level) begin
                $display("  ERROR: Service Level mismatch! Expected=0x%02h, Got=0x%02h", exp_service_level, rx_rdma_service_level);
                errors = errors + 1;
            end else begin
                $display("  PASS: Service Level = 0x%02h", rx_rdma_service_level);
            end
            
            if (errors == 0) begin
                $display("  === ALL HEADER CHECKS PASSED ===");
            end else begin
                $display("  === %0d HEADER ERRORS FOUND ===", errors);
            end
        end
    endtask
    
    //--------------------------------------------------------------------------
    // Task: Send complete RDMA packet (header + payload)
    //--------------------------------------------------------------------------
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
        
        begin
            $display("\n========================================");
            $display("[%0t] Sending RDMA Packet:", $time);
            $display("  Opcode:     0x%02h", opcode);
            $display("  PSN:        0x%06h", psn);
            $display("  Dest QP:    0x%06h", dest_qp);
            $display("  Remote Addr: 0x%08h", remote_addr);
            $display("  Offset:     0x%04h (%0d bytes)", frag_offset, frag_offset);
            $display("  Length:     %0d bytes", length);
            $display("  Part Key:   0x%04h", partition_key);
            $display("  Service Lvl: 0x%02h", service_level);
            $display("  Payload:    %0d beats", num_payload_beats);
            $display("========================================");
            
            // Set TX header metadata
            tx_rdma_opcode        = opcode;
            tx_rdma_psn           = psn;
            tx_rdma_dest_qp       = dest_qp;
            tx_rdma_remote_addr   = {32'h00000000, remote_addr};
            tx_rdma_rkey          = 32'h0;
            tx_rdma_length        = length;
            tx_rdma_partition_key = partition_key;
            tx_rdma_service_level = service_level;
            tx_fragment_id        = 16'h0;
            tx_more_fragments     = 1'b0;
            tx_fragment_offset    = frag_offset;
            
            tx_payload_beats = num_payload_beats;
            
            // Pulse start_tx
            @(posedge aclk);
            start_tx = 1;
            @(posedge aclk);
            start_tx = 0;
            
            // Wait a bit for header to start
            repeat (3) @(posedge aclk);
            
            // Fork parallel processes for TX send and RX receive
            fork
                // Send payload through TX
                send_tx_payload(num_payload_beats);
                
                // Receive and verify through RX
                begin
                    // Wait for header_valid pulse
                    while (!header_valid) @(posedge aclk);
                    @(posedge aclk);
                    
                    // Check parsed header
                    check_rx_header(
                        opcode, psn, dest_qp, remote_addr, frag_offset,
                        length, partition_key, service_level
                    );
                    
                    // Receive payload
                    receive_rx_payload(num_payload_beats);
                end
            join
            
            // Wait for completion
            while (tx_busy || rx_busy) @(posedge aclk);
            repeat (10) @(posedge aclk);
            
            $display("[%0t] Packet complete\n", $time);
        end
    endtask
    
    //--------------------------------------------------------------------------
    // Main test
    //--------------------------------------------------------------------------
    integer i;
    integer test_num;
    
    initial begin
        // Initialize signals
        aresetn = 0;
        
        tx_s_axis_tdata  = 0;
        tx_s_axis_tkeep  = 0;
        tx_s_axis_tvalid = 0;
        tx_s_axis_tlast  = 0;
        
        start_tx = 0;
        
        tx_rdma_opcode        = 0;
        tx_rdma_psn           = 0;
        tx_rdma_dest_qp       = 0;
        tx_rdma_remote_addr   = 0;
        tx_rdma_rkey          = 0;
        tx_rdma_length        = 0;
        tx_rdma_partition_key = 0;
        tx_rdma_service_level = 0;
        tx_fragment_id        = 0;
        tx_more_fragments     = 0;
        tx_fragment_offset    = 0;
        
        rx_m_axis_tready = 1;  // Always ready to receive
        
        // Initialize payload data
        for (i = 0; i < 256; i = i + 1) begin
            tx_payload_data[i] = 32'hDEAD0000 + i;
        end
        
        // Reset
        $display("========================================");
        $display("TX-RX Loopback Testbench");
        $display("========================================");
        #100;
        aresetn = 1;
        #50;
        
        test_num = 0;
        
        //----------------------------------------------------------------------
        // Test 1: Small packet (256 bytes)
        //----------------------------------------------------------------------
        test_num = test_num + 1;
        $display("\n[TEST %0d] Small packet: 256 bytes", test_num);
        send_rdma_packet(
            .opcode(8'h01),
            .psn(24'h000001),
            .dest_qp(24'h000100),
            .remote_addr(32'h40000000),
            .frag_offset(16'h0000),
            .length(32'd256),
            .partition_key(16'hFFFF),
            .service_level(8'h05),
            .num_payload_beats(64)
        );
        
        //----------------------------------------------------------------------
        // Test 2: Medium packet with offset (512 bytes)
        //----------------------------------------------------------------------
        test_num = test_num + 1;
        $display("\n[TEST %0d] Medium packet: 512 bytes at offset 0x1000", test_num);
        send_rdma_packet(
            .opcode(8'h0A),
            .psn(24'h000002),
            .dest_qp(24'h000100),
            .remote_addr(32'h40000000),
            .frag_offset(16'h1000),
            .length(32'd512),
            .partition_key(16'h1234),
            .service_level(8'h03),
            .num_payload_beats(128)
        );
        
        //----------------------------------------------------------------------
        // Test 3: Large packet (1024 bytes)
        //----------------------------------------------------------------------
        test_num = test_num + 1;
        $display("\n[TEST %0d] Large packet: 1024 bytes", test_num);
        send_rdma_packet(
            .opcode(8'h0B),
            .psn(24'h000003),
            .dest_qp(24'h000200),
            .remote_addr(32'h50000000),
            .frag_offset(16'h0000),
            .length(32'd1024),
            .partition_key(16'h5678),
            .service_level(8'h07),
            .num_payload_beats(256)
        );
        
        //----------------------------------------------------------------------
        // Test 4: Back-to-back packets (continuous streaming)
        //----------------------------------------------------------------------
        test_num = test_num + 1;
        $display("\n[TEST %0d] Back-to-back packets test", test_num);
        
        for (i = 0; i < 3; i = i + 1) begin
            $display("\n  [Packet %0d/3]", i+1);
            send_rdma_packet(
                .opcode(8'h0C),
                .psn(24'h000004 + i),
                .dest_qp(24'h000300),
                .remote_addr(32'h60000000),
                .frag_offset(16'h2000 + (i * 128)),
                .length(32'd128),
                .partition_key(16'hABCD),
                .service_level(8'h02),
                .num_payload_beats(32)
            );
        end
        
        //----------------------------------------------------------------------
        // Test 5: Minimum size packet (4 bytes)
        //----------------------------------------------------------------------
        test_num = test_num + 1;
        $display("\n[TEST %0d] Minimum packet: 4 bytes", test_num);
        send_rdma_packet(
            .opcode(8'h01),
            .psn(24'h000007),
            .dest_qp(24'h000100),
            .remote_addr(32'h70000000),
            .frag_offset(16'h0000),
            .length(32'd4),
            .partition_key(16'h0001),
            .service_level(8'h01),
            .num_payload_beats(1)
        );
        
        //----------------------------------------------------------------------
        // Test complete
        //----------------------------------------------------------------------
        #500;
        $display("\n========================================");
        $display("All tests completed successfully!");
        $display("========================================");
        $finish;
    end
    
    //--------------------------------------------------------------------------
    // Monitor key events
    //--------------------------------------------------------------------------
    always @(posedge aclk) begin
        if (tx_done) begin
            $display("[%0t] *** TX_DONE pulse ***", $time);
        end
        if (header_valid) begin
            $display("[%0t] *** HEADER_VALID pulse ***", $time);
        end
    end
    
    //--------------------------------------------------------------------------
    // Timeout watchdog
    //--------------------------------------------------------------------------
    initial begin
        #500000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
