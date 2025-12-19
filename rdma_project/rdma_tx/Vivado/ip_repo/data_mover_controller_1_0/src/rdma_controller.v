----------------------------------------------------------------------------------
-- Company: KUL - Group T - RDMA Team
-- Engineer: Tolga Kuntman <kuntmantolga@gmail.com>
-- 
-- Create Date: 21/11/2025 14:25:54 PM
-- Design Name: 
-- Module Name: rdma_controller
-- Project Name: RDMA
-- Target Devices: Kria KR260
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
`timescale 1ns / 1ps

module rdma_controller #(
    parameter ADDR_WIDTH = 32,
    parameter SQ_IDX_WIDTH = 16
)(
    input  wire                    clk,
    input  wire                    rst,               // active high reset

    // Control
    input  wire                    START_RDMA,        // global enable
    input  wire                    RESET_RDMA,        // reset queues (optional)

    // SQ configuration / pointers
    input  wire [ADDR_WIDTH-1:0]   SQ_BASE_ADDR,      // base DDR addr of SQ ring
    input wire [ADDR_WIDTH-1:0]  CQ_BASE_ADDR,           // CQ base addr

    input  wire [SQ_IDX_WIDTH-1:0] SQ_SIZE,
    input wire [SQ_IDX_WIDTH-1:0] CQ_SIZE,

    input  wire [SQ_IDX_WIDTH-1:0] SQ_TAIL_SW, 
    output wire [SQ_IDX_WIDTH-1:0] SQ_HEAD_HW,

    output  wire  [SQ_IDX_WIDTH-1:0] CQ_TAIL_HW,
    input wire  [SQ_IDX_WIDTH-1:0] CQ_HEAD_SW,

    // RDMA Entry Inputs (from slave stream parser)
    input wire [31:0]   rdma_id,
    input wire [15:0]   rdma_opcode,
    input wire [15:0]   rdma_flags,
    input wire [63:0]   rdma_local_key,
    input wire [63:0]   rdma_remote_key,
    input wire [127:0]  rdma_btt,
    input wire          rdma_entry_valid,

    // Command controller (unified for SQ/CQ operations)
    input  wire                    CMD_CTRL_READY,
    output wire                     CMD_CTRL_START,
    output wire  [31:0]             CMD_CTRL_SRC_ADDR,
    output wire  [31:0]             CMD_CTRL_DST_ADDR,
    output wire  [31:0]             CMD_CTRL_BTT,
    output wire                     CMD_CTRL_IS_READ,
    input  wire                    READ_COMPLETE,      // from MM2S data path
    input wire                    WRITE_COMPLETE,     // from S2MM data path

    // TX Streamer Interface (for sending RDMA packets)
    output wire                     tx_cmd_valid,
    input  wire                     tx_cmd_ready,
    output wire [7:0]               tx_cmd_sq_index,
    output wire [31:0]              tx_cmd_ddr_addr,
    output wire [31:0]              tx_cmd_length,
    output wire [7:0]               tx_cmd_opcode,
    output wire [23:0]              tx_cmd_dest_qp,
    output wire [63:0]              tx_cmd_remote_addr,
    output wire [31:0]              tx_cmd_rkey,
    output wire [15:0]              tx_cmd_partition_key,
    output wire [7:0]               tx_cmd_service_level,
    output wire [23:0]              tx_cmd_psn,
    
    input  wire                     tx_cpl_valid,
    output wire                     tx_cpl_ready,
    input  wire [7:0]               tx_cpl_sq_index,
    input  wire [7:0]               tx_cpl_status,
    input  wire [31:0]              tx_cpl_bytes_sent,

    output wire [3:0]               STATE_REG,
    output wire                     HAS_WORK,
    output wire                     START_STREAM,
    input wire                      IS_STREAM_BUSY,

    // CQ Entry outputs to master stream (8 x 32-bit words)
    output wire [31:0]              cq_entry_0,
    output wire [31:0]              cq_entry_1,
    output wire [31:0]              cq_entry_2,
    output wire [31:0]              cq_entry_3,
    output wire [31:0]              cq_entry_4,
    output wire [31:0]              cq_entry_5,
    output wire [31:0]              cq_entry_6,
    output wire [31:0]              cq_entry_7
);

    localparam integer SQ_DESC_BYTES = 64;
    localparam integer CQ_DESC_BYTES = 32;
    localparam integer SQ_DESC_SHIFT = 6; // log2(64)
    localparam integer CQ_DESC_SHIFT = 5;

    // FSM states
    localparam S_IDLE             = 4'd0;
    localparam S_PREPARE_READ     = 4'd1;
    localparam S_READ_CMD         = 4'd2;
    localparam S_WAIT_READ_DONE   = 4'd3;
    localparam S_IS_STREAM_BUSY   = 4'd4;
    localparam S_SEND_TX_CMD      = 4'd5;
    localparam S_WAIT_TX_CPL      = 4'd6;
    localparam S_PREPARE_WRITE    = 4'd7;
    localparam S_WRITE_CMD        = 4'd8;
    localparam S_START_STREAM     = 4'd9;
    localparam S_WAIT_WRITE_DONE  = 4'd10;

    reg [3:0] state_reg, state_next;

    // SQ/CQ pointers
    reg [SQ_IDX_WIDTH-1:0] sq_head_reg;
    reg [SQ_IDX_WIDTH-1:0] cq_tail_reg;
    assign SQ_HEAD_HW = sq_head_reg;
    assign CQ_TAIL_HW = cq_tail_reg;
    
    // Latched RDMA entry
    reg [31:0]   rdma_id_reg;
    reg [15:0]   rdma_opcode_reg;
    reg [63:0]   rdma_local_key_reg;
    reg [63:0]   rdma_remote_key_reg;
    reg [31:0]   rdma_length_reg;
    
    // CQ Entry registers (8 x 32-bit = 32 bytes)
    reg [31:0]   cq_entry_reg_0;
    reg [31:0]   cq_entry_reg_1;
    reg [31:0]   cq_entry_reg_2;
    reg [31:0]   cq_entry_reg_3;
    reg [31:0]   cq_entry_reg_4;
    reg [31:0]   cq_entry_reg_5;
    reg [31:0]   cq_entry_reg_6;
    reg [31:0]   cq_entry_reg_7;
    
    // Check if there's work to do
    wire has_work = (sq_head_reg != SQ_TAIL_SW);
    assign HAS_WORK = has_work;
    
    // Pointer increment with wraparound
    wire [SQ_IDX_WIDTH-1:0] sq_head_next =
        (sq_head_reg + 1 == SQ_SIZE) ? {SQ_IDX_WIDTH{1'b0}} : (sq_head_reg + 1);
    wire [SQ_IDX_WIDTH-1:0] cq_tail_next =
        (cq_tail_reg + 1 == CQ_SIZE) ? {SQ_IDX_WIDTH{1'b0}} : (cq_tail_reg + 1);
    // Sequential part
    always @(posedge clk) begin
        if (rst) begin
            state_reg     <= S_IDLE;
            sq_head_reg   <= {SQ_IDX_WIDTH{1'b0}};
            cq_tail_reg   <= {SQ_IDX_WIDTH{1'b0}};
            rdma_id_reg   <= 0;
            rdma_opcode_reg <= 0;
            rdma_local_key_reg <= 0;
            rdma_remote_key_reg <= 0;
            rdma_length_reg <= 0;
            cq_entry_reg_0 <= 0;
            cq_entry_reg_1 <= 0;
            cq_entry_reg_2 <= 0;
            cq_entry_reg_3 <= 0;
            cq_entry_reg_4 <= 0;
            cq_entry_reg_5 <= 0;
            cq_entry_reg_6 <= 0;
            cq_entry_reg_7 <= 0;
        end else begin
            state_reg  <= state_next;

            // Latch RDMA entry when parsed (in WAIT_READ_DONE or IS_STREAM_BUSY state)
            if (rdma_entry_valid) begin
                rdma_id_reg <= rdma_id;
                rdma_opcode_reg <= rdma_opcode;
                rdma_local_key_reg <= rdma_local_key;
                rdma_remote_key_reg <= rdma_remote_key;
                rdma_length_reg <= rdma_btt[31:0];
            end

            // Update pointers on CQ write completion
            if ((state_reg == S_WAIT_WRITE_DONE) && WRITE_COMPLETE) begin
                cq_tail_reg <= cq_tail_next;
                sq_head_reg <= sq_head_next;
            end else begin
                cq_tail_reg <= cq_tail_reg;
                sq_head_reg <= sq_head_reg;
            end

            // Build CQ entry in PREPARE_WRITE state (after TX completion)
            // This ensures we capture the completion info at the right time
            if (state_reg == S_PREPARE_WRITE) begin
                // CQ Entry Format (32 bytes):
                // Word 0: WQE ID (SQ index)
                // Word 1: Status (8-bit) | Opcode (8-bit) | Reserved (16-bit)
                // Word 2: Bytes transferred (lower 32 bits)
                // Word 3: Bytes transferred (upper 32 bits)
                // Word 4-7: Reserved / Extended info
                cq_entry_reg_0 <= {24'd0, tx_cpl_sq_index};
                cq_entry_reg_1 <= {24'd0, tx_cpl_status};  // Status assumed success
                cq_entry_reg_2 <= tx_cpl_bytes_sent;  // Use the original length as bytes sent
                cq_entry_reg_3 <= {24'd0, tx_cpl_sq_index};  // Upper bytes (assuming 32-bit length)
                cq_entry_reg_4 <= rdma_id_reg;  // Original WQE ID for reference
                cq_entry_reg_5 <= rdma_length_reg;  // Original length requested
                cq_entry_reg_6 <= 32'd0;  // Reserved
                cq_entry_reg_7 <= 32'd0;  // Reserved
            end
        end
    end

    // Internal command registers (unified)
    reg                    cmd_ctrl_start_r;
    reg [31:0]             cmd_ctrl_src_addr_r;
    reg [31:0]             cmd_ctrl_dst_addr_r;
    reg [31:0]             cmd_ctrl_btt_r;
    reg                    cmd_ctrl_is_read_r;
    reg                    start_stream_r;
    reg                    tx_cmd_valid_r;
    
    // Output assignments
    assign CMD_CTRL_START    = cmd_ctrl_start_r;
    assign CMD_CTRL_SRC_ADDR = cmd_ctrl_src_addr_r;
    assign CMD_CTRL_DST_ADDR = cmd_ctrl_dst_addr_r;
    assign CMD_CTRL_BTT      = cmd_ctrl_btt_r;
    assign CMD_CTRL_IS_READ  = cmd_ctrl_is_read_r;
    
    assign tx_cmd_valid = tx_cmd_valid_r;
    assign tx_cmd_sq_index = sq_head_reg[7:0];
    assign tx_cmd_ddr_addr = rdma_local_key_reg[31:0];
    assign tx_cmd_length = rdma_length_reg;
    assign tx_cmd_opcode = rdma_opcode_reg[7:0];
    assign tx_cmd_dest_qp = rdma_id_reg[23:0];  // Assuming ID contains dest QP
    assign tx_cmd_remote_addr = rdma_remote_key_reg;
    assign tx_cmd_rkey = rdma_remote_key_reg[31:0];
    assign tx_cmd_partition_key = 16'hFFFF;
    assign tx_cmd_service_level = 8'h00;
    assign tx_cmd_psn = 24'h000001;
    
    assign tx_cpl_ready = 1'b1; // Always ready for completion
    assign STATE_REG = state_reg;
    assign START_STREAM = start_stream_r;
    
    // CQ Entry outputs
    assign cq_entry_0 = cq_entry_reg_0;
    assign cq_entry_1 = cq_entry_reg_1;
    assign cq_entry_2 = cq_entry_reg_2;
    assign cq_entry_3 = cq_entry_reg_3;
    assign cq_entry_4 = cq_entry_reg_4;
    assign cq_entry_5 = cq_entry_reg_5;
    assign cq_entry_6 = cq_entry_reg_6;
    assign cq_entry_7 = cq_entry_reg_7;
    // Combinational next-state logic
    always @(*) begin
        state_next = state_reg;

        case (state_reg)
            S_IDLE: begin
                if (START_RDMA && has_work)
                    state_next = S_PREPARE_READ;
            end

            S_PREPARE_READ: begin
                state_next = S_READ_CMD;
            end

            S_READ_CMD: begin
                if (CMD_CTRL_READY)
                    state_next = S_WAIT_READ_DONE;
            end

            S_WAIT_READ_DONE: begin
                if (READ_COMPLETE)
                    state_next = S_IS_STREAM_BUSY;
            end

            S_IS_STREAM_BUSY: begin
                if (!IS_STREAM_BUSY && rdma_entry_valid)
                    state_next = S_SEND_TX_CMD;
            end

            S_SEND_TX_CMD: begin
                if (tx_cmd_ready)
                    state_next = S_WAIT_TX_CPL;
            end

            S_WAIT_TX_CPL: begin
                if (tx_cpl_valid)
                    state_next = S_PREPARE_WRITE;
            end

            S_PREPARE_WRITE: begin
                state_next = S_WRITE_CMD;
            end

            S_WRITE_CMD: begin
                if (CMD_CTRL_READY)
                    state_next = S_START_STREAM;
            end

            S_START_STREAM: begin
                state_next = S_WAIT_WRITE_DONE;
            end

            S_WAIT_WRITE_DONE: begin
                if (WRITE_COMPLETE)
                    state_next = S_IDLE;
            end

            default: state_next = S_IDLE;
        endcase
    end

    // Sequential logic: command generation
    always @(posedge clk) begin
        if (rst) begin
            cmd_ctrl_start_r    <= 1'b0;
            cmd_ctrl_src_addr_r <= 32'd0;
            cmd_ctrl_dst_addr_r <= 32'd0;
            cmd_ctrl_btt_r      <= 32'd0;
            cmd_ctrl_is_read_r  <= 1'b1;
            tx_cmd_valid_r      <= 1'b0;
            start_stream_r      <= 1'b0;
        end else begin
            // Default: clear pulses
            cmd_ctrl_start_r <= 1'b0;
            tx_cmd_valid_r   <= 1'b0;
            start_stream_r   <= 1'b0;

            case (state_reg)
                S_PREPARE_READ: begin
                    cmd_ctrl_src_addr_r <= SQ_BASE_ADDR[31:0] + (sq_head_reg << SQ_DESC_SHIFT);
                    cmd_ctrl_dst_addr_r <= 32'd0;
                    cmd_ctrl_btt_r      <= SQ_DESC_BYTES;
                    cmd_ctrl_is_read_r  <= 1'b1;
                end

                S_READ_CMD: begin
                    if (CMD_CTRL_READY) begin
                        cmd_ctrl_start_r   <= 1'b1;
                        cmd_ctrl_is_read_r <= 1'b1;
                    end
                end

                S_SEND_TX_CMD: begin
                    tx_cmd_valid_r <= 1'b1;
                end

                S_PREPARE_WRITE: begin
                    cmd_ctrl_src_addr_r <= 32'd0;
                    cmd_ctrl_dst_addr_r <= CQ_BASE_ADDR[31:0] + (cq_tail_reg << CQ_DESC_SHIFT);
                    cmd_ctrl_btt_r      <= CQ_DESC_BYTES;
                    cmd_ctrl_is_read_r  <= 1'b0;
                end

                S_WRITE_CMD: begin
                    if (CMD_CTRL_READY) begin
                        cmd_ctrl_start_r   <= 1'b1;
                        cmd_ctrl_is_read_r <= 1'b0;
                    end
                end

                S_START_STREAM: begin
                    start_stream_r <= 1'b1;
                end

                default: begin
                    cmd_ctrl_is_read_r <= cmd_ctrl_is_read_r;
                end
            endcase
        end
    end

endmodule
