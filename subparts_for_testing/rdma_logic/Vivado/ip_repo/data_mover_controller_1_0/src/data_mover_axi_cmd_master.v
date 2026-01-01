`timescale 1ns / 1ps

module data_mover_axi_cmd_master
    (
        input wire         clk,
        input wire         rst_n,
        input wire         is_read, // 1: read from memory, 0: write to memory
        output wire        ready,
        input wire [31:0]  saddr,
        input wire [31:0]  daddr,
        input wire [31:0]  btt,
        input wire         start,
        output wire [71:0] m_axis_mm2s_cmd_tdata,
        output wire        m_axis_mm2s_cmd_tvalid,
        output wire [71:0] m_axis_s2mm_cmd_tdata,
        output wire        m_axis_s2mm_cmd_tvalid,
        input wire         s2mm_wr_xfer_cmplt,
        input wire         mm2s_rd_xfer_cmplt,
        output wire [2:0] STATE_REG
    );
    
    // FSM states
    localparam IDLE         = 2'd0;
    localparam SEND_CMD     = 2'd1;
    localparam WAIT_S2MM    = 2'd2;
    localparam WAIT_MM2S    = 2'd3;

    reg [2:0] state_reg, state_next;
    // capture start edge and direction at start
    reg start_d;
    reg dir_reg; // 1 = read (MM2S), 0 = write (S2MM)

    // Sequential state and start sampling
    always @(posedge clk) begin
        if (~rst_n) begin
            state_reg <= IDLE;
            start_d <= 1'b0;
            dir_reg <= 1'b1;
        end else begin
            state_reg <= state_next;
            start_d <= start;
            if (start_pulse)
                dir_reg <= is_read;
        end
    end

    // Edge detect for start (rising edge)
    wire start_pulse = start && ~start_d;
    assign STATE_REG = state_reg;
    // Next-state logic
    always @(*) begin
        // default
        state_next = state_reg;
        case (state_reg)
            IDLE: begin
                if (start_pulse) begin
                    state_next = SEND_CMD;
                end
            end
            SEND_CMD: begin
                // after we assert the appropriate command valid for one cycle,
                // go to WAIT_S2MM if we issued a S2MM (write), otherwise return to IDLE
                if (dir_reg == 1'b0)
                    state_next = WAIT_S2MM; // wait write completion
                else
                    state_next = WAIT_MM2S; // read: wait read completion
            end
            WAIT_S2MM: begin
                if (s2mm_wr_xfer_cmplt)
                    state_next = IDLE;
            end
            WAIT_MM2S: begin
                if (mm2s_rd_xfer_cmplt)
                    state_next = IDLE;
            end
            default: state_next = IDLE;
        endcase
    end


    assign ready = (state_reg == IDLE) ? 1'b1 : 1'b0;

    // Build command TDATA fields (72-bit) as before
    assign m_axis_s2mm_cmd_tdata = {8'b00000000, daddr, 1'b0, 1'b1, 6'b000000, 1'b1, btt[22:0]}; // S2MM instruction
    assign m_axis_mm2s_cmd_tdata = {8'b00000000, saddr, 1'b0, 1'b1, 6'b000000, 1'b1, btt[22:0]}; // MM2S instruction

    // tvalid asserted for one cycle in SEND_CMD and directed by dir_reg
    assign m_axis_s2mm_cmd_tvalid = (state_reg == SEND_CMD && dir_reg == 1'b0) ? 1'b1 : 1'b0;
    assign m_axis_mm2s_cmd_tvalid = (state_reg == SEND_CMD && dir_reg == 1'b1) ? 1'b1 : 1'b0;
endmodule
