`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------
// -- Company: KUL - Group T - RDMA Team
// -- Engineer: Tubi Soyer <tugberksoyer@gmail.com>
// -- 
// -- Create Date: 22/11/2025 12:09:11 PM
// -- Design Name: 
// -- Module Name: endpoint_lookup
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

module endpoint_lookup #(
    parameter ADDR_WIDTH = 11,             // supports 256 entries by default
    parameter BRAM_DATA_WIDTH = 256       // must be >= 160
)(
    input  wire                    clk,
    input  wire                    rstn,           // active-high reset deasserted = 1

    // Lookup interface
    input  wire [31:0]             dst_ip,         // requested destination IP
    input  wire                    lookup_valid,   // pulse when a lookup is requested
    output reg                     lookup_ready,   // high when module can accept lookup
    output reg                     lookup_done,    // pulse when result ready
    output reg                     lookup_hit,     // 1 = found match
    output reg                     lookup_error,   // 1 = miss or invalid entry

    // MAC outputs (valid when lookup_done pulses)
    output reg  [47:0]             dst_mac,
    output reg  [47:0]             src_mac,

    // BRAM Port B signals (synchronous read port)
    output reg  [ADDR_WIDTH-1:0]   bram_addr_b,
    output reg                     bram_en_b,
    input  wire [BRAM_DATA_WIDTH-1:0] bram_dout_b
);

// Ensure BRAM data width is enough
initial begin
    if (BRAM_DATA_WIDTH < 160) begin
        $display("ERROR: BRAM_DATA_WIDTH (%0d) must be >= 160", BRAM_DATA_WIDTH);
        $finish;
    end
end

// Field bit positions (MSB-first)
localparam integer BIT_ENTRY_VALID = BRAM_DATA_WIDTH - 1;
localparam integer BIT_DST_IP_MSB  = BRAM_DATA_WIDTH - 33;
localparam integer BIT_DST_IP_LSB  = BRAM_DATA_WIDTH - 64;
localparam integer BIT_DST_MAC_MSB = BRAM_DATA_WIDTH - 65;
localparam integer BIT_DST_MAC_LSB = BRAM_DATA_WIDTH - 112;
localparam integer BIT_SRC_MAC_MSB = BRAM_DATA_WIDTH - 113;
localparam integer BIT_SRC_MAC_LSB = BRAM_DATA_WIDTH - 160;


// FSM states
localparam [1:0] S_IDLE     = 2'd0;
localparam [1:0] S_BRAM_REQ = 2'd1;
localparam [1:0] S_BRAM_DOUT= 2'd2;
localparam [1:0] S_RESP     = 2'd3;

reg [1:0] state, state_n;
reg [ADDR_WIDTH-1:0] index_reg;
reg [31:0] req_ip;

// Simple index/hash: XOR of low ADDR_WIDTH bits and some higher bits for mixing
wire [ADDR_WIDTH-1:0] computed_index;
assign computed_index = dst_ip[ADDR_WIDTH-1:0] ^ dst_ip[ADDR_WIDTH+7:8];

/*
// --- DEDICATED HASH CALCULATION BLOCK ---
reg [ADDR_WIDTH-1:0] computed_index;

always @(*) begin
    // Hash: dst_ip[3:0] XOR dst_ip[11:8]
    computed_index = dst_ip[3:0] ^ dst_ip[11:8];
end
// --- END HASH BLOCK ---
*/

// Sequential FSM & outputs
always @(posedge clk) begin
    if (!rstn) begin
        state       <= S_IDLE;
        bram_en_b   <= 1'b0;
        bram_addr_b <= {ADDR_WIDTH{1'b0}};
        lookup_ready<= 1'b1;
        lookup_done <= 1'b0;
        lookup_hit  <= 1'b0;
        lookup_error<= 1'b0;
        dst_mac     <= 48'd0;
        src_mac     <= 48'd0;
        req_ip      <= 32'd0;
        index_reg   <= {ADDR_WIDTH{1'b0}};
    end else begin
        // default clear pulses
        lookup_done <= 1'b0;
        lookup_hit  <= 1'b0;
        lookup_error<= 1'b0;

        state <= state_n;

        case (state)
            S_IDLE: begin
                bram_en_b <= 1'b0;
                lookup_ready <= 1'b1;
                if (lookup_valid && lookup_ready) begin
                    // capture request and compute index for BRAM
                    req_ip <= dst_ip;
                    index_reg <= computed_index;
                    lookup_ready <= 1'b0;
                    // transition handled by next_state logic
                end
            end

            S_BRAM_REQ: begin
                lookup_ready <= 1'b0;
                // issue BRAM synchronous read (data will appear next cycle)
                bram_addr_b <= index_reg;
                bram_en_b <= 1'b1;
            end

            S_BRAM_DOUT: begin
                lookup_ready <= 1'b0;
                // deassert en (single-cycle pulse) and evaluate bram_dout_b
                bram_en_b <= 1'b0;

                // Extract fields from bram_dout_b (MSB-first)
                // Use local regs to hold extracted values
                // Note: synthesis tools allow slicing of vector
                if (bram_dout_b[BIT_ENTRY_VALID]) begin
                    // stored IP, dst_mac, src_mac
                    // compare stored IP to requested IP
                    if (bram_dout_b[BIT_DST_IP_MSB:BIT_DST_IP_LSB] == req_ip) begin
                        dst_mac <= bram_dout_b[BIT_DST_MAC_MSB:BIT_DST_MAC_LSB];
                        src_mac <= bram_dout_b[BIT_SRC_MAC_MSB:BIT_SRC_MAC_LSB];
                        lookup_hit <= 1'b1;
                        lookup_error <= 1'b0;
                    end else begin
                        dst_mac <= 48'd0;
                        src_mac <= 48'd0;
                        lookup_hit <= 1'b0;
                        lookup_error <= 1'b1; // stored entry does not match (hash collision) => miss
                    end
                end else begin
                    dst_mac <= 48'd0;
                    src_mac <= 48'd0;
                    lookup_hit <= 1'b0;
                    lookup_error <= 1'b1; // entry invalid
                end
                lookup_done <= 1'b1;
            end

            S_RESP: begin
                lookup_ready <= 1'b0;
                // nothing special: outputs were already latched in previous state
            end

            default: begin
                lookup_ready <= 1'b0;
                // shouldn't happen
            end
        endcase
    end
end

// Combinational next-state logic
always @(*) begin
    state_n = state;
    case (state)
        S_IDLE: begin
            if (lookup_valid && lookup_ready) state_n = S_BRAM_REQ;
            else state_n = S_IDLE;
        end
        S_BRAM_REQ: begin
            state_n = S_BRAM_DOUT; // wait for bram_dout next cycle
        end
        S_BRAM_DOUT: begin
            state_n = S_RESP;
        end
        S_RESP: begin
            state_n = S_IDLE;
        end
        default: state_n = S_IDLE;
    endcase
end

endmodule
