`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// axi_lite_regs.v -- Fixed AXI4-Lite slave for IP encapsulator registers
//
// Features:
//  - Robust AW/W/B handshake (no deadlock if AW and W arrive in any order)
//  - Read address handshake and read data handshake
//  - Byte-strobe aware writes
//  - Sticky lookup_error, irq_pending, clear_counters pulse
//  - Exposes control/status, pkt/byte counters, bram base/size, queue doorbells
//
// Note: compare with your original version and replace in BD. Ensure clocks/resets
// are connected and the Address Editor uses the same offsets as defined here.
//
// Uploaded block diagram for reference:
// file:///mnt/data/A_block_diagram_in_the_digital_illustration_depict.png
//////////////////////////////////////////////////////////////////////////////////

module axi_lite_regs #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  wire                    clk,
    input  wire                    rstn,            // active-high reset (1 = not reset)

    // AXI4-Lite slave interface
    input  wire [ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  wire                    s_axi_awvalid,
    output reg                     s_axi_awready,
    input  wire [DATA_WIDTH-1:0]   s_axi_wdata,
    input  wire [DATA_WIDTH/8-1:0] s_axi_wstrb,
    input  wire                    s_axi_wvalid,
    output reg                     s_axi_wready,
    output reg [1:0]               s_axi_bresp,
    output reg                     s_axi_bvalid,
    input  wire                    s_axi_bready,

    input  wire [ADDR_WIDTH-1:0]   s_axi_araddr,
    input  wire                    s_axi_arvalid,
    output reg                     s_axi_arready,
    output reg [DATA_WIDTH-1:0]    s_axi_rdata,
    output reg [1:0]               s_axi_rresp,
    output reg                     s_axi_rvalid,
    input  wire                    s_axi_rready,

    // User signals (from design)
    input  wire [63:0]             pkt_count_in,
    input  wire [63:0]             byte_count_in,
    input  wire                    lookup_error_in,
    input  wire                    irq_req_in,
    output wire                    irq_out,

    // control outputs
    output reg                     enable_out,
    output reg                     loopback_out,
    output reg                     clear_counters_out,

    // BRAM base/size
    output reg [31:0]              bram_base_out,
    output reg [31:0]              bram_size_out,

    // doorbells / queue regs
    output reg [31:0]              sq_head_out,
    output reg [31:0]              sq_tail_out,
    output reg [31:0]              cq_head_out,
    output reg [31:0]              cq_tail_out
);

    // ---------------- register address map (lower byte) ----------------
    localparam REG_CONTROL   = 8'h00;
    localparam REG_STATUS    = 8'h04;
    localparam REG_PKT_LO    = 8'h10;
    localparam REG_PKT_HI    = 8'h14;
    localparam REG_BYTE_LO   = 8'h18;
    localparam REG_BYTE_HI   = 8'h1C;
    localparam REG_BRAM_BASE = 8'h20;
    localparam REG_BRAM_SIZE = 8'h24;
    localparam REG_SQ_HEAD   = 8'h30;
    localparam REG_SQ_TAIL   = 8'h34;
    localparam REG_CQ_HEAD   = 8'h38;
    localparam REG_CQ_TAIL   = 8'h3C;
    localparam REG_IRQ_ACK   = 8'h40;

    // control bits
    // CONTROL[0] = enable
    // CONTROL[1] = loopback
    // CONTROL[2] = clear_counters (write 1 to pulse)
    // CONTROL[3] = irq_enable
    reg [31:0] reg_control;

    // status (bit0 ready, bit1 lookup_error, bit2 irq_pending)
    reg lookup_error_sticky;
    reg irq_pending;

    // write state: latch address and data in any order; commit when both present
    reg [ADDR_WIDTH-1:0] awaddr_latched;
    reg                 aw_flag;    // aw received
    reg [DATA_WIDTH-1:0] wdata_latched;
    reg [DATA_WIDTH/8-1:0] wstrb_latched;
    reg                 w_flag;     // w received

    // local write_burst in progress indicator (marks that BVALID needs to be issued)
    reg write_in_progress;

    // ---------------- Reset / initial values ----------------
    integer i;
    always @(posedge clk) begin
        if (!rstn) begin
            // AXI signals
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00;
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= 2'b00;
            s_axi_rdata   <= {DATA_WIDTH{1'b0}};

            // internal regs
            reg_control <= 32'h0;
            bram_base_out <= 32'h0;
            bram_size_out <= 32'h0;
            sq_head_out <= 32'h0;
            sq_tail_out <= 32'h0;
            cq_head_out <= 32'h0;
            cq_tail_out <= 32'h0;
            clear_counters_out <= 1'b0;
            lookup_error_sticky <= 1'b0;
            irq_pending <= 1'b0;

            awaddr_latched <= {ADDR_WIDTH{1'b0}};
            aw_flag <= 1'b0;
            wdata_latched <= {DATA_WIDTH{1'b0}};
            wstrb_latched <= {DATA_WIDTH/8{1'b0}};
            w_flag <= 1'b0;
            write_in_progress <= 1'b0;

            enable_out <= 1'b0;
            loopback_out <= 1'b0;
        end else begin
            // default pulse-clear of clear_counters_out
            clear_counters_out <= 1'b0;

            // ------------ AW channel latch ------------
            // Accept AW when awvalid asserted and we are ready to accept a new addr.
            if (~aw_flag && ~s_axi_awready && s_axi_awvalid) begin
                s_axi_awready <= 1'b1;
                awaddr_latched <= s_axi_awaddr;
                aw_flag <= 1'b1;
            end else begin
                // clear AWREADY once accepted (one-cycle pulse)
                if (s_axi_awready)
                    s_axi_awready <= 1'b0;
            end

            // ------------ W channel latch ------------
            if (~w_flag && ~s_axi_wready && s_axi_wvalid) begin
                s_axi_wready <= 1'b1;
                wdata_latched <= s_axi_wdata;
                wstrb_latched <= s_axi_wstrb;
                w_flag <= 1'b1;
            end else begin
                if (s_axi_wready)
                    s_axi_wready <= 1'b0;
            end

            // ------------ Write commit: when both AW and W have arrived and no write_in_progress ------------
            if (aw_flag && w_flag && ~write_in_progress) begin
                // commit write to registers using awaddr_latched[7:0] as decode
                write_in_progress <= 1'b1; // indicate we'll create BVALID after commit

                case (awaddr_latched[7:0])
                    REG_CONTROL: begin
                        // apply byte enables
                        if (wstrb_latched[0]) reg_control[7:0]   <= wdata_latched[7:0];
                        if (wstrb_latched[1]) reg_control[15:8]  <= wdata_latched[15:8];
                        if (wstrb_latched[2]) reg_control[23:16] <= wdata_latched[23:16];
                        if (wstrb_latched[3]) reg_control[31:24] <= wdata_latched[31:24];

                        // update outputs according to written bits
                        if (wstrb_latched != 0) begin
                            enable_out <= wdata_latched[0];
                            loopback_out <= wdata_latched[1];
                            if (wdata_latched[2]) clear_counters_out <= 1'b1;
                            // irq_enable stored in reg_control[3] (already written above)
                        end
                    end

                    REG_BRAM_BASE: begin
                        if (wstrb_latched[0]) bram_base_out[7:0]  <= wdata_latched[7:0];
                        if (wstrb_latched[1]) bram_base_out[15:8] <= wdata_latched[15:8];
                        if (wstrb_latched[2]) bram_base_out[23:16] <= wdata_latched[23:16];
                        if (wstrb_latched[3]) bram_base_out[31:24] <= wdata_latched[31:24];
                    end

                    REG_BRAM_SIZE: begin
                        if (wstrb_latched[0]) bram_size_out[7:0]  <= wdata_latched[7:0];
                        if (wstrb_latched[1]) bram_size_out[15:8] <= wdata_latched[15:8];
                        if (wstrb_latched[2]) bram_size_out[23:16] <= wdata_latched[23:16];
                        if (wstrb_latched[3]) bram_size_out[31:24] <= wdata_latched[31:24];
                    end

                    REG_SQ_HEAD: begin
                        if (wstrb_latched[0]) sq_head_out[7:0]   <= wdata_latched[7:0];
                        if (wstrb_latched[1]) sq_head_out[15:8]  <= wdata_latched[15:8];
                        if (wstrb_latched[2]) sq_head_out[23:16] <= wdata_latched[23:16];
                        if (wstrb_latched[3]) sq_head_out[31:24] <= wdata_latched[31:24];
                    end

                    REG_SQ_TAIL: begin
                        if (wstrb_latched[0]) sq_tail_out[7:0]   <= wdata_latched[7:0];
                        if (wstrb_latched[1]) sq_tail_out[15:8]  <= wdata_latched[15:8];
                        if (wstrb_latched[2]) sq_tail_out[23:16] <= wdata_latched[23:16];
                        if (wstrb_latched[3]) sq_tail_out[31:24] <= wdata_latched[31:24];
                    end

                    REG_CQ_HEAD: begin
                        if (wstrb_latched[0]) cq_head_out[7:0]   <= wdata_latched[7:0];
                        if (wstrb_latched[1]) cq_head_out[15:8]  <= wdata_latched[15:8];
                        if (wstrb_latched[2]) cq_head_out[23:16] <= wdata_latched[23:16];
                        if (wstrb_latched[3]) cq_head_out[31:24] <= wdata_latched[31:24];
                    end

                    REG_CQ_TAIL: begin
                        if (wstrb_latched[0]) cq_tail_out[7:0]   <= wdata_latched[7:0];
                        if (wstrb_latched[1]) cq_tail_out[15:8]  <= wdata_latched[15:8];
                        if (wstrb_latched[2]) cq_tail_out[23:16] <= wdata_latched[23:16];
                        if (wstrb_latched[3]) cq_tail_out[31:24] <= wdata_latched[31:24];
                    end

                    REG_IRQ_ACK: begin
                        // any non-zero write clears pending IRQ
                        if (wdata_latched != 32'h0) irq_pending <= 1'b0;
                    end

                    default: begin
                        // ignore writes to unmapped offsets
                    end
                endcase

                // After commit, present write response on next cycles
                s_axi_bvalid <= 1'b1;
                s_axi_bresp  <= 2'b00; // OKAY

                // clear flags so a new AW/W pair can be collected
                aw_flag <= 1'b0;
                w_flag  <= 1'b0;
            end else begin
                // If BVALID & BREADY, complete the handshake and clear write_in_progress
                if (s_axi_bvalid && s_axi_bready) begin
                    s_axi_bvalid <= 1'b0;
                    write_in_progress <= 1'b0;
                end
            end

            // ---------------- Update sticky flags from inputs ----------------
            if (lookup_error_in) lookup_error_sticky <= 1'b1;
            if (irq_req_in)     irq_pending <= 1'b1;

            // Keep enable/loopback outputs stable otherwise (they are updated when control is written)
            enable_out <= enable_out;
            loopback_out <= loopback_out;
        end
    end

    // ---------------- Read channel: AR handshake + RRESP/RDATA ----------------
    always @(posedge clk) begin
        if (!rstn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= 2'b00;
            s_axi_rdata   <= {DATA_WIDTH{1'b0}};
        end else begin
            if (~s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1'b1;
                // perform combinational read decode; latch read data
                case (s_axi_araddr[7:0])
                    REG_CONTROL: begin
                        s_axi_rdata <= reg_control;
                    end
                    REG_STATUS: begin
                        // build status: [31:3]=0, [2]=irq_pending, [1]=lookup_error_sticky, [0]=1 (ready)
                        s_axi_rdata <= {29'h0, irq_pending ? 1'b1 : 1'b0, lookup_error_sticky ? 1'b1 : 1'b0, 1'b1};
                    end
                    REG_PKT_LO:  s_axi_rdata <= pkt_count_in[31:0];
                    REG_PKT_HI:  s_axi_rdata <= pkt_count_in[63:32];
                    REG_BYTE_LO: s_axi_rdata <= byte_count_in[31:0];
                    REG_BYTE_HI: s_axi_rdata <= byte_count_in[63:32];
                    REG_BRAM_BASE: s_axi_rdata <= bram_base_out;
                    REG_BRAM_SIZE: s_axi_rdata <= bram_size_out;
                    REG_SQ_HEAD:  s_axi_rdata <= sq_head_out;
                    REG_SQ_TAIL:  s_axi_rdata <= sq_tail_out;
                    REG_CQ_HEAD:  s_axi_rdata <= cq_head_out;
                    REG_CQ_TAIL:  s_axi_rdata <= cq_tail_out;
                    REG_IRQ_ACK:  s_axi_rdata <= irq_pending ? 32'h1 : 32'h0;
                    default:      s_axi_rdata <= 32'h0;
                endcase
                s_axi_rvalid <= 1'b1;
                s_axi_rresp  <= 2'b00; // OKAY
            end else begin
                // clear ARREADY after one cycle
                if (s_axi_arready)
                    s_axi_arready <= 1'b0;

                // finish read when master accepts data
                if (s_axi_rvalid && s_axi_rready) begin
                    s_axi_rvalid <= 1'b0;
                    s_axi_rresp  <= 2'b00;
                end
            end
        end
    end

    // irq output (gated by reg_control[3] = irq_enable)
    assign irq_out = irq_pending & reg_control[3];

endmodule





/*
`timescale 1ns / 1ps
// axi_lite_regs.v
// Simple AXI4-Lite slave with register map for control, status, counters, BRAM base, doorbells.
//
// Notes:
// - 32-bit AXI-Lite.
// - Write strobes supported.
// - clear_counters_out pulses high for one cycle when CONTROL.clear_counters is written.
// - irq_out asserted when irq_req_in asserted AND CONTROL.irq_enable set.
// - lookup_error_in is sticky into STATUS until cleared by writing STATUS_CLEAR bit (not implemented separately here).
//

module axi_lite_regs #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  wire                    clk,
    input  wire                    rstn,            // active-high reset deasserted = 1

    // AXI4-Lite slave interface
    input  wire [ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  wire                    s_axi_awvalid,
    output reg                     s_axi_awready,
    input  wire [DATA_WIDTH-1:0]   s_axi_wdata,
    input  wire [DATA_WIDTH/8-1:0] s_axi_wstrb,
    input  wire                    s_axi_wvalid,
    output reg                     s_axi_wready,
    output reg [1:0]               s_axi_bresp,
    output reg                     s_axi_bvalid,
    input  wire                    s_axi_bready,

    input  wire [ADDR_WIDTH-1:0]   s_axi_araddr,
    input  wire                    s_axi_arvalid,
    output reg                     s_axi_arready,
    output reg [DATA_WIDTH-1:0]    s_axi_rdata,
    output reg [1:0]               s_axi_rresp,
    output reg                     s_axi_rvalid,
    input  wire                    s_axi_rready,

    // User signals (connect to your design)
    input  wire [63:0]             pkt_count_in,     // sampleable counters
    input  wire [63:0]             byte_count_in,
    input  wire                    lookup_error_in,  // source of lookup errors (sticky)
    input  wire                    irq_req_in,       // HW requests IRQ
    output wire                    irq_out,          // to PS fabric IRQ or interrupt controller

    // control outputs
    output reg                     enable_out,
    output reg                     loopback_out,
    output reg                     clear_counters_out,

    // BRAM base/size
    output reg [31:0]              bram_base_out,
    output reg [31:0]              bram_size_out,

    // doorbells / queue regs
    output reg [31:0]              sq_head_out,
    output reg [31:0]              sq_tail_out,
    output reg [31:0]              cq_head_out,
    output reg [31:0]              cq_tail_out
);

// --------------- internal reg file ----------------
localparam REG_CONTROL      = 8'h00;
localparam REG_STATUS       = 8'h04;
localparam REG_PKT_LO       = 8'h10;
localparam REG_PKT_HI       = 8'h14;
localparam REG_BYTE_LO      = 8'h18;
localparam REG_BYTE_HI      = 8'h1C;
localparam REG_BRAM_BASE    = 8'h20;
localparam REG_BRAM_SIZE    = 8'h24;
localparam REG_SQ_HEAD      = 8'h30;
localparam REG_SQ_TAIL      = 8'h34;
localparam REG_CQ_HEAD      = 8'h38;
localparam REG_CQ_TAIL      = 8'h3C;
localparam REG_IRQ_ACK      = 8'h40;

// control bits
// CONTROL[0] = enable
// CONTROL[1] = loopback
// CONTROL[2] = clear_counters (write 1 to pulse)
// CONTROL[3] = irq_enable
reg [31:0] reg_control;

// status bits (read-only, reg_status reflects sticky error)
reg [31:0] reg_status; // bit0 ready, bit1 lookup_error, bit2 irq_pending

// internal sticky flags
reg lookup_error_sticky;
reg irq_pending;

// AXI write address latch
reg [ADDR_WIDTH-1:0] awaddr_latched;
reg aw_en;

// Simple write handshake
always @(posedge clk) begin
    if (!rstn) begin
        s_axi_awready <= 1'b0;
        aw_en <= 1'b1;
    end else begin
        if (~s_axi_awready & s_axi_awvalid & aw_en) begin
            // accept address
            s_axi_awready <= 1'b1;
            awaddr_latched <= s_axi_awaddr;
            aw_en <= 1'b0;
        end else if (s_axi_wvalid & s_axi_awready) begin
            // transfer will happen in write_data block
            s_axi_awready <= 1'b0;
        end else if (s_axi_bready & s_axi_bvalid) begin
            aw_en <= 1'b1; // ready for next write
        end else begin
            s_axi_awready <= 1'b0;
        end
    end
end

// Write data handling
always @(posedge clk) begin
    if (!rstn) begin
        s_axi_wready <= 1'b0;
        s_axi_bvalid <= 1'b0;
        s_axi_bresp <= 2'b00;
        // default regs
        reg_control <= 32'h0;
        bram_base_out <= 32'h0;
        bram_size_out <= 32'h0;
        sq_head_out <= 32'h0;
        sq_tail_out <= 32'h0;
        cq_head_out <= 32'h0;
        cq_tail_out <= 32'h0;
        clear_counters_out <= 1'b0;
        lookup_error_sticky <= 1'b0;
        irq_pending <= 1'b0;
    end else begin
        clear_counters_out <= 1'b0; // pulse only when written below
        // default: lower RESP/valid after write ack
        if (~s_axi_wready & s_axi_wvalid & ~s_axi_bvalid) begin
            // accept write data
            s_axi_wready <= 1'b1;
        end

        if (s_axi_wready & s_axi_wvalid) begin
            // perform write to register selected by awaddr_latched
            // only use lower 32-bit address bits for decode
            case (awaddr_latched[7:0])
                REG_CONTROL: begin
                    // apply wstrb
                    // write byte-enable aware
                    if (s_axi_wstrb[0]) reg_control[7:0]   <= s_axi_wdata[7:0];
                    if (s_axi_wstrb[1]) reg_control[15:8]  <= s_axi_wdata[15:8];
                    if (s_axi_wstrb[2]) reg_control[23:16] <= s_axi_wdata[23:16];
                    if (s_axi_wstrb[3]) reg_control[31:24] <= s_axi_wdata[31:24];

                    // update outputs tied to control bits
                    enable_out <= s_axi_wdata[0];
                    loopback_out <= s_axi_wdata[1];
                    // clear_counters should pulse when software writes 1 to bit 2
                    if (s_axi_wdata[2]) clear_counters_out <= 1'b1;
                    // irq_enable stored in reg_control bit3
                end

                REG_BRAM_BASE: begin
                    // BRAM base register
                    if (s_axi_wstrb[0]) bram_base_out[7:0] <= s_axi_wdata[7:0];
                    if (s_axi_wstrb[1]) bram_base_out[15:8] <= s_axi_wdata[15:8];
                    if (s_axi_wstrb[2]) bram_base_out[23:16] <= s_axi_wdata[23:16];
                    if (s_axi_wstrb[3]) bram_base_out[31:24] <= s_axi_wdata[31:24];
                end

                REG_BRAM_SIZE: begin
                    if (s_axi_wstrb[0]) bram_size_out[7:0] <= s_axi_wdata[7:0];
                    if (s_axi_wstrb[1]) bram_size_out[15:8] <= s_axi_wdata[15:8];
                    if (s_axi_wstrb[2]) bram_size_out[23:16] <= s_axi_wdata[23:16];
                    if (s_axi_wstrb[3]) bram_size_out[31:24] <= s_axi_wdata[31:24];
                end

                REG_SQ_HEAD: begin
                    if (s_axi_wstrb[0]) sq_head_out[7:0] <= s_axi_wdata[7:0];
                    if (s_axi_wstrb[1]) sq_head_out[15:8] <= s_axi_wdata[15:8];
                    if (s_axi_wstrb[2]) sq_head_out[23:16] <= s_axi_wdata[23:16];
                    if (s_axi_wstrb[3]) sq_head_out[31:24] <= s_axi_wdata[31:24];
                end

                REG_SQ_TAIL: begin
                    if (s_axi_wstrb[0]) sq_tail_out[7:0] <= s_axi_wdata[7:0];
                    if (s_axi_wstrb[1]) sq_tail_out[15:8] <= s_axi_wdata[15:8];
                    if (s_axi_wstrb[2]) sq_tail_out[23:16] <= s_axi_wdata[23:16];
                    if (s_axi_wstrb[3]) sq_tail_out[31:24] <= s_axi_wdata[31:24];
                end

                REG_CQ_HEAD: begin
                    if (s_axi_wstrb[0]) cq_head_out[7:0] <= s_axi_wdata[7:0];
                    if (s_axi_wstrb[1]) cq_head_out[15:8] <= s_axi_wdata[15:8];
                    if (s_axi_wstrb[2]) cq_head_out[23:16] <= s_axi_wdata[23:16];
                    if (s_axi_wstrb[3]) cq_head_out[31:24] <= s_axi_wdata[31:24];
                end

                REG_CQ_TAIL: begin
                    if (s_axi_wstrb[0]) cq_tail_out[7:0] <= s_axi_wdata[7:0];
                    if (s_axi_wstrb[1]) cq_tail_out[15:8] <= s_axi_wdata[15:8];
                    if (s_axi_wstrb[2]) cq_tail_out[23:16] <= s_axi_wdata[23:16];
                    if (s_axi_wstrb[3]) cq_tail_out[31:24] <= s_axi_wdata[31:24];
                end

                REG_IRQ_ACK: begin
                    // writing any non-zero value clears pending IRQ
                    if (s_axi_wdata != 32'h0) irq_pending <= 1'b0;
                end

                default: begin
                    // ignore writes to other addresses
                end
            endcase

            // provide write response
            s_axi_bvalid <= 1'b1;
            s_axi_bresp <= 2'b00; // OKAY
            s_axi_wready <= 1'b0;
        end else begin
            // clear write handshake when CPU reads bready
            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
                s_axi_wready <= 1'b0;
            end else begin
                s_axi_wready <= 1'b0;
            end
        end

        // update reg_control[3] (irq_enable) stored persistently
        // We set enable_out and loopback_out as well already when written
        // reflect reg_control bits
        reg_control[3] <= reg_control[3]; // no-op to satisfy liveness, actual stored above

        // update sticky lookup error if input asserts
        if (lookup_error_in) lookup_error_sticky <= 1'b1;

        // update irq pending when IRQ request comes in
        if (irq_req_in) irq_pending <= 1'b1;

    end
end

// Read address handshake
always @(posedge clk) begin
    if (!rstn) begin
        s_axi_arready <= 1'b0;
        s_axi_rvalid <= 1'b0;
        s_axi_rresp <= 2'b00;
        s_axi_rdata <= 32'h0;
    end else begin
        if (~s_axi_arready & s_axi_arvalid) begin
            s_axi_arready <= 1'b1;
            // latch and perform read combinationally below
            case (s_axi_araddr[7:0])
                REG_CONTROL: begin
                    s_axi_rdata <= reg_control;
                end
                REG_STATUS: begin
                    // bit0 ready = 1 if design enabled (for example)
                    // bit1 lookup_error_sticky
                    // bit2 irq_pending
                    s_axi_rdata <= {29'h0, irq_pending ? 1'b1 : 1'b0, lookup_error_sticky ? 1'b1 : 1'b0, 1'b1};
                end
                REG_PKT_LO: begin
                    s_axi_rdata <= pkt_count_in[31:0];
                end
                REG_PKT_HI: begin
                    s_axi_rdata <= pkt_count_in[63:32];
                end
                REG_BYTE_LO: begin
                    s_axi_rdata <= byte_count_in[31:0];
                end
                REG_BYTE_HI: begin
                    s_axi_rdata <= byte_count_in[63:32];
                end
                REG_BRAM_BASE: begin
                    s_axi_rdata <= bram_base_out;
                end
                REG_BRAM_SIZE: begin
                    s_axi_rdata <= bram_size_out;
                end
                REG_SQ_HEAD: begin
                    s_axi_rdata <= sq_head_out;
                end
                REG_SQ_TAIL: begin
                    s_axi_rdata <= sq_tail_out;
                end
                REG_CQ_HEAD: begin
                    s_axi_rdata <= cq_head_out;
                end
                REG_CQ_TAIL: begin
                    s_axi_rdata <= cq_tail_out;
                end
                REG_IRQ_ACK: begin
                    s_axi_rdata <= irq_pending ? 32'h1 : 32'h0;
                end
                default: begin
                    s_axi_rdata <= 32'h0;
                end
            endcase
            s_axi_rvalid <= 1'b1;
            s_axi_rresp <= 2'b00;
        end else if (s_axi_rvalid & s_axi_rready) begin
            s_axi_rvalid <= 1'b0;
            s_axi_arready <= 1'b0;
        end else begin
            s_axi_rvalid <= s_axi_rvalid;
            s_axi_arready <= 1'b0;
        end
    end
end

// expose irq_out to fabric: gated by control bit (reg_control[3] is irq_enable)
assign irq_out = irq_pending & reg_control[3];

// tie enable_out and loopback_out default on reset
always @(posedge clk) begin
    if (!rstn) begin
        enable_out <= 1'b0;
        loopback_out <= 1'b0;
    end else begin
        // enable_out and loopback_out set in write handler when CONTROL written
        // nothing else to do here
        enable_out <= enable_out;
        loopback_out <= loopback_out;
    end
end

endmodule
*/
