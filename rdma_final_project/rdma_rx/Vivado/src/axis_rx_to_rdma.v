module axis_rx_to_bram #(
    parameter DUMMY = 0    //placeholder
)(
    input  wire        axis_clk,
    input  wire        axis_aresetn,
    input  wire        capture_en,   // I put it here for initial tests with both tx and rx. Tie this permanently to 1 if you always want to capture

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
    // According to ethernet ip datasheet:
    //   tdata[15:0]  = frame length in bytes
    //   tdata[31:16] = VLAN tag / auxiliary fields
    //   tkeep        = 4'hF
    //   tlast        = 1 (single word)
    // -------------------------------------------------
    input  wire [31:0] s_axis_rxs_tdata,
    input  wire [3:0]  s_axis_rxs_tkeep,
    input  wire        s_axis_rxs_tvalid,
    output reg         s_axis_rxs_tready,
    input  wire        s_axis_rxs_tlast,

    // -------------------------------------------------
    // AXI-Stream master: Ethernet frame -> RDMA decapsulator
    // (In the BD this connects to rdma_axilite_rx_ctrl_0.s_axis_eth_*)
    // -------------------------------------------------
    output reg  [31:0] m_axis_eth_tdata,
    output reg  [3:0]  m_axis_eth_tkeep,
    output reg         m_axis_eth_tvalid,
    input  wire        m_axis_eth_tready,
    output reg         m_axis_eth_tlast,

    // -------------------------------------------------
    // Simple status outputs (for PS/Vitis – we did not use them in the final version)
    // -------------------------------------------------
    output reg         frame_done,       // Pulses when a "good frame" is received (status bit0 = 1)
    output reg [15:0]  frame_len_bytes  
);

    // --------------------------------------------------------------------
    // DATA PATH:
    //  - If the buffer is empty OR downstream is ready, accept a new word
    //  - While downstream is not ready, hold m_axis_eth_* stable (valid + data) (this solved the problem of decapsulator validator hanging the line for a few clocks and causing lost words)
    // --------------------------------------------------------------------
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
            // ------------ default status values -------------
            frame_done        <= 1'b0;      // one-cycle pulse
            s_axis_rxs_tready <= 1'b1;      // always ready to accept status

            // ----------------------------------
            // DATA: pass m_axis_rxd forward to m_axis_eth
            //  - Upstream handshake: capture_en && s_axis_tvalid && s_axis_tready
            //  - Downstream handshake: m_axis_eth_tvalid && m_axis_eth_tready
            // ----------------------------------
            if (capture_en && s_axis_tvalid && s_axis_tready) begin
                // Capture a new word into the buffer
                m_axis_eth_tdata  <= s_axis_tdata;
                m_axis_eth_tkeep  <= s_axis_tkeep;
                m_axis_eth_tlast  <= s_axis_tlast;
                m_axis_eth_tvalid <= 1'b1;
            end
            else if (m_axis_eth_tvalid && m_axis_eth_tready) begin
                // Downstream consumed this word, buffer is now empty
                m_axis_eth_tvalid <= 1'b0;
                // tdata/tkeep/tlast don't matter when valid=0; they won't be observed
            end

            // ----------------------------------
            // STATUS: consume m_axis_rxs and extract length / frame_ok
            // ----------------------------------
            if (s_axis_rxs_tvalid && s_axis_rxs_tready) begin
                // ethernet ip block datasheet: tdata[15:0] = frame length in bytes
                frame_len_bytes <= s_axis_rxs_tdata[15:0];

                // Treat bit 0 as "frame_ok"
                last_frame_ok <= s_axis_rxs_tdata[0];

                if (s_axis_rxs_tlast && s_axis_rxs_tdata[0]) begin
                    frame_done <= 1'b1;
                end
            end
        end
    end

endmodule
