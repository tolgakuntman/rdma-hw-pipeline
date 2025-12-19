//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2024.1 (win64) Build 5076996 Wed May 22 18:37:14 MDT 2024
//Date        : Fri Dec 19 11:31:28 2025
//Host        : LAPTOP-VRV5DMOG running 64-bit major release  (build 9200)
//Command     : generate_target design_1.bd
//Design      : design_1
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CORE_GENERATION_INFO = "design_1,IP_Integrator,{x_ipVendor=xilinx.com,x_ipLibrary=BlockDiagram,x_ipName=design_1,x_ipVersion=1.00.a,x_ipLanguage=VERILOG,numBlks=25,numReposBlks=23,numNonXlnxBlks=0,numHierBlks=2,maxHierDepth=0,numSysgenBlks=0,numHlsBlks=0,numHdlrefBlks=4,numPkgbdBlks=0,bdsource=USER,da_aeth_cnt=2,da_axi4_cnt=4,da_board_cnt=1,da_clkrst_cnt=9,synth_mode=None}" *) (* HW_HANDOFF = "design_1.hwdef" *) 
module design_1
   (som240_1_connector_hpa_clk0p_clk,
    som240_2_connector_pl_gem3_reset,
    som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdc,
    som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdio_i,
    som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdio_o,
    som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdio_t,
    som240_2_connector_pl_gem3_rgmii_rd,
    som240_2_connector_pl_gem3_rgmii_rx_ctl,
    som240_2_connector_pl_gem3_rgmii_rxc,
    som240_2_connector_pl_gem3_rgmii_td,
    som240_2_connector_pl_gem3_rgmii_tx_ctl,
    som240_2_connector_pl_gem3_rgmii_txc);
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.SOM240_1_CONNECTOR_HPA_CLK0P_CLK CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.SOM240_1_CONNECTOR_HPA_CLK0P_CLK, CLK_DOMAIN design_1_som240_1_connector_hpa_clk0p_clk, FREQ_HZ 25000000, FREQ_TOLERANCE_HZ 0, INSERT_VIP 0, PHASE 0.0" *) input som240_1_connector_hpa_clk0p_clk;
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST.SOM240_2_CONNECTOR_PL_GEM3_RESET RST" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME RST.SOM240_2_CONNECTOR_PL_GEM3_RESET, INSERT_VIP 0, POLARITY ACTIVE_LOW" *) output [0:0]som240_2_connector_pl_gem3_reset;
  (* X_INTERFACE_INFO = "xilinx.com:interface:mdio:1.0 som240_2_connector_pl_gem3_rgmii_mdio_mdc MDC" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME som240_2_connector_pl_gem3_rgmii_mdio_mdc, CAN_DEBUG false" *) output som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdc;
  (* X_INTERFACE_INFO = "xilinx.com:interface:mdio:1.0 som240_2_connector_pl_gem3_rgmii_mdio_mdc MDIO_I" *) input som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdio_i;
  (* X_INTERFACE_INFO = "xilinx.com:interface:mdio:1.0 som240_2_connector_pl_gem3_rgmii_mdio_mdc MDIO_O" *) output som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdio_o;
  (* X_INTERFACE_INFO = "xilinx.com:interface:mdio:1.0 som240_2_connector_pl_gem3_rgmii_mdio_mdc MDIO_T" *) output som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdio_t;
  (* X_INTERFACE_INFO = "xilinx.com:interface:rgmii:1.0 som240_2_connector_pl_gem3_rgmii RD" *) input [3:0]som240_2_connector_pl_gem3_rgmii_rd;
  (* X_INTERFACE_INFO = "xilinx.com:interface:rgmii:1.0 som240_2_connector_pl_gem3_rgmii RX_CTL" *) input som240_2_connector_pl_gem3_rgmii_rx_ctl;
  (* X_INTERFACE_INFO = "xilinx.com:interface:rgmii:1.0 som240_2_connector_pl_gem3_rgmii RXC" *) input som240_2_connector_pl_gem3_rgmii_rxc;
  (* X_INTERFACE_INFO = "xilinx.com:interface:rgmii:1.0 som240_2_connector_pl_gem3_rgmii TD" *) output [3:0]som240_2_connector_pl_gem3_rgmii_td;
  (* X_INTERFACE_INFO = "xilinx.com:interface:rgmii:1.0 som240_2_connector_pl_gem3_rgmii TX_CTL" *) output som240_2_connector_pl_gem3_rgmii_tx_ctl;
  (* X_INTERFACE_INFO = "xilinx.com:interface:rgmii:1.0 som240_2_connector_pl_gem3_rgmii TXC" *) output som240_2_connector_pl_gem3_rgmii_txc;

  wire [39:0]S00_AXI_1_ARADDR;
  wire [1:0]S00_AXI_1_ARBURST;
  wire [3:0]S00_AXI_1_ARCACHE;
  wire [15:0]S00_AXI_1_ARID;
  wire [7:0]S00_AXI_1_ARLEN;
  wire S00_AXI_1_ARLOCK;
  wire [2:0]S00_AXI_1_ARPROT;
  wire [3:0]S00_AXI_1_ARQOS;
  wire S00_AXI_1_ARREADY;
  wire [2:0]S00_AXI_1_ARSIZE;
  wire S00_AXI_1_ARVALID;
  wire [39:0]S00_AXI_1_AWADDR;
  wire [1:0]S00_AXI_1_AWBURST;
  wire [3:0]S00_AXI_1_AWCACHE;
  wire [15:0]S00_AXI_1_AWID;
  wire [7:0]S00_AXI_1_AWLEN;
  wire S00_AXI_1_AWLOCK;
  wire [2:0]S00_AXI_1_AWPROT;
  wire [3:0]S00_AXI_1_AWQOS;
  wire S00_AXI_1_AWREADY;
  wire [2:0]S00_AXI_1_AWSIZE;
  wire S00_AXI_1_AWVALID;
  wire [15:0]S00_AXI_1_BID;
  wire S00_AXI_1_BREADY;
  wire [1:0]S00_AXI_1_BRESP;
  wire S00_AXI_1_BVALID;
  wire [31:0]S00_AXI_1_RDATA;
  wire [15:0]S00_AXI_1_RID;
  wire S00_AXI_1_RLAST;
  wire S00_AXI_1_RREADY;
  wire [1:0]S00_AXI_1_RRESP;
  wire S00_AXI_1_RVALID;
  wire [31:0]S00_AXI_1_WDATA;
  wire S00_AXI_1_WLAST;
  wire S00_AXI_1_WREADY;
  wire [3:0]S00_AXI_1_WSTRB;
  wire S00_AXI_1_WVALID;
  wire [12:0]axi_bram_ctrl_0_BRAM_PORTA_ADDR;
  wire axi_bram_ctrl_0_BRAM_PORTA_CLK;
  wire [31:0]axi_bram_ctrl_0_BRAM_PORTA_DIN;
  wire [31:0]axi_bram_ctrl_0_BRAM_PORTA_DOUT;
  wire axi_bram_ctrl_0_BRAM_PORTA_EN;
  wire axi_bram_ctrl_0_BRAM_PORTA_RST;
  wire [3:0]axi_bram_ctrl_0_BRAM_PORTA_WE;
  wire [31:0]axi_datamover_0_M_AXIS_MM2S_TDATA;
  wire axi_datamover_0_M_AXIS_MM2S_TLAST;
  wire axi_datamover_0_M_AXIS_MM2S_TREADY;
  wire axi_datamover_0_M_AXIS_MM2S_TVALID;
  wire [31:0]axi_datamover_0_M_AXI_MM2S_ARADDR;
  wire [1:0]axi_datamover_0_M_AXI_MM2S_ARBURST;
  wire [3:0]axi_datamover_0_M_AXI_MM2S_ARCACHE;
  wire [3:0]axi_datamover_0_M_AXI_MM2S_ARID;
  wire [7:0]axi_datamover_0_M_AXI_MM2S_ARLEN;
  wire [2:0]axi_datamover_0_M_AXI_MM2S_ARPROT;
  wire axi_datamover_0_M_AXI_MM2S_ARREADY;
  wire [2:0]axi_datamover_0_M_AXI_MM2S_ARSIZE;
  wire [3:0]axi_datamover_0_M_AXI_MM2S_ARUSER;
  wire axi_datamover_0_M_AXI_MM2S_ARVALID;
  wire [31:0]axi_datamover_0_M_AXI_MM2S_RDATA;
  wire axi_datamover_0_M_AXI_MM2S_RLAST;
  wire axi_datamover_0_M_AXI_MM2S_RREADY;
  wire [1:0]axi_datamover_0_M_AXI_MM2S_RRESP;
  wire axi_datamover_0_M_AXI_MM2S_RVALID;
  wire [31:0]axi_datamover_0_M_AXI_S2MM_AWADDR;
  wire [1:0]axi_datamover_0_M_AXI_S2MM_AWBURST;
  wire [3:0]axi_datamover_0_M_AXI_S2MM_AWCACHE;
  wire [3:0]axi_datamover_0_M_AXI_S2MM_AWID;
  wire [7:0]axi_datamover_0_M_AXI_S2MM_AWLEN;
  wire [2:0]axi_datamover_0_M_AXI_S2MM_AWPROT;
  wire axi_datamover_0_M_AXI_S2MM_AWREADY;
  wire [2:0]axi_datamover_0_M_AXI_S2MM_AWSIZE;
  wire [3:0]axi_datamover_0_M_AXI_S2MM_AWUSER;
  wire axi_datamover_0_M_AXI_S2MM_AWVALID;
  wire axi_datamover_0_M_AXI_S2MM_BREADY;
  wire [1:0]axi_datamover_0_M_AXI_S2MM_BRESP;
  wire axi_datamover_0_M_AXI_S2MM_BVALID;
  wire [31:0]axi_datamover_0_M_AXI_S2MM_WDATA;
  wire axi_datamover_0_M_AXI_S2MM_WLAST;
  wire axi_datamover_0_M_AXI_S2MM_WREADY;
  wire [3:0]axi_datamover_0_M_AXI_S2MM_WSTRB;
  wire axi_datamover_0_M_AXI_S2MM_WVALID;
  wire axi_datamover_0_mm2s_rd_xfer_cmplt;
  wire axi_datamover_0_s2mm_wr_xfer_cmplt;
  wire axi_datamover_0_s_axis_s2mm_tready;
  wire [31:0]axi_datamover_1_M_AXIS_MM2S_TDATA;
  wire [3:0]axi_datamover_1_M_AXIS_MM2S_TKEEP;
  wire axi_datamover_1_M_AXIS_MM2S_TLAST;
  wire axi_datamover_1_M_AXIS_MM2S_TREADY;
  wire axi_datamover_1_M_AXIS_MM2S_TVALID;
  wire [31:0]axi_datamover_1_M_AXI_MM2S_ARADDR;
  wire [1:0]axi_datamover_1_M_AXI_MM2S_ARBURST;
  wire [3:0]axi_datamover_1_M_AXI_MM2S_ARCACHE;
  wire [3:0]axi_datamover_1_M_AXI_MM2S_ARID;
  wire [7:0]axi_datamover_1_M_AXI_MM2S_ARLEN;
  wire [2:0]axi_datamover_1_M_AXI_MM2S_ARPROT;
  wire axi_datamover_1_M_AXI_MM2S_ARREADY;
  wire [2:0]axi_datamover_1_M_AXI_MM2S_ARSIZE;
  wire [3:0]axi_datamover_1_M_AXI_MM2S_ARUSER;
  wire axi_datamover_1_M_AXI_MM2S_ARVALID;
  wire [31:0]axi_datamover_1_M_AXI_MM2S_RDATA;
  wire axi_datamover_1_M_AXI_MM2S_RLAST;
  wire axi_datamover_1_M_AXI_MM2S_RREADY;
  wire [1:0]axi_datamover_1_M_AXI_MM2S_RRESP;
  wire axi_datamover_1_M_AXI_MM2S_RVALID;
  wire [31:0]axi_datamover_1_M_AXI_S2MM_AWADDR;
  wire [1:0]axi_datamover_1_M_AXI_S2MM_AWBURST;
  wire [3:0]axi_datamover_1_M_AXI_S2MM_AWCACHE;
  wire [3:0]axi_datamover_1_M_AXI_S2MM_AWID;
  wire [7:0]axi_datamover_1_M_AXI_S2MM_AWLEN;
  wire [2:0]axi_datamover_1_M_AXI_S2MM_AWPROT;
  wire axi_datamover_1_M_AXI_S2MM_AWREADY;
  wire [2:0]axi_datamover_1_M_AXI_S2MM_AWSIZE;
  wire [3:0]axi_datamover_1_M_AXI_S2MM_AWUSER;
  wire axi_datamover_1_M_AXI_S2MM_AWVALID;
  wire axi_datamover_1_M_AXI_S2MM_BREADY;
  wire [1:0]axi_datamover_1_M_AXI_S2MM_BRESP;
  wire axi_datamover_1_M_AXI_S2MM_BVALID;
  wire [31:0]axi_datamover_1_M_AXI_S2MM_WDATA;
  wire axi_datamover_1_M_AXI_S2MM_WLAST;
  wire axi_datamover_1_M_AXI_S2MM_WREADY;
  wire [3:0]axi_datamover_1_M_AXI_S2MM_WSTRB;
  wire axi_datamover_1_M_AXI_S2MM_WVALID;
  wire axi_datamover_1_mm2s_rd_xfer_cmplt;
  wire axi_datamover_1_s_axis_mm2s_cmd_tready;
  wire axi_ethernet_0_refclk_clk_out1;
  wire axi_ethernet_0_refclk_clk_out2;
  wire axi_ethernet_1_mdio_MDC;
  wire axi_ethernet_1_mdio_MDIO_I;
  wire axi_ethernet_1_mdio_MDIO_O;
  wire axi_ethernet_1_mdio_MDIO_T;
  wire [0:0]axi_ethernet_1_phy_rst_n;
  wire [3:0]axi_ethernet_1_rgmii_RD;
  wire axi_ethernet_1_rgmii_RXC;
  wire axi_ethernet_1_rgmii_RX_CTL;
  wire [3:0]axi_ethernet_1_rgmii_TD;
  wire axi_ethernet_1_rgmii_TXC;
  wire axi_ethernet_1_rgmii_TX_CTL;
  wire axi_ethernet_1_s_axis_txc_tready;
  wire [39:0]axi_interconnect_0_M00_AXI_ARADDR;
  wire axi_interconnect_0_M00_AXI_ARREADY;
  wire axi_interconnect_0_M00_AXI_ARVALID;
  wire [39:0]axi_interconnect_0_M00_AXI_AWADDR;
  wire axi_interconnect_0_M00_AXI_AWREADY;
  wire axi_interconnect_0_M00_AXI_AWVALID;
  wire axi_interconnect_0_M00_AXI_BREADY;
  wire [1:0]axi_interconnect_0_M00_AXI_BRESP;
  wire axi_interconnect_0_M00_AXI_BVALID;
  wire [31:0]axi_interconnect_0_M00_AXI_RDATA;
  wire axi_interconnect_0_M00_AXI_RREADY;
  wire [1:0]axi_interconnect_0_M00_AXI_RRESP;
  wire axi_interconnect_0_M00_AXI_RVALID;
  wire [31:0]axi_interconnect_0_M00_AXI_WDATA;
  wire axi_interconnect_0_M00_AXI_WREADY;
  wire [3:0]axi_interconnect_0_M00_AXI_WSTRB;
  wire axi_interconnect_0_M00_AXI_WVALID;
  wire [31:0]axis_data_fifo_1_M_AXIS_TDATA;
  wire [3:0]axis_data_fifo_1_M_AXIS_TKEEP;
  wire axis_data_fifo_1_M_AXIS_TLAST;
  wire axis_data_fifo_1_M_AXIS_TREADY;
  wire axis_data_fifo_1_M_AXIS_TVALID;
  wire [31:0]data_mover_controller_0_m00_axis_tdata;
  wire data_mover_controller_0_m00_axis_tlast;
  wire data_mover_controller_0_m00_axis_tvalid;
  wire [71:0]data_mover_controller_0_m_axis_mm2s_cmd_tdata;
  wire data_mover_controller_0_m_axis_mm2s_cmd_tvalid;
  wire [71:0]data_mover_controller_0_m_axis_s2mm_cmd_tdata;
  wire data_mover_controller_0_m_axis_s2mm_cmd_tvalid;
  wire [31:0]data_mover_controller_0_tx_cmd_ddr_addr;
  wire [23:0]data_mover_controller_0_tx_cmd_dest_qp;
  wire [31:0]data_mover_controller_0_tx_cmd_length;
  wire [7:0]data_mover_controller_0_tx_cmd_opcode;
  wire [15:0]data_mover_controller_0_tx_cmd_partition_key;
  wire [23:0]data_mover_controller_0_tx_cmd_psn;
  wire [63:0]data_mover_controller_0_tx_cmd_remote_addr;
  wire [31:0]data_mover_controller_0_tx_cmd_rkey;
  wire [7:0]data_mover_controller_0_tx_cmd_service_level;
  wire [7:0]data_mover_controller_0_tx_cmd_sq_index;
  wire data_mover_controller_0_tx_cmd_valid;
  wire data_mover_controller_0_tx_cpl_ready;
  wire [31:0]eth_pkt_gen_0_m_axis_TDATA;
  wire [3:0]eth_pkt_gen_0_m_axis_TKEEP;
  wire eth_pkt_gen_0_m_axis_TLAST;
  wire eth_pkt_gen_0_m_axis_TREADY;
  wire eth_pkt_gen_0_m_axis_TVALID;
  wire [31:0]eth_pkt_gen_0_m_axis_txc_data;
  wire [3:0]eth_pkt_gen_0_m_axis_txc_keep;
  wire eth_pkt_gen_0_m_axis_txc_last;
  wire eth_pkt_gen_0_m_axis_txc_valid;
  wire [31:0]rdma_axilite_ctrl_0_m_axis_packet_TDATA;
  wire [3:0]rdma_axilite_ctrl_0_m_axis_packet_TKEEP;
  wire rdma_axilite_ctrl_0_m_axis_packet_TLAST;
  wire rdma_axilite_ctrl_0_m_axis_packet_TREADY;
  wire rdma_axilite_ctrl_0_m_axis_packet_TVALID;
  wire [0:0]rst_ps8_0_99M_peripheral_aresetn;
  wire [0:0]rst_ps8_0_99M_peripheral_aresetn1;
  wire [12:0]smartconnect_0_M00_AXI_ARADDR;
  wire [1:0]smartconnect_0_M00_AXI_ARBURST;
  wire [3:0]smartconnect_0_M00_AXI_ARCACHE;
  wire [7:0]smartconnect_0_M00_AXI_ARLEN;
  wire [0:0]smartconnect_0_M00_AXI_ARLOCK;
  wire [2:0]smartconnect_0_M00_AXI_ARPROT;
  wire smartconnect_0_M00_AXI_ARREADY;
  wire [2:0]smartconnect_0_M00_AXI_ARSIZE;
  wire smartconnect_0_M00_AXI_ARVALID;
  wire [12:0]smartconnect_0_M00_AXI_AWADDR;
  wire [1:0]smartconnect_0_M00_AXI_AWBURST;
  wire [3:0]smartconnect_0_M00_AXI_AWCACHE;
  wire [7:0]smartconnect_0_M00_AXI_AWLEN;
  wire [0:0]smartconnect_0_M00_AXI_AWLOCK;
  wire [2:0]smartconnect_0_M00_AXI_AWPROT;
  wire smartconnect_0_M00_AXI_AWREADY;
  wire [2:0]smartconnect_0_M00_AXI_AWSIZE;
  wire smartconnect_0_M00_AXI_AWVALID;
  wire smartconnect_0_M00_AXI_BREADY;
  wire [1:0]smartconnect_0_M00_AXI_BRESP;
  wire smartconnect_0_M00_AXI_BVALID;
  wire [31:0]smartconnect_0_M00_AXI_RDATA;
  wire smartconnect_0_M00_AXI_RLAST;
  wire smartconnect_0_M00_AXI_RREADY;
  wire [1:0]smartconnect_0_M00_AXI_RRESP;
  wire smartconnect_0_M00_AXI_RVALID;
  wire [31:0]smartconnect_0_M00_AXI_WDATA;
  wire smartconnect_0_M00_AXI_WLAST;
  wire smartconnect_0_M00_AXI_WREADY;
  wire [3:0]smartconnect_0_M00_AXI_WSTRB;
  wire smartconnect_0_M00_AXI_WVALID;
  wire [6:0]smartconnect_0_M01_AXI_ARADDR;
  wire [2:0]smartconnect_0_M01_AXI_ARPROT;
  wire smartconnect_0_M01_AXI_ARREADY;
  wire smartconnect_0_M01_AXI_ARVALID;
  wire [6:0]smartconnect_0_M01_AXI_AWADDR;
  wire [2:0]smartconnect_0_M01_AXI_AWPROT;
  wire smartconnect_0_M01_AXI_AWREADY;
  wire smartconnect_0_M01_AXI_AWVALID;
  wire smartconnect_0_M01_AXI_BREADY;
  wire [1:0]smartconnect_0_M01_AXI_BRESP;
  wire smartconnect_0_M01_AXI_BVALID;
  wire [31:0]smartconnect_0_M01_AXI_RDATA;
  wire smartconnect_0_M01_AXI_RREADY;
  wire [1:0]smartconnect_0_M01_AXI_RRESP;
  wire smartconnect_0_M01_AXI_RVALID;
  wire [31:0]smartconnect_0_M01_AXI_WDATA;
  wire smartconnect_0_M01_AXI_WREADY;
  wire [3:0]smartconnect_0_M01_AXI_WSTRB;
  wire smartconnect_0_M01_AXI_WVALID;
  wire [48:0]smartconnect_0_M02_AXI_ARADDR;
  wire [1:0]smartconnect_0_M02_AXI_ARBURST;
  wire [3:0]smartconnect_0_M02_AXI_ARCACHE;
  wire [7:0]smartconnect_0_M02_AXI_ARLEN;
  wire [0:0]smartconnect_0_M02_AXI_ARLOCK;
  wire [2:0]smartconnect_0_M02_AXI_ARPROT;
  wire [3:0]smartconnect_0_M02_AXI_ARQOS;
  wire smartconnect_0_M02_AXI_ARREADY;
  wire [2:0]smartconnect_0_M02_AXI_ARSIZE;
  wire [15:0]smartconnect_0_M02_AXI_ARUSER;
  wire smartconnect_0_M02_AXI_ARVALID;
  wire [48:0]smartconnect_0_M02_AXI_AWADDR;
  wire [1:0]smartconnect_0_M02_AXI_AWBURST;
  wire [3:0]smartconnect_0_M02_AXI_AWCACHE;
  wire [7:0]smartconnect_0_M02_AXI_AWLEN;
  wire [0:0]smartconnect_0_M02_AXI_AWLOCK;
  wire [2:0]smartconnect_0_M02_AXI_AWPROT;
  wire [3:0]smartconnect_0_M02_AXI_AWQOS;
  wire smartconnect_0_M02_AXI_AWREADY;
  wire [2:0]smartconnect_0_M02_AXI_AWSIZE;
  wire [15:0]smartconnect_0_M02_AXI_AWUSER;
  wire smartconnect_0_M02_AXI_AWVALID;
  wire smartconnect_0_M02_AXI_BREADY;
  wire [1:0]smartconnect_0_M02_AXI_BRESP;
  wire smartconnect_0_M02_AXI_BVALID;
  wire [127:0]smartconnect_0_M02_AXI_RDATA;
  wire smartconnect_0_M02_AXI_RLAST;
  wire smartconnect_0_M02_AXI_RREADY;
  wire [1:0]smartconnect_0_M02_AXI_RRESP;
  wire smartconnect_0_M02_AXI_RVALID;
  wire [127:0]smartconnect_0_M02_AXI_WDATA;
  wire smartconnect_0_M02_AXI_WLAST;
  wire smartconnect_0_M02_AXI_WREADY;
  wire [15:0]smartconnect_0_M02_AXI_WSTRB;
  wire smartconnect_0_M02_AXI_WVALID;
  wire [48:0]smartconnect_1_M00_AXI_ARADDR;
  wire [1:0]smartconnect_1_M00_AXI_ARBURST;
  wire [3:0]smartconnect_1_M00_AXI_ARCACHE;
  wire [7:0]smartconnect_1_M00_AXI_ARLEN;
  wire [0:0]smartconnect_1_M00_AXI_ARLOCK;
  wire [2:0]smartconnect_1_M00_AXI_ARPROT;
  wire [3:0]smartconnect_1_M00_AXI_ARQOS;
  wire smartconnect_1_M00_AXI_ARREADY;
  wire [2:0]smartconnect_1_M00_AXI_ARSIZE;
  wire [3:0]smartconnect_1_M00_AXI_ARUSER;
  wire smartconnect_1_M00_AXI_ARVALID;
  wire [48:0]smartconnect_1_M00_AXI_AWADDR;
  wire [1:0]smartconnect_1_M00_AXI_AWBURST;
  wire [3:0]smartconnect_1_M00_AXI_AWCACHE;
  wire [7:0]smartconnect_1_M00_AXI_AWLEN;
  wire [0:0]smartconnect_1_M00_AXI_AWLOCK;
  wire [2:0]smartconnect_1_M00_AXI_AWPROT;
  wire [3:0]smartconnect_1_M00_AXI_AWQOS;
  wire smartconnect_1_M00_AXI_AWREADY;
  wire [2:0]smartconnect_1_M00_AXI_AWSIZE;
  wire [3:0]smartconnect_1_M00_AXI_AWUSER;
  wire smartconnect_1_M00_AXI_AWVALID;
  wire smartconnect_1_M00_AXI_BREADY;
  wire [1:0]smartconnect_1_M00_AXI_BRESP;
  wire smartconnect_1_M00_AXI_BVALID;
  wire [127:0]smartconnect_1_M00_AXI_RDATA;
  wire smartconnect_1_M00_AXI_RLAST;
  wire smartconnect_1_M00_AXI_RREADY;
  wire [1:0]smartconnect_1_M00_AXI_RRESP;
  wire smartconnect_1_M00_AXI_RVALID;
  wire [127:0]smartconnect_1_M00_AXI_WDATA;
  wire smartconnect_1_M00_AXI_WLAST;
  wire smartconnect_1_M00_AXI_WREADY;
  wire [15:0]smartconnect_1_M00_AXI_WSTRB;
  wire smartconnect_1_M00_AXI_WVALID;
  wire som240_1_connector_hpa_clk0p_clk_1;
  wire [31:0]tx_header_inserter_0_m_axis_TDATA;
  wire [3:0]tx_header_inserter_0_m_axis_TKEEP;
  wire tx_header_inserter_0_m_axis_TLAST;
  wire tx_header_inserter_0_m_axis_TREADY;
  wire tx_header_inserter_0_m_axis_TVALID;
  wire [15:0]tx_header_inserter_0_rdma_sodir_length;
  wire tx_header_inserter_0_start;
  wire tx_header_inserter_0_tx_busy;
  wire tx_header_inserter_0_tx_done;
  wire [15:0]tx_streamer_0_hdr_fragment_id;
  wire [15:0]tx_streamer_0_hdr_fragment_offset;
  wire tx_streamer_0_hdr_more_fragments;
  wire [23:0]tx_streamer_0_hdr_rdma_dest_qp;
  wire [31:0]tx_streamer_0_hdr_rdma_length;
  wire [7:0]tx_streamer_0_hdr_rdma_opcode;
  wire [15:0]tx_streamer_0_hdr_rdma_partition_key;
  wire [23:0]tx_streamer_0_hdr_rdma_psn;
  wire [63:0]tx_streamer_0_hdr_rdma_remote_addr;
  wire [31:0]tx_streamer_0_hdr_rdma_rkey;
  wire [7:0]tx_streamer_0_hdr_rdma_service_level;
  wire tx_streamer_0_hdr_start_tx;
  wire [71:0]tx_streamer_0_m_axis_mm2s_cmd_tdata;
  wire tx_streamer_0_m_axis_mm2s_cmd_tvalid;
  wire tx_streamer_0_tx_cmd_ready;
  wire [31:0]tx_streamer_0_tx_cpl_bytes_sent;
  wire [7:0]tx_streamer_0_tx_cpl_sq_index;
  wire [7:0]tx_streamer_0_tx_cpl_status;
  wire tx_streamer_0_tx_cpl_valid;
  wire [0:0]xlconstant_0_dout;
  wire [3:0]xlconstant_1_dout;
  wire [0:0]xlconstant_2_dout;
  wire [0:0]xlconstant_3_dout;
  wire [0:0]xlconstant_4_dout;
  wire [0:0]xlconstant_5_dout;
  wire [39:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARADDR;
  wire [1:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARBURST;
  wire [3:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARCACHE;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARID;
  wire [7:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARLEN;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARLOCK;
  wire [2:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARPROT;
  wire [3:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARQOS;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARREADY;
  wire [2:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARSIZE;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARUSER;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARVALID;
  wire [39:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWADDR;
  wire [1:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWBURST;
  wire [3:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWCACHE;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWID;
  wire [7:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWLEN;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWLOCK;
  wire [2:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWPROT;
  wire [3:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWQOS;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWREADY;
  wire [2:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWSIZE;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWUSER;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWVALID;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BID;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BREADY;
  wire [1:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BRESP;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BVALID;
  wire [127:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RDATA;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RID;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RLAST;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RREADY;
  wire [1:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RRESP;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RVALID;
  wire [127:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WDATA;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WLAST;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WREADY;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WSTRB;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WVALID;
  wire zynq_ultra_ps_e_0_pl_clk0;
  wire zynq_ultra_ps_e_0_pl_resetn0;

  assign axi_ethernet_1_mdio_MDIO_I = som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdio_i;
  assign axi_ethernet_1_rgmii_RD = som240_2_connector_pl_gem3_rgmii_rd[3:0];
  assign axi_ethernet_1_rgmii_RXC = som240_2_connector_pl_gem3_rgmii_rxc;
  assign axi_ethernet_1_rgmii_RX_CTL = som240_2_connector_pl_gem3_rgmii_rx_ctl;
  assign som240_1_connector_hpa_clk0p_clk_1 = som240_1_connector_hpa_clk0p_clk;
  assign som240_2_connector_pl_gem3_reset[0] = axi_ethernet_1_phy_rst_n;
  assign som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdc = axi_ethernet_1_mdio_MDC;
  assign som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdio_o = axi_ethernet_1_mdio_MDIO_O;
  assign som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdio_t = axi_ethernet_1_mdio_MDIO_T;
  assign som240_2_connector_pl_gem3_rgmii_td[3:0] = axi_ethernet_1_rgmii_TD;
  assign som240_2_connector_pl_gem3_rgmii_tx_ctl = axi_ethernet_1_rgmii_TX_CTL;
  assign som240_2_connector_pl_gem3_rgmii_txc = axi_ethernet_1_rgmii_TXC;
  design_1_axi_bram_ctrl_0_0 axi_bram_ctrl_0
       (.bram_addr_a(axi_bram_ctrl_0_BRAM_PORTA_ADDR),
        .bram_clk_a(axi_bram_ctrl_0_BRAM_PORTA_CLK),
        .bram_en_a(axi_bram_ctrl_0_BRAM_PORTA_EN),
        .bram_rddata_a(axi_bram_ctrl_0_BRAM_PORTA_DOUT),
        .bram_rst_a(axi_bram_ctrl_0_BRAM_PORTA_RST),
        .bram_we_a(axi_bram_ctrl_0_BRAM_PORTA_WE),
        .bram_wrdata_a(axi_bram_ctrl_0_BRAM_PORTA_DIN),
        .s_axi_aclk(zynq_ultra_ps_e_0_pl_clk0),
        .s_axi_araddr(smartconnect_0_M00_AXI_ARADDR),
        .s_axi_arburst(smartconnect_0_M00_AXI_ARBURST),
        .s_axi_arcache(smartconnect_0_M00_AXI_ARCACHE),
        .s_axi_aresetn(rst_ps8_0_99M_peripheral_aresetn),
        .s_axi_arlen(smartconnect_0_M00_AXI_ARLEN),
        .s_axi_arlock(smartconnect_0_M00_AXI_ARLOCK),
        .s_axi_arprot(smartconnect_0_M00_AXI_ARPROT),
        .s_axi_arready(smartconnect_0_M00_AXI_ARREADY),
        .s_axi_arsize(smartconnect_0_M00_AXI_ARSIZE),
        .s_axi_arvalid(smartconnect_0_M00_AXI_ARVALID),
        .s_axi_awaddr(smartconnect_0_M00_AXI_AWADDR),
        .s_axi_awburst(smartconnect_0_M00_AXI_AWBURST),
        .s_axi_awcache(smartconnect_0_M00_AXI_AWCACHE),
        .s_axi_awlen(smartconnect_0_M00_AXI_AWLEN),
        .s_axi_awlock(smartconnect_0_M00_AXI_AWLOCK),
        .s_axi_awprot(smartconnect_0_M00_AXI_AWPROT),
        .s_axi_awready(smartconnect_0_M00_AXI_AWREADY),
        .s_axi_awsize(smartconnect_0_M00_AXI_AWSIZE),
        .s_axi_awvalid(smartconnect_0_M00_AXI_AWVALID),
        .s_axi_bready(smartconnect_0_M00_AXI_BREADY),
        .s_axi_bresp(smartconnect_0_M00_AXI_BRESP),
        .s_axi_bvalid(smartconnect_0_M00_AXI_BVALID),
        .s_axi_rdata(smartconnect_0_M00_AXI_RDATA),
        .s_axi_rlast(smartconnect_0_M00_AXI_RLAST),
        .s_axi_rready(smartconnect_0_M00_AXI_RREADY),
        .s_axi_rresp(smartconnect_0_M00_AXI_RRESP),
        .s_axi_rvalid(smartconnect_0_M00_AXI_RVALID),
        .s_axi_wdata(smartconnect_0_M00_AXI_WDATA),
        .s_axi_wlast(smartconnect_0_M00_AXI_WLAST),
        .s_axi_wready(smartconnect_0_M00_AXI_WREADY),
        .s_axi_wstrb(smartconnect_0_M00_AXI_WSTRB),
        .s_axi_wvalid(smartconnect_0_M00_AXI_WVALID));
  design_1_axi_datamover_0_0 axi_datamover_0
       (.m_axi_mm2s_aclk(zynq_ultra_ps_e_0_pl_clk0),
        .m_axi_mm2s_araddr(axi_datamover_0_M_AXI_MM2S_ARADDR),
        .m_axi_mm2s_arburst(axi_datamover_0_M_AXI_MM2S_ARBURST),
        .m_axi_mm2s_arcache(axi_datamover_0_M_AXI_MM2S_ARCACHE),
        .m_axi_mm2s_aresetn(rst_ps8_0_99M_peripheral_aresetn1),
        .m_axi_mm2s_arid(axi_datamover_0_M_AXI_MM2S_ARID),
        .m_axi_mm2s_arlen(axi_datamover_0_M_AXI_MM2S_ARLEN),
        .m_axi_mm2s_arprot(axi_datamover_0_M_AXI_MM2S_ARPROT),
        .m_axi_mm2s_arready(axi_datamover_0_M_AXI_MM2S_ARREADY),
        .m_axi_mm2s_arsize(axi_datamover_0_M_AXI_MM2S_ARSIZE),
        .m_axi_mm2s_aruser(axi_datamover_0_M_AXI_MM2S_ARUSER),
        .m_axi_mm2s_arvalid(axi_datamover_0_M_AXI_MM2S_ARVALID),
        .m_axi_mm2s_rdata(axi_datamover_0_M_AXI_MM2S_RDATA),
        .m_axi_mm2s_rlast(axi_datamover_0_M_AXI_MM2S_RLAST),
        .m_axi_mm2s_rready(axi_datamover_0_M_AXI_MM2S_RREADY),
        .m_axi_mm2s_rresp(axi_datamover_0_M_AXI_MM2S_RRESP),
        .m_axi_mm2s_rvalid(axi_datamover_0_M_AXI_MM2S_RVALID),
        .m_axi_s2mm_aclk(zynq_ultra_ps_e_0_pl_clk0),
        .m_axi_s2mm_aresetn(rst_ps8_0_99M_peripheral_aresetn1),
        .m_axi_s2mm_awaddr(axi_datamover_0_M_AXI_S2MM_AWADDR),
        .m_axi_s2mm_awburst(axi_datamover_0_M_AXI_S2MM_AWBURST),
        .m_axi_s2mm_awcache(axi_datamover_0_M_AXI_S2MM_AWCACHE),
        .m_axi_s2mm_awid(axi_datamover_0_M_AXI_S2MM_AWID),
        .m_axi_s2mm_awlen(axi_datamover_0_M_AXI_S2MM_AWLEN),
        .m_axi_s2mm_awprot(axi_datamover_0_M_AXI_S2MM_AWPROT),
        .m_axi_s2mm_awready(axi_datamover_0_M_AXI_S2MM_AWREADY),
        .m_axi_s2mm_awsize(axi_datamover_0_M_AXI_S2MM_AWSIZE),
        .m_axi_s2mm_awuser(axi_datamover_0_M_AXI_S2MM_AWUSER),
        .m_axi_s2mm_awvalid(axi_datamover_0_M_AXI_S2MM_AWVALID),
        .m_axi_s2mm_bready(axi_datamover_0_M_AXI_S2MM_BREADY),
        .m_axi_s2mm_bresp(axi_datamover_0_M_AXI_S2MM_BRESP),
        .m_axi_s2mm_bvalid(axi_datamover_0_M_AXI_S2MM_BVALID),
        .m_axi_s2mm_wdata(axi_datamover_0_M_AXI_S2MM_WDATA),
        .m_axi_s2mm_wlast(axi_datamover_0_M_AXI_S2MM_WLAST),
        .m_axi_s2mm_wready(axi_datamover_0_M_AXI_S2MM_WREADY),
        .m_axi_s2mm_wstrb(axi_datamover_0_M_AXI_S2MM_WSTRB),
        .m_axi_s2mm_wvalid(axi_datamover_0_M_AXI_S2MM_WVALID),
        .m_axis_mm2s_cmdsts_aclk(zynq_ultra_ps_e_0_pl_clk0),
        .m_axis_mm2s_cmdsts_aresetn(rst_ps8_0_99M_peripheral_aresetn1),
        .m_axis_mm2s_sts_tready(1'b1),
        .m_axis_mm2s_tdata(axi_datamover_0_M_AXIS_MM2S_TDATA),
        .m_axis_mm2s_tlast(axi_datamover_0_M_AXIS_MM2S_TLAST),
        .m_axis_mm2s_tready(axi_datamover_0_M_AXIS_MM2S_TREADY),
        .m_axis_mm2s_tvalid(axi_datamover_0_M_AXIS_MM2S_TVALID),
        .m_axis_s2mm_cmdsts_aresetn(rst_ps8_0_99M_peripheral_aresetn1),
        .m_axis_s2mm_cmdsts_awclk(zynq_ultra_ps_e_0_pl_clk0),
        .m_axis_s2mm_sts_tready(1'b1),
        .mm2s_allow_addr_req(1'b1),
        .mm2s_dbg_sel({1'b0,1'b0,1'b0,1'b0}),
        .mm2s_halt(1'b0),
        .mm2s_rd_xfer_cmplt(axi_datamover_0_mm2s_rd_xfer_cmplt),
        .s2mm_allow_addr_req(xlconstant_0_dout),
        .s2mm_dbg_sel({1'b0,1'b0,1'b0,1'b0}),
        .s2mm_halt(1'b0),
        .s2mm_wr_xfer_cmplt(axi_datamover_0_s2mm_wr_xfer_cmplt),
        .s_axis_mm2s_cmd_tdata(data_mover_controller_0_m_axis_mm2s_cmd_tdata),
        .s_axis_mm2s_cmd_tvalid(data_mover_controller_0_m_axis_mm2s_cmd_tvalid),
        .s_axis_s2mm_cmd_tdata(data_mover_controller_0_m_axis_s2mm_cmd_tdata),
        .s_axis_s2mm_cmd_tvalid(data_mover_controller_0_m_axis_s2mm_cmd_tvalid),
        .s_axis_s2mm_tdata(data_mover_controller_0_m00_axis_tdata),
        .s_axis_s2mm_tkeep(xlconstant_1_dout),
        .s_axis_s2mm_tlast(data_mover_controller_0_m00_axis_tlast),
        .s_axis_s2mm_tready(axi_datamover_0_s_axis_s2mm_tready),
        .s_axis_s2mm_tvalid(data_mover_controller_0_m00_axis_tvalid));
  design_1_axi_datamover_1_0 axi_datamover_1
       (.m_axi_mm2s_aclk(zynq_ultra_ps_e_0_pl_clk0),
        .m_axi_mm2s_araddr(axi_datamover_1_M_AXI_MM2S_ARADDR),
        .m_axi_mm2s_arburst(axi_datamover_1_M_AXI_MM2S_ARBURST),
        .m_axi_mm2s_arcache(axi_datamover_1_M_AXI_MM2S_ARCACHE),
        .m_axi_mm2s_aresetn(rst_ps8_0_99M_peripheral_aresetn1),
        .m_axi_mm2s_arid(axi_datamover_1_M_AXI_MM2S_ARID),
        .m_axi_mm2s_arlen(axi_datamover_1_M_AXI_MM2S_ARLEN),
        .m_axi_mm2s_arprot(axi_datamover_1_M_AXI_MM2S_ARPROT),
        .m_axi_mm2s_arready(axi_datamover_1_M_AXI_MM2S_ARREADY),
        .m_axi_mm2s_arsize(axi_datamover_1_M_AXI_MM2S_ARSIZE),
        .m_axi_mm2s_aruser(axi_datamover_1_M_AXI_MM2S_ARUSER),
        .m_axi_mm2s_arvalid(axi_datamover_1_M_AXI_MM2S_ARVALID),
        .m_axi_mm2s_rdata(axi_datamover_1_M_AXI_MM2S_RDATA),
        .m_axi_mm2s_rlast(axi_datamover_1_M_AXI_MM2S_RLAST),
        .m_axi_mm2s_rready(axi_datamover_1_M_AXI_MM2S_RREADY),
        .m_axi_mm2s_rresp(axi_datamover_1_M_AXI_MM2S_RRESP),
        .m_axi_mm2s_rvalid(axi_datamover_1_M_AXI_MM2S_RVALID),
        .m_axi_s2mm_aclk(zynq_ultra_ps_e_0_pl_clk0),
        .m_axi_s2mm_aresetn(rst_ps8_0_99M_peripheral_aresetn1),
        .m_axi_s2mm_awaddr(axi_datamover_1_M_AXI_S2MM_AWADDR),
        .m_axi_s2mm_awburst(axi_datamover_1_M_AXI_S2MM_AWBURST),
        .m_axi_s2mm_awcache(axi_datamover_1_M_AXI_S2MM_AWCACHE),
        .m_axi_s2mm_awid(axi_datamover_1_M_AXI_S2MM_AWID),
        .m_axi_s2mm_awlen(axi_datamover_1_M_AXI_S2MM_AWLEN),
        .m_axi_s2mm_awprot(axi_datamover_1_M_AXI_S2MM_AWPROT),
        .m_axi_s2mm_awready(axi_datamover_1_M_AXI_S2MM_AWREADY),
        .m_axi_s2mm_awsize(axi_datamover_1_M_AXI_S2MM_AWSIZE),
        .m_axi_s2mm_awuser(axi_datamover_1_M_AXI_S2MM_AWUSER),
        .m_axi_s2mm_awvalid(axi_datamover_1_M_AXI_S2MM_AWVALID),
        .m_axi_s2mm_bready(axi_datamover_1_M_AXI_S2MM_BREADY),
        .m_axi_s2mm_bresp(axi_datamover_1_M_AXI_S2MM_BRESP),
        .m_axi_s2mm_bvalid(axi_datamover_1_M_AXI_S2MM_BVALID),
        .m_axi_s2mm_wdata(axi_datamover_1_M_AXI_S2MM_WDATA),
        .m_axi_s2mm_wlast(axi_datamover_1_M_AXI_S2MM_WLAST),
        .m_axi_s2mm_wready(axi_datamover_1_M_AXI_S2MM_WREADY),
        .m_axi_s2mm_wstrb(axi_datamover_1_M_AXI_S2MM_WSTRB),
        .m_axi_s2mm_wvalid(axi_datamover_1_M_AXI_S2MM_WVALID),
        .m_axis_mm2s_cmdsts_aclk(zynq_ultra_ps_e_0_pl_clk0),
        .m_axis_mm2s_cmdsts_aresetn(rst_ps8_0_99M_peripheral_aresetn1),
        .m_axis_mm2s_sts_tready(1'b1),
        .m_axis_mm2s_tdata(axi_datamover_1_M_AXIS_MM2S_TDATA),
        .m_axis_mm2s_tkeep(axi_datamover_1_M_AXIS_MM2S_TKEEP),
        .m_axis_mm2s_tlast(axi_datamover_1_M_AXIS_MM2S_TLAST),
        .m_axis_mm2s_tready(axi_datamover_1_M_AXIS_MM2S_TREADY),
        .m_axis_mm2s_tvalid(axi_datamover_1_M_AXIS_MM2S_TVALID),
        .m_axis_s2mm_cmdsts_aresetn(rst_ps8_0_99M_peripheral_aresetn1),
        .m_axis_s2mm_cmdsts_awclk(zynq_ultra_ps_e_0_pl_clk0),
        .m_axis_s2mm_sts_tready(1'b1),
        .mm2s_allow_addr_req(xlconstant_4_dout),
        .mm2s_dbg_sel({1'b0,1'b0,1'b0,1'b0}),
        .mm2s_halt(1'b0),
        .mm2s_rd_xfer_cmplt(axi_datamover_1_mm2s_rd_xfer_cmplt),
        .s2mm_allow_addr_req(xlconstant_3_dout),
        .s2mm_dbg_sel({1'b0,1'b0,1'b0,1'b0}),
        .s2mm_halt(1'b0),
        .s_axis_mm2s_cmd_tdata(tx_streamer_0_m_axis_mm2s_cmd_tdata),
        .s_axis_mm2s_cmd_tready(axi_datamover_1_s_axis_mm2s_cmd_tready),
        .s_axis_mm2s_cmd_tvalid(tx_streamer_0_m_axis_mm2s_cmd_tvalid),
        .s_axis_s2mm_cmd_tdata({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axis_s2mm_cmd_tvalid(1'b0),
        .s_axis_s2mm_tdata({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .s_axis_s2mm_tkeep({1'b1,1'b1,1'b1,1'b1}),
        .s_axis_s2mm_tlast(1'b0),
        .s_axis_s2mm_tvalid(1'b0));
  design_1_axi_ethernet_0_refclk_0 axi_ethernet_0_refclk
       (.clk_in1(som240_1_connector_hpa_clk0p_clk_1),
        .clk_out1(axi_ethernet_0_refclk_clk_out1),
        .clk_out2(axi_ethernet_0_refclk_clk_out2));
  design_1_axi_ethernet_1_0 axi_ethernet_1
       (.axi_rxd_arstn(rst_ps8_0_99M_peripheral_aresetn1),
        .axi_rxs_arstn(rst_ps8_0_99M_peripheral_aresetn1),
        .axi_txc_arstn(rst_ps8_0_99M_peripheral_aresetn1),
        .axi_txd_arstn(rst_ps8_0_99M_peripheral_aresetn1),
        .axis_clk(zynq_ultra_ps_e_0_pl_clk0),
        .gtx_clk(axi_ethernet_0_refclk_clk_out2),
        .m_axis_rxd_tready(1'b1),
        .m_axis_rxs_tready(1'b1),
        .mdio_mdc(axi_ethernet_1_mdio_MDC),
        .mdio_mdio_i(axi_ethernet_1_mdio_MDIO_I),
        .mdio_mdio_o(axi_ethernet_1_mdio_MDIO_O),
        .mdio_mdio_t(axi_ethernet_1_mdio_MDIO_T),
        .phy_rst_n(axi_ethernet_1_phy_rst_n),
        .ref_clk(axi_ethernet_0_refclk_clk_out1),
        .rgmii_rd(axi_ethernet_1_rgmii_RD),
        .rgmii_rx_ctl(axi_ethernet_1_rgmii_RX_CTL),
        .rgmii_rxc(axi_ethernet_1_rgmii_RXC),
        .rgmii_td(axi_ethernet_1_rgmii_TD),
        .rgmii_tx_ctl(axi_ethernet_1_rgmii_TX_CTL),
        .rgmii_txc(axi_ethernet_1_rgmii_TXC),
        .s_axi_araddr(axi_interconnect_0_M00_AXI_ARADDR[17:0]),
        .s_axi_arready(axi_interconnect_0_M00_AXI_ARREADY),
        .s_axi_arvalid(axi_interconnect_0_M00_AXI_ARVALID),
        .s_axi_awaddr(axi_interconnect_0_M00_AXI_AWADDR[17:0]),
        .s_axi_awready(axi_interconnect_0_M00_AXI_AWREADY),
        .s_axi_awvalid(axi_interconnect_0_M00_AXI_AWVALID),
        .s_axi_bready(axi_interconnect_0_M00_AXI_BREADY),
        .s_axi_bresp(axi_interconnect_0_M00_AXI_BRESP),
        .s_axi_bvalid(axi_interconnect_0_M00_AXI_BVALID),
        .s_axi_lite_clk(zynq_ultra_ps_e_0_pl_clk0),
        .s_axi_lite_resetn(rst_ps8_0_99M_peripheral_aresetn1),
        .s_axi_rdata(axi_interconnect_0_M00_AXI_RDATA),
        .s_axi_rready(axi_interconnect_0_M00_AXI_RREADY),
        .s_axi_rresp(axi_interconnect_0_M00_AXI_RRESP),
        .s_axi_rvalid(axi_interconnect_0_M00_AXI_RVALID),
        .s_axi_wdata(axi_interconnect_0_M00_AXI_WDATA),
        .s_axi_wready(axi_interconnect_0_M00_AXI_WREADY),
        .s_axi_wstrb(axi_interconnect_0_M00_AXI_WSTRB),
        .s_axi_wvalid(axi_interconnect_0_M00_AXI_WVALID),
        .s_axis_txc_tdata(eth_pkt_gen_0_m_axis_txc_data),
        .s_axis_txc_tkeep(eth_pkt_gen_0_m_axis_txc_keep),
        .s_axis_txc_tlast(eth_pkt_gen_0_m_axis_txc_last),
        .s_axis_txc_tready(axi_ethernet_1_s_axis_txc_tready),
        .s_axis_txc_tvalid(eth_pkt_gen_0_m_axis_txc_valid),
        .s_axis_txd_tdata(eth_pkt_gen_0_m_axis_TDATA),
        .s_axis_txd_tkeep(eth_pkt_gen_0_m_axis_TKEEP),
        .s_axis_txd_tlast(eth_pkt_gen_0_m_axis_TLAST),
        .s_axis_txd_tready(eth_pkt_gen_0_m_axis_TREADY),
        .s_axis_txd_tvalid(eth_pkt_gen_0_m_axis_TVALID));
  design_1_axi_interconnect_0_1 axi_interconnect_0
       (.ACLK(zynq_ultra_ps_e_0_pl_clk0),
        .ARESETN(rst_ps8_0_99M_peripheral_aresetn1),
        .M00_ACLK(zynq_ultra_ps_e_0_pl_clk0),
        .M00_ARESETN(rst_ps8_0_99M_peripheral_aresetn1),
        .M00_AXI_araddr(axi_interconnect_0_M00_AXI_ARADDR),
        .M00_AXI_arready(axi_interconnect_0_M00_AXI_ARREADY),
        .M00_AXI_arvalid(axi_interconnect_0_M00_AXI_ARVALID),
        .M00_AXI_awaddr(axi_interconnect_0_M00_AXI_AWADDR),
        .M00_AXI_awready(axi_interconnect_0_M00_AXI_AWREADY),
        .M00_AXI_awvalid(axi_interconnect_0_M00_AXI_AWVALID),
        .M00_AXI_bready(axi_interconnect_0_M00_AXI_BREADY),
        .M00_AXI_bresp(axi_interconnect_0_M00_AXI_BRESP),
        .M00_AXI_bvalid(axi_interconnect_0_M00_AXI_BVALID),
        .M00_AXI_rdata(axi_interconnect_0_M00_AXI_RDATA),
        .M00_AXI_rready(axi_interconnect_0_M00_AXI_RREADY),
        .M00_AXI_rresp(axi_interconnect_0_M00_AXI_RRESP),
        .M00_AXI_rvalid(axi_interconnect_0_M00_AXI_RVALID),
        .M00_AXI_wdata(axi_interconnect_0_M00_AXI_WDATA),
        .M00_AXI_wready(axi_interconnect_0_M00_AXI_WREADY),
        .M00_AXI_wstrb(axi_interconnect_0_M00_AXI_WSTRB),
        .M00_AXI_wvalid(axi_interconnect_0_M00_AXI_WVALID),
        .S00_ACLK(zynq_ultra_ps_e_0_pl_clk0),
        .S00_ARESETN(rst_ps8_0_99M_peripheral_aresetn1),
        .S00_AXI_araddr(S00_AXI_1_ARADDR),
        .S00_AXI_arburst(S00_AXI_1_ARBURST),
        .S00_AXI_arcache(S00_AXI_1_ARCACHE),
        .S00_AXI_arid(S00_AXI_1_ARID),
        .S00_AXI_arlen(S00_AXI_1_ARLEN),
        .S00_AXI_arlock(S00_AXI_1_ARLOCK),
        .S00_AXI_arprot(S00_AXI_1_ARPROT),
        .S00_AXI_arqos(S00_AXI_1_ARQOS),
        .S00_AXI_arready(S00_AXI_1_ARREADY),
        .S00_AXI_arsize(S00_AXI_1_ARSIZE),
        .S00_AXI_arvalid(S00_AXI_1_ARVALID),
        .S00_AXI_awaddr(S00_AXI_1_AWADDR),
        .S00_AXI_awburst(S00_AXI_1_AWBURST),
        .S00_AXI_awcache(S00_AXI_1_AWCACHE),
        .S00_AXI_awid(S00_AXI_1_AWID),
        .S00_AXI_awlen(S00_AXI_1_AWLEN),
        .S00_AXI_awlock(S00_AXI_1_AWLOCK),
        .S00_AXI_awprot(S00_AXI_1_AWPROT),
        .S00_AXI_awqos(S00_AXI_1_AWQOS),
        .S00_AXI_awready(S00_AXI_1_AWREADY),
        .S00_AXI_awsize(S00_AXI_1_AWSIZE),
        .S00_AXI_awvalid(S00_AXI_1_AWVALID),
        .S00_AXI_bid(S00_AXI_1_BID),
        .S00_AXI_bready(S00_AXI_1_BREADY),
        .S00_AXI_bresp(S00_AXI_1_BRESP),
        .S00_AXI_bvalid(S00_AXI_1_BVALID),
        .S00_AXI_rdata(S00_AXI_1_RDATA),
        .S00_AXI_rid(S00_AXI_1_RID),
        .S00_AXI_rlast(S00_AXI_1_RLAST),
        .S00_AXI_rready(S00_AXI_1_RREADY),
        .S00_AXI_rresp(S00_AXI_1_RRESP),
        .S00_AXI_rvalid(S00_AXI_1_RVALID),
        .S00_AXI_wdata(S00_AXI_1_WDATA),
        .S00_AXI_wlast(S00_AXI_1_WLAST),
        .S00_AXI_wready(S00_AXI_1_WREADY),
        .S00_AXI_wstrb(S00_AXI_1_WSTRB),
        .S00_AXI_wvalid(S00_AXI_1_WVALID));
  design_1_axis_data_fifo_1_0 axis_data_fifo_1
       (.m_axis_tdata(axis_data_fifo_1_M_AXIS_TDATA),
        .m_axis_tkeep(axis_data_fifo_1_M_AXIS_TKEEP),
        .m_axis_tlast(axis_data_fifo_1_M_AXIS_TLAST),
        .m_axis_tready(axis_data_fifo_1_M_AXIS_TREADY),
        .m_axis_tvalid(axis_data_fifo_1_M_AXIS_TVALID),
        .s_axis_aclk(zynq_ultra_ps_e_0_pl_clk0),
        .s_axis_aresetn(rst_ps8_0_99M_peripheral_aresetn1),
        .s_axis_tdata(rdma_axilite_ctrl_0_m_axis_packet_TDATA),
        .s_axis_tkeep(rdma_axilite_ctrl_0_m_axis_packet_TKEEP),
        .s_axis_tlast(rdma_axilite_ctrl_0_m_axis_packet_TLAST),
        .s_axis_tready(rdma_axilite_ctrl_0_m_axis_packet_TREADY),
        .s_axis_tvalid(rdma_axilite_ctrl_0_m_axis_packet_TVALID));
  design_1_blk_mem_gen_0_0 blk_mem_gen_0
       (.addra({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,axi_bram_ctrl_0_BRAM_PORTA_ADDR}),
        .addrb({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .clka(axi_bram_ctrl_0_BRAM_PORTA_CLK),
        .clkb(zynq_ultra_ps_e_0_pl_clk0),
        .dina(axi_bram_ctrl_0_BRAM_PORTA_DIN),
        .dinb({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b1,1'b0,1'b0,1'b0}),
        .douta(axi_bram_ctrl_0_BRAM_PORTA_DOUT),
        .ena(axi_bram_ctrl_0_BRAM_PORTA_EN),
        .enb(1'b0),
        .rsta(axi_bram_ctrl_0_BRAM_PORTA_RST),
        .rstb(xlconstant_2_dout),
        .wea(axi_bram_ctrl_0_BRAM_PORTA_WE),
        .web({1'b0,1'b0,1'b0,1'b0}));
  design_1_data_mover_controller_0_0 data_mover_controller_0
       (.m00_axis_aclk(zynq_ultra_ps_e_0_pl_clk0),
        .m00_axis_aresetn(rst_ps8_0_99M_peripheral_aresetn1),
        .m00_axis_tdata(data_mover_controller_0_m00_axis_tdata),
        .m00_axis_tlast(data_mover_controller_0_m00_axis_tlast),
        .m00_axis_tready(axi_datamover_0_s_axis_s2mm_tready),
        .m00_axis_tvalid(data_mover_controller_0_m00_axis_tvalid),
        .m_axis_mm2s_cmd_tdata(data_mover_controller_0_m_axis_mm2s_cmd_tdata),
        .m_axis_mm2s_cmd_tvalid(data_mover_controller_0_m_axis_mm2s_cmd_tvalid),
        .m_axis_s2mm_cmd_tdata(data_mover_controller_0_m_axis_s2mm_cmd_tdata),
        .m_axis_s2mm_cmd_tvalid(data_mover_controller_0_m_axis_s2mm_cmd_tvalid),
        .mm2s_rd_xfer_cmplt(axi_datamover_0_mm2s_rd_xfer_cmplt),
        .s00_axi_aclk(zynq_ultra_ps_e_0_pl_clk0),
        .s00_axi_araddr(smartconnect_0_M01_AXI_ARADDR),
        .s00_axi_aresetn(rst_ps8_0_99M_peripheral_aresetn1),
        .s00_axi_arprot(smartconnect_0_M01_AXI_ARPROT),
        .s00_axi_arready(smartconnect_0_M01_AXI_ARREADY),
        .s00_axi_arvalid(smartconnect_0_M01_AXI_ARVALID),
        .s00_axi_awaddr(smartconnect_0_M01_AXI_AWADDR),
        .s00_axi_awprot(smartconnect_0_M01_AXI_AWPROT),
        .s00_axi_awready(smartconnect_0_M01_AXI_AWREADY),
        .s00_axi_awvalid(smartconnect_0_M01_AXI_AWVALID),
        .s00_axi_bready(smartconnect_0_M01_AXI_BREADY),
        .s00_axi_bresp(smartconnect_0_M01_AXI_BRESP),
        .s00_axi_bvalid(smartconnect_0_M01_AXI_BVALID),
        .s00_axi_rdata(smartconnect_0_M01_AXI_RDATA),
        .s00_axi_rready(smartconnect_0_M01_AXI_RREADY),
        .s00_axi_rresp(smartconnect_0_M01_AXI_RRESP),
        .s00_axi_rvalid(smartconnect_0_M01_AXI_RVALID),
        .s00_axi_wdata(smartconnect_0_M01_AXI_WDATA),
        .s00_axi_wready(smartconnect_0_M01_AXI_WREADY),
        .s00_axi_wstrb(smartconnect_0_M01_AXI_WSTRB),
        .s00_axi_wvalid(smartconnect_0_M01_AXI_WVALID),
        .s00_axis_aclk(zynq_ultra_ps_e_0_pl_clk0),
        .s00_axis_aresetn(rst_ps8_0_99M_peripheral_aresetn1),
        .s00_axis_tdata(axi_datamover_0_M_AXIS_MM2S_TDATA),
        .s00_axis_tlast(axi_datamover_0_M_AXIS_MM2S_TLAST),
        .s00_axis_tready(axi_datamover_0_M_AXIS_MM2S_TREADY),
        .s00_axis_tstrb({1'b1,1'b1,1'b1,1'b1}),
        .s00_axis_tvalid(axi_datamover_0_M_AXIS_MM2S_TVALID),
        .s2mm_wr_xfer_cmplt(axi_datamover_0_s2mm_wr_xfer_cmplt),
        .tx_cmd_ddr_addr(data_mover_controller_0_tx_cmd_ddr_addr),
        .tx_cmd_dest_qp(data_mover_controller_0_tx_cmd_dest_qp),
        .tx_cmd_length(data_mover_controller_0_tx_cmd_length),
        .tx_cmd_opcode(data_mover_controller_0_tx_cmd_opcode),
        .tx_cmd_partition_key(data_mover_controller_0_tx_cmd_partition_key),
        .tx_cmd_psn(data_mover_controller_0_tx_cmd_psn),
        .tx_cmd_ready(tx_streamer_0_tx_cmd_ready),
        .tx_cmd_remote_addr(data_mover_controller_0_tx_cmd_remote_addr),
        .tx_cmd_rkey(data_mover_controller_0_tx_cmd_rkey),
        .tx_cmd_service_level(data_mover_controller_0_tx_cmd_service_level),
        .tx_cmd_sq_index(data_mover_controller_0_tx_cmd_sq_index),
        .tx_cmd_valid(data_mover_controller_0_tx_cmd_valid),
        .tx_cpl_bytes_sent(tx_streamer_0_tx_cpl_bytes_sent),
        .tx_cpl_ready(data_mover_controller_0_tx_cpl_ready),
        .tx_cpl_sq_index(tx_streamer_0_tx_cpl_sq_index),
        .tx_cpl_status(tx_streamer_0_tx_cpl_status),
        .tx_cpl_valid(tx_streamer_0_tx_cpl_valid));
  design_1_eth_pkt_gen_0_0 eth_pkt_gen_0
       (.aclk(zynq_ultra_ps_e_0_pl_clk0),
        .aresetn(rst_ps8_0_99M_peripheral_aresetn1),
        .m_axis_tdata(eth_pkt_gen_0_m_axis_TDATA),
        .m_axis_tkeep(eth_pkt_gen_0_m_axis_TKEEP),
        .m_axis_tlast(eth_pkt_gen_0_m_axis_TLAST),
        .m_axis_tready(eth_pkt_gen_0_m_axis_TREADY),
        .m_axis_tvalid(eth_pkt_gen_0_m_axis_TVALID),
        .m_axis_txc_data(eth_pkt_gen_0_m_axis_txc_data),
        .m_axis_txc_keep(eth_pkt_gen_0_m_axis_txc_keep),
        .m_axis_txc_last(eth_pkt_gen_0_m_axis_txc_last),
        .m_axis_txc_ready(axi_ethernet_1_s_axis_txc_tready),
        .m_axis_txc_valid(eth_pkt_gen_0_m_axis_txc_valid),
        .s_axis_tdata(axis_data_fifo_1_M_AXIS_TDATA),
        .s_axis_tkeep(axis_data_fifo_1_M_AXIS_TKEEP),
        .s_axis_tlast(axis_data_fifo_1_M_AXIS_TLAST),
        .s_axis_tready(axis_data_fifo_1_M_AXIS_TREADY),
        .s_axis_tvalid(axis_data_fifo_1_M_AXIS_TVALID));
  design_1_rdma_axilite_ctrl_0_0 rdma_axilite_ctrl_0
       (.clk(zynq_ultra_ps_e_0_pl_clk0),
        .enable(xlconstant_5_dout),
        .m_axis_packet_tdata(rdma_axilite_ctrl_0_m_axis_packet_TDATA),
        .m_axis_packet_tkeep(rdma_axilite_ctrl_0_m_axis_packet_TKEEP),
        .m_axis_packet_tlast(rdma_axilite_ctrl_0_m_axis_packet_TLAST),
        .m_axis_packet_tready(rdma_axilite_ctrl_0_m_axis_packet_TREADY),
        .m_axis_packet_tvalid(rdma_axilite_ctrl_0_m_axis_packet_TVALID),
        .rdma_length(tx_header_inserter_0_rdma_sodir_length),
        .rst_n(rst_ps8_0_99M_peripheral_aresetn1),
        .s_axis_payload_tdata(tx_header_inserter_0_m_axis_TDATA),
        .s_axis_payload_tkeep(tx_header_inserter_0_m_axis_TKEEP),
        .s_axis_payload_tlast(tx_header_inserter_0_m_axis_TLAST),
        .s_axis_payload_tready(tx_header_inserter_0_m_axis_TREADY),
        .s_axis_payload_tvalid(tx_header_inserter_0_m_axis_TVALID),
        .start(tx_header_inserter_0_start));
  design_1_rst_ps8_0_99M_0 rst_ps8_0_99M
       (.aux_reset_in(1'b1),
        .dcm_locked(1'b1),
        .ext_reset_in(zynq_ultra_ps_e_0_pl_resetn0),
        .interconnect_aresetn(rst_ps8_0_99M_peripheral_aresetn),
        .mb_debug_sys_rst(1'b0),
        .peripheral_aresetn(rst_ps8_0_99M_peripheral_aresetn1),
        .slowest_sync_clk(zynq_ultra_ps_e_0_pl_clk0));
  design_1_smartconnect_0_0 smartconnect_0
       (.M00_AXI_araddr(smartconnect_0_M00_AXI_ARADDR),
        .M00_AXI_arburst(smartconnect_0_M00_AXI_ARBURST),
        .M00_AXI_arcache(smartconnect_0_M00_AXI_ARCACHE),
        .M00_AXI_arlen(smartconnect_0_M00_AXI_ARLEN),
        .M00_AXI_arlock(smartconnect_0_M00_AXI_ARLOCK),
        .M00_AXI_arprot(smartconnect_0_M00_AXI_ARPROT),
        .M00_AXI_arready(smartconnect_0_M00_AXI_ARREADY),
        .M00_AXI_arsize(smartconnect_0_M00_AXI_ARSIZE),
        .M00_AXI_arvalid(smartconnect_0_M00_AXI_ARVALID),
        .M00_AXI_awaddr(smartconnect_0_M00_AXI_AWADDR),
        .M00_AXI_awburst(smartconnect_0_M00_AXI_AWBURST),
        .M00_AXI_awcache(smartconnect_0_M00_AXI_AWCACHE),
        .M00_AXI_awlen(smartconnect_0_M00_AXI_AWLEN),
        .M00_AXI_awlock(smartconnect_0_M00_AXI_AWLOCK),
        .M00_AXI_awprot(smartconnect_0_M00_AXI_AWPROT),
        .M00_AXI_awready(smartconnect_0_M00_AXI_AWREADY),
        .M00_AXI_awsize(smartconnect_0_M00_AXI_AWSIZE),
        .M00_AXI_awvalid(smartconnect_0_M00_AXI_AWVALID),
        .M00_AXI_bready(smartconnect_0_M00_AXI_BREADY),
        .M00_AXI_bresp(smartconnect_0_M00_AXI_BRESP),
        .M00_AXI_bvalid(smartconnect_0_M00_AXI_BVALID),
        .M00_AXI_rdata(smartconnect_0_M00_AXI_RDATA),
        .M00_AXI_rlast(smartconnect_0_M00_AXI_RLAST),
        .M00_AXI_rready(smartconnect_0_M00_AXI_RREADY),
        .M00_AXI_rresp(smartconnect_0_M00_AXI_RRESP),
        .M00_AXI_rvalid(smartconnect_0_M00_AXI_RVALID),
        .M00_AXI_wdata(smartconnect_0_M00_AXI_WDATA),
        .M00_AXI_wlast(smartconnect_0_M00_AXI_WLAST),
        .M00_AXI_wready(smartconnect_0_M00_AXI_WREADY),
        .M00_AXI_wstrb(smartconnect_0_M00_AXI_WSTRB),
        .M00_AXI_wvalid(smartconnect_0_M00_AXI_WVALID),
        .M01_AXI_araddr(smartconnect_0_M01_AXI_ARADDR),
        .M01_AXI_arprot(smartconnect_0_M01_AXI_ARPROT),
        .M01_AXI_arready(smartconnect_0_M01_AXI_ARREADY),
        .M01_AXI_arvalid(smartconnect_0_M01_AXI_ARVALID),
        .M01_AXI_awaddr(smartconnect_0_M01_AXI_AWADDR),
        .M01_AXI_awprot(smartconnect_0_M01_AXI_AWPROT),
        .M01_AXI_awready(smartconnect_0_M01_AXI_AWREADY),
        .M01_AXI_awvalid(smartconnect_0_M01_AXI_AWVALID),
        .M01_AXI_bready(smartconnect_0_M01_AXI_BREADY),
        .M01_AXI_bresp(smartconnect_0_M01_AXI_BRESP),
        .M01_AXI_bvalid(smartconnect_0_M01_AXI_BVALID),
        .M01_AXI_rdata(smartconnect_0_M01_AXI_RDATA),
        .M01_AXI_rready(smartconnect_0_M01_AXI_RREADY),
        .M01_AXI_rresp(smartconnect_0_M01_AXI_RRESP),
        .M01_AXI_rvalid(smartconnect_0_M01_AXI_RVALID),
        .M01_AXI_wdata(smartconnect_0_M01_AXI_WDATA),
        .M01_AXI_wready(smartconnect_0_M01_AXI_WREADY),
        .M01_AXI_wstrb(smartconnect_0_M01_AXI_WSTRB),
        .M01_AXI_wvalid(smartconnect_0_M01_AXI_WVALID),
        .M02_AXI_araddr(smartconnect_0_M02_AXI_ARADDR),
        .M02_AXI_arburst(smartconnect_0_M02_AXI_ARBURST),
        .M02_AXI_arcache(smartconnect_0_M02_AXI_ARCACHE),
        .M02_AXI_arlen(smartconnect_0_M02_AXI_ARLEN),
        .M02_AXI_arlock(smartconnect_0_M02_AXI_ARLOCK),
        .M02_AXI_arprot(smartconnect_0_M02_AXI_ARPROT),
        .M02_AXI_arqos(smartconnect_0_M02_AXI_ARQOS),
        .M02_AXI_arready(smartconnect_0_M02_AXI_ARREADY),
        .M02_AXI_arsize(smartconnect_0_M02_AXI_ARSIZE),
        .M02_AXI_aruser(smartconnect_0_M02_AXI_ARUSER),
        .M02_AXI_arvalid(smartconnect_0_M02_AXI_ARVALID),
        .M02_AXI_awaddr(smartconnect_0_M02_AXI_AWADDR),
        .M02_AXI_awburst(smartconnect_0_M02_AXI_AWBURST),
        .M02_AXI_awcache(smartconnect_0_M02_AXI_AWCACHE),
        .M02_AXI_awlen(smartconnect_0_M02_AXI_AWLEN),
        .M02_AXI_awlock(smartconnect_0_M02_AXI_AWLOCK),
        .M02_AXI_awprot(smartconnect_0_M02_AXI_AWPROT),
        .M02_AXI_awqos(smartconnect_0_M02_AXI_AWQOS),
        .M02_AXI_awready(smartconnect_0_M02_AXI_AWREADY),
        .M02_AXI_awsize(smartconnect_0_M02_AXI_AWSIZE),
        .M02_AXI_awuser(smartconnect_0_M02_AXI_AWUSER),
        .M02_AXI_awvalid(smartconnect_0_M02_AXI_AWVALID),
        .M02_AXI_bready(smartconnect_0_M02_AXI_BREADY),
        .M02_AXI_bresp(smartconnect_0_M02_AXI_BRESP),
        .M02_AXI_bvalid(smartconnect_0_M02_AXI_BVALID),
        .M02_AXI_rdata(smartconnect_0_M02_AXI_RDATA),
        .M02_AXI_rlast(smartconnect_0_M02_AXI_RLAST),
        .M02_AXI_rready(smartconnect_0_M02_AXI_RREADY),
        .M02_AXI_rresp(smartconnect_0_M02_AXI_RRESP),
        .M02_AXI_rvalid(smartconnect_0_M02_AXI_RVALID),
        .M02_AXI_wdata(smartconnect_0_M02_AXI_WDATA),
        .M02_AXI_wlast(smartconnect_0_M02_AXI_WLAST),
        .M02_AXI_wready(smartconnect_0_M02_AXI_WREADY),
        .M02_AXI_wstrb(smartconnect_0_M02_AXI_WSTRB),
        .M02_AXI_wvalid(smartconnect_0_M02_AXI_WVALID),
        .S00_AXI_araddr(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARADDR),
        .S00_AXI_arburst(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARBURST),
        .S00_AXI_arcache(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARCACHE),
        .S00_AXI_arid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARID),
        .S00_AXI_arlen(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARLEN),
        .S00_AXI_arlock(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARLOCK),
        .S00_AXI_arprot(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARPROT),
        .S00_AXI_arqos(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARQOS),
        .S00_AXI_arready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARREADY),
        .S00_AXI_arsize(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARSIZE),
        .S00_AXI_aruser(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARUSER),
        .S00_AXI_arvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARVALID),
        .S00_AXI_awaddr(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWADDR),
        .S00_AXI_awburst(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWBURST),
        .S00_AXI_awcache(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWCACHE),
        .S00_AXI_awid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWID),
        .S00_AXI_awlen(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWLEN),
        .S00_AXI_awlock(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWLOCK),
        .S00_AXI_awprot(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWPROT),
        .S00_AXI_awqos(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWQOS),
        .S00_AXI_awready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWREADY),
        .S00_AXI_awsize(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWSIZE),
        .S00_AXI_awuser(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWUSER),
        .S00_AXI_awvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWVALID),
        .S00_AXI_bid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BID),
        .S00_AXI_bready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BREADY),
        .S00_AXI_bresp(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BRESP),
        .S00_AXI_bvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BVALID),
        .S00_AXI_rdata(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RDATA),
        .S00_AXI_rid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RID),
        .S00_AXI_rlast(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RLAST),
        .S00_AXI_rready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RREADY),
        .S00_AXI_rresp(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RRESP),
        .S00_AXI_rvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RVALID),
        .S00_AXI_wdata(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WDATA),
        .S00_AXI_wlast(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WLAST),
        .S00_AXI_wready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WREADY),
        .S00_AXI_wstrb(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WSTRB),
        .S00_AXI_wvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WVALID),
        .S01_AXI_araddr(axi_datamover_0_M_AXI_MM2S_ARADDR),
        .S01_AXI_arburst(axi_datamover_0_M_AXI_MM2S_ARBURST),
        .S01_AXI_arcache(axi_datamover_0_M_AXI_MM2S_ARCACHE),
        .S01_AXI_arid(axi_datamover_0_M_AXI_MM2S_ARID),
        .S01_AXI_arlen(axi_datamover_0_M_AXI_MM2S_ARLEN),
        .S01_AXI_arlock(1'b0),
        .S01_AXI_arprot(axi_datamover_0_M_AXI_MM2S_ARPROT),
        .S01_AXI_arqos({1'b0,1'b0,1'b0,1'b0}),
        .S01_AXI_arready(axi_datamover_0_M_AXI_MM2S_ARREADY),
        .S01_AXI_arsize(axi_datamover_0_M_AXI_MM2S_ARSIZE),
        .S01_AXI_aruser(axi_datamover_0_M_AXI_MM2S_ARUSER),
        .S01_AXI_arvalid(axi_datamover_0_M_AXI_MM2S_ARVALID),
        .S01_AXI_rdata(axi_datamover_0_M_AXI_MM2S_RDATA),
        .S01_AXI_rlast(axi_datamover_0_M_AXI_MM2S_RLAST),
        .S01_AXI_rready(axi_datamover_0_M_AXI_MM2S_RREADY),
        .S01_AXI_rresp(axi_datamover_0_M_AXI_MM2S_RRESP),
        .S01_AXI_rvalid(axi_datamover_0_M_AXI_MM2S_RVALID),
        .S02_AXI_awaddr(axi_datamover_0_M_AXI_S2MM_AWADDR),
        .S02_AXI_awburst(axi_datamover_0_M_AXI_S2MM_AWBURST),
        .S02_AXI_awcache(axi_datamover_0_M_AXI_S2MM_AWCACHE),
        .S02_AXI_awid(axi_datamover_0_M_AXI_S2MM_AWID),
        .S02_AXI_awlen(axi_datamover_0_M_AXI_S2MM_AWLEN),
        .S02_AXI_awlock(1'b0),
        .S02_AXI_awprot(axi_datamover_0_M_AXI_S2MM_AWPROT),
        .S02_AXI_awqos({1'b0,1'b0,1'b0,1'b0}),
        .S02_AXI_awready(axi_datamover_0_M_AXI_S2MM_AWREADY),
        .S02_AXI_awsize(axi_datamover_0_M_AXI_S2MM_AWSIZE),
        .S02_AXI_awuser(axi_datamover_0_M_AXI_S2MM_AWUSER),
        .S02_AXI_awvalid(axi_datamover_0_M_AXI_S2MM_AWVALID),
        .S02_AXI_bready(axi_datamover_0_M_AXI_S2MM_BREADY),
        .S02_AXI_bresp(axi_datamover_0_M_AXI_S2MM_BRESP),
        .S02_AXI_bvalid(axi_datamover_0_M_AXI_S2MM_BVALID),
        .S02_AXI_wdata(axi_datamover_0_M_AXI_S2MM_WDATA),
        .S02_AXI_wlast(axi_datamover_0_M_AXI_S2MM_WLAST),
        .S02_AXI_wready(axi_datamover_0_M_AXI_S2MM_WREADY),
        .S02_AXI_wstrb(axi_datamover_0_M_AXI_S2MM_WSTRB),
        .S02_AXI_wvalid(axi_datamover_0_M_AXI_S2MM_WVALID),
        .aclk(zynq_ultra_ps_e_0_pl_clk0),
        .aresetn(rst_ps8_0_99M_peripheral_aresetn));
  design_1_smartconnect_1_0 smartconnect_1
       (.M00_AXI_araddr(smartconnect_1_M00_AXI_ARADDR),
        .M00_AXI_arburst(smartconnect_1_M00_AXI_ARBURST),
        .M00_AXI_arcache(smartconnect_1_M00_AXI_ARCACHE),
        .M00_AXI_arlen(smartconnect_1_M00_AXI_ARLEN),
        .M00_AXI_arlock(smartconnect_1_M00_AXI_ARLOCK),
        .M00_AXI_arprot(smartconnect_1_M00_AXI_ARPROT),
        .M00_AXI_arqos(smartconnect_1_M00_AXI_ARQOS),
        .M00_AXI_arready(smartconnect_1_M00_AXI_ARREADY),
        .M00_AXI_arsize(smartconnect_1_M00_AXI_ARSIZE),
        .M00_AXI_aruser(smartconnect_1_M00_AXI_ARUSER),
        .M00_AXI_arvalid(smartconnect_1_M00_AXI_ARVALID),
        .M00_AXI_awaddr(smartconnect_1_M00_AXI_AWADDR),
        .M00_AXI_awburst(smartconnect_1_M00_AXI_AWBURST),
        .M00_AXI_awcache(smartconnect_1_M00_AXI_AWCACHE),
        .M00_AXI_awlen(smartconnect_1_M00_AXI_AWLEN),
        .M00_AXI_awlock(smartconnect_1_M00_AXI_AWLOCK),
        .M00_AXI_awprot(smartconnect_1_M00_AXI_AWPROT),
        .M00_AXI_awqos(smartconnect_1_M00_AXI_AWQOS),
        .M00_AXI_awready(smartconnect_1_M00_AXI_AWREADY),
        .M00_AXI_awsize(smartconnect_1_M00_AXI_AWSIZE),
        .M00_AXI_awuser(smartconnect_1_M00_AXI_AWUSER),
        .M00_AXI_awvalid(smartconnect_1_M00_AXI_AWVALID),
        .M00_AXI_bready(smartconnect_1_M00_AXI_BREADY),
        .M00_AXI_bresp(smartconnect_1_M00_AXI_BRESP),
        .M00_AXI_bvalid(smartconnect_1_M00_AXI_BVALID),
        .M00_AXI_rdata(smartconnect_1_M00_AXI_RDATA),
        .M00_AXI_rlast(smartconnect_1_M00_AXI_RLAST),
        .M00_AXI_rready(smartconnect_1_M00_AXI_RREADY),
        .M00_AXI_rresp(smartconnect_1_M00_AXI_RRESP),
        .M00_AXI_rvalid(smartconnect_1_M00_AXI_RVALID),
        .M00_AXI_wdata(smartconnect_1_M00_AXI_WDATA),
        .M00_AXI_wlast(smartconnect_1_M00_AXI_WLAST),
        .M00_AXI_wready(smartconnect_1_M00_AXI_WREADY),
        .M00_AXI_wstrb(smartconnect_1_M00_AXI_WSTRB),
        .M00_AXI_wvalid(smartconnect_1_M00_AXI_WVALID),
        .S00_AXI_araddr(axi_datamover_1_M_AXI_MM2S_ARADDR),
        .S00_AXI_arburst(axi_datamover_1_M_AXI_MM2S_ARBURST),
        .S00_AXI_arcache(axi_datamover_1_M_AXI_MM2S_ARCACHE),
        .S00_AXI_arid(axi_datamover_1_M_AXI_MM2S_ARID),
        .S00_AXI_arlen(axi_datamover_1_M_AXI_MM2S_ARLEN),
        .S00_AXI_arlock(1'b0),
        .S00_AXI_arprot(axi_datamover_1_M_AXI_MM2S_ARPROT),
        .S00_AXI_arqos({1'b0,1'b0,1'b0,1'b0}),
        .S00_AXI_arready(axi_datamover_1_M_AXI_MM2S_ARREADY),
        .S00_AXI_arsize(axi_datamover_1_M_AXI_MM2S_ARSIZE),
        .S00_AXI_aruser(axi_datamover_1_M_AXI_MM2S_ARUSER),
        .S00_AXI_arvalid(axi_datamover_1_M_AXI_MM2S_ARVALID),
        .S00_AXI_rdata(axi_datamover_1_M_AXI_MM2S_RDATA),
        .S00_AXI_rlast(axi_datamover_1_M_AXI_MM2S_RLAST),
        .S00_AXI_rready(axi_datamover_1_M_AXI_MM2S_RREADY),
        .S00_AXI_rresp(axi_datamover_1_M_AXI_MM2S_RRESP),
        .S00_AXI_rvalid(axi_datamover_1_M_AXI_MM2S_RVALID),
        .S01_AXI_awaddr(axi_datamover_1_M_AXI_S2MM_AWADDR),
        .S01_AXI_awburst(axi_datamover_1_M_AXI_S2MM_AWBURST),
        .S01_AXI_awcache(axi_datamover_1_M_AXI_S2MM_AWCACHE),
        .S01_AXI_awid(axi_datamover_1_M_AXI_S2MM_AWID),
        .S01_AXI_awlen(axi_datamover_1_M_AXI_S2MM_AWLEN),
        .S01_AXI_awlock(1'b0),
        .S01_AXI_awprot(axi_datamover_1_M_AXI_S2MM_AWPROT),
        .S01_AXI_awqos({1'b0,1'b0,1'b0,1'b0}),
        .S01_AXI_awready(axi_datamover_1_M_AXI_S2MM_AWREADY),
        .S01_AXI_awsize(axi_datamover_1_M_AXI_S2MM_AWSIZE),
        .S01_AXI_awuser(axi_datamover_1_M_AXI_S2MM_AWUSER),
        .S01_AXI_awvalid(axi_datamover_1_M_AXI_S2MM_AWVALID),
        .S01_AXI_bready(axi_datamover_1_M_AXI_S2MM_BREADY),
        .S01_AXI_bresp(axi_datamover_1_M_AXI_S2MM_BRESP),
        .S01_AXI_bvalid(axi_datamover_1_M_AXI_S2MM_BVALID),
        .S01_AXI_wdata(axi_datamover_1_M_AXI_S2MM_WDATA),
        .S01_AXI_wlast(axi_datamover_1_M_AXI_S2MM_WLAST),
        .S01_AXI_wready(axi_datamover_1_M_AXI_S2MM_WREADY),
        .S01_AXI_wstrb(axi_datamover_1_M_AXI_S2MM_WSTRB),
        .S01_AXI_wvalid(axi_datamover_1_M_AXI_S2MM_WVALID),
        .aclk(zynq_ultra_ps_e_0_pl_clk0),
        .aresetn(rst_ps8_0_99M_peripheral_aresetn1));
  design_1_tx_header_inserter_0_0 tx_header_inserter_0
       (.aclk(zynq_ultra_ps_e_0_pl_clk0),
        .aresetn(rst_ps8_0_99M_peripheral_aresetn1),
        .fragment_id(tx_streamer_0_hdr_fragment_id),
        .fragment_offset(tx_streamer_0_hdr_fragment_offset),
        .m_axis_tdata(tx_header_inserter_0_m_axis_TDATA),
        .m_axis_tkeep(tx_header_inserter_0_m_axis_TKEEP),
        .m_axis_tlast(tx_header_inserter_0_m_axis_TLAST),
        .m_axis_tready(tx_header_inserter_0_m_axis_TREADY),
        .m_axis_tvalid(tx_header_inserter_0_m_axis_TVALID),
        .more_fragments(tx_streamer_0_hdr_more_fragments),
        .rdma_dest_qp(tx_streamer_0_hdr_rdma_dest_qp),
        .rdma_length(tx_streamer_0_hdr_rdma_length),
        .rdma_opcode(tx_streamer_0_hdr_rdma_opcode),
        .rdma_partition_key(tx_streamer_0_hdr_rdma_partition_key),
        .rdma_psn(tx_streamer_0_hdr_rdma_psn),
        .rdma_remote_addr(tx_streamer_0_hdr_rdma_remote_addr),
        .rdma_rkey(tx_streamer_0_hdr_rdma_rkey),
        .rdma_service_level(tx_streamer_0_hdr_rdma_service_level),
        .rdma_sodir_length(tx_header_inserter_0_rdma_sodir_length),
        .s_axis_tdata(axi_datamover_1_M_AXIS_MM2S_TDATA),
        .s_axis_tkeep(axi_datamover_1_M_AXIS_MM2S_TKEEP),
        .s_axis_tlast(axi_datamover_1_M_AXIS_MM2S_TLAST),
        .s_axis_tready(axi_datamover_1_M_AXIS_MM2S_TREADY),
        .s_axis_tvalid(axi_datamover_1_M_AXIS_MM2S_TVALID),
        .start(tx_header_inserter_0_start),
        .start_tx(tx_streamer_0_hdr_start_tx),
        .tx_busy(tx_header_inserter_0_tx_busy),
        .tx_done(tx_header_inserter_0_tx_done));
  design_1_tx_streamer_0_0 tx_streamer_0
       (.aclk(zynq_ultra_ps_e_0_pl_clk0),
        .aresetn(rst_ps8_0_99M_peripheral_aresetn1),
        .hdr_fragment_id(tx_streamer_0_hdr_fragment_id),
        .hdr_fragment_offset(tx_streamer_0_hdr_fragment_offset),
        .hdr_more_fragments(tx_streamer_0_hdr_more_fragments),
        .hdr_rdma_dest_qp(tx_streamer_0_hdr_rdma_dest_qp),
        .hdr_rdma_length(tx_streamer_0_hdr_rdma_length),
        .hdr_rdma_opcode(tx_streamer_0_hdr_rdma_opcode),
        .hdr_rdma_partition_key(tx_streamer_0_hdr_rdma_partition_key),
        .hdr_rdma_psn(tx_streamer_0_hdr_rdma_psn),
        .hdr_rdma_remote_addr(tx_streamer_0_hdr_rdma_remote_addr),
        .hdr_rdma_rkey(tx_streamer_0_hdr_rdma_rkey),
        .hdr_rdma_service_level(tx_streamer_0_hdr_rdma_service_level),
        .hdr_start_tx(tx_streamer_0_hdr_start_tx),
        .hdr_tx_busy(tx_header_inserter_0_tx_busy),
        .hdr_tx_done(tx_header_inserter_0_tx_done),
        .m_axis_mm2s_cmd_tdata(tx_streamer_0_m_axis_mm2s_cmd_tdata),
        .m_axis_mm2s_cmd_tready(axi_datamover_1_s_axis_mm2s_cmd_tready),
        .m_axis_mm2s_cmd_tvalid(tx_streamer_0_m_axis_mm2s_cmd_tvalid),
        .mm2s_rd_xfer_cmplt(axi_datamover_1_mm2s_rd_xfer_cmplt),
        .tx_cmd_ddr_addr(data_mover_controller_0_tx_cmd_ddr_addr),
        .tx_cmd_dest_qp(data_mover_controller_0_tx_cmd_dest_qp),
        .tx_cmd_length(data_mover_controller_0_tx_cmd_length),
        .tx_cmd_opcode(data_mover_controller_0_tx_cmd_opcode),
        .tx_cmd_partition_key(data_mover_controller_0_tx_cmd_partition_key),
        .tx_cmd_psn(data_mover_controller_0_tx_cmd_psn),
        .tx_cmd_ready(tx_streamer_0_tx_cmd_ready),
        .tx_cmd_remote_addr(data_mover_controller_0_tx_cmd_remote_addr),
        .tx_cmd_rkey(data_mover_controller_0_tx_cmd_rkey),
        .tx_cmd_service_level(data_mover_controller_0_tx_cmd_service_level),
        .tx_cmd_sq_index(data_mover_controller_0_tx_cmd_sq_index),
        .tx_cmd_valid(data_mover_controller_0_tx_cmd_valid),
        .tx_cpl_bytes_sent(tx_streamer_0_tx_cpl_bytes_sent),
        .tx_cpl_ready(data_mover_controller_0_tx_cpl_ready),
        .tx_cpl_sq_index(tx_streamer_0_tx_cpl_sq_index),
        .tx_cpl_status(tx_streamer_0_tx_cpl_status),
        .tx_cpl_valid(tx_streamer_0_tx_cpl_valid));
  design_1_xlconstant_0_0 xlconstant_0
       (.dout(xlconstant_0_dout));
  design_1_xlconstant_1_0 xlconstant_1
       (.dout(xlconstant_1_dout));
  design_1_xlconstant_2_0 xlconstant_2
       (.dout(xlconstant_2_dout));
  design_1_xlconstant_3_0 xlconstant_3
       (.dout(xlconstant_3_dout));
  design_1_xlconstant_4_0 xlconstant_4
       (.dout(xlconstant_4_dout));
  design_1_xlconstant_5_0 xlconstant_5
       (.dout(xlconstant_5_dout));
  design_1_zynq_ultra_ps_e_0_0 zynq_ultra_ps_e_0
       (.maxigp0_araddr(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARADDR),
        .maxigp0_arburst(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARBURST),
        .maxigp0_arcache(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARCACHE),
        .maxigp0_arid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARID),
        .maxigp0_arlen(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARLEN),
        .maxigp0_arlock(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARLOCK),
        .maxigp0_arprot(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARPROT),
        .maxigp0_arqos(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARQOS),
        .maxigp0_arready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARREADY),
        .maxigp0_arsize(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARSIZE),
        .maxigp0_aruser(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARUSER),
        .maxigp0_arvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARVALID),
        .maxigp0_awaddr(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWADDR),
        .maxigp0_awburst(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWBURST),
        .maxigp0_awcache(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWCACHE),
        .maxigp0_awid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWID),
        .maxigp0_awlen(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWLEN),
        .maxigp0_awlock(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWLOCK),
        .maxigp0_awprot(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWPROT),
        .maxigp0_awqos(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWQOS),
        .maxigp0_awready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWREADY),
        .maxigp0_awsize(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWSIZE),
        .maxigp0_awuser(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWUSER),
        .maxigp0_awvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWVALID),
        .maxigp0_bid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BID),
        .maxigp0_bready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BREADY),
        .maxigp0_bresp(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BRESP),
        .maxigp0_bvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BVALID),
        .maxigp0_rdata(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RDATA),
        .maxigp0_rid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RID),
        .maxigp0_rlast(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RLAST),
        .maxigp0_rready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RREADY),
        .maxigp0_rresp(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RRESP),
        .maxigp0_rvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RVALID),
        .maxigp0_wdata(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WDATA),
        .maxigp0_wlast(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WLAST),
        .maxigp0_wready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WREADY),
        .maxigp0_wstrb(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WSTRB),
        .maxigp0_wvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WVALID),
        .maxigp2_araddr(S00_AXI_1_ARADDR),
        .maxigp2_arburst(S00_AXI_1_ARBURST),
        .maxigp2_arcache(S00_AXI_1_ARCACHE),
        .maxigp2_arid(S00_AXI_1_ARID),
        .maxigp2_arlen(S00_AXI_1_ARLEN),
        .maxigp2_arlock(S00_AXI_1_ARLOCK),
        .maxigp2_arprot(S00_AXI_1_ARPROT),
        .maxigp2_arqos(S00_AXI_1_ARQOS),
        .maxigp2_arready(S00_AXI_1_ARREADY),
        .maxigp2_arsize(S00_AXI_1_ARSIZE),
        .maxigp2_arvalid(S00_AXI_1_ARVALID),
        .maxigp2_awaddr(S00_AXI_1_AWADDR),
        .maxigp2_awburst(S00_AXI_1_AWBURST),
        .maxigp2_awcache(S00_AXI_1_AWCACHE),
        .maxigp2_awid(S00_AXI_1_AWID),
        .maxigp2_awlen(S00_AXI_1_AWLEN),
        .maxigp2_awlock(S00_AXI_1_AWLOCK),
        .maxigp2_awprot(S00_AXI_1_AWPROT),
        .maxigp2_awqos(S00_AXI_1_AWQOS),
        .maxigp2_awready(S00_AXI_1_AWREADY),
        .maxigp2_awsize(S00_AXI_1_AWSIZE),
        .maxigp2_awvalid(S00_AXI_1_AWVALID),
        .maxigp2_bid(S00_AXI_1_BID),
        .maxigp2_bready(S00_AXI_1_BREADY),
        .maxigp2_bresp(S00_AXI_1_BRESP),
        .maxigp2_bvalid(S00_AXI_1_BVALID),
        .maxigp2_rdata(S00_AXI_1_RDATA),
        .maxigp2_rid(S00_AXI_1_RID),
        .maxigp2_rlast(S00_AXI_1_RLAST),
        .maxigp2_rready(S00_AXI_1_RREADY),
        .maxigp2_rresp(S00_AXI_1_RRESP),
        .maxigp2_rvalid(S00_AXI_1_RVALID),
        .maxigp2_wdata(S00_AXI_1_WDATA),
        .maxigp2_wlast(S00_AXI_1_WLAST),
        .maxigp2_wready(S00_AXI_1_WREADY),
        .maxigp2_wstrb(S00_AXI_1_WSTRB),
        .maxigp2_wvalid(S00_AXI_1_WVALID),
        .maxihpm0_fpd_aclk(zynq_ultra_ps_e_0_pl_clk0),
        .maxihpm0_lpd_aclk(zynq_ultra_ps_e_0_pl_clk0),
        .pl_clk0(zynq_ultra_ps_e_0_pl_clk0),
        .pl_resetn0(zynq_ultra_ps_e_0_pl_resetn0),
        .saxigp0_araddr(smartconnect_0_M02_AXI_ARADDR),
        .saxigp0_arburst(smartconnect_0_M02_AXI_ARBURST),
        .saxigp0_arcache(smartconnect_0_M02_AXI_ARCACHE),
        .saxigp0_arid({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .saxigp0_arlen(smartconnect_0_M02_AXI_ARLEN),
        .saxigp0_arlock(smartconnect_0_M02_AXI_ARLOCK),
        .saxigp0_arprot(smartconnect_0_M02_AXI_ARPROT),
        .saxigp0_arqos(smartconnect_0_M02_AXI_ARQOS),
        .saxigp0_arready(smartconnect_0_M02_AXI_ARREADY),
        .saxigp0_arsize(smartconnect_0_M02_AXI_ARSIZE),
        .saxigp0_aruser(smartconnect_0_M02_AXI_ARUSER[0]),
        .saxigp0_arvalid(smartconnect_0_M02_AXI_ARVALID),
        .saxigp0_awaddr(smartconnect_0_M02_AXI_AWADDR),
        .saxigp0_awburst(smartconnect_0_M02_AXI_AWBURST),
        .saxigp0_awcache(smartconnect_0_M02_AXI_AWCACHE),
        .saxigp0_awid({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .saxigp0_awlen(smartconnect_0_M02_AXI_AWLEN),
        .saxigp0_awlock(smartconnect_0_M02_AXI_AWLOCK),
        .saxigp0_awprot(smartconnect_0_M02_AXI_AWPROT),
        .saxigp0_awqos(smartconnect_0_M02_AXI_AWQOS),
        .saxigp0_awready(smartconnect_0_M02_AXI_AWREADY),
        .saxigp0_awsize(smartconnect_0_M02_AXI_AWSIZE),
        .saxigp0_awuser(smartconnect_0_M02_AXI_AWUSER[0]),
        .saxigp0_awvalid(smartconnect_0_M02_AXI_AWVALID),
        .saxigp0_bready(smartconnect_0_M02_AXI_BREADY),
        .saxigp0_bresp(smartconnect_0_M02_AXI_BRESP),
        .saxigp0_bvalid(smartconnect_0_M02_AXI_BVALID),
        .saxigp0_rdata(smartconnect_0_M02_AXI_RDATA),
        .saxigp0_rlast(smartconnect_0_M02_AXI_RLAST),
        .saxigp0_rready(smartconnect_0_M02_AXI_RREADY),
        .saxigp0_rresp(smartconnect_0_M02_AXI_RRESP),
        .saxigp0_rvalid(smartconnect_0_M02_AXI_RVALID),
        .saxigp0_wdata(smartconnect_0_M02_AXI_WDATA),
        .saxigp0_wlast(smartconnect_0_M02_AXI_WLAST),
        .saxigp0_wready(smartconnect_0_M02_AXI_WREADY),
        .saxigp0_wstrb(smartconnect_0_M02_AXI_WSTRB),
        .saxigp0_wvalid(smartconnect_0_M02_AXI_WVALID),
        .saxigp1_araddr(smartconnect_1_M00_AXI_ARADDR),
        .saxigp1_arburst(smartconnect_1_M00_AXI_ARBURST),
        .saxigp1_arcache(smartconnect_1_M00_AXI_ARCACHE),
        .saxigp1_arid({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .saxigp1_arlen(smartconnect_1_M00_AXI_ARLEN),
        .saxigp1_arlock(smartconnect_1_M00_AXI_ARLOCK),
        .saxigp1_arprot(smartconnect_1_M00_AXI_ARPROT),
        .saxigp1_arqos(smartconnect_1_M00_AXI_ARQOS),
        .saxigp1_arready(smartconnect_1_M00_AXI_ARREADY),
        .saxigp1_arsize(smartconnect_1_M00_AXI_ARSIZE),
        .saxigp1_aruser(smartconnect_1_M00_AXI_ARUSER[0]),
        .saxigp1_arvalid(smartconnect_1_M00_AXI_ARVALID),
        .saxigp1_awaddr(smartconnect_1_M00_AXI_AWADDR),
        .saxigp1_awburst(smartconnect_1_M00_AXI_AWBURST),
        .saxigp1_awcache(smartconnect_1_M00_AXI_AWCACHE),
        .saxigp1_awid({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .saxigp1_awlen(smartconnect_1_M00_AXI_AWLEN),
        .saxigp1_awlock(smartconnect_1_M00_AXI_AWLOCK),
        .saxigp1_awprot(smartconnect_1_M00_AXI_AWPROT),
        .saxigp1_awqos(smartconnect_1_M00_AXI_AWQOS),
        .saxigp1_awready(smartconnect_1_M00_AXI_AWREADY),
        .saxigp1_awsize(smartconnect_1_M00_AXI_AWSIZE),
        .saxigp1_awuser(smartconnect_1_M00_AXI_AWUSER[0]),
        .saxigp1_awvalid(smartconnect_1_M00_AXI_AWVALID),
        .saxigp1_bready(smartconnect_1_M00_AXI_BREADY),
        .saxigp1_bresp(smartconnect_1_M00_AXI_BRESP),
        .saxigp1_bvalid(smartconnect_1_M00_AXI_BVALID),
        .saxigp1_rdata(smartconnect_1_M00_AXI_RDATA),
        .saxigp1_rlast(smartconnect_1_M00_AXI_RLAST),
        .saxigp1_rready(smartconnect_1_M00_AXI_RREADY),
        .saxigp1_rresp(smartconnect_1_M00_AXI_RRESP),
        .saxigp1_rvalid(smartconnect_1_M00_AXI_RVALID),
        .saxigp1_wdata(smartconnect_1_M00_AXI_WDATA),
        .saxigp1_wlast(smartconnect_1_M00_AXI_WLAST),
        .saxigp1_wready(smartconnect_1_M00_AXI_WREADY),
        .saxigp1_wstrb(smartconnect_1_M00_AXI_WSTRB),
        .saxigp1_wvalid(smartconnect_1_M00_AXI_WVALID),
        .saxihpc0_fpd_aclk(zynq_ultra_ps_e_0_pl_clk0),
        .saxihpc1_fpd_aclk(zynq_ultra_ps_e_0_pl_clk0));
endmodule

module design_1_axi_interconnect_0_1
   (ACLK,
    ARESETN,
    M00_ACLK,
    M00_ARESETN,
    M00_AXI_araddr,
    M00_AXI_arready,
    M00_AXI_arvalid,
    M00_AXI_awaddr,
    M00_AXI_awready,
    M00_AXI_awvalid,
    M00_AXI_bready,
    M00_AXI_bresp,
    M00_AXI_bvalid,
    M00_AXI_rdata,
    M00_AXI_rready,
    M00_AXI_rresp,
    M00_AXI_rvalid,
    M00_AXI_wdata,
    M00_AXI_wready,
    M00_AXI_wstrb,
    M00_AXI_wvalid,
    S00_ACLK,
    S00_ARESETN,
    S00_AXI_araddr,
    S00_AXI_arburst,
    S00_AXI_arcache,
    S00_AXI_arid,
    S00_AXI_arlen,
    S00_AXI_arlock,
    S00_AXI_arprot,
    S00_AXI_arqos,
    S00_AXI_arready,
    S00_AXI_arsize,
    S00_AXI_arvalid,
    S00_AXI_awaddr,
    S00_AXI_awburst,
    S00_AXI_awcache,
    S00_AXI_awid,
    S00_AXI_awlen,
    S00_AXI_awlock,
    S00_AXI_awprot,
    S00_AXI_awqos,
    S00_AXI_awready,
    S00_AXI_awsize,
    S00_AXI_awvalid,
    S00_AXI_bid,
    S00_AXI_bready,
    S00_AXI_bresp,
    S00_AXI_bvalid,
    S00_AXI_rdata,
    S00_AXI_rid,
    S00_AXI_rlast,
    S00_AXI_rready,
    S00_AXI_rresp,
    S00_AXI_rvalid,
    S00_AXI_wdata,
    S00_AXI_wlast,
    S00_AXI_wready,
    S00_AXI_wstrb,
    S00_AXI_wvalid);
  input ACLK;
  input ARESETN;
  input M00_ACLK;
  input M00_ARESETN;
  output [39:0]M00_AXI_araddr;
  input M00_AXI_arready;
  output M00_AXI_arvalid;
  output [39:0]M00_AXI_awaddr;
  input M00_AXI_awready;
  output M00_AXI_awvalid;
  output M00_AXI_bready;
  input [1:0]M00_AXI_bresp;
  input M00_AXI_bvalid;
  input [31:0]M00_AXI_rdata;
  output M00_AXI_rready;
  input [1:0]M00_AXI_rresp;
  input M00_AXI_rvalid;
  output [31:0]M00_AXI_wdata;
  input M00_AXI_wready;
  output [3:0]M00_AXI_wstrb;
  output M00_AXI_wvalid;
  input S00_ACLK;
  input S00_ARESETN;
  input [39:0]S00_AXI_araddr;
  input [1:0]S00_AXI_arburst;
  input [3:0]S00_AXI_arcache;
  input [15:0]S00_AXI_arid;
  input [7:0]S00_AXI_arlen;
  input [0:0]S00_AXI_arlock;
  input [2:0]S00_AXI_arprot;
  input [3:0]S00_AXI_arqos;
  output S00_AXI_arready;
  input [2:0]S00_AXI_arsize;
  input S00_AXI_arvalid;
  input [39:0]S00_AXI_awaddr;
  input [1:0]S00_AXI_awburst;
  input [3:0]S00_AXI_awcache;
  input [15:0]S00_AXI_awid;
  input [7:0]S00_AXI_awlen;
  input [0:0]S00_AXI_awlock;
  input [2:0]S00_AXI_awprot;
  input [3:0]S00_AXI_awqos;
  output S00_AXI_awready;
  input [2:0]S00_AXI_awsize;
  input S00_AXI_awvalid;
  output [15:0]S00_AXI_bid;
  input S00_AXI_bready;
  output [1:0]S00_AXI_bresp;
  output S00_AXI_bvalid;
  output [31:0]S00_AXI_rdata;
  output [15:0]S00_AXI_rid;
  output S00_AXI_rlast;
  input S00_AXI_rready;
  output [1:0]S00_AXI_rresp;
  output S00_AXI_rvalid;
  input [31:0]S00_AXI_wdata;
  input S00_AXI_wlast;
  output S00_AXI_wready;
  input [3:0]S00_AXI_wstrb;
  input S00_AXI_wvalid;

  wire S00_ACLK_1;
  wire S00_ARESETN_1;
  wire axi_interconnect_0_ACLK_net;
  wire axi_interconnect_0_ARESETN_net;
  wire [39:0]axi_interconnect_0_to_s00_couplers_ARADDR;
  wire [1:0]axi_interconnect_0_to_s00_couplers_ARBURST;
  wire [3:0]axi_interconnect_0_to_s00_couplers_ARCACHE;
  wire [15:0]axi_interconnect_0_to_s00_couplers_ARID;
  wire [7:0]axi_interconnect_0_to_s00_couplers_ARLEN;
  wire [0:0]axi_interconnect_0_to_s00_couplers_ARLOCK;
  wire [2:0]axi_interconnect_0_to_s00_couplers_ARPROT;
  wire [3:0]axi_interconnect_0_to_s00_couplers_ARQOS;
  wire axi_interconnect_0_to_s00_couplers_ARREADY;
  wire [2:0]axi_interconnect_0_to_s00_couplers_ARSIZE;
  wire axi_interconnect_0_to_s00_couplers_ARVALID;
  wire [39:0]axi_interconnect_0_to_s00_couplers_AWADDR;
  wire [1:0]axi_interconnect_0_to_s00_couplers_AWBURST;
  wire [3:0]axi_interconnect_0_to_s00_couplers_AWCACHE;
  wire [15:0]axi_interconnect_0_to_s00_couplers_AWID;
  wire [7:0]axi_interconnect_0_to_s00_couplers_AWLEN;
  wire [0:0]axi_interconnect_0_to_s00_couplers_AWLOCK;
  wire [2:0]axi_interconnect_0_to_s00_couplers_AWPROT;
  wire [3:0]axi_interconnect_0_to_s00_couplers_AWQOS;
  wire axi_interconnect_0_to_s00_couplers_AWREADY;
  wire [2:0]axi_interconnect_0_to_s00_couplers_AWSIZE;
  wire axi_interconnect_0_to_s00_couplers_AWVALID;
  wire [15:0]axi_interconnect_0_to_s00_couplers_BID;
  wire axi_interconnect_0_to_s00_couplers_BREADY;
  wire [1:0]axi_interconnect_0_to_s00_couplers_BRESP;
  wire axi_interconnect_0_to_s00_couplers_BVALID;
  wire [31:0]axi_interconnect_0_to_s00_couplers_RDATA;
  wire [15:0]axi_interconnect_0_to_s00_couplers_RID;
  wire axi_interconnect_0_to_s00_couplers_RLAST;
  wire axi_interconnect_0_to_s00_couplers_RREADY;
  wire [1:0]axi_interconnect_0_to_s00_couplers_RRESP;
  wire axi_interconnect_0_to_s00_couplers_RVALID;
  wire [31:0]axi_interconnect_0_to_s00_couplers_WDATA;
  wire axi_interconnect_0_to_s00_couplers_WLAST;
  wire axi_interconnect_0_to_s00_couplers_WREADY;
  wire [3:0]axi_interconnect_0_to_s00_couplers_WSTRB;
  wire axi_interconnect_0_to_s00_couplers_WVALID;
  wire [39:0]s00_couplers_to_axi_interconnect_0_ARADDR;
  wire s00_couplers_to_axi_interconnect_0_ARREADY;
  wire s00_couplers_to_axi_interconnect_0_ARVALID;
  wire [39:0]s00_couplers_to_axi_interconnect_0_AWADDR;
  wire s00_couplers_to_axi_interconnect_0_AWREADY;
  wire s00_couplers_to_axi_interconnect_0_AWVALID;
  wire s00_couplers_to_axi_interconnect_0_BREADY;
  wire [1:0]s00_couplers_to_axi_interconnect_0_BRESP;
  wire s00_couplers_to_axi_interconnect_0_BVALID;
  wire [31:0]s00_couplers_to_axi_interconnect_0_RDATA;
  wire s00_couplers_to_axi_interconnect_0_RREADY;
  wire [1:0]s00_couplers_to_axi_interconnect_0_RRESP;
  wire s00_couplers_to_axi_interconnect_0_RVALID;
  wire [31:0]s00_couplers_to_axi_interconnect_0_WDATA;
  wire s00_couplers_to_axi_interconnect_0_WREADY;
  wire [3:0]s00_couplers_to_axi_interconnect_0_WSTRB;
  wire s00_couplers_to_axi_interconnect_0_WVALID;

  assign M00_AXI_araddr[39:0] = s00_couplers_to_axi_interconnect_0_ARADDR;
  assign M00_AXI_arvalid = s00_couplers_to_axi_interconnect_0_ARVALID;
  assign M00_AXI_awaddr[39:0] = s00_couplers_to_axi_interconnect_0_AWADDR;
  assign M00_AXI_awvalid = s00_couplers_to_axi_interconnect_0_AWVALID;
  assign M00_AXI_bready = s00_couplers_to_axi_interconnect_0_BREADY;
  assign M00_AXI_rready = s00_couplers_to_axi_interconnect_0_RREADY;
  assign M00_AXI_wdata[31:0] = s00_couplers_to_axi_interconnect_0_WDATA;
  assign M00_AXI_wstrb[3:0] = s00_couplers_to_axi_interconnect_0_WSTRB;
  assign M00_AXI_wvalid = s00_couplers_to_axi_interconnect_0_WVALID;
  assign S00_ACLK_1 = S00_ACLK;
  assign S00_ARESETN_1 = S00_ARESETN;
  assign S00_AXI_arready = axi_interconnect_0_to_s00_couplers_ARREADY;
  assign S00_AXI_awready = axi_interconnect_0_to_s00_couplers_AWREADY;
  assign S00_AXI_bid[15:0] = axi_interconnect_0_to_s00_couplers_BID;
  assign S00_AXI_bresp[1:0] = axi_interconnect_0_to_s00_couplers_BRESP;
  assign S00_AXI_bvalid = axi_interconnect_0_to_s00_couplers_BVALID;
  assign S00_AXI_rdata[31:0] = axi_interconnect_0_to_s00_couplers_RDATA;
  assign S00_AXI_rid[15:0] = axi_interconnect_0_to_s00_couplers_RID;
  assign S00_AXI_rlast = axi_interconnect_0_to_s00_couplers_RLAST;
  assign S00_AXI_rresp[1:0] = axi_interconnect_0_to_s00_couplers_RRESP;
  assign S00_AXI_rvalid = axi_interconnect_0_to_s00_couplers_RVALID;
  assign S00_AXI_wready = axi_interconnect_0_to_s00_couplers_WREADY;
  assign axi_interconnect_0_ACLK_net = M00_ACLK;
  assign axi_interconnect_0_ARESETN_net = M00_ARESETN;
  assign axi_interconnect_0_to_s00_couplers_ARADDR = S00_AXI_araddr[39:0];
  assign axi_interconnect_0_to_s00_couplers_ARBURST = S00_AXI_arburst[1:0];
  assign axi_interconnect_0_to_s00_couplers_ARCACHE = S00_AXI_arcache[3:0];
  assign axi_interconnect_0_to_s00_couplers_ARID = S00_AXI_arid[15:0];
  assign axi_interconnect_0_to_s00_couplers_ARLEN = S00_AXI_arlen[7:0];
  assign axi_interconnect_0_to_s00_couplers_ARLOCK = S00_AXI_arlock[0];
  assign axi_interconnect_0_to_s00_couplers_ARPROT = S00_AXI_arprot[2:0];
  assign axi_interconnect_0_to_s00_couplers_ARQOS = S00_AXI_arqos[3:0];
  assign axi_interconnect_0_to_s00_couplers_ARSIZE = S00_AXI_arsize[2:0];
  assign axi_interconnect_0_to_s00_couplers_ARVALID = S00_AXI_arvalid;
  assign axi_interconnect_0_to_s00_couplers_AWADDR = S00_AXI_awaddr[39:0];
  assign axi_interconnect_0_to_s00_couplers_AWBURST = S00_AXI_awburst[1:0];
  assign axi_interconnect_0_to_s00_couplers_AWCACHE = S00_AXI_awcache[3:0];
  assign axi_interconnect_0_to_s00_couplers_AWID = S00_AXI_awid[15:0];
  assign axi_interconnect_0_to_s00_couplers_AWLEN = S00_AXI_awlen[7:0];
  assign axi_interconnect_0_to_s00_couplers_AWLOCK = S00_AXI_awlock[0];
  assign axi_interconnect_0_to_s00_couplers_AWPROT = S00_AXI_awprot[2:0];
  assign axi_interconnect_0_to_s00_couplers_AWQOS = S00_AXI_awqos[3:0];
  assign axi_interconnect_0_to_s00_couplers_AWSIZE = S00_AXI_awsize[2:0];
  assign axi_interconnect_0_to_s00_couplers_AWVALID = S00_AXI_awvalid;
  assign axi_interconnect_0_to_s00_couplers_BREADY = S00_AXI_bready;
  assign axi_interconnect_0_to_s00_couplers_RREADY = S00_AXI_rready;
  assign axi_interconnect_0_to_s00_couplers_WDATA = S00_AXI_wdata[31:0];
  assign axi_interconnect_0_to_s00_couplers_WLAST = S00_AXI_wlast;
  assign axi_interconnect_0_to_s00_couplers_WSTRB = S00_AXI_wstrb[3:0];
  assign axi_interconnect_0_to_s00_couplers_WVALID = S00_AXI_wvalid;
  assign s00_couplers_to_axi_interconnect_0_ARREADY = M00_AXI_arready;
  assign s00_couplers_to_axi_interconnect_0_AWREADY = M00_AXI_awready;
  assign s00_couplers_to_axi_interconnect_0_BRESP = M00_AXI_bresp[1:0];
  assign s00_couplers_to_axi_interconnect_0_BVALID = M00_AXI_bvalid;
  assign s00_couplers_to_axi_interconnect_0_RDATA = M00_AXI_rdata[31:0];
  assign s00_couplers_to_axi_interconnect_0_RRESP = M00_AXI_rresp[1:0];
  assign s00_couplers_to_axi_interconnect_0_RVALID = M00_AXI_rvalid;
  assign s00_couplers_to_axi_interconnect_0_WREADY = M00_AXI_wready;
  s00_couplers_imp_O7FAN0 s00_couplers
       (.M_ACLK(axi_interconnect_0_ACLK_net),
        .M_ARESETN(axi_interconnect_0_ARESETN_net),
        .M_AXI_araddr(s00_couplers_to_axi_interconnect_0_ARADDR),
        .M_AXI_arready(s00_couplers_to_axi_interconnect_0_ARREADY),
        .M_AXI_arvalid(s00_couplers_to_axi_interconnect_0_ARVALID),
        .M_AXI_awaddr(s00_couplers_to_axi_interconnect_0_AWADDR),
        .M_AXI_awready(s00_couplers_to_axi_interconnect_0_AWREADY),
        .M_AXI_awvalid(s00_couplers_to_axi_interconnect_0_AWVALID),
        .M_AXI_bready(s00_couplers_to_axi_interconnect_0_BREADY),
        .M_AXI_bresp(s00_couplers_to_axi_interconnect_0_BRESP),
        .M_AXI_bvalid(s00_couplers_to_axi_interconnect_0_BVALID),
        .M_AXI_rdata(s00_couplers_to_axi_interconnect_0_RDATA),
        .M_AXI_rready(s00_couplers_to_axi_interconnect_0_RREADY),
        .M_AXI_rresp(s00_couplers_to_axi_interconnect_0_RRESP),
        .M_AXI_rvalid(s00_couplers_to_axi_interconnect_0_RVALID),
        .M_AXI_wdata(s00_couplers_to_axi_interconnect_0_WDATA),
        .M_AXI_wready(s00_couplers_to_axi_interconnect_0_WREADY),
        .M_AXI_wstrb(s00_couplers_to_axi_interconnect_0_WSTRB),
        .M_AXI_wvalid(s00_couplers_to_axi_interconnect_0_WVALID),
        .S_ACLK(S00_ACLK_1),
        .S_ARESETN(S00_ARESETN_1),
        .S_AXI_araddr(axi_interconnect_0_to_s00_couplers_ARADDR),
        .S_AXI_arburst(axi_interconnect_0_to_s00_couplers_ARBURST),
        .S_AXI_arcache(axi_interconnect_0_to_s00_couplers_ARCACHE),
        .S_AXI_arid(axi_interconnect_0_to_s00_couplers_ARID),
        .S_AXI_arlen(axi_interconnect_0_to_s00_couplers_ARLEN),
        .S_AXI_arlock(axi_interconnect_0_to_s00_couplers_ARLOCK),
        .S_AXI_arprot(axi_interconnect_0_to_s00_couplers_ARPROT),
        .S_AXI_arqos(axi_interconnect_0_to_s00_couplers_ARQOS),
        .S_AXI_arready(axi_interconnect_0_to_s00_couplers_ARREADY),
        .S_AXI_arsize(axi_interconnect_0_to_s00_couplers_ARSIZE),
        .S_AXI_arvalid(axi_interconnect_0_to_s00_couplers_ARVALID),
        .S_AXI_awaddr(axi_interconnect_0_to_s00_couplers_AWADDR),
        .S_AXI_awburst(axi_interconnect_0_to_s00_couplers_AWBURST),
        .S_AXI_awcache(axi_interconnect_0_to_s00_couplers_AWCACHE),
        .S_AXI_awid(axi_interconnect_0_to_s00_couplers_AWID),
        .S_AXI_awlen(axi_interconnect_0_to_s00_couplers_AWLEN),
        .S_AXI_awlock(axi_interconnect_0_to_s00_couplers_AWLOCK),
        .S_AXI_awprot(axi_interconnect_0_to_s00_couplers_AWPROT),
        .S_AXI_awqos(axi_interconnect_0_to_s00_couplers_AWQOS),
        .S_AXI_awready(axi_interconnect_0_to_s00_couplers_AWREADY),
        .S_AXI_awsize(axi_interconnect_0_to_s00_couplers_AWSIZE),
        .S_AXI_awvalid(axi_interconnect_0_to_s00_couplers_AWVALID),
        .S_AXI_bid(axi_interconnect_0_to_s00_couplers_BID),
        .S_AXI_bready(axi_interconnect_0_to_s00_couplers_BREADY),
        .S_AXI_bresp(axi_interconnect_0_to_s00_couplers_BRESP),
        .S_AXI_bvalid(axi_interconnect_0_to_s00_couplers_BVALID),
        .S_AXI_rdata(axi_interconnect_0_to_s00_couplers_RDATA),
        .S_AXI_rid(axi_interconnect_0_to_s00_couplers_RID),
        .S_AXI_rlast(axi_interconnect_0_to_s00_couplers_RLAST),
        .S_AXI_rready(axi_interconnect_0_to_s00_couplers_RREADY),
        .S_AXI_rresp(axi_interconnect_0_to_s00_couplers_RRESP),
        .S_AXI_rvalid(axi_interconnect_0_to_s00_couplers_RVALID),
        .S_AXI_wdata(axi_interconnect_0_to_s00_couplers_WDATA),
        .S_AXI_wlast(axi_interconnect_0_to_s00_couplers_WLAST),
        .S_AXI_wready(axi_interconnect_0_to_s00_couplers_WREADY),
        .S_AXI_wstrb(axi_interconnect_0_to_s00_couplers_WSTRB),
        .S_AXI_wvalid(axi_interconnect_0_to_s00_couplers_WVALID));
endmodule

module s00_couplers_imp_O7FAN0
   (M_ACLK,
    M_ARESETN,
    M_AXI_araddr,
    M_AXI_arready,
    M_AXI_arvalid,
    M_AXI_awaddr,
    M_AXI_awready,
    M_AXI_awvalid,
    M_AXI_bready,
    M_AXI_bresp,
    M_AXI_bvalid,
    M_AXI_rdata,
    M_AXI_rready,
    M_AXI_rresp,
    M_AXI_rvalid,
    M_AXI_wdata,
    M_AXI_wready,
    M_AXI_wstrb,
    M_AXI_wvalid,
    S_ACLK,
    S_ARESETN,
    S_AXI_araddr,
    S_AXI_arburst,
    S_AXI_arcache,
    S_AXI_arid,
    S_AXI_arlen,
    S_AXI_arlock,
    S_AXI_arprot,
    S_AXI_arqos,
    S_AXI_arready,
    S_AXI_arsize,
    S_AXI_arvalid,
    S_AXI_awaddr,
    S_AXI_awburst,
    S_AXI_awcache,
    S_AXI_awid,
    S_AXI_awlen,
    S_AXI_awlock,
    S_AXI_awprot,
    S_AXI_awqos,
    S_AXI_awready,
    S_AXI_awsize,
    S_AXI_awvalid,
    S_AXI_bid,
    S_AXI_bready,
    S_AXI_bresp,
    S_AXI_bvalid,
    S_AXI_rdata,
    S_AXI_rid,
    S_AXI_rlast,
    S_AXI_rready,
    S_AXI_rresp,
    S_AXI_rvalid,
    S_AXI_wdata,
    S_AXI_wlast,
    S_AXI_wready,
    S_AXI_wstrb,
    S_AXI_wvalid);
  input M_ACLK;
  input M_ARESETN;
  output [39:0]M_AXI_araddr;
  input M_AXI_arready;
  output M_AXI_arvalid;
  output [39:0]M_AXI_awaddr;
  input M_AXI_awready;
  output M_AXI_awvalid;
  output M_AXI_bready;
  input [1:0]M_AXI_bresp;
  input M_AXI_bvalid;
  input [31:0]M_AXI_rdata;
  output M_AXI_rready;
  input [1:0]M_AXI_rresp;
  input M_AXI_rvalid;
  output [31:0]M_AXI_wdata;
  input M_AXI_wready;
  output [3:0]M_AXI_wstrb;
  output M_AXI_wvalid;
  input S_ACLK;
  input S_ARESETN;
  input [39:0]S_AXI_araddr;
  input [1:0]S_AXI_arburst;
  input [3:0]S_AXI_arcache;
  input [15:0]S_AXI_arid;
  input [7:0]S_AXI_arlen;
  input [0:0]S_AXI_arlock;
  input [2:0]S_AXI_arprot;
  input [3:0]S_AXI_arqos;
  output S_AXI_arready;
  input [2:0]S_AXI_arsize;
  input S_AXI_arvalid;
  input [39:0]S_AXI_awaddr;
  input [1:0]S_AXI_awburst;
  input [3:0]S_AXI_awcache;
  input [15:0]S_AXI_awid;
  input [7:0]S_AXI_awlen;
  input [0:0]S_AXI_awlock;
  input [2:0]S_AXI_awprot;
  input [3:0]S_AXI_awqos;
  output S_AXI_awready;
  input [2:0]S_AXI_awsize;
  input S_AXI_awvalid;
  output [15:0]S_AXI_bid;
  input S_AXI_bready;
  output [1:0]S_AXI_bresp;
  output S_AXI_bvalid;
  output [31:0]S_AXI_rdata;
  output [15:0]S_AXI_rid;
  output S_AXI_rlast;
  input S_AXI_rready;
  output [1:0]S_AXI_rresp;
  output S_AXI_rvalid;
  input [31:0]S_AXI_wdata;
  input S_AXI_wlast;
  output S_AXI_wready;
  input [3:0]S_AXI_wstrb;
  input S_AXI_wvalid;

  wire S_ACLK_1;
  wire S_ARESETN_1;
  wire [39:0]auto_pc_to_s00_couplers_ARADDR;
  wire auto_pc_to_s00_couplers_ARREADY;
  wire auto_pc_to_s00_couplers_ARVALID;
  wire [39:0]auto_pc_to_s00_couplers_AWADDR;
  wire auto_pc_to_s00_couplers_AWREADY;
  wire auto_pc_to_s00_couplers_AWVALID;
  wire auto_pc_to_s00_couplers_BREADY;
  wire [1:0]auto_pc_to_s00_couplers_BRESP;
  wire auto_pc_to_s00_couplers_BVALID;
  wire [31:0]auto_pc_to_s00_couplers_RDATA;
  wire auto_pc_to_s00_couplers_RREADY;
  wire [1:0]auto_pc_to_s00_couplers_RRESP;
  wire auto_pc_to_s00_couplers_RVALID;
  wire [31:0]auto_pc_to_s00_couplers_WDATA;
  wire auto_pc_to_s00_couplers_WREADY;
  wire [3:0]auto_pc_to_s00_couplers_WSTRB;
  wire auto_pc_to_s00_couplers_WVALID;
  wire [39:0]s00_couplers_to_auto_pc_ARADDR;
  wire [1:0]s00_couplers_to_auto_pc_ARBURST;
  wire [3:0]s00_couplers_to_auto_pc_ARCACHE;
  wire [15:0]s00_couplers_to_auto_pc_ARID;
  wire [7:0]s00_couplers_to_auto_pc_ARLEN;
  wire [0:0]s00_couplers_to_auto_pc_ARLOCK;
  wire [2:0]s00_couplers_to_auto_pc_ARPROT;
  wire [3:0]s00_couplers_to_auto_pc_ARQOS;
  wire s00_couplers_to_auto_pc_ARREADY;
  wire [2:0]s00_couplers_to_auto_pc_ARSIZE;
  wire s00_couplers_to_auto_pc_ARVALID;
  wire [39:0]s00_couplers_to_auto_pc_AWADDR;
  wire [1:0]s00_couplers_to_auto_pc_AWBURST;
  wire [3:0]s00_couplers_to_auto_pc_AWCACHE;
  wire [15:0]s00_couplers_to_auto_pc_AWID;
  wire [7:0]s00_couplers_to_auto_pc_AWLEN;
  wire [0:0]s00_couplers_to_auto_pc_AWLOCK;
  wire [2:0]s00_couplers_to_auto_pc_AWPROT;
  wire [3:0]s00_couplers_to_auto_pc_AWQOS;
  wire s00_couplers_to_auto_pc_AWREADY;
  wire [2:0]s00_couplers_to_auto_pc_AWSIZE;
  wire s00_couplers_to_auto_pc_AWVALID;
  wire [15:0]s00_couplers_to_auto_pc_BID;
  wire s00_couplers_to_auto_pc_BREADY;
  wire [1:0]s00_couplers_to_auto_pc_BRESP;
  wire s00_couplers_to_auto_pc_BVALID;
  wire [31:0]s00_couplers_to_auto_pc_RDATA;
  wire [15:0]s00_couplers_to_auto_pc_RID;
  wire s00_couplers_to_auto_pc_RLAST;
  wire s00_couplers_to_auto_pc_RREADY;
  wire [1:0]s00_couplers_to_auto_pc_RRESP;
  wire s00_couplers_to_auto_pc_RVALID;
  wire [31:0]s00_couplers_to_auto_pc_WDATA;
  wire s00_couplers_to_auto_pc_WLAST;
  wire s00_couplers_to_auto_pc_WREADY;
  wire [3:0]s00_couplers_to_auto_pc_WSTRB;
  wire s00_couplers_to_auto_pc_WVALID;

  assign M_AXI_araddr[39:0] = auto_pc_to_s00_couplers_ARADDR;
  assign M_AXI_arvalid = auto_pc_to_s00_couplers_ARVALID;
  assign M_AXI_awaddr[39:0] = auto_pc_to_s00_couplers_AWADDR;
  assign M_AXI_awvalid = auto_pc_to_s00_couplers_AWVALID;
  assign M_AXI_bready = auto_pc_to_s00_couplers_BREADY;
  assign M_AXI_rready = auto_pc_to_s00_couplers_RREADY;
  assign M_AXI_wdata[31:0] = auto_pc_to_s00_couplers_WDATA;
  assign M_AXI_wstrb[3:0] = auto_pc_to_s00_couplers_WSTRB;
  assign M_AXI_wvalid = auto_pc_to_s00_couplers_WVALID;
  assign S_ACLK_1 = S_ACLK;
  assign S_ARESETN_1 = S_ARESETN;
  assign S_AXI_arready = s00_couplers_to_auto_pc_ARREADY;
  assign S_AXI_awready = s00_couplers_to_auto_pc_AWREADY;
  assign S_AXI_bid[15:0] = s00_couplers_to_auto_pc_BID;
  assign S_AXI_bresp[1:0] = s00_couplers_to_auto_pc_BRESP;
  assign S_AXI_bvalid = s00_couplers_to_auto_pc_BVALID;
  assign S_AXI_rdata[31:0] = s00_couplers_to_auto_pc_RDATA;
  assign S_AXI_rid[15:0] = s00_couplers_to_auto_pc_RID;
  assign S_AXI_rlast = s00_couplers_to_auto_pc_RLAST;
  assign S_AXI_rresp[1:0] = s00_couplers_to_auto_pc_RRESP;
  assign S_AXI_rvalid = s00_couplers_to_auto_pc_RVALID;
  assign S_AXI_wready = s00_couplers_to_auto_pc_WREADY;
  assign auto_pc_to_s00_couplers_ARREADY = M_AXI_arready;
  assign auto_pc_to_s00_couplers_AWREADY = M_AXI_awready;
  assign auto_pc_to_s00_couplers_BRESP = M_AXI_bresp[1:0];
  assign auto_pc_to_s00_couplers_BVALID = M_AXI_bvalid;
  assign auto_pc_to_s00_couplers_RDATA = M_AXI_rdata[31:0];
  assign auto_pc_to_s00_couplers_RRESP = M_AXI_rresp[1:0];
  assign auto_pc_to_s00_couplers_RVALID = M_AXI_rvalid;
  assign auto_pc_to_s00_couplers_WREADY = M_AXI_wready;
  assign s00_couplers_to_auto_pc_ARADDR = S_AXI_araddr[39:0];
  assign s00_couplers_to_auto_pc_ARBURST = S_AXI_arburst[1:0];
  assign s00_couplers_to_auto_pc_ARCACHE = S_AXI_arcache[3:0];
  assign s00_couplers_to_auto_pc_ARID = S_AXI_arid[15:0];
  assign s00_couplers_to_auto_pc_ARLEN = S_AXI_arlen[7:0];
  assign s00_couplers_to_auto_pc_ARLOCK = S_AXI_arlock[0];
  assign s00_couplers_to_auto_pc_ARPROT = S_AXI_arprot[2:0];
  assign s00_couplers_to_auto_pc_ARQOS = S_AXI_arqos[3:0];
  assign s00_couplers_to_auto_pc_ARSIZE = S_AXI_arsize[2:0];
  assign s00_couplers_to_auto_pc_ARVALID = S_AXI_arvalid;
  assign s00_couplers_to_auto_pc_AWADDR = S_AXI_awaddr[39:0];
  assign s00_couplers_to_auto_pc_AWBURST = S_AXI_awburst[1:0];
  assign s00_couplers_to_auto_pc_AWCACHE = S_AXI_awcache[3:0];
  assign s00_couplers_to_auto_pc_AWID = S_AXI_awid[15:0];
  assign s00_couplers_to_auto_pc_AWLEN = S_AXI_awlen[7:0];
  assign s00_couplers_to_auto_pc_AWLOCK = S_AXI_awlock[0];
  assign s00_couplers_to_auto_pc_AWPROT = S_AXI_awprot[2:0];
  assign s00_couplers_to_auto_pc_AWQOS = S_AXI_awqos[3:0];
  assign s00_couplers_to_auto_pc_AWSIZE = S_AXI_awsize[2:0];
  assign s00_couplers_to_auto_pc_AWVALID = S_AXI_awvalid;
  assign s00_couplers_to_auto_pc_BREADY = S_AXI_bready;
  assign s00_couplers_to_auto_pc_RREADY = S_AXI_rready;
  assign s00_couplers_to_auto_pc_WDATA = S_AXI_wdata[31:0];
  assign s00_couplers_to_auto_pc_WLAST = S_AXI_wlast;
  assign s00_couplers_to_auto_pc_WSTRB = S_AXI_wstrb[3:0];
  assign s00_couplers_to_auto_pc_WVALID = S_AXI_wvalid;
  design_1_auto_pc_0 auto_pc
       (.aclk(S_ACLK_1),
        .aresetn(S_ARESETN_1),
        .m_axi_araddr(auto_pc_to_s00_couplers_ARADDR),
        .m_axi_arready(auto_pc_to_s00_couplers_ARREADY),
        .m_axi_arvalid(auto_pc_to_s00_couplers_ARVALID),
        .m_axi_awaddr(auto_pc_to_s00_couplers_AWADDR),
        .m_axi_awready(auto_pc_to_s00_couplers_AWREADY),
        .m_axi_awvalid(auto_pc_to_s00_couplers_AWVALID),
        .m_axi_bready(auto_pc_to_s00_couplers_BREADY),
        .m_axi_bresp(auto_pc_to_s00_couplers_BRESP),
        .m_axi_bvalid(auto_pc_to_s00_couplers_BVALID),
        .m_axi_rdata(auto_pc_to_s00_couplers_RDATA),
        .m_axi_rready(auto_pc_to_s00_couplers_RREADY),
        .m_axi_rresp(auto_pc_to_s00_couplers_RRESP),
        .m_axi_rvalid(auto_pc_to_s00_couplers_RVALID),
        .m_axi_wdata(auto_pc_to_s00_couplers_WDATA),
        .m_axi_wready(auto_pc_to_s00_couplers_WREADY),
        .m_axi_wstrb(auto_pc_to_s00_couplers_WSTRB),
        .m_axi_wvalid(auto_pc_to_s00_couplers_WVALID),
        .s_axi_araddr(s00_couplers_to_auto_pc_ARADDR),
        .s_axi_arburst(s00_couplers_to_auto_pc_ARBURST),
        .s_axi_arcache(s00_couplers_to_auto_pc_ARCACHE),
        .s_axi_arid(s00_couplers_to_auto_pc_ARID),
        .s_axi_arlen(s00_couplers_to_auto_pc_ARLEN),
        .s_axi_arlock(s00_couplers_to_auto_pc_ARLOCK),
        .s_axi_arprot(s00_couplers_to_auto_pc_ARPROT),
        .s_axi_arqos(s00_couplers_to_auto_pc_ARQOS),
        .s_axi_arready(s00_couplers_to_auto_pc_ARREADY),
        .s_axi_arregion({1'b0,1'b0,1'b0,1'b0}),
        .s_axi_arsize(s00_couplers_to_auto_pc_ARSIZE),
        .s_axi_arvalid(s00_couplers_to_auto_pc_ARVALID),
        .s_axi_awaddr(s00_couplers_to_auto_pc_AWADDR),
        .s_axi_awburst(s00_couplers_to_auto_pc_AWBURST),
        .s_axi_awcache(s00_couplers_to_auto_pc_AWCACHE),
        .s_axi_awid(s00_couplers_to_auto_pc_AWID),
        .s_axi_awlen(s00_couplers_to_auto_pc_AWLEN),
        .s_axi_awlock(s00_couplers_to_auto_pc_AWLOCK),
        .s_axi_awprot(s00_couplers_to_auto_pc_AWPROT),
        .s_axi_awqos(s00_couplers_to_auto_pc_AWQOS),
        .s_axi_awready(s00_couplers_to_auto_pc_AWREADY),
        .s_axi_awregion({1'b0,1'b0,1'b0,1'b0}),
        .s_axi_awsize(s00_couplers_to_auto_pc_AWSIZE),
        .s_axi_awvalid(s00_couplers_to_auto_pc_AWVALID),
        .s_axi_bid(s00_couplers_to_auto_pc_BID),
        .s_axi_bready(s00_couplers_to_auto_pc_BREADY),
        .s_axi_bresp(s00_couplers_to_auto_pc_BRESP),
        .s_axi_bvalid(s00_couplers_to_auto_pc_BVALID),
        .s_axi_rdata(s00_couplers_to_auto_pc_RDATA),
        .s_axi_rid(s00_couplers_to_auto_pc_RID),
        .s_axi_rlast(s00_couplers_to_auto_pc_RLAST),
        .s_axi_rready(s00_couplers_to_auto_pc_RREADY),
        .s_axi_rresp(s00_couplers_to_auto_pc_RRESP),
        .s_axi_rvalid(s00_couplers_to_auto_pc_RVALID),
        .s_axi_wdata(s00_couplers_to_auto_pc_WDATA),
        .s_axi_wlast(s00_couplers_to_auto_pc_WLAST),
        .s_axi_wready(s00_couplers_to_auto_pc_WREADY),
        .s_axi_wstrb(s00_couplers_to_auto_pc_WSTRB),
        .s_axi_wvalid(s00_couplers_to_auto_pc_WVALID));
endmodule
