`timescale 1ns/1ps
// ============================================================================
// Module: rdma_meta_validator
// ============================================================================
module rdma_meta_validator (
    input  wire        iClk,
    input  wire        iRst,

    // Input metadata
    input  wire [15:0] i_payload_len,
    input  wire [31:0] i_src_ip,
    input  wire [31:0] i_dst_ip,
    input  wire [15:0] i_src_port,
    input  wire [15:0] i_dst_port,
    input  wire [7:0]  i_flags,
    input  wire [7:0]  i_endpoint_id,
    input  wire        i_valid,
    output reg         o_ready,

    // Validated output metadata
    output reg  [15:0] o_payload_len,
    output reg  [31:0] o_src_ip,
    output reg  [31:0] o_dst_ip,
    output reg  [15:0] o_src_port,
    output reg  [15:0] o_dst_port,
    output reg  [7:0]  o_flags,
    output reg  [7:0]  o_endpoint_id,
    output reg         o_valid,
    input  wire        i_ready,

    // Error signaling
    output reg         o_error,
    output reg  [3:0]  o_error_code
);

    // Error codes
    localparam [3:0] ERR_NONE           = 4'h0,
                     ERR_PAYLOAD_ZERO   = 4'h1,
                     ERR_PAYLOAD_LARGE  = 4'h2,
                     ERR_SRC_IP_ZERO    = 4'h3,
                     ERR_DST_IP_ZERO    = 4'h4,
                     ERR_SRC_PORT_ZERO  = 4'h5,
                     ERR_DST_PORT_ZERO  = 4'h6;

    // FSM States
    localparam [1:0] IDLE     = 2'b00,
                     VALIDATE = 2'b01,
                     FORWARD  = 2'b10,
                     ERROR_ST = 2'b11;

    reg [1:0] state;

    // Max payload: MTU (1500) - IP header (20) - UDP header (8) = 1472
    localparam [15:0] MAX_PAYLOAD = 16'd1472;

    // Validation checks
    wire valid_payload_len = (i_payload_len != 16'd0) && (i_payload_len <= MAX_PAYLOAD);
    wire valid_src_ip      = (i_src_ip != 32'd0);
    wire valid_dst_ip      = (i_dst_ip != 32'd0);
    wire valid_src_port    = (i_src_port != 16'd0);
    wire valid_dst_port    = (i_dst_port != 16'd0);
    wire all_valid         = valid_payload_len && valid_src_ip && valid_dst_ip && 
                             valid_src_port && valid_dst_port;

    // Determine error code
    function [3:0] get_error_code;
        input [15:0] len;
        input [31:0] sip, dip;
        input [15:0] sport, dport;
        begin
            if (len == 16'd0)
                get_error_code = ERR_PAYLOAD_ZERO;
            else if (len > MAX_PAYLOAD)
                get_error_code = ERR_PAYLOAD_LARGE;
            else if (sip == 32'd0)
                get_error_code = ERR_SRC_IP_ZERO;
            else if (dip == 32'd0)
                get_error_code = ERR_DST_IP_ZERO;
            else if (sport == 16'd0)
                get_error_code = ERR_SRC_PORT_ZERO;
            else if (dport == 16'd0)
                get_error_code = ERR_DST_PORT_ZERO;
            else
                get_error_code = ERR_NONE;
        end
    endfunction

    always @(posedge iClk) begin
        if (!iRst) begin
            state        <= IDLE;
            o_ready      <= 1'b0;
            o_valid      <= 1'b0;
            o_error      <= 1'b0;
            o_error_code <= ERR_NONE;
            o_payload_len <= 16'd0;
            o_src_ip     <= 32'd0;
            o_dst_ip     <= 32'd0;
            o_src_port   <= 16'd0;
            o_dst_port   <= 16'd0;
            o_flags      <= 8'd0;
            o_endpoint_id <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    o_ready <= 1'b1;
                    o_valid <= 1'b0;
                    o_error <= 1'b0;
                    o_error_code <= ERR_NONE;
                    
                    if (i_valid && o_ready) begin
                        o_ready <= 1'b0;
                        state <= VALIDATE;
                    end
                end

                VALIDATE: begin
                    if (all_valid) begin
                        o_payload_len <= i_payload_len;
                        o_src_ip      <= i_src_ip;
                        o_dst_ip      <= i_dst_ip;
                        o_src_port    <= i_src_port;
                        o_dst_port    <= i_dst_port;
                        o_flags       <= i_flags;
                        o_endpoint_id <= i_endpoint_id;
                        o_valid       <= 1'b1;
                        state         <= FORWARD;
                    end else begin
                        o_error      <= 1'b1;
                        o_error_code <= get_error_code(i_payload_len, i_src_ip, 
                                                       i_dst_ip, i_src_port, i_dst_port);
                        state        <= ERROR_ST;
                    end
                end

                FORWARD: begin
                    if (i_ready && o_valid) begin
                        o_valid <= 1'b0;
                        state   <= IDLE;
                    end
                end

                ERROR_ST: begin
                    // Hold error for one cycle, then return to idle
                    o_error <= 1'b0;
                    state   <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule