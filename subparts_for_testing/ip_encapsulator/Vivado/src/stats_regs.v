`timescale 1ns / 1ps
// stats_regs.v
// Packet and byte counters with 64-bit output and clear pulse support
module stats_regs(
    input  wire        clk,
    input  wire        rstn,
    input  wire        pkt_valid,
    input  wire [15:0] pkt_bytes,
    input  wire        clear_counters,   // pulse to reset counters

    output reg [63:0]  pkt_count_out,
    output reg [63:0]  byte_count_out
);

always @(posedge clk) begin
    if (!rstn || clear_counters) begin
        pkt_count_out  <= 64'h0;
        byte_count_out <= 64'h0;
    end else if (pkt_valid) begin
        pkt_count_out  <= pkt_count_out + 1;
        byte_count_out <= byte_count_out + pkt_bytes;
    end
end

endmodule