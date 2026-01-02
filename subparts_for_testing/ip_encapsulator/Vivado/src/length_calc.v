`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------
// -- Company: KUL - Group T - RDMA Team
// -- Engineer: Tubi Soyer <tugberksoyer@gmail.com>
// -- 
// -- Create Date: 22/11/2025 12:09:11 PM
// -- Design Name: 
// -- Module Name: length_calc
// -- Project Name: RDMA
// -- Target Devices: Kria KR260
// -- Tool Versions: 
// -- Description: 
// -- 
// -- Dependencies: 
// -- 
// -- Revision:
// -- Revision 0.01 - File Created
// -- Additional Comments:
// -- 
// -------------------------------------------------------------------------------
//////////////////////////////////////////////////////////////////////////////////

module length_calc #(
    parameter PAYLOAD_WIDTH = 16 // payload length in bytes
)(
    input  wire clk,
    input  wire rstn,

    input  wire [15:0] payload_len_in,
    input  wire payload_len_valid,
    output reg  payload_len_ready,

    output reg [15:0] ip_total_length,
    output reg [15:0] udp_length,
    output reg        length_valid,
    input  wire       length_ready
);


// All sequential assignments for registered outputs are consolidated here.
always @(posedge clk) begin
    if (!rstn) begin
        // Reset state
        ip_total_length <= 16'h0000;
        udp_length <= 16'h0000;
        length_valid <= 1'b0;
        payload_len_ready <= 1'b1; // Start in the ready state
    end else begin
        // Default: hold current values if no transition occurs
        ip_total_length <= ip_total_length;
        udp_length <= udp_length;
        length_valid <= length_valid;
        payload_len_ready <= payload_len_ready;
        
        // Priority 1: Output Accepted by downstream (Go to IDLE/Ready state)
        if (length_valid && length_ready) begin
            length_valid <= 1'b0;
            payload_len_ready <= 1'b1;
        end
        
        // Priority 2: New data accepted (Go to ACTIVE/Valid state)
        else if (payload_len_valid && payload_len_ready) begin
            // IP header is 20 bytes, UDP header is 8 bytes.
            ip_total_length <= 16'd20 + 16'd8 + payload_len_in; // IP total length
            udp_length      <= 16'd8 + payload_len_in;         // UDP length
            
            length_valid <= 1'b1;
            payload_len_ready <= 1'b0; // De-assert ready while the output is pending acceptance
        end
    end
end

endmodule
