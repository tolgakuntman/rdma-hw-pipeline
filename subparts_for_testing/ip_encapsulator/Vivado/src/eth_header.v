`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------
// -- Company: KUL - Group T - RDMA Team
// -- Engineer: Tubi Soyer <tugberksoyer@gmail.com>
// -- 
// -- Create Date: 22/11/2025 12:09:11 PM
// -- Design Name: 
// -- Module Name: eth_header
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

module eth_header(
    input  wire        clk,
    input  wire        rstn,
    input  wire [47:0] dst_mac,
    input  wire [47:0] src_mac,
    input  wire        valid_in,
    output reg  [111:0] eth_header, // 14-byte Ethernet header (MSB-first)
    output reg         valid_out,
    input  wire        ready_in
);

localparam ETHERTYPE_IPV4 = 16'h0800;

always @(posedge clk) begin
    if (!rstn) begin
        eth_header <= 112'd0;
        valid_out  <= 1'b0;
    end else begin
        // Hold current header until downstream consumes it
        if (valid_out && ready_in) begin
            valid_out <= 1'b0;
        end

        // Capture a new header when available and no header is pending
        if (valid_in && (!valid_out || (valid_out && ready_in))) begin
            eth_header <= {dst_mac, src_mac, ETHERTYPE_IPV4};
            valid_out  <= 1'b1;
        end
    end
end
endmodule
