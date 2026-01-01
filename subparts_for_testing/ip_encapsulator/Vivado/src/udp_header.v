`timescale 1ns / 1ps
// udp_header.v
// Build UDP header
module udp_header(
    input  wire clk,
    input  wire rstn,
    input  wire [15:0] src_port,
    input  wire [15:0] dst_port,
    input  wire [15:0] udp_length,
    input  wire valid_in,
    output reg  ready_in,
    output reg  [63:0] udp_header, // 4 bytes x2 + optional padding
    output reg  valid_out,
    input  wire ready_out
);


// All sequential assignments for registered outputs are consolidated here.
always @(posedge clk) begin
    if (!rstn) begin
        // Reset state
        udp_header <= 64'h0;
        valid_out <= 1'b0;
        ready_in <= 1'b1; // Start in the ready state
    end else begin
        // Default: hold current values for outputs unless a transition occurs
        udp_header <= udp_header;
        valid_out <= valid_out;
        ready_in <= ready_in; // Hold the current ready state
        
        // Output Acceptance (Priority 1: Go to IDLE/Ready state)
        if (valid_out && ready_out) begin
            valid_out <= 1'b0;
            ready_in <= 1'b1; // Ready for new input
        end 
        
        // Input Acceptance (Priority 2: Go to ACTIVE/Valid state)
        else if (valid_in && ready_in) begin
            // Build the UDP header (MSB-first)
            // Bytes 0-1: Source Port
            // Bytes 2-3: Destination Port
            // Bytes 4-5: Length
            // Bytes 6-7: Checksum (set to 0 for now)
            udp_header <= {
                src_port, 
                dst_port, 
                udp_length, 
                16'h0000 
            };
            
            valid_out <= 1'b1;
            ready_in <= 1'b0; // De-assert ready while the output is pending acceptance
        end
    end
end


/*
always @(posedge clk) begin
    if (!rstn) begin
        valid_out <= 0;
        ready_in <= 1;
    end else begin
        if (valid_in && ready_in) begin
            udp_header[63:48] <= src_port;
            udp_header[47:32] <= dst_port;
            udp_header[31:16] <= udp_length;
            udp_header[15:0]  <= 16'h0000; // checksum 0
            valid_out <= 1;
        end else if (valid_out && ready_out) begin
            valid_out <= 0;
        end
    end
end
*/
endmodule
