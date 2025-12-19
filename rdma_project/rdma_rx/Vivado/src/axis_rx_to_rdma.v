module axis_rx_to_bram #(
    parameter DUMMY = 0    // eski ADDR_WIDTH vs. yok, placeholder
)(
    input  wire        axis_clk,
    input  wire        axis_aresetn,
    input  wire        capture_en,   // sabit 1'e bağlayabilirsin

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
    // PG138'e göre:
    //  tdata[15:0]  = status bits
    //  tdata[31:16] = frame length (bytes)
    //  tkeep        = 4'hF
    //  tlast        = 1 (tek word)
    // -------------------------------------------------
    input  wire [31:0] s_axis_rxs_tdata,
    input  wire [3:0]  s_axis_rxs_tkeep,
    input  wire        s_axis_rxs_tvalid,
    output reg         s_axis_rxs_tready,
    input  wire        s_axis_rxs_tlast,

    // -------------------------------------------------
    // AXI-Stream master: ETH frame -> RDMA decapsulator
    // (BD'de rdma_axilite_rx_ctrl_0.s_axis_eth_* girişine gidecek)
    // -------------------------------------------------
    output reg  [31:0] m_axis_eth_tdata,
    output reg  [3:0]  m_axis_eth_tkeep,
    output reg         m_axis_eth_tvalid,
    input  wire        m_axis_eth_tready,
    output reg         m_axis_eth_tlast,

    // -------------------------------------------------
    // Basit status (PS/Vitis için - istersen kullanmazsın)
    // -------------------------------------------------
    output reg         frame_done,       // "good frame" geldi (bit0=1)
    output reg [15:0]  frame_len_bytes   // RXS length field
);

    // --------------------------------------------------------------------
    // DATA PATH:
    // Tek-word register slice mantığı:
    //  - Eğer buffer boşsa VEYA downstream hazırsa, upstream'den yeni word al
    //  - Downstream hazır değilken m_axis_eth_* sabit kalır (valid + data)
    // --------------------------------------------------------------------
    assign s_axis_tready = capture_en && (!m_axis_eth_tvalid || m_axis_eth_tready);

    // RXS'ten gelen "frame_ok" bitini hatırlamak için latch
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
            frame_done        <= 1'b0;      // tek cycle pulse
            s_axis_rxs_tready <= 1'b1;      // status kanalını hep hazır bırak

            // ----------------------------------
            // DATA: m_axis_rxd -> m_axis_eth ileriye aktar
            //  - Upstream handshake: capture_en && s_axis_tvalid && s_axis_tready
            //  - Downstream handshake: m_axis_eth_tvalid && m_axis_eth_tready
            // ----------------------------------
            if (capture_en && s_axis_tvalid && s_axis_tready) begin
                // Yeni kelimeyi buffer'a al
                m_axis_eth_tdata  <= s_axis_tdata;
                m_axis_eth_tkeep  <= s_axis_tkeep;
                m_axis_eth_tlast  <= s_axis_tlast;
                m_axis_eth_tvalid <= 1'b1;
            end
            else if (m_axis_eth_tvalid && m_axis_eth_tready) begin
                // Downstream bu kelimeyi tüketti, buffer artık boş
                m_axis_eth_tvalid <= 1'b0;
                // tdata/tkeep/tlast değerleri önemli değil; valid=0 iken okunmayacaklar
            end

            // ----------------------------------
            // STATUS: m_axis_rxs -> length / frame_ok
            // ----------------------------------
            if (s_axis_rxs_tvalid && s_axis_rxs_tready) begin
                // PG138: tdata[31:16] = frame length (bytes)
                frame_len_bytes <= s_axis_rxs_tdata[31:16];

                // bit0: "frame_ok" kabul edelim
                last_frame_ok <= s_axis_rxs_tdata[0];

                if (s_axis_rxs_tlast && s_axis_rxs_tdata[0]) begin
                    frame_done <= 1'b1;
                end
            end
        end
    end

endmodule
