`timescale 1 ns / 1 ps

        module data_mover_test (
            // basic clock / reset for testbench
            input  wire         clk,
            input  wire         rst_n,

            input  wire [6:0]   s_axi_awaddr,
            input  wire [2:0]   s_axi_awprot,
            input  wire         s_axi_awvalid,
            output wire         s_axi_awready,
            input  wire [31:0]  s_axi_wdata,
            input  wire [3:0]   s_axi_wstrb,
            input  wire         s_axi_wvalid,
            output wire         s_axi_wready,
            output wire [1:0]   s_axi_bresp,
            output wire         s_axi_bvalid,
            input  wire         s_axi_bready,
            input  wire [6:0]   s_axi_araddr,
            input  wire [2:0]   s_axi_arprot,
            input  wire         s_axi_arvalid,
            output wire         s_axi_arready,
            output wire [31:0]  s_axi_rdata,
            output wire [1:0]   s_axi_rresp,
            output wire         s_axi_rvalid,
            input  wire         s_axi_rready,

            // Optional: expose some debug signals
            output wire [3:0]   HW_SQ_HEAD,
            output wire         cmd_ctrl_ready,
            output wire [31:0]  debug_status_word,
            
            // Input for simulating DataMover completion
            input  wire         mm2s_rd_xfer_cmplt
        );

            // Local clock/reset nets
            wire m00_axis_aclk;
            wire m00_axis_aresetn;
            assign m00_axis_aclk   = clk;
            assign m00_axis_aresetn = rst_n;

            // Register outputs from AXI-Lite slave to RDMA controller
            wire        GLOBAL_ENABLE;
            wire        SOFT_RESET;
            wire [31:0] SQ_BASE_LO;
            wire [3:0]  SQ_SIZE;
            wire [3:0]  SQ_TAIL;
            wire [3:0]  sq_head_internal;

            // Command-controller internal nets
            wire        CMD_CTRL_READY;
            wire        CMD_CTRL_START;
            wire [31:0] CMD_CTRL_SRC_ADDR;
            wire [31:0] CMD_CTRL_DST_ADDR;
            wire [31:0] CMD_CTRL_BTT;
            wire        CMD_IS_READ;

            // Transfer-complete signals
            wire s2mm_wr_xfer_cmplt;

            // AXI command interface nets
            wire [71:0] m_axis_mm2s_cmd_tdata;
            wire        m_axis_mm2s_cmd_tvalid;
            wire [71:0] m_axis_s2mm_cmd_tdata;
            wire        m_axis_s2mm_cmd_tvalid;

            // Debug outputs
            wire [31:0] HW_STATUS_WORD;
            wire [31:0] HW_BYTES_LO;
            wire [31:0] HW_BYTES_HI;
            wire [31:0] HW_WQE_PROCESSED;

            assign HW_SQ_HEAD = sq_head_internal;
            assign cmd_ctrl_ready = CMD_CTRL_READY;
            assign debug_status_word = HW_STATUS_WORD;

            // Instantiate the data mover AXI command master helper
            data_mover_axi_cmd_master data_mover_axi_cmd_master_inst (
                .clk(m00_axis_aclk),
                .rst_n(m00_axis_aresetn),
                .is_read(CMD_IS_READ),
                .ready(CMD_CTRL_READY),
                .saddr(CMD_CTRL_SRC_ADDR),
                .daddr(CMD_CTRL_DST_ADDR),
                .btt(CMD_CTRL_BTT),
                .start(CMD_CTRL_START),
                .m_axis_mm2s_cmd_tdata(m_axis_mm2s_cmd_tdata),
                .m_axis_mm2s_cmd_tvalid(m_axis_mm2s_cmd_tvalid),
                .m_axis_s2mm_cmd_tdata(m_axis_s2mm_cmd_tdata),
                .m_axis_s2mm_cmd_tvalid(m_axis_s2mm_cmd_tvalid),
                .s2mm_wr_xfer_cmplt(s2mm_wr_xfer_cmplt),
                .mm2s_rd_xfer_cmplt(mm2s_rd_xfer_cmplt)
            );

            // Instantiate the RDMA controller under test
            rdma_controller #(
                .SQ_IDX_WIDTH(4),
                .ADDR_WIDTH  (32)
            ) rdma_controller_inst (
                .clk              (m00_axis_aclk),
                .rst              (~m00_axis_aresetn),
                .START_RDMA       (GLOBAL_ENABLE),
                .RESET_RDMA       (SOFT_RESET),

                .SQ_BASE_ADDR     (SQ_BASE_LO),
                .SQ_SIZE          (SQ_SIZE),
                .SQ_TAIL_SW       (SQ_TAIL),
                .SQ_HEAD_HW       (sq_head_internal),

                .CMD_CTRL_READY   (CMD_CTRL_READY),
                .CMD_CTRL_START   (CMD_CTRL_START),
                .CMD_CTRL_SRC_ADDR(CMD_CTRL_SRC_ADDR),
                .CMD_CTRL_DST_ADDR(CMD_CTRL_DST_ADDR),
                .CMD_CTRL_BTT     (CMD_CTRL_BTT),
                .CMD_CTRL_IS_READ (CMD_IS_READ),
                .READ_COMPLETE    (mm2s_rd_xfer_cmplt)
            );

            // Instantiate the AXI-Lite slave for register access
            data_mover_controller_slave_lite_v1_0_S00_AXI #(
                .C_S_AXI_DATA_WIDTH(32),
                .C_S_AXI_ADDR_WIDTH(7)
            ) axi_slave_inst (
                .S_AXI_ACLK(clk),
                .S_AXI_ARESETN(rst_n),
                .S_AXI_AWADDR(s_axi_awaddr),
                .S_AXI_AWPROT(s_axi_awprot),
                .S_AXI_AWVALID(s_axi_awvalid),
                .S_AXI_AWREADY(s_axi_awready),
                .S_AXI_WDATA(s_axi_wdata),
                .S_AXI_WSTRB(s_axi_wstrb),
                .S_AXI_WVALID(s_axi_wvalid),
                .S_AXI_WREADY(s_axi_wready),
                .S_AXI_BRESP(s_axi_bresp),
                .S_AXI_BVALID(s_axi_bvalid),
                .S_AXI_BREADY(s_axi_bready),
                .S_AXI_ARADDR(s_axi_araddr),
                .S_AXI_ARPROT(s_axi_arprot),
                .S_AXI_ARVALID(s_axi_arvalid),
                .S_AXI_ARREADY(s_axi_arready),
                .S_AXI_RDATA(s_axi_rdata),
                .S_AXI_RRESP(s_axi_rresp),
                .S_AXI_RVALID(s_axi_rvalid),
                .S_AXI_RREADY(s_axi_rready),

                // Control outputs to RDMA controller
                .GLOBAL_ENABLE(GLOBAL_ENABLE),
                .SOFT_RESET(SOFT_RESET),
                .SQ_BASE_LO(SQ_BASE_LO),
                .SQ_SIZE(SQ_SIZE),
                .SQ_TAIL(SQ_TAIL),
                .HW_SQ_HEAD({28'b0, sq_head_internal}),

                // Debug signal inputs
                .HW_STATUS_WORD({29'b0, CMD_CTRL_READY, CMD_IS_READ, CMD_CTRL_START}),
                .HW_BYTES_LO(CMD_CTRL_SRC_ADDR),
                .HW_BYTES_HI(CMD_CTRL_DST_ADDR),
                .HW_WQE_PROCESSED(CMD_CTRL_BTT),
                .mm2s_data(m_axis_mm2s_cmd_tdata)
            );

        endmodule