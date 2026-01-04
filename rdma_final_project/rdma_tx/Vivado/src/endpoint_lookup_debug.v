`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// ------------------------------------------------------------------------------
// -- Company: KUL - Group T - RDMA Team
// -- Engineer: Tubi Soyer <tugberksoyer@gmail.com>
// -- 
// -- Create Date: 22/11/2025 12:09:11 PM
// -- Design Name: 
// -- Module Name: endpoint_lookup_debug
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

module endpoint_lookup_debug (
    input  wire         clk,
    input  wire         rstn,


    // Lookup Interface
    input  wire [31:0]  dst_ip,        // Unused in this simple version
    input  wire         lookup_valid,
    output reg          lookup_ready,
    output reg          lookup_done,
    output reg          lookup_hit,
    output reg          lookup_error,
    output reg [47:0]   dst_mac,
    output reg [47:0]   src_mac,

    // BRAM Port B Interface (Connect to Block Memory Generator Port B)
    output reg          bram_en,
    output reg [3:0]    bram_we,       // Write Enable (0 for reading)
    output reg [31:0]   bram_addr,
    output reg [31:0]   bram_din,      // Unused (we only read)
    input  wire [31:0]  bram_dout
);

    // State Machine
    localparam [2:0] S_IDLE       = 3'd0;
    localparam [2:0] S_READ_SRC_L = 3'd1;
    localparam [2:0] S_READ_SRC_H = 3'd2;
    localparam [2:0] S_READ_DST_L = 3'd3;
    localparam [2:0] S_READ_DST_H = 3'd4;
    localparam [2:0] S_DONE       = 3'd5;

    reg [2:0] state;

    // Temporary storage
    reg [31:0] src_mac_low;
    reg [31:0] dst_mac_low;

    // BRAM Read Latency is typically 2 cycles in Block Designs
    // Cycle 1: Address presented
    // Cycle 2: Data available

    always @(posedge clk) begin
        if (!rstn) begin
            state        <= S_IDLE;
            lookup_ready <= 1'b0;
            lookup_done  <= 1'b0;
            lookup_hit   <= 1'b0;
            lookup_error <= 1'b0;
            dst_mac      <= 48'h0;
            src_mac      <= 48'h0;
            
            bram_en      <= 1'b0;
            bram_we      <= 4'b0000;
            bram_addr    <= 32'b0;
            bram_din     <= 32'b0;
        end else begin
            // Default signals
            lookup_done <= 1'b0;
            bram_en     <= 1'b0; // Default disable to save power
            bram_we     <= 4'b0; // Never write

            case (state)
                S_IDLE: begin
                    lookup_ready <= 1'b1;
                    if (lookup_valid) begin
                        lookup_ready <= 1'b0;
                        
                        // Start Read 1: SRC MAC LOW (Offset 0x0)
                        bram_en   <= 1'b1;
                        bram_addr <= 32'd0; 
                        state     <= S_READ_SRC_L;
                    end
                end

                S_READ_SRC_L: begin
                    // Pipeline wait. Prepare Read 2: SRC MAC HIGH (Offset 0x4)
                    bram_en   <= 1'b1;
                    bram_addr <= 32'd4;
                    state     <= S_READ_SRC_H;
                end

                S_READ_SRC_H: begin
                    // Capture Read 1 Data (SRC Low)
                    src_mac_low <= bram_dout;

                    // Prepare Read 3: DST MAC LOW (Offset 0x8)
                    bram_en   <= 1'b1;
                    bram_addr <= 32'd8;
                    state     <= S_READ_DST_L;
                end

                S_READ_DST_L: begin
                    // Capture Read 2 Data (SRC High) -> Complete SRC MAC
                    src_mac <= {bram_dout[15:0], src_mac_low};

                    // Prepare Read 4: DST MAC HIGH (Offset 0xC)
                    bram_en   <= 1'b1;
                    bram_addr <= 32'd12;
                    state     <= S_READ_DST_H;
                end

                S_READ_DST_H: begin
                    // Capture Read 3 Data (DST Low)
                    dst_mac_low <= bram_dout;
                    
                    // No new read to prepare
                    state <= S_DONE;
                end

                S_DONE: begin
                    // Capture Read 4 Data (DST High) -> Complete DST MAC
                    dst_mac <= {bram_dout[15:0], dst_mac_low};

                    // Finish handshake
                    lookup_done  <= 1'b1;
                    lookup_hit   <= 1'b1; // Always hit in this mode
                    lookup_error <= 1'b0;
                    
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule