`timescale 1ns / 1ps
// meta_align.v
// Aligns metadata (UdpMetaIn) with AXI-Stream payload

module meta_align #(
    parameter DATA_WIDTH = 64,
    parameter META_WIDTH = 128
)(
    input  wire clk,
    input  wire rstn,
    
    // AXI-Stream payload input
    input  wire [DATA_WIDTH-1:0] s_axis_tdata,
    input  wire [DATA_WIDTH/8-1:0] s_axis_tkeep,
    input  wire s_axis_tvalid,
    output reg  s_axis_tready,
    input  wire s_axis_tlast,
    
    // Metadata input
    input  wire [META_WIDTH-1:0] udp_meta_in,
    input  wire udp_meta_valid,
    output reg  udp_meta_ready,
    
    // AXI-Stream payload output
    output reg  [DATA_WIDTH-1:0] m_axis_tdata,
    output reg  [DATA_WIDTH/8-1:0] m_axis_tkeep,
    output reg  m_axis_tvalid,
    input  wire m_axis_tready,
    output reg  m_axis_tlast,
    
    // Metadata output (aligned with payload)
    output reg  [META_WIDTH-1:0] udp_meta_out,
    output reg  udp_meta_out_valid,
    input  wire udp_meta_out_ready
);

    // FSM states
    localparam IDLE = 2'b00;
    localparam WAIT_PAYLOAD = 2'b01;
    localparam FORWARD = 2'b10;
    
    reg [1:0] state;
    reg [META_WIDTH-1:0] meta_reg;
    reg first_beat;
    
    always @(posedge clk) begin
        if (!rstn) begin
            state <= IDLE;
            s_axis_tready <= 1'b0;
            udp_meta_ready <= 1'b1;
            m_axis_tvalid <= 1'b0;
            udp_meta_out_valid <= 1'b0;
            first_beat <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    udp_meta_ready <= 1'b1;
                    s_axis_tready <= 1'b0;
                    
                    // Wait for metadata
                    if (udp_meta_valid && udp_meta_ready) begin
                        meta_reg <= udp_meta_in;
                        udp_meta_ready <= 1'b0;
                        state <= WAIT_PAYLOAD;
                        first_beat <= 1'b1;
                    end
                end
                
                WAIT_PAYLOAD: begin
                    s_axis_tready <= 1'b1;
                    
                    // Wait for first payload beat
                    if (s_axis_tvalid && s_axis_tready) begin
                        // Output metadata WITH first payload beat
                        udp_meta_out <= meta_reg;
                        udp_meta_out_valid <= 1'b1;
                        
                        // Forward payload
                        m_axis_tdata <= s_axis_tdata;
                        m_axis_tkeep <= s_axis_tkeep;
                        m_axis_tvalid <= 1'b1;
                        m_axis_tlast <= s_axis_tlast;
                        
                        if (s_axis_tlast) begin
                            state <= IDLE;
                        end else begin
                            state <= FORWARD;
                        end
                    end
                end
                
                FORWARD: begin
                    // Clear metadata valid after first beat
                    if (udp_meta_out_valid && udp_meta_out_ready) begin
                        udp_meta_out_valid <= 1'b0;
                    end
                    
                    // Continue forwarding payload
                    s_axis_tready <= m_axis_tready;
                    
                    if (s_axis_tvalid && m_axis_tready) begin
                        m_axis_tdata <= s_axis_tdata;
                        m_axis_tkeep <= s_axis_tkeep;
                        m_axis_tvalid <= 1'b1;
                        m_axis_tlast <= s_axis_tlast;
                        
                        if (s_axis_tlast) begin
                            state <= IDLE;
                        end
                    end else if (!s_axis_tvalid) begin
                        m_axis_tvalid <= 1'b0;
                    end
                end
            endcase
        end
    end

endmodule