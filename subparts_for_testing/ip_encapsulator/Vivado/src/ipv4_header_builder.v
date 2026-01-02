`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------
// -- Company: KUL - Group T - RDMA Team
// -- Engineer: Tubi Soyer <tugberksoyer@gmail.com>
// -- 
// -- Create Date: 22/11/2025 12:09:11 PM
// -- Design Name: 
// -- Module Name: ipv4_header_builder
// -- Project Name: RDMA
// -- Target Devices: Kria KR260
// -- Tool Versions: 
// -- Description:
//      Build IPv4 header (20 bytes) and compute IPv4 header checksum (ones' complement).
//      Output format: ipv4_header[159:0] = {byte0, byte1, ..., byte19} MSB-first
//      byte0 = Version/IHL, byte1 = DSCP/ECN, bytes2..3 = Total Length, etc. 
// -- 
// -- Dependencies: 
// -- 
// -- Revision:
// -- Revision 0.01 - File Created
// -- Additional Comments:
// -- 
// -------------------------------------------------------------------------------
//////////////////////////////////////////////////////////////////////////////////

module ipv4_header_builder #(
    parameter TTL_DEFAULT = 8'd64,
    parameter PROTOCOL   = 8'd17    // UDP
)(
    input  wire         clk,
    input  wire         rstn,

    // Inputs (per-packet)
    input  wire [31:0]  src_ip,
    input  wire [31:0]  dst_ip,
    input  wire [15:0]  ip_total_length, // IP total length (header + payload)
    input  wire         valid_in,
    output reg          ready_in,

    // Outputs
    output reg  [159:0] ipv4_header,
    output reg  [15:0]  checksum_out,
    output reg          valid_out,
    input  wire         ready_out
);

    // Internal identification counter (wraps naturally)
    reg [15:0] id_counter;

    // Simple FSM: IDLE -> CAPTURE -> OUTPUT (hold until accepted)
    localparam ST_IDLE   = 2'd0;
    localparam ST_CAPTURE= 2'd1;
    localparam ST_OUT    = 2'd2;

    reg [1:0] state, next_state;

    // captured fields
    reg [31:0] src_ip_r;
    reg [31:0] dst_ip_r;
    reg [15:0] total_len_r;
    reg [7:0]  ttl_r;
    reg [7:0]  proto_r;
    reg [15:0] id_r;
    
    
    //------------------------------------------------------------------
    // Combinational Checksum Calculation Logic
    // Uses the registered input values (e.g., total_len_r)
    //------------------------------------------------------------------

    // Prepare 16-bit words for checksum (word[0] through word[9])
    // The Version/IHL word (w0) is set to 0x4500 (Version=4, IHL=5, DSCP/ECN=0)
    wire [15:0] w [0:9];

    assign w[0] = 16'h4500;                // Version=4,IHL=5 (0x45), DSCP/ECN=0x00
    assign w[1] = total_len_r;
    assign w[2] = id_r;
    assign w[3] = 16'h0000;                // flags(3)/frag offset(13) = 0
    assign w[4] = {ttl_r, proto_r};        // TTL and Protocol
    assign w[5] = 16'h0000;                // Header checksum (0 for calculation)
    assign w[6] = src_ip_r[31:16];
    assign w[7] = src_ip_r[15:0];
    assign w[8] = dst_ip_r[31:16];
    assign w[9] = dst_ip_r[15:0];

    // Combinational summation (32-bit width to avoid overflow)
    wire [31:0] sum_32bit = w[0] + w[1] + w[2] + w[3] + w[4] + w[5] + w[6] + w[7] + w[8] + w[9];
    
    // Checksum Folding: Add the upper 16 bits (carry) to the lower 16 bits.
    // This process must be repeated until the carry is 0.
    wire [16:0] sum_temp_1 = {1'b0, sum_32bit[15:0]} + {1'b0, sum_32bit[31:16]};
    wire [15:0] sum_final  = sum_temp_1[15:0] + {15'b0, sum_temp_1[16]}; // Add carry back

    // Final checksum is the one's complement of the folded sum
    wire [15:0] final_checksum_w = ~sum_final;


    //------------------------------------------------------------------
    // FSM Sequential Logic (Consolidated)
    // All registered outputs are driven ONLY in this block.
    //------------------------------------------------------------------
    always @(posedge clk) begin
        if (!rstn) begin
            state <= ST_IDLE;
            id_counter <= 16'h0000;
            ready_in <= 1'b1;
            valid_out <= 1'b0;
            ipv4_header <= 160'h0;
            checksum_out <= 16'h0;
        end else begin
            state <= next_state;

            case (state)
                ST_IDLE: begin
                    valid_out <= 1'b0;
                    ready_in <= 1'b1; // Ready for input
                    if (valid_in && ready_in) begin
                        // Capture inputs
                        src_ip_r <= src_ip;
                        dst_ip_r <= dst_ip;
                        total_len_r <= ip_total_length;
                        ttl_r <= TTL_DEFAULT;
                        proto_r <= PROTOCOL;
                        id_r <= id_counter;
                        id_counter <= id_counter + 1;
                        // ready_in de-asserted by default assignment above
                    end
                end

                ST_CAPTURE: begin
                    ready_in <= 1'b0;
                    // Calculation is done combinatorially (final_checksum_w) based on captured registers.
                    // When leaving this state (next_state == ST_OUT), register the outputs.
                    if (next_state == ST_OUT) begin
                        // Register final checksum and header
                        checksum_out <= final_checksum_w;
                        
                        // Build header in MSB-first order
                        ipv4_header <= {
                            8'h45,                       // byte 0 (Version/IHL)
                            8'h00,                       // byte 1 (DSCP/ECN)
                            total_len_r,                 // bytes 2-3 (Total length)
                            id_r,                        // bytes 4-5 (Identification)
                            16'h0000,                    // bytes 6-7 (Flags/FragmentOffset)
                            ttl_r,                       // byte 8 (TTL)
                            proto_r,                     // byte 9 (Protocol)
                            final_checksum_w,            // bytes 10-11 (Header Checksum)
                            src_ip_r,                    // bytes 12-15 (Src IP)
                            dst_ip_r                     // bytes 16-19 (Dst IP)
                        };

                        // Assert output valid
                        valid_out <= 1'b1;
                    end
                end

                ST_OUT: begin
                    ready_in <= 1'b0;
                    // Hold outputs and wait for ready_out
                    if (valid_out && ready_out) begin
                        // Downstream accepted data
                        valid_out <= 1'b0;
                    end
                end
                default: begin
                    ready_in <= 1'b0;
                    valid_out <= 1'b0;
                end
            endcase
        end
    end

    // Next-state logic (simple combinational block)
    always @(*) begin
        next_state = state;
        case (state)
            ST_IDLE: begin
                if (valid_in && ready_in) next_state = ST_CAPTURE;
            end
            ST_CAPTURE: begin
                // Move directly to output state after capturing inputs/preparing calculation
                next_state = ST_OUT;
            end
            ST_OUT: begin
                if (valid_out && ready_out) next_state = ST_IDLE;
            end
        endcase
    end

endmodule
