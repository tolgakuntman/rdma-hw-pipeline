//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2024 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2024.1 (win64) Build 5076996 Wed May 22 18:37:14 MDT 2024
//Date        : Fri Dec 19 11:31:28 2025
//Host        : LAPTOP-VRV5DMOG running 64-bit major release  (build 9200)
//Command     : generate_target design_1_wrapper.bd
//Design      : design_1_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module design_1_wrapper
   (som240_1_connector_hpa_clk0p_clk,
    som240_2_connector_pl_gem3_reset,
    som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdc,
    som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdio_io,
    som240_2_connector_pl_gem3_rgmii_rd,
    som240_2_connector_pl_gem3_rgmii_rx_ctl,
    som240_2_connector_pl_gem3_rgmii_rxc,
    som240_2_connector_pl_gem3_rgmii_td,
    som240_2_connector_pl_gem3_rgmii_tx_ctl,
    som240_2_connector_pl_gem3_rgmii_txc);
  input som240_1_connector_hpa_clk0p_clk;
  output [0:0]som240_2_connector_pl_gem3_reset;
  output som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdc;
  inout som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdio_io;
  input [3:0]som240_2_connector_pl_gem3_rgmii_rd;
  input som240_2_connector_pl_gem3_rgmii_rx_ctl;
  input som240_2_connector_pl_gem3_rgmii_rxc;
  output [3:0]som240_2_connector_pl_gem3_rgmii_td;
  output som240_2_connector_pl_gem3_rgmii_tx_ctl;
  output som240_2_connector_pl_gem3_rgmii_txc;

  wire som240_1_connector_hpa_clk0p_clk;
  wire [0:0]som240_2_connector_pl_gem3_reset;
  wire som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdc;
  wire som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdio_i;
  wire som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdio_io;
  wire som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdio_o;
  wire som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdio_t;
  wire [3:0]som240_2_connector_pl_gem3_rgmii_rd;
  wire som240_2_connector_pl_gem3_rgmii_rx_ctl;
  wire som240_2_connector_pl_gem3_rgmii_rxc;
  wire [3:0]som240_2_connector_pl_gem3_rgmii_td;
  wire som240_2_connector_pl_gem3_rgmii_tx_ctl;
  wire som240_2_connector_pl_gem3_rgmii_txc;

  design_1 design_1_i
       (.som240_1_connector_hpa_clk0p_clk(som240_1_connector_hpa_clk0p_clk),
        .som240_2_connector_pl_gem3_reset(som240_2_connector_pl_gem3_reset),
        .som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdc(som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdc),
        .som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdio_i(som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdio_i),
        .som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdio_o(som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdio_o),
        .som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdio_t(som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdio_t),
        .som240_2_connector_pl_gem3_rgmii_rd(som240_2_connector_pl_gem3_rgmii_rd),
        .som240_2_connector_pl_gem3_rgmii_rx_ctl(som240_2_connector_pl_gem3_rgmii_rx_ctl),
        .som240_2_connector_pl_gem3_rgmii_rxc(som240_2_connector_pl_gem3_rgmii_rxc),
        .som240_2_connector_pl_gem3_rgmii_td(som240_2_connector_pl_gem3_rgmii_td),
        .som240_2_connector_pl_gem3_rgmii_tx_ctl(som240_2_connector_pl_gem3_rgmii_tx_ctl),
        .som240_2_connector_pl_gem3_rgmii_txc(som240_2_connector_pl_gem3_rgmii_txc));
  IOBUF som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdio_iobuf
       (.I(som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdio_o),
        .IO(som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdio_io),
        .O(som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdio_i),
        .T(som240_2_connector_pl_gem3_rgmii_mdio_mdc_mdio_t));
endmodule
