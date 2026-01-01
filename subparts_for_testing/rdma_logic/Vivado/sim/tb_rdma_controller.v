`timescale 1ns / 1ps

module tb_rdma_controller;

    // Parameters
    parameter ADDR_WIDTH = 32;
    parameter SQ_IDX_WIDTH = 16;
    parameter CLK_PERIOD = 10;
    
    // Clock and reset
    reg clk;
    reg rst;
    
    // Control signals
    reg START_RDMA;
    reg RESET_RDMA;
    
    // Queue configuration
    reg [ADDR_WIDTH-1:0] SQ_BASE_ADDR;
    reg [ADDR_WIDTH-1:0] CQ_BASE_ADDR;
    reg [SQ_IDX_WIDTH-1:0] SQ_SIZE;
    reg [SQ_IDX_WIDTH-1:0] CQ_SIZE;
    reg [SQ_IDX_WIDTH-1:0] SQ_TAIL_SW;
    reg [SQ_IDX_WIDTH-1:0] CQ_HEAD_SW;
    wire [SQ_IDX_WIDTH-1:0] SQ_HEAD_HW;
    wire [SQ_IDX_WIDTH-1:0] CQ_TAIL_HW;
    
    // RDMA Entry inputs (from stream parser)
    reg [31:0] rdma_id;
    reg [15:0] rdma_opcode;
    reg [15:0] rdma_flags;
    reg [63:0] rdma_local_key;
    reg [63:0] rdma_remote_key;
    reg [127:0] rdma_btt;
    reg rdma_entry_valid;
    
    // Command controller interface
    reg CMD_CTRL_READY;
    wire CMD_CTRL_START;
    wire [31:0] CMD_CTRL_SRC_ADDR;
    wire [31:0] CMD_CTRL_DST_ADDR;
    wire [31:0] CMD_CTRL_BTT;
    wire CMD_CTRL_IS_READ;
    reg READ_COMPLETE;
    reg WRITE_COMPLETE;
    
    // TX Streamer interface
    wire tx_cmd_valid;
    reg tx_cmd_ready;
    wire [7:0] tx_cmd_sq_index;
    wire [31:0] tx_cmd_ddr_addr;
    wire [31:0] tx_cmd_length;
    wire [7:0] tx_cmd_opcode;
    wire [23:0] tx_cmd_dest_qp;
    wire [63:0] tx_cmd_remote_addr;
    wire [31:0] tx_cmd_rkey;
    wire [15:0] tx_cmd_partition_key;
    wire [7:0] tx_cmd_service_level;
    wire [23:0] tx_cmd_psn;
    reg tx_cpl_valid;
    wire tx_cpl_ready;
    reg [7:0] tx_cpl_sq_index;
    reg [7:0] tx_cpl_status;
    reg [31:0] tx_cpl_bytes_sent;
    
    // Status outputs
    wire [3:0] STATE_REG;
    wire HAS_WORK;
    wire START_STREAM;
    reg IS_STREAM_BUSY;
    
    // CQ Entry outputs
    wire [31:0] cq_entry_0;
    wire [31:0] cq_entry_1;
    wire [31:0] cq_entry_2;
    wire [31:0] cq_entry_3;
    wire [31:0] cq_entry_4;
    wire [31:0] cq_entry_5;
    wire [31:0] cq_entry_6;
    wire [31:0] cq_entry_7;
    
    // State names for display
    reg [127:0] state_name;
    always @(*) begin
        case (STATE_REG)
            4'd0: state_name = "IDLE";
            4'd1: state_name = "PREPARE_READ";
            4'd2: state_name = "READ_CMD";
            4'd3: state_name = "WAIT_READ_DONE";
            4'd4: state_name = "IS_STREAM_BUSY";
            4'd5: state_name = "SEND_TX_CMD";
            4'd6: state_name = "WAIT_TX_CPL";
            4'd7: state_name = "PREPARE_WRITE";
            4'd8: state_name = "WRITE_CMD";
            4'd9: state_name = "START_STREAM";
            4'd10: state_name = "WAIT_WRITE_DONE";
            default: state_name = "UNKNOWN";
        endcase
    end
    
    // DUT instantiation
    rdma_controller #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .SQ_IDX_WIDTH(SQ_IDX_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .START_RDMA(START_RDMA),
        .RESET_RDMA(RESET_RDMA),
        .SQ_BASE_ADDR(SQ_BASE_ADDR),
        .CQ_BASE_ADDR(CQ_BASE_ADDR),
        .SQ_SIZE(SQ_SIZE),
        .CQ_SIZE(CQ_SIZE),
        .SQ_TAIL_SW(SQ_TAIL_SW),
        .SQ_HEAD_HW(SQ_HEAD_HW),
        .CQ_TAIL_HW(CQ_TAIL_HW),
        .CQ_HEAD_SW(CQ_HEAD_SW),
        .rdma_id(rdma_id),
        .rdma_opcode(rdma_opcode),
        .rdma_flags(rdma_flags),
        .rdma_local_key(rdma_local_key),
        .rdma_remote_key(rdma_remote_key),
        .rdma_btt(rdma_btt),
        .rdma_entry_valid(rdma_entry_valid),
        .CMD_CTRL_READY(CMD_CTRL_READY),
        .CMD_CTRL_START(CMD_CTRL_START),
        .CMD_CTRL_SRC_ADDR(CMD_CTRL_SRC_ADDR),
        .CMD_CTRL_DST_ADDR(CMD_CTRL_DST_ADDR),
        .CMD_CTRL_BTT(CMD_CTRL_BTT),
        .CMD_CTRL_IS_READ(CMD_CTRL_IS_READ),
        .READ_COMPLETE(READ_COMPLETE),
        .WRITE_COMPLETE(WRITE_COMPLETE),
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
        .tx_cpl_valid(tx_cpl_valid),
        .tx_cpl_ready(tx_cpl_ready),
        .tx_cpl_sq_index(tx_cpl_sq_index),
        .tx_cpl_status(tx_cpl_status),
        .tx_cpl_bytes_sent(tx_cpl_bytes_sent),
        .STATE_REG(STATE_REG),
        .HAS_WORK(HAS_WORK),
        .START_STREAM(START_STREAM),
        .IS_STREAM_BUSY(IS_STREAM_BUSY),
        .cq_entry_0(cq_entry_0),
        .cq_entry_1(cq_entry_1),
        .cq_entry_2(cq_entry_2),
        .cq_entry_3(cq_entry_3),
        .cq_entry_4(cq_entry_4),
        .cq_entry_5(cq_entry_5),
        .cq_entry_6(cq_entry_6),
        .cq_entry_7(cq_entry_7)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Monitor state changes
    always @(posedge clk) begin
        if (STATE_REG !== dut.state_reg) begin
            $display("[%0t] STATE CHANGE: %s (0x%0h)", $time, state_name, STATE_REG);
        end
    end
    
    // Monitor important signals
    always @(posedge clk) begin
        if (CMD_CTRL_START) begin
            $display("[%0t] CMD_CTRL: START pulse, IS_READ=%0b, SRC=0x%08h, DST=0x%08h, BTT=%0d", 
                     $time, CMD_CTRL_IS_READ, CMD_CTRL_SRC_ADDR, CMD_CTRL_DST_ADDR, CMD_CTRL_BTT);
        end
        
        if (tx_cmd_valid && tx_cmd_ready) begin
            $display("[%0t] TX_CMD: sq_idx=%0d, addr=0x%08h, len=%0d, opcode=0x%02h", 
                     $time, tx_cmd_sq_index, tx_cmd_ddr_addr, tx_cmd_length, tx_cmd_opcode);
        end
        
        if (tx_cpl_valid && tx_cpl_ready) begin
            $display("[%0t] TX_CPL: sq_idx=%0d, status=0x%02h, bytes_sent=%0d", 
                     $time, tx_cpl_sq_index, tx_cpl_status, tx_cpl_bytes_sent);
        end
        
        if (START_STREAM) begin
            $display("[%0t] START_STREAM pulse - CQ Entry:", $time);
            $display("         [0]=0x%08h [1]=0x%08h [2]=0x%08h [3]=0x%08h", 
                     cq_entry_0, cq_entry_1, cq_entry_2, cq_entry_3);
            $display("         [4]=0x%08h [5]=0x%08h [6]=0x%08h [7]=0x%08h", 
                     cq_entry_4, cq_entry_5, cq_entry_6, cq_entry_7);
        end
        
        if (rdma_entry_valid) begin
            $display("[%0t] RDMA_ENTRY: id=0x%08h, opcode=0x%04h, local=0x%016h, len=%0d",
                     $time, rdma_id, rdma_opcode, rdma_local_key, rdma_btt[31:0]);
        end
    end
    
    // Mock Data Mover response (handles both read and write)
    always @(posedge clk) begin
        if (CMD_CTRL_START && CMD_CTRL_IS_READ) begin
            // Simulate MM2S (read) completion with delay
            READ_COMPLETE <= 0;
            repeat(5) @(posedge clk);
            READ_COMPLETE <= 1;
            @(posedge clk);
            READ_COMPLETE <= 0;
            $display("[%0t] Data Mover: READ completed", $time);
        end
        
        if (CMD_CTRL_START && !CMD_CTRL_IS_READ) begin
            // Simulate S2MM (write) completion with delay
            WRITE_COMPLETE <= 0;
            repeat(7) @(posedge clk);
            WRITE_COMPLETE <= 1;
            @(posedge clk);
            WRITE_COMPLETE <= 0;
            $display("[%0t] Data Mover: WRITE completed", $time);
        end
    end
    
    // Mock TX Streamer behavior
    always @(posedge clk) begin
        if (tx_cmd_valid && tx_cmd_ready) begin
            // Deassert ready, simulate TX processing
            tx_cmd_ready <= 0;
            tx_cpl_valid <= 0;
            
            // Simulate transmission delay (varies based on length)
            repeat(10 + (tx_cmd_length / 256)) @(posedge clk);
            
            // Send completion
            tx_cpl_sq_index <= tx_cmd_sq_index;
            tx_cpl_status <= 8'h00; // Success
            tx_cpl_bytes_sent <= tx_cmd_length;
            tx_cpl_valid <= 1;
            
            @(posedge clk);
            while (!tx_cpl_ready) @(posedge clk);
            
            tx_cpl_valid <= 0;
            @(posedge clk);
            tx_cmd_ready <= 1;
            
            $display("[%0t] TX Streamer: Completed transmission", $time);
        end
    end
    
    // Mock stream parser - provides RDMA entry after read completes
    always @(posedge clk) begin
        if (READ_COMPLETE) begin
            rdma_entry_valid <= 0;
            repeat(2) @(posedge clk);
            rdma_entry_valid <= 1;
            @(posedge clk);
            rdma_entry_valid <= 0;
        end
    end
    
    // Task to submit an SQ entry
    task submit_sq_entry(
        input [31:0] id,
        input [15:0] opcode,
        input [63:0] local_addr,
        input [63:0] remote_addr,
        input [31:0] length
    );
    begin
        $display("\n[%0t] ========== Submitting SQ Entry ==========", $time);
        $display("  ID: 0x%08h", id);
        $display("  Opcode: 0x%04h", opcode);
        $display("  Local Addr: 0x%016h", local_addr);
        $display("  Remote Addr: 0x%016h", remote_addr);
        $display("  Length: %0d bytes", length);
        
        // Prepare RDMA entry data (will be provided when read completes)
        rdma_id = id;
        rdma_opcode = opcode;
        rdma_flags = 16'h0000;
        rdma_local_key = local_addr;
        rdma_remote_key = remote_addr;
        rdma_btt = {96'd0, length};
        
        // Increment SW tail
        SQ_TAIL_SW = SQ_TAIL_SW + 1;
        
        $display("[%0t] SQ_TAIL_SW advanced to %0d", $time, SQ_TAIL_SW);
    end
    endtask
    
    // Task to wait for completion
    task wait_for_cq_entry;
        reg [SQ_IDX_WIDTH-1:0] prev_cq_tail;
    begin
        prev_cq_tail = CQ_TAIL_HW;
        $display("[%0t] Waiting for CQ entry (current CQ_TAIL=%0d)...", $time, CQ_TAIL_HW);
        
        wait (CQ_TAIL_HW != prev_cq_tail);
        
        $display("[%0t] ========== CQ Entry Received ==========", $time);
        $display("  CQ_TAIL advanced to %0d", CQ_TAIL_HW);
        $display("  SQ_HEAD advanced to %0d", SQ_HEAD_HW);
        
        // Acknowledge by advancing CQ head
        CQ_HEAD_SW = CQ_TAIL_HW;
        $display("[%0t] CQ_HEAD_SW advanced to %0d", $time, CQ_HEAD_SW);
    end
    endtask
    
    // Main test sequence
    initial begin
        $dumpfile("tb_rdma_controller.vcd");
        $dumpvars(0, tb_rdma_controller);
        
        // Initialize signals
        rst = 1;
        START_RDMA = 0;
        RESET_RDMA = 0;
        SQ_BASE_ADDR = 32'h1000_0000;
        CQ_BASE_ADDR = 32'h2000_0000;
        SQ_SIZE = 16;
        CQ_SIZE = 16;
        SQ_TAIL_SW = 0;
        CQ_HEAD_SW = 0;
        CMD_CTRL_READY = 1;
        READ_COMPLETE = 0;
        WRITE_COMPLETE = 0;
        tx_cmd_ready = 1;
        tx_cpl_valid = 0;
        tx_cpl_sq_index = 0;
        tx_cpl_status = 0;
        tx_cpl_bytes_sent = 0;
        IS_STREAM_BUSY = 0;
        rdma_id = 0;
        rdma_opcode = 0;
        rdma_flags = 0;
        rdma_local_key = 0;
        rdma_remote_key = 0;
        rdma_btt = 0;
        rdma_entry_valid = 0;
        
        $display("\n========================================");
        $display("  RDMA Controller Testbench");
        $display("========================================\n");
        
        // Reset
        repeat(5) @(posedge clk);
        rst = 0;
        repeat(2) @(posedge clk);
        
        // Enable controller
        START_RDMA = 1;
        $display("[%0t] RDMA Controller enabled\n", $time);
        
        // Test 1: Small transfer (256 bytes)
        submit_sq_entry(
            .id(32'h0001_0001),
            .opcode(16'h0001),
            .local_addr(64'h0000_0000_3000_0000),
            .remote_addr(64'h0000_0000_4000_0000),
            .length(32'd256)
        );
        wait_for_cq_entry();
        repeat(10) @(posedge clk);
        
        // Test 2: Medium transfer (1024 bytes)
        submit_sq_entry(
            .id(32'h0002_0002),
            .opcode(16'h0001),
            .local_addr(64'h0000_0000_3000_1000),
            .remote_addr(64'h0000_0000_4000_1000),
            .length(32'd1024)
        );
        wait_for_cq_entry();
        repeat(10) @(posedge clk);
        
        // Test 3: Large transfer (8192 bytes - will fragment)
        submit_sq_entry(
            .id(32'h0003_0003),
            .opcode(16'h0001),
            .local_addr(64'h0000_0000_3000_2000),
            .remote_addr(64'h0000_0000_4000_2000),
            .length(32'd8192)
        );
        wait_for_cq_entry();
        repeat(10) @(posedge clk);
        
        $display("\n========================================");
        $display("  Test Complete - All 3 entries processed");
        $display("  Final SQ_HEAD: %0d", SQ_HEAD_HW);
        $display("  Final CQ_TAIL: %0d", CQ_TAIL_HW);
        $display("========================================\n");
        
        repeat(10) @(posedge clk);
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #100000;
        $display("\n[ERROR] Testbench timeout!");
        $finish;
    end

endmodule
