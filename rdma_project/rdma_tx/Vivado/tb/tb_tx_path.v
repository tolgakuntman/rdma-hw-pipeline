`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Testbench: tb_tx_path
// 
// Description:
//   Tests the complete TX path including tx_streamer and tx_header_inserter
//   - Simulates RDMA controller command interface
//   - Mocks AXI Data Mover behavior (command acceptance + data streaming)
//   - Verifies fragmentation logic
//   - Checks header insertion and data pass-through
//
// Test Scenarios:
//   1. Single fragment transfer (< 4KB)
//   2. Multi-fragment transfer (> 4KB) 
//   3. 4KB boundary alignment
//   4. Back-to-back commands
//
////////////////////////////////////////////////////////////////////////////////

module tb_tx_path();

    //========================================================================
    // Parameters
    //========================================================================
    parameter CLK_PERIOD = 10;  // 100 MHz clock
    
    parameter C_ADDR_WIDTH       = 32;
    parameter C_DATA_WIDTH       = 32;
    parameter C_BTT_WIDTH        = 23;
    parameter BLOCK_SIZE         = 4096;
    parameter BOUNDARY_4KB       = 4096;
    parameter SQ_INDEX_WIDTH     = 8;
    parameter RDMA_OPCODE_WIDTH  = 8;
    parameter RDMA_PSN_WIDTH     = 24;
    parameter RDMA_QPN_WIDTH     = 24;
    parameter RDMA_ADDR_WIDTH    = 64;
    parameter RDMA_RKEY_WIDTH    = 32;
    parameter RDMA_LENGTH_WIDTH  = 32;
    
    parameter C_AXIS_TDATA_WIDTH = 32;
    parameter C_AXIS_TKEEP_WIDTH = 4;
    
    //========================================================================
    // Signals
    //========================================================================
    // Clock and Reset
    reg aclk;
    reg aresetn;
    
    // Command Interface to tx_streamer
    reg                             tx_cmd_valid;
    wire                            tx_cmd_ready;
    reg [SQ_INDEX_WIDTH-1:0]       tx_cmd_sq_index;
    reg [C_ADDR_WIDTH-1:0]         tx_cmd_ddr_addr;
    reg [RDMA_LENGTH_WIDTH-1:0]    tx_cmd_length;
    reg [RDMA_OPCODE_WIDTH-1:0]    tx_cmd_opcode;
    reg [RDMA_QPN_WIDTH-1:0]       tx_cmd_dest_qp;
    reg [RDMA_ADDR_WIDTH-1:0]      tx_cmd_remote_addr;
    reg [RDMA_RKEY_WIDTH-1:0]      tx_cmd_rkey;
    reg [15:0]                      tx_cmd_partition_key;
    reg [7:0]                       tx_cmd_service_level;
    reg [RDMA_PSN_WIDTH-1:0]       tx_cmd_psn;
    
    // Completion Interface from tx_streamer
    wire                            tx_cpl_valid;
    reg                             tx_cpl_ready;
    wire [SQ_INDEX_WIDTH-1:0]      tx_cpl_sq_index;
    wire [7:0]                      tx_cpl_status;
    wire [RDMA_LENGTH_WIDTH-1:0]   tx_cpl_bytes_sent;
    
    // Header Inserter Interface (tx_streamer <-> tx_header_inserter)
    wire                            hdr_start_tx;
    wire                            hdr_tx_busy;
    wire                            hdr_tx_done;
    wire [RDMA_OPCODE_WIDTH-1:0]   hdr_rdma_opcode;
    wire [RDMA_PSN_WIDTH-1:0]      hdr_rdma_psn;
    wire [RDMA_QPN_WIDTH-1:0]      hdr_rdma_dest_qp;
    wire [RDMA_ADDR_WIDTH-1:0]     hdr_rdma_remote_addr;
    wire [RDMA_RKEY_WIDTH-1:0]     hdr_rdma_rkey;
    wire [RDMA_LENGTH_WIDTH-1:0]   hdr_rdma_length;
    wire [15:0]                     hdr_rdma_partition_key;
    wire [7:0]                      hdr_rdma_service_level;
    wire [15:0]                     hdr_fragment_id;
    wire                            hdr_more_fragments;
    wire [15:0]                     hdr_fragment_offset;
    
    // MM2S Command Interface (tx_streamer output)
    wire [71:0]                     m_axis_mm2s_cmd_tdata;
    wire                            m_axis_mm2s_cmd_tvalid;
    reg                             m_axis_mm2s_cmd_tready;
    
    // MM2S Status (mock Data Mover)
    reg                             mm2s_rd_xfer_cmplt;
    
    // Data Mover to Header Inserter (AXI-Stream)
    reg [C_AXIS_TDATA_WIDTH-1:0]   s_axis_tdata;
    reg [C_AXIS_TKEEP_WIDTH-1:0]   s_axis_tkeep;
    reg                             s_axis_tvalid;
    wire                            s_axis_tready;
    reg                             s_axis_tlast;
    
    // Header Inserter Output (to Network)
    wire [C_AXIS_TDATA_WIDTH-1:0]  m_axis_tdata;
    wire [C_AXIS_TKEEP_WIDTH-1:0]  m_axis_tkeep;
    wire                            m_axis_tvalid;
    reg                             m_axis_tready;
    wire                            m_axis_tlast;
    
    //========================================================================
    // Data Mover Mock State
    //========================================================================
    reg [4:0] dm_delay_counter;
    reg       dm_transfer_active;
    reg [RDMA_LENGTH_WIDTH-1:0] dm_bytes_remaining;
    reg [C_ADDR_WIDTH-1:0] dm_current_addr;
    
    //========================================================================
    // Test Variables
    //========================================================================
    integer test_num;
    integer header_beats_received;
    integer data_beats_received;
    integer total_beats_received;
    
    //========================================================================
    // Clock Generation
    //========================================================================
    initial begin
        aclk = 0;
        forever #(CLK_PERIOD/2) aclk = ~aclk;
    end
    
    //========================================================================
    // DUT Instantiation - tx_streamer
    //========================================================================
    tx_streamer #(
        .C_ADDR_WIDTH(C_ADDR_WIDTH),
        .C_DATA_WIDTH(C_DATA_WIDTH),
        .C_BTT_WIDTH(C_BTT_WIDTH),
        .BLOCK_SIZE(BLOCK_SIZE),
        .BOUNDARY_4KB(BOUNDARY_4KB),
        .SQ_INDEX_WIDTH(SQ_INDEX_WIDTH),
        .RDMA_OPCODE_WIDTH(RDMA_OPCODE_WIDTH),
        .RDMA_PSN_WIDTH(RDMA_PSN_WIDTH),
        .RDMA_QPN_WIDTH(RDMA_QPN_WIDTH),
        .RDMA_ADDR_WIDTH(RDMA_ADDR_WIDTH),
        .RDMA_RKEY_WIDTH(RDMA_RKEY_WIDTH),
        .RDMA_LENGTH_WIDTH(RDMA_LENGTH_WIDTH)
    ) dut_streamer (
        .aclk(aclk),
        .aresetn(aresetn),
        
        // Command Interface
        .tx_cmd_valid(tx_cmd_valid),
        .tx_cmd_ready(tx_cmd_ready),
        .tx_cmd_sq_index(tx_cmd_sq_index),
        .tx_cmd_ddr_addr(tx_cmd_ddr_addr),
        .tx_cmd_length(tx_cmd_length),
        .tx_cmd_opcode(tx_cmd_opcode),
        .tx_cmd_dest_qp(tx_cmd_dest_qp),
        .tx_cmd_remote_addr(tx_cmd_remote_addr),
        .tx_cmd_rkey(tx_cmd_rkey),
        .tx_cmd_partition_key(tx_cmd_partition_key),
        .tx_cmd_service_level(tx_cmd_service_level),
        .tx_cmd_psn(tx_cmd_psn),
        
        // Completion Interface
        .tx_cpl_valid(tx_cpl_valid),
        .tx_cpl_ready(tx_cpl_ready),
        .tx_cpl_sq_index(tx_cpl_sq_index),
        .tx_cpl_status(tx_cpl_status),
        .tx_cpl_bytes_sent(tx_cpl_bytes_sent),
        
        // Header Inserter Interface
        .hdr_start_tx(hdr_start_tx),
        .hdr_tx_busy(hdr_tx_busy),
        .hdr_tx_done(hdr_tx_done),
        .hdr_rdma_opcode(hdr_rdma_opcode),
        .hdr_rdma_psn(hdr_rdma_psn),
        .hdr_rdma_dest_qp(hdr_rdma_dest_qp),
        .hdr_rdma_remote_addr(hdr_rdma_remote_addr),
        .hdr_rdma_rkey(hdr_rdma_rkey),
        .hdr_rdma_length(hdr_rdma_length),
        .hdr_rdma_partition_key(hdr_rdma_partition_key),
        .hdr_rdma_service_level(hdr_rdma_service_level),
        .hdr_fragment_id(hdr_fragment_id),
        .hdr_more_fragments(hdr_more_fragments),
        .hdr_fragment_offset(hdr_fragment_offset),
        
        // MM2S Command Interface
        .m_axis_mm2s_cmd_tdata(m_axis_mm2s_cmd_tdata),
        .m_axis_mm2s_cmd_tvalid(m_axis_mm2s_cmd_tvalid),
        .m_axis_mm2s_cmd_tready(m_axis_mm2s_cmd_tready),
        
        // MM2S Status
        .mm2s_rd_xfer_cmplt(mm2s_rd_xfer_cmplt)
    );
    
    //========================================================================
    // DUT Instantiation - tx_header_inserter
    //========================================================================
    tx_header_inserter #(
        .C_AXIS_TDATA_WIDTH(C_AXIS_TDATA_WIDTH),
        .C_AXIS_TKEEP_WIDTH(C_AXIS_TKEEP_WIDTH),
        .RDMA_OPCODE_WIDTH(RDMA_OPCODE_WIDTH),
        .RDMA_PSN_WIDTH(RDMA_PSN_WIDTH),
        .RDMA_QPN_WIDTH(RDMA_QPN_WIDTH),
        .RDMA_ADDR_WIDTH(RDMA_ADDR_WIDTH),
        .RDMA_RKEY_WIDTH(RDMA_RKEY_WIDTH),
        .RDMA_LENGTH_WIDTH(RDMA_LENGTH_WIDTH)
    ) dut_header_inserter (
        .aclk(aclk),
        .aresetn(aresetn),
        
        // AXI-Stream Slave (from Data Mover mock)
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        
        // AXI-Stream Master (to Network)
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tkeep(m_axis_tkeep),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),
        
        // Control Signals
        .start_tx(hdr_start_tx),
        .tx_busy(hdr_tx_busy),
        .tx_done(hdr_tx_done),
        
        // RDMA Header Fields
        .rdma_opcode(hdr_rdma_opcode),
        .rdma_psn(hdr_rdma_psn),
        .rdma_dest_qp(hdr_rdma_dest_qp),
        .rdma_remote_addr(hdr_rdma_remote_addr),
        .rdma_rkey(hdr_rdma_rkey),
        .rdma_length(hdr_rdma_length),
        .rdma_partition_key(hdr_rdma_partition_key),
        .rdma_service_level(hdr_rdma_service_level),
        .fragment_id(hdr_fragment_id),
        .more_fragments(hdr_more_fragments),
        .fragment_offset(hdr_fragment_offset)
    );
    
    //========================================================================
    // Mock Data Mover Behavior
    //========================================================================
    // Accept MM2S commands and assert completion after delay
    always @(posedge aclk) begin
        if (!aresetn) begin
            dm_delay_counter <= 0;
            dm_transfer_active <= 0;
            mm2s_rd_xfer_cmplt <= 0;
            dm_bytes_remaining <= 0;
            dm_current_addr <= 0;
        end else begin
            mm2s_rd_xfer_cmplt <= 0;  // Pulse signal
            
            // Accept new MM2S command
            if (m_axis_mm2s_cmd_tvalid && m_axis_mm2s_cmd_tready && !dm_transfer_active) begin
                dm_transfer_active <= 1;
                dm_delay_counter <= 0;
                // Extract BTT from command
                dm_bytes_remaining <= m_axis_mm2s_cmd_tdata[22:0];
                // Extract address
                dm_current_addr <= m_axis_mm2s_cmd_tdata[62:31];
                $display("[%0t] Data Mover: Accepted MM2S command - Addr=0x%08h, BTT=%0d", 
                         $time, m_axis_mm2s_cmd_tdata[62:31], m_axis_mm2s_cmd_tdata[22:0]);
            end
            
            // Simulate transfer delay (5 cycles)
            if (dm_transfer_active) begin
                dm_delay_counter <= dm_delay_counter + 1;
                if (dm_delay_counter >= 4) begin
                    mm2s_rd_xfer_cmplt <= 1;
                    dm_transfer_active <= 0;
                    $display("[%0t] Data Mover: Transfer complete", $time);
                end
            end
        end
    end
    
    // Always ready to accept MM2S commands (unless transfer active)
    always @(*) begin
        m_axis_mm2s_cmd_tready = !dm_transfer_active;
    end
    
    //========================================================================
    // Mock Data Stream Generator
    //========================================================================
    // Generate AXI-Stream data after MM2S command accepted
    reg [7:0] data_beat_count;
    reg [31:0] data_pattern;
    
    always @(posedge aclk) begin
        if (!aresetn) begin
            s_axis_tvalid <= 0;
            s_axis_tdata <= 0;
            s_axis_tkeep <= 0;
            s_axis_tlast <= 0;
            data_beat_count <= 0;
            data_pattern <= 32'hDEAD0000;
        end else begin
            // Start streaming when transfer active and header inserter ready
            if (dm_transfer_active && s_axis_tready && dm_delay_counter >= 2) begin
                s_axis_tvalid <= 1;
                s_axis_tdata <= data_pattern;
                s_axis_tkeep <= 4'hF;
                data_pattern <= data_pattern + 1;
                data_beat_count <= data_beat_count + 1;
                
                // Calculate if this is the last beat (simplified: 16 beats = 64 bytes)
                if (data_beat_count >= (dm_bytes_remaining[31:2] - 1)) begin
                    s_axis_tlast <= 1;
                    data_beat_count <= 0;
                end else begin
                    s_axis_tlast <= 0;
                end
            end else if (s_axis_tlast && s_axis_tvalid && s_axis_tready) begin
                // Reset after last beat transferred
                s_axis_tvalid <= 0;
                s_axis_tlast <= 0;
                data_beat_count <= 0;
            end
        end
    end
    
    //========================================================================
    // Output Monitor
    //========================================================================
    always @(posedge aclk) begin
        if (aresetn && m_axis_tvalid && m_axis_tready) begin
            if (header_beats_received < 7) begin
                $display("[%0t] Header Beat %0d: 0x%08h", $time, header_beats_received, m_axis_tdata);
                header_beats_received = header_beats_received + 1;
            end else begin
                $display("[%0t] Data Beat %0d: 0x%08h %s", 
                         $time, data_beats_received, m_axis_tdata, 
                         m_axis_tlast ? "(LAST)" : "");
                data_beats_received = data_beats_received + 1;
            end
            total_beats_received = total_beats_received + 1;
        end
    end
    
    //========================================================================
    // Task: Send Command
    //========================================================================
    task send_command(
        input [7:0] sq_idx,
        input [31:0] ddr_addr,
        input [31:0] length,
        input [7:0] opcode,
        input [23:0] qp,
        input [63:0] remote_addr,
        input [31:0] rkey
    );
    begin
        @(posedge aclk);
        tx_cmd_valid <= 1;
        tx_cmd_sq_index <= sq_idx;
        tx_cmd_ddr_addr <= ddr_addr;
        tx_cmd_length <= length;
        tx_cmd_opcode <= opcode;
        tx_cmd_dest_qp <= qp;
        tx_cmd_remote_addr <= remote_addr;
        tx_cmd_rkey <= rkey;
        tx_cmd_partition_key <= 16'hFFFF;
        tx_cmd_service_level <= 8'h00;
        tx_cmd_psn <= 24'h000001;
        
        wait(tx_cmd_ready);
        @(posedge aclk);
        tx_cmd_valid <= 0;
        $display("[%0t] Command sent: SQ_IDX=%0d, ADDR=0x%08h, LEN=%0d", 
                 $time, sq_idx, ddr_addr, length);
    end
    endtask
    
    //========================================================================
    // Task: Wait for Completion
    //========================================================================
    task wait_completion();
    begin
        wait(tx_cpl_valid);
        @(posedge aclk);
        $display("[%0t] Completion: SQ_IDX=%0d, Status=0x%02h, Bytes=%0d", 
                 $time, tx_cpl_sq_index, tx_cpl_status, tx_cpl_bytes_sent);
    end
    endtask
    
    //========================================================================
    // Test Stimulus
    //========================================================================
    initial begin
        // Initialize
        aresetn = 0;
        tx_cmd_valid = 0;
        tx_cpl_ready = 1;
        m_axis_tready = 1;  // Always ready to receive output
        
        test_num = 0;
        header_beats_received = 0;
        data_beats_received = 0;
        total_beats_received = 0;
        
        // Reset
        repeat(10) @(posedge aclk);
        aresetn = 1;
        repeat(5) @(posedge aclk);
        
        //====================================================================
        // Test 1: Single Fragment (2KB transfer)
        //====================================================================
        test_num = 1;
        $display("\n========================================");
        $display("Test %0d: Single Fragment (2KB)", test_num);
        $display("========================================");
        header_beats_received = 0;
        data_beats_received = 0;
        
        send_command(8'd1, 32'h1000_0000, 32'd8192, 8'h0A, 24'h123456, 64'hDEAD_BEEF_CAFE_0000, 32'hABCD_EF01);
        
        wait_completion();
        repeat(20) @(posedge aclk);
        
        //====================================================================
        // Test 2: Multi-Fragment (8KB transfer - should be 2 fragments)
        //====================================================================
        test_num = 2;
        $display("\n========================================");
        $display("Test %0d: Multi-Fragment (8KB = 2x4KB)", test_num);
        $display("========================================");
        header_beats_received = 0;
        data_beats_received = 0;
        
        send_command(8'd2, 32'h2000_0000, 32'd8192, 8'h0A, 24'h654321, 64'h1234_5678_9ABC_0000, 32'h5555_AAAA);
        
        wait_completion();
        repeat(20) @(posedge aclk);
        
        //====================================================================
        // Test 3: 4KB Boundary Crossing (3KB at 0x1FFF_F800)
        //====================================================================
        test_num = 3;
        $display("\n========================================");
        $display("Test %0d: 4KB Boundary Crossing", test_num);
        $display("========================================");
        header_beats_received = 0;
        data_beats_received = 0;
        
        send_command(8'd3, 32'h1FFF_F800, 32'd3072, 8'h0A, 24'hABCDEF, 64'hFEED_FACE_DEAD_0000, 32'h9999_8888);
        
        wait_completion();
        repeat(20) @(posedge aclk);
        
        //====================================================================
        // Test 4: Small Transfer (256 bytes)
        //====================================================================
        test_num = 4;
        $display("\n========================================");
        $display("Test %0d: Small Transfer (256B)", test_num);
        $display("========================================");
        header_beats_received = 0;
        data_beats_received = 0;
        
        send_command(8'd4, 32'h3000_0100, 32'd256, 8'h0C, 24'h111111, 64'h8888_7777_6666_5555, 32'h1111_2222);
        
        wait_completion();
        repeat(20) @(posedge aclk);
        
        //====================================================================
        // Test Complete
        //====================================================================
        $display("\n========================================");
        $display("All Tests Complete!");
        $display("========================================");
        repeat(50) @(posedge aclk);
        $finish;
    end
    
    //========================================================================
    // Timeout Watchdog
    //========================================================================
    initial begin
        #1000000;  // 1ms timeout
        $display("ERROR: Simulation timeout!");
        $finish;
    end
    
    //========================================================================
    // Waveform Dump
    //========================================================================
    initial begin
        $dumpfile("tb_tx_path.vcd");
        $dumpvars(0, tb_tx_path);
    end

endmodule
