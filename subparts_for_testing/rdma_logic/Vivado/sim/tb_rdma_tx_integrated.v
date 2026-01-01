`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Integrated Testbench: rdma_controller + tx_streamer
//
// Tests the complete TX path from RDMA controller through TX streamer
// Mock components:
//   - Data Mover (MM2S/S2MM commands and status)
//   - Stream Parser (provides RDMA entries)
//   - TX Header Inserter (simulates header transmission)
//   - Memory (simulates DDR for SQ/CQ)
////////////////////////////////////////////////////////////////////////////////

module tb_rdma_tx_integrated();

    // Clock and Reset
    reg clk;
    reg rst;
    
    // Clock generation: 100 MHz (10ns period)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // DUT signals - RDMA Controller
    reg         START_RDMA;
    reg         RESET_RDMA;
    reg [31:0]  SQ_BASE_ADDR;
    reg [31:0]  CQ_BASE_ADDR;
    reg [15:0]  SQ_SIZE;
    reg [15:0]  CQ_SIZE;
    reg [15:0]  SQ_TAIL_SW;
    wire [15:0] SQ_HEAD_HW;
    wire [15:0] CQ_TAIL_HW;
    reg [15:0]  CQ_HEAD_SW;
    
    // RDMA Entry (from mock stream parser)
    reg [31:0]  rdma_id;
    reg [15:0]  rdma_opcode;
    reg [15:0]  rdma_flags;
    reg [63:0]  rdma_local_key;
    reg [63:0]  rdma_remote_key;
    reg [127:0] rdma_btt;
    reg         rdma_entry_valid;
    
    // Command Controller (mock Data Mover commands)
    reg         CMD_CTRL_READY;
    wire        CMD_CTRL_START;
    wire [31:0] CMD_CTRL_SRC_ADDR;
    wire [31:0] CMD_CTRL_DST_ADDR;
    wire [31:0] CMD_CTRL_BTT;
    wire        CMD_CTRL_IS_READ;
    reg         READ_COMPLETE;
    reg         WRITE_COMPLETE;
    
    // TX Streamer Interface (connected between modules)
    wire        tx_cmd_valid;
    wire        tx_cmd_ready;
    wire [7:0]  tx_cmd_sq_index;
    wire [31:0] tx_cmd_ddr_addr;
    wire [31:0] tx_cmd_length;
    wire [7:0]  tx_cmd_opcode;
    wire [23:0] tx_cmd_dest_qp;
    wire [63:0] tx_cmd_remote_addr;
    wire [31:0] tx_cmd_rkey;
    wire [15:0] tx_cmd_partition_key;
    wire [7:0]  tx_cmd_service_level;
    wire [23:0] tx_cmd_psn;
    
    wire        tx_cpl_valid;
    wire        tx_cpl_ready;
    wire [7:0]  tx_cpl_sq_index;
    wire [7:0]  tx_cpl_status;
    wire [31:0] tx_cpl_bytes_sent;
    
    // State monitoring
    wire [3:0]  STATE_REG;
    wire        HAS_WORK;
    wire        START_STREAM;
    reg         IS_STREAM_BUSY;
    
    // CQ Entry outputs
    wire [31:0] cq_entry_0;
    wire [31:0] cq_entry_1;
    wire [31:0] cq_entry_2;
    wire [31:0] cq_entry_3;
    wire [31:0] cq_entry_4;
    wire [31:0] cq_entry_5;
    wire [31:0] cq_entry_6;
    wire [31:0] cq_entry_7;
    
    // TX Streamer <-> Header Inserter interface
    wire        hdr_start_tx;
    reg         hdr_tx_busy;
    reg         hdr_tx_done;
    wire [7:0]  hdr_rdma_opcode;
    wire [23:0] hdr_rdma_psn;
    wire [23:0] hdr_rdma_dest_qp;
    wire [63:0] hdr_rdma_remote_addr;
    wire [31:0] hdr_rdma_rkey;
    wire [31:0] hdr_rdma_length;
    wire [15:0] hdr_rdma_partition_key;
    wire [7:0]  hdr_rdma_service_level;
    wire [15:0] hdr_fragment_id;
    wire        hdr_more_fragments;
    wire [15:0] hdr_fragment_offset;
    
    // TX Streamer <-> Data Mover MM2S interface
    wire [71:0] m_axis_mm2s_cmd_tdata;
    wire        m_axis_mm2s_cmd_tvalid;
    reg         m_axis_mm2s_cmd_tready;
    reg         mm2s_rd_xfer_cmplt;
    
    // Instantiate RDMA Controller
    rdma_controller #(
        .ADDR_WIDTH(32),
        .SQ_IDX_WIDTH(16)
    ) u_rdma_controller (
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
    
    // Instantiate TX Streamer
    tx_streamer #(
        .C_ADDR_WIDTH(32),
        .C_DATA_WIDTH(32),
        .C_BTT_WIDTH(23),
        .BLOCK_SIZE(4096),
        .BOUNDARY_4KB(4096),
        .SQ_INDEX_WIDTH(8),
        .RDMA_OPCODE_WIDTH(8),
        .RDMA_PSN_WIDTH(24),
        .RDMA_QPN_WIDTH(24),
        .RDMA_ADDR_WIDTH(64),
        .RDMA_RKEY_WIDTH(32),
        .RDMA_LENGTH_WIDTH(32)
    ) u_tx_streamer (
        .aclk(clk),
        .aresetn(~rst),
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
        .m_axis_mm2s_cmd_tdata(m_axis_mm2s_cmd_tdata),
        .m_axis_mm2s_cmd_tvalid(m_axis_mm2s_cmd_tvalid),
        .m_axis_mm2s_cmd_tready(m_axis_mm2s_cmd_tready),
        .mm2s_rd_xfer_cmplt(mm2s_rd_xfer_cmplt)
    );
    
    // State name display for debugging
    reg [127:0] state_name;
    always @(*) begin
        case (STATE_REG)
            4'd0:  state_name = "IDLE";
            4'd1:  state_name = "PREPARE_READ";
            4'd2:  state_name = "READ_CMD";
            4'd3:  state_name = "WAIT_READ_DONE";
            4'd4:  state_name = "IS_STREAM_BUSY";
            4'd5:  state_name = "SEND_TX_CMD";
            4'd6:  state_name = "WAIT_TX_CPL";
            4'd7:  state_name = "PREPARE_WRITE";
            4'd8:  state_name = "WRITE_CMD";
            4'd9:  state_name = "START_STREAM";
            4'd10: state_name = "WAIT_WRITE_DONE";
            default: state_name = "UNKNOWN";
        endcase
    end
    
    //========================================================================
    // Mock Data Mover (MM2S/S2MM Command Handler)
    //========================================================================
    reg [4:0] dm_read_delay_cnt;
    reg [4:0] dm_write_delay_cnt;
    
    always @(posedge clk) begin
        if (rst) begin
            CMD_CTRL_READY <= 1;
            READ_COMPLETE <= 0;
            WRITE_COMPLETE <= 0;
            dm_read_delay_cnt <= 0;
            dm_write_delay_cnt <= 0;
        end else begin
            READ_COMPLETE <= 0;
            WRITE_COMPLETE <= 0;
            
            // Handle READ commands (SQ read)
            if (CMD_CTRL_START && CMD_CTRL_IS_READ) begin
                CMD_CTRL_READY <= 0;
                dm_read_delay_cnt <= 5; // 5 cycle delay
                $display("[%0t] Mock DM: READ CMD - Addr=0x%h, BTT=%0d", 
                         $time, CMD_CTRL_SRC_ADDR, CMD_CTRL_BTT);
            end else if (dm_read_delay_cnt > 0) begin
                dm_read_delay_cnt <= dm_read_delay_cnt - 1;
                if (dm_read_delay_cnt == 1) begin
                    READ_COMPLETE <= 1;
                    CMD_CTRL_READY <= 1;
                    $display("[%0t] Mock DM: READ COMPLETE", $time);
                end
            end
            
            // Handle WRITE commands (CQ write)
            if (CMD_CTRL_START && !CMD_CTRL_IS_READ) begin
                CMD_CTRL_READY <= 0;
                dm_write_delay_cnt <= 7; // 7 cycle delay
                $display("[%0t] Mock DM: WRITE CMD - Addr=0x%h, BTT=%0d", 
                         $time, CMD_CTRL_DST_ADDR, CMD_CTRL_BTT);
            end else if (dm_write_delay_cnt > 0) begin
                dm_write_delay_cnt <= dm_write_delay_cnt - 1;
                if (dm_write_delay_cnt == 1) begin
                    WRITE_COMPLETE <= 1;
                    CMD_CTRL_READY <= 1;
                    $display("[%0t] Mock DM: WRITE COMPLETE", $time);
                    $display("[%0t] CQ Entry: [0]=0x%h [1]=0x%h [2]=0x%h [3]=0x%h [4]=0x%h [5]=0x%h",
                             $time, cq_entry_0, cq_entry_1, cq_entry_2, cq_entry_3, cq_entry_4, cq_entry_5);
                end
            end
        end
    end
    
    //========================================================================
    // Mock Stream Parser (provides RDMA entries after SQ read)
    //========================================================================
    reg [1:0] parser_delay_cnt;
    
    always @(posedge clk) begin
        if (rst) begin
            rdma_entry_valid <= 0;
            parser_delay_cnt <= 0;
        end else begin
            rdma_entry_valid <= 0;
            
            // Trigger parsing 2 cycles after READ_COMPLETE
            if (READ_COMPLETE) begin
                parser_delay_cnt <= 2;
            end else if (parser_delay_cnt > 0) begin
                parser_delay_cnt <= parser_delay_cnt - 1;
                if (parser_delay_cnt == 1) begin
                    rdma_entry_valid <= 1;
                    $display("[%0t] Mock Parser: Entry Valid - ID=0x%h, Length=%0d", 
                             $time, rdma_id, rdma_btt[31:0]);
                end
            end
        end
    end
    
    //========================================================================
    // Mock TX Header Inserter
    //========================================================================
    reg [4:0] hdr_tx_cnt;
    
    always @(posedge clk) begin
        if (rst) begin
            hdr_tx_busy <= 0;
            hdr_tx_done <= 0;
            hdr_tx_cnt <= 0;
        end else begin
            hdr_tx_done <= 1;
            if (hdr_start_tx && !hdr_tx_busy) begin
                hdr_tx_busy <= 1;
                hdr_tx_cnt <= 32; // 7 beats for header
                $display("[%0t] Mock HDR: Start TX - Opcode=0x%h, Length=%0d, FragID=%0d, More=%b",
                         $time, hdr_rdma_opcode, hdr_rdma_length, hdr_fragment_id, hdr_more_fragments);
            end else if (hdr_tx_cnt > 0) begin
                hdr_tx_cnt <= hdr_tx_cnt - 1;
                if (hdr_tx_cnt == 1) begin
                    hdr_tx_busy <= 0;
                    
                    $display("[%0t] Mock HDR: TX Done", $time);
                end
            end
        end
    end
    
    //========================================================================
    // Mock Data Mover MM2S (payload read)
    //========================================================================
    reg [7:0] mm2s_transfer_cnt;
    reg [22:0] btt;
    reg [31:0] addr;
    always @(posedge clk) begin
        if (rst) begin
            m_axis_mm2s_cmd_tready <= 1;
            mm2s_rd_xfer_cmplt <= 0;
            mm2s_transfer_cnt <= 0;
        end else begin
            mm2s_rd_xfer_cmplt <= 0;
            
            if (m_axis_mm2s_cmd_tvalid && m_axis_mm2s_cmd_tready) begin
                // Extract BTT from command
                
                btt = m_axis_mm2s_cmd_tdata[22:0];
                addr = m_axis_mm2s_cmd_tdata[63:32];
                
                // Simulate transfer delay (1 cycle per 256 bytes)
                mm2s_transfer_cnt <= 5 + (btt[22:8]); // Base 5 + btt/256
                m_axis_mm2s_cmd_tready <= 0;
                
                $display("[%0t] Mock MM2S: CMD Received - Addr=0x%h, BTT=%0d", 
                         $time, addr, btt);
            end else if (mm2s_transfer_cnt > 0) begin
                mm2s_transfer_cnt <= mm2s_transfer_cnt - 1;
                if (mm2s_transfer_cnt == 1) begin
                    mm2s_rd_xfer_cmplt <= 1;
                    m_axis_mm2s_cmd_tready <= 1;
                    $display("[%0t] Mock MM2S: Transfer Complete", $time);
                end
            end
        end
    end
    
    //========================================================================
    // Mock Master Stream (IS_STREAM_BUSY)
    //========================================================================
    reg [2:0] stream_busy_cnt;
    
    always @(posedge clk) begin
        if (rst) begin
            IS_STREAM_BUSY <= 0;
            stream_busy_cnt <= 0;
        end else begin
            if (START_STREAM) begin
                IS_STREAM_BUSY <= 1;
                stream_busy_cnt <= 3; // Busy for 3 cycles
                $display("[%0t] Mock Stream: START_STREAM received", $time);
            end else if (stream_busy_cnt > 0) begin
                stream_busy_cnt <= stream_busy_cnt - 1;
                if (stream_busy_cnt == 1) begin
                    IS_STREAM_BUSY <= 0;
                end
            end
        end
    end
    
    //========================================================================
    // State transition monitoring
    //========================================================================
    reg [3:0] prev_state;
    always @(posedge clk) begin
        if (STATE_REG != prev_state) begin
            $display("[%0t] State: %s -> %s", $time, 
                     get_state_name(prev_state), get_state_name(STATE_REG));
            prev_state <= STATE_REG;
        end
    end
    
    function [127:0] get_state_name;
        input [3:0] state;
        begin
            case (state)
                4'd0:  get_state_name = "IDLE";
                4'd1:  get_state_name = "PREPARE_READ";
                4'd2:  get_state_name = "READ_CMD";
                4'd3:  get_state_name = "WAIT_READ_DONE";
                4'd4:  get_state_name = "IS_STREAM_BUSY";
                4'd5:  get_state_name = "SEND_TX_CMD";
                4'd6:  get_state_name = "WAIT_TX_CPL";
                4'd7:  get_state_name = "PREPARE_WRITE";
                4'd8:  get_state_name = "WRITE_CMD";
                4'd9:  get_state_name = "START_STREAM";
                4'd10: get_state_name = "WAIT_WRITE_DONE";
                default: get_state_name = "UNKNOWN";
            endcase
        end
    endfunction
    
    //========================================================================
    // TX Streamer monitoring
    //========================================================================
    always @(posedge clk) begin
        if (tx_cmd_valid && tx_cmd_ready) begin
            $display("[%0t] TX CMD: SQ_IDX=%0d, Addr=0x%h, Len=%0d, Opcode=0x%h",
                     $time, tx_cmd_sq_index, tx_cmd_ddr_addr, tx_cmd_length, tx_cmd_opcode);
        end
        
        if (tx_cpl_valid && tx_cpl_ready) begin
            $display("[%0t] TX CPL: SQ_IDX=%0d, Status=%0d, Bytes=%0d",
                     $time, tx_cpl_sq_index, tx_cpl_status, tx_cpl_bytes_sent);
        end
    end
    
    //========================================================================
    // Test Tasks
    //========================================================================
    task submit_sq_entry;
        input [31:0] id;
        input [15:0] opcode;
        input [31:0] local_addr;
        input [63:0] remote_addr;
        input [31:0] length;
        begin
            rdma_id = id;
            rdma_opcode = opcode;
            rdma_flags = 16'h0000;
            rdma_local_key = {32'h0, local_addr};
            rdma_remote_key = remote_addr;
            rdma_btt = {96'h0, length};
            
            SQ_TAIL_SW = SQ_TAIL_SW + 1;
            $display("[%0t] === Submitted SQ Entry: ID=0x%h, LocalAddr=0x%h, Length=%0d ===",
                     $time, id, local_addr, length);
        end
    endtask
    
    task wait_for_cq_entry;
        input integer timeout;
        integer cnt;
        begin
            cnt = 0;
            while (CQ_TAIL_HW == CQ_HEAD_SW && cnt < timeout) begin
                @(posedge clk);
                cnt = cnt + 1;
            end
            
            if (cnt >= timeout) begin
                $display("[%0t] ERROR: Timeout waiting for CQ entry", $time);
            end else begin
                $display("[%0t] === CQ Entry Received ===", $time);
                CQ_HEAD_SW = CQ_HEAD_SW + 1;
            end
        end
    endtask
    
    //========================================================================
    // Test Stimulus
    //========================================================================
    initial begin
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
        
        rdma_id = 0;
        rdma_opcode = 0;
        rdma_flags = 0;
        rdma_local_key = 0;
        rdma_remote_key = 0;
        rdma_btt = 0;
        rdma_entry_valid = 0;
        
        prev_state = 4'd0;
        
        // Generate VCD for waveform viewing
        $dumpfile("tb_rdma_tx_integrated.vcd");
        $dumpvars(0, tb_rdma_tx_integrated);
        
        // Reset sequence
        repeat(10) @(posedge clk);
        rst = 0;
        repeat(5) @(posedge clk);
        
        $display("\n========================================");
        $display("Starting Integrated TX Path Test");
        $display("========================================\n");
        
        START_RDMA = 1;
        
        // Test 1: Small transfer (256 bytes, single fragment)
        $display("\n--- Test 1: 256 byte transfer ---");
        submit_sq_entry(32'h1234, 16'h0A, 32'h3000_0000, 64'h5000_0000_0000_0000, 32'd256);
        wait_for_cq_entry(500);
        repeat(20) @(posedge clk);
        
        // Test 2: Medium transfer (1KB, single fragment)
        $display("\n--- Test 2: 1KB transfer ---");
        submit_sq_entry(32'h1235, 16'h0A, 32'h3000_1000, 64'h5000_0000_0000_1000, 32'd1024);
        wait_for_cq_entry(500);
        repeat(20) @(posedge clk);
        
        // Test 3: Large transfer (8KB, multiple fragments)
        $display("\n--- Test 3: 8KB transfer ---");
        submit_sq_entry(32'h1236, 16'h0A, 32'h3000_2000, 64'h5000_0000_0000_2000, 32'd8192);
        wait_for_cq_entry(1000);
        repeat(20) @(posedge clk);
        
        // Test 4: Boundary-crossing transfer (4KB at unaligned address)
        $display("\n--- Test 4: 4KB at unaligned address ---");
        submit_sq_entry(32'h1237, 16'h0A, 32'h3000_0800, 64'h5000_0000_0000_3000, 32'd4096);
        wait_for_cq_entry(1000);
        repeat(20) @(posedge clk);
        
        $display("\n========================================");
        $display("Test Complete");
        $display("========================================\n");
        
        repeat(50) @(posedge clk);
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #100000;
        $display("ERROR: Simulation timeout!");
        $finish;
    end

endmodule
