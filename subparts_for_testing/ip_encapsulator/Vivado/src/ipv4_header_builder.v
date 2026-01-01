// ipv4_header_builder.v
// Build IPv4 header (20 bytes) and compute IPv4 header checksum (ones' complement).
// Output format: ipv4_header[159:0] = {byte0, byte1, ..., byte19} MSB-first
// byte0 = Version/IHL, byte1 = DSCP/ECN, bytes2..3 = Total Length, etc.

`timescale 1ns / 1ps
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
    
    

//    // checksum calc regs
//    reg [31:0] sum;   // accumulator for sums of 16-bit words
//    integer i;

//    // Prepare 16-bit words for checksum (word[0] through word[9])
//    reg [15:0] words [0:9];

//    // FSM sequential
//    always @(posedge clk) begin
//        if (!rstn) begin
//            state <= ST_IDLE;
//            id_counter <= 16'h0000;
//            ready_in <= 1'b1;
//            valid_out <= 1'b0;
//            ipv4_header <= 160'h0;
//            checksum_out <= 16'h0;
//        end else begin
//            state <= next_state;

//            case (state)
//                ST_IDLE: begin
//                    valid_out <= 1'b0;
//                    if (valid_in && ready_in) begin
//                        // capture inputs
//                        src_ip_r <= src_ip;
//                        dst_ip_r <= dst_ip;
//                        total_len_r <= ip_total_length;
//                        ttl_r <= TTL_DEFAULT;
//                        proto_r <= PROTOCOL;
//                        id_r <= id_counter;
//                        id_counter <= id_counter + 1;
//                    end
//                end

//                ST_CAPTURE: begin
//                    // compute words for checksum (checksum field set to 0 here)
//                    // Word ordering follows IPv4 header 16-bit words:
//                    // w0 = Version/IHL + DSCP/ECN
//                    // w1 = Total Length
//                    // w2 = Identification
//                    // w3 = Flags/FragmentOffset
//                    // w4 = TTL/Protocol
//                    // w5 = Header checksum (0 for calculation)
//                    // w6 = Src IP high
//                    // w7 = Src IP low
//                    // w8 = Dst IP high
//                    // w9 = Dst IP low

//                    words[0] <= {4'b0100, 4'b0101, 8'h00}; // Version=4,IHL=5, DSCP/ECN = 0
//                    words[1] <= total_len_r;
//                    words[2] <= id_r;
//                    words[3] <= 16'h0000;                    // flags(3)/frag offset(13) = 0
//                    words[4] <= {ttl_r, proto_r};           // TTL and Protocol
//                    words[5] <= 16'h0000;                   // checksum field = 0 for calc
//                    words[6] <= src_ip_r[31:16];
//                    words[7] <= src_ip_r[15:0];
//                    words[8] <= dst_ip_r[31:16];
//                    words[9] <= dst_ip_r[15:0];

//                    // Sum all 10 words (32-bit accumulator)
//                    sum <= 32'd0;
//                    for (i = 0; i < 10; i = i + 1) begin
//                        sum <= sum + {16'd0, words[i]};
//                    end

//                    // After assigning sum above, move to compute stage next tick
//                end

//                ST_OUT: begin
//                    // nothing to capture here; wait until downstream accepts
//                    if (valid_out && ready_out) begin
//                        valid_out <= 1'b0;
//                    end
//                end
//            endcase
//        end
//    end

//    // Next-state logic (simple)
//    always @(*) begin
//        next_state = state;
//        case (state)
//            ST_IDLE: begin
//                if (valid_in && ready_in) next_state = ST_CAPTURE;
//            end
//            ST_CAPTURE: begin
//                // we perform the combinational folding in the same cycle after sum is formed
//                next_state = ST_OUT;
//            end
//            ST_OUT: begin
//                if (valid_out && ready_out) next_state = ST_IDLE;
//            end
//        endcase
//    end

//    // Combinational / sequential block to finalize checksum, build header and assert outputs.
//    // Use a small sequential block triggered when state == ST_CAPTURE -> ST_OUT transition.
//    reg capture_tick;
//    reg [31:0] sum_reg;

//    // capture_tick detection
//    reg state_d;
//    always @(posedge clk) begin
//        if (!rstn) begin
//            state_d <= ST_IDLE;
//            capture_tick <= 1'b0;
//            sum_reg <= 32'd0;
//        end else begin
//            state_d <= state;
//            capture_tick <= (state == ST_CAPTURE);
//            // latch the cumulative sum that was computed in the previous always block
//            sum_reg <= sum;
//        end
//    end

//    // Compute final checksum by folding carries and taking ones' complement, and build ipv4_header
//    reg [31:0] s;
//    always @(posedge clk) begin
//        if (!rstn) begin
//            ipv4_header <= 160'h0;
//            checksum_out <= 16'h0;
//            valid_out <= 1'b0;
//        end else begin
//            if (capture_tick) begin
//                // fold carries: note sum_reg may be greater than 16 bits; fold until fits 16 bits
//                s = sum_reg;
//                // first fold
//                s = (s[31:16] + s[15:0]);
//                // second fold (in case another carry)
//                s = (s[31:16] + s[15:0]);
//                // ones' complement
//                checksum_out <= ~s[15:0];

//                // Build header in MSB-first order:
//                // bytes:
//                // [0] Version/IHL (0x45)
//                // [1] DSCP/ECN (0x00)
//                // [2..3] Total length
//                // [4..5] Identification
//                // [6..7] Flags/FragmentOffset
//                // [8] TTL
//                // [9] Protocol
//                // [10..11] Header checksum
//                // [12..15] Src IP
//                // [16..19] Dst IP

//                ipv4_header <= {
//                    8'h45,                       // byte 0
//                    8'h00,                       // byte 1 (DSCP/ECN)
//                    total_len_r,                 // bytes 2-3
//                    id_r,                        // bytes 4-5
//                    16'h0000,                    // bytes 6-7 flags/frag
//                    ttl_r,                       // byte 8
//                    proto_r,                     // byte 9
//                    ~s[15:0],                    // bytes 10-11 (checksum)
//                    src_ip_r,                    // bytes 12-15
//                    dst_ip_r                     // bytes 16-19
//                };

//                // assert valid_out and wait for ready_out; ready_in should be deasserted while output not accepted
//                valid_out <= 1'b1;
//                ready_in <= 1'b0;
//            end else begin
//                // Once output accepted, clear and allow new captures
//                if (valid_out && ready_out) begin
//                    valid_out <= 1'b0;
//                    ready_in <= 1'b1;
//                end
//            end
//        end
//    end


endmodule
