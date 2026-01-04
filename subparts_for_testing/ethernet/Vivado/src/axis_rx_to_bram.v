----------------------------------------------------------------------------------
-- Company: KUL - Group T - RDMA Team
-- Engineer: Emir Yalcin <emir.yalcin@hotmail.com>
-- 
-- Create Date: 22/11/2025 12:09:11 PM
-- Design Name: 
-- Module Name: axis_rx_to_bram
-- Project Name: RDMA
-- Target Devices: Kria KR260
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------
// axis_rx_to_rdma.v
// AXI Ethernet RX (m_axis_rxd + m_axis_rxs) --> RDMA RX decapsulator
module axis_rx_to_bram #(
    parameter DUMMY = 0    
)(
    input  wire        axis_clk,
    input  wire        axis_aresetn,
    input  wire        capture_en,  

    // -------------------------------------------------
    // AXI-Stream RX DATA (from axi_ethernet_0.m_axis_rxd)
    // -------------------------------------------------
    input  wire [31:0] s_axis_tdata,
    input  wire [3:0]  s_axis_tkeep,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tlast,

    // -------------------------------------------------
    // AXI-Stream RX STATUS (from axi_ethernet_0.m_axis_rxs)
    // PG138:
    //  tdata[15:0]  = status bits
    //  tdata[31:16] = frame length (bytes)
    //  tkeep        = 4'hF
    //  tlast        = 1 
    // -------------------------------------------------
    input  wire [31:0] s_axis_rxs_tdata,
    input  wire [3:0]  s_axis_rxs_tkeep,
    input  wire        s_axis_rxs_tvalid,
    output reg         s_axis_rxs_tready,
    input  wire        s_axis_rxs_tlast,

    // -------------------------------------------------
    // AXI-Stream master: ETH frame -> RDMA decapsulator  
    // -------------------------------------------------
    output reg  [31:0] m_axis_eth_tdata,
    output reg  [3:0]  m_axis_eth_tkeep,
    output reg         m_axis_eth_tvalid,
    input  wire        m_axis_eth_tready,
    output reg         m_axis_eth_tlast,

    output reg         frame_done,       
    output reg [15:0]  frame_len_bytes   // RXS length field
);

    assign s_axis_tready = capture_en && (!m_axis_eth_tvalid || m_axis_eth_tready);

    reg last_frame_ok;

    always @(posedge axis_clk) begin
        if (!axis_aresetn) begin
            // Data path reset
            m_axis_eth_tdata  <= 32'h0;
            m_axis_eth_tkeep  <= 4'h0;
            m_axis_eth_tvalid <= 1'b0;
            m_axis_eth_tlast  <= 1'b0;

            // Status reset
            frame_done        <= 1'b0;
            frame_len_bytes   <= 16'd0;
            s_axis_rxs_tready <= 1'b0;
            last_frame_ok     <= 1'b0;
        end
        else begin
            // ------------ defaults (status) -------------
            frame_done        <= 1'b0;      
            s_axis_rxs_tready <= 1'b1;     

            // ----------------------------------
            // DATA: m_axis_rxd -> m_axis_eth 
            //  - Upstream handshake: capture_en && s_axis_tvalid && s_axis_tready
            //  - Downstream handshake: m_axis_eth_tvalid && m_axis_eth_tready
            // ----------------------------------
            if (capture_en && s_axis_tvalid && s_axis_tready) begin

                m_axis_eth_tdata  <= s_axis_tdata;
                m_axis_eth_tkeep  <= s_axis_tkeep;
                m_axis_eth_tlast  <= s_axis_tlast;
                m_axis_eth_tvalid <= 1'b1;
            end
            else if (m_axis_eth_tvalid && m_axis_eth_tready) begin
                m_axis_eth_tvalid <= 1'b0;
            end

            // ----------------------------------
            // STATUS: m_axis_rxs -> length / frame_ok
            // ----------------------------------
            if (s_axis_rxs_tvalid && s_axis_rxs_tready) begin
                // PG138: tdata[15:0] = frame length (bytes)
                frame_len_bytes <= s_axis_rxs_tdata[15:0];

                last_frame_ok <= s_axis_rxs_tdata[0];

                if (s_axis_rxs_tlast && s_axis_rxs_tdata[0]) begin
                    frame_done <= 1'b1;
                end
            end
        end
    end

endmodule
