`timescale 1ns / 1ps
// header_packer.v
// Combine Ethernet + IP + UDP headers + payload into AXI-Stream


module header_packer #(
    parameter DATA_WIDTH = 64
)(
    input  wire                     clk,
    input  wire                     rstn,

    // Header channels
    input  wire [111:0]             eth_header,
    input  wire                     eth_header_valid,
    output reg                      eth_header_ready,

    input  wire [159:0]             ip_header,
    input  wire                     ip_header_valid,
    output reg                      ip_header_ready,

    input  wire [63:0]              udp_header,
    input  wire                     udp_header_valid,
    output reg                      udp_header_ready,

    input  wire [15:0]              payload_length_bytes,
    input  wire                     length_valid,
    output reg                      length_ready,

    // Payload input
    input  wire [DATA_WIDTH-1:0]    payload_in,
    input  wire [DATA_WIDTH/8-1:0]  payload_in_keep,
    input  wire                     payload_valid,
    output reg                      payload_ready,
    input  wire                     payload_last,

    // AXI-Stream output
    output reg  [DATA_WIDTH-1:0]    m_axis_tdata,
    output reg  [DATA_WIDTH/8-1:0]  m_axis_tkeep,
    output reg                      m_axis_tvalid,
    input  wire                     m_axis_tready,
    output reg                      m_axis_tlast
);

    localparam integer KEEP_WIDTH          = DATA_WIDTH / 8;
    localparam integer HEADER_BYTES        = 14 + 20 + 8; // ETH + IPv4 + UDP
    localparam integer HEADER_BEATS        = (HEADER_BYTES + KEEP_WIDTH - 1) / KEEP_WIDTH;
    localparam integer PAD_BYTES           = (HEADER_BEATS * KEEP_WIDTH) - HEADER_BYTES;
    localparam integer PAD_BITS            = PAD_BYTES * 8;
    localparam integer HEADER_VEC_WIDTH    = (HEADER_BYTES + PAD_BYTES) * 8;

    localparam [1:0] ST_IDLE    = 2'd0;
    localparam [1:0] ST_HEADERS = 2'd1;
    localparam [1:0] ST_PAYLOAD = 2'd2;

    reg [1:0]                   state;
    reg [HEADER_VEC_WIDTH-1:0]  header_shift;
    reg [15:0]                  hdr_bytes_remaining;
    reg                         payload_is_empty;

    // Helper constants
    localparam [7:0] BEAT_BYTES = DATA_WIDTH / 8;

    wire [7:0] bytes_this      = (hdr_bytes_remaining >= BEAT_BYTES) ? BEAT_BYTES : hdr_bytes_remaining[7:0];
    wire       last_header_word = (hdr_bytes_remaining <= BEAT_BYTES);

    // Keep mask helper (MSB-first byte ordering)
    function [KEEP_WIDTH-1:0] keep_mask;
        input [7:0] bytes_valid;
        integer i;
        begin
            keep_mask = {KEEP_WIDTH{1'b0}};
            for (i = 0; i < KEEP_WIDTH; i = i + 1) begin
                if (i < bytes_valid)
                    keep_mask[KEEP_WIDTH-1-i] = 1'b1;
            end
        end
    endfunction

    always @(posedge clk) begin
        if (!rstn) begin
            state               <= ST_IDLE;
            header_shift        <= {HEADER_VEC_WIDTH{1'b0}};
            hdr_bytes_remaining <= 16'd0;
            payload_is_empty    <= 1'b0;

            m_axis_tdata  <= {DATA_WIDTH{1'b0}};
            m_axis_tkeep  <= {KEEP_WIDTH{1'b0}};
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
            payload_ready <= 1'b0;

            eth_header_ready <= 1'b0;
            ip_header_ready  <= 1'b0;
            udp_header_ready <= 1'b0;
            length_ready     <= 1'b0;
        end else begin
            // Default deassert single-cycle strobes
            eth_header_ready <= 1'b0;
            ip_header_ready  <= 1'b0;
            udp_header_ready <= 1'b0;
            length_ready     <= 1'b0;

            case (state)
                ST_IDLE: begin
                    m_axis_tvalid <= 1'b0;
                    m_axis_tlast  <= 1'b0;
                    payload_ready <= 1'b0;

                    if (eth_header_valid && ip_header_valid && udp_header_valid && length_valid) begin
                        header_shift        <= {eth_header, ip_header, udp_header, {PAD_BITS{1'b0}}};
                        hdr_bytes_remaining <= HEADER_BYTES;
                        payload_is_empty    <= (payload_length_bytes == 16'd0);

                        eth_header_ready <= 1'b1;
                        ip_header_ready  <= 1'b1;
                        udp_header_ready <= 1'b1;
                        length_ready     <= 1'b1;

                        state <= ST_HEADERS;
                    end
                end

                ST_HEADERS: begin
                    payload_ready <= 1'b0;

                    if (!m_axis_tvalid) begin
                        m_axis_tdata  <= header_shift[HEADER_VEC_WIDTH-1 -: DATA_WIDTH];
                        m_axis_tkeep  <= keep_mask(bytes_this);
                        m_axis_tvalid <= 1'b1;
                        m_axis_tlast  <= (payload_is_empty && last_header_word);
                    end

                    if (m_axis_tvalid && m_axis_tready) begin
                        header_shift        <= {header_shift[HEADER_VEC_WIDTH-DATA_WIDTH-1:0], {DATA_WIDTH{1'b0}}};
                        hdr_bytes_remaining <= hdr_bytes_remaining - bytes_this;
                        m_axis_tvalid       <= 1'b0;

                        if (last_header_word) begin
                            if (payload_is_empty) begin
                                state <= ST_IDLE;
                            end else begin
                                state <= ST_PAYLOAD;
                            end
                        end
                    end
                end

                ST_PAYLOAD: begin
                    if (m_axis_tvalid) begin
                        payload_ready <= 1'b0;
                        if (m_axis_tready) begin
                            if (m_axis_tlast) begin
                                m_axis_tvalid <= 1'b0;
                                state         <= ST_IDLE;
                            end else begin
                                m_axis_tvalid <= 1'b0;
                            end
                        end
                    end else begin
                        payload_ready <= m_axis_tready;

                        if (payload_valid && m_axis_tready) begin
                            m_axis_tdata  <= payload_in;
                            m_axis_tkeep  <= payload_in_keep;
                            m_axis_tvalid <= 1'b1;
                            m_axis_tlast  <= payload_last;
                        end
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
