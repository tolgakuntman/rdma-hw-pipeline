
        `timescale 1 ns / 1 ps

        module data_mover_test (
            // basic clock / reset for testbench
            input  wire         clk,
            input  wire         rst_n,

            // RDMA controller control inputs (driven by testbench)
            input  wire         GLOBAL_ENABLE,
            input  wire         SOFT_RESET,
            input  wire         SQ_DOORBELL_PULSE,
            input  wire [31:0]  SQ_BASE_LO,
            input  wire [3:0]   SQ_SIZE,
            input  wire [3:0]   SQ_TAIL,
            output wire [3:0]   HW_SQ_HEAD,

            // Command controller interface (external to IPs)
            output wire         cmd_ctrl_ready,
            input  wire         cmd_ctrl_start,
            input  wire [31:0]  cmd_ctrl_src_addr,
            input  wire [31:0]  cmd_ctrl_dst_addr,
            input  wire [31:0]  cmd_ctrl_btt,
            input  wire         cmd_ctrl_is_read,
            output wire         read_complete
        );

            // Local clock/reset nets expected by submodules
            wire m00_axis_aclk;
            wire m00_axis_aresetn;
            assign m00_axis_aclk   = clk;
            assign m00_axis_aresetn = rst_n;

            // Command-controller internal nets (connected between rdma_controller
            // and data_mover_axi_cmd_master). Top-level `cmd_ctrl_*` ports are
            // connected to these nets so the testbench can drive/observe them.
            wire        CMD_CTRL_READY;
            wire        CMD_CTRL_START;
            wire [31:0] CMD_CTRL_SRC_ADDR;
            wire [31:0] CMD_CTRL_DST_ADDR;
            wire [31:0] CMD_CTRL_BTT;
            wire        CMD_IS_READ;

            // Transfer-complete signals from the data mover/AXI helper
            wire mm2s_rd_xfer_cmplt;
            wire s2mm_wr_xfer_cmplt;

            // AXI command interface nets (sizes chosen conservatively for testbench)
            wire [63:0] m_axis_mm2s_cmd_tdata;
            wire        m_axis_mm2s_cmd_tvalid;
            wire [63:0] m_axis_s2mm_cmd_tdata;
            wire        m_axis_s2mm_cmd_tvalid;

            // Tie the module-level command-controller ports to the internal nets
            assign cmd_ctrl_ready      = CMD_CTRL_READY;
            assign CMD_CTRL_START      = cmd_ctrl_start;
            assign CMD_CTRL_SRC_ADDR   = cmd_ctrl_src_addr;
            assign CMD_CTRL_DST_ADDR   = cmd_ctrl_dst_addr;
            assign CMD_CTRL_BTT        = cmd_ctrl_btt;
            assign CMD_IS_READ         = cmd_ctrl_is_read;
            assign read_complete       = mm2s_rd_xfer_cmplt;

            // Instantiate the data mover AXI command master helper
            data_mover_axi_cmd_master data_mover_axi_cmd_master_inst (
                .clk(m00_axis_aclk),
                .rst_n(~m00_axis_aresetn),
                .is_read(CMD_IS_READ), // 1: read from memory, 0: write to memory
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
                .SQ_DOORBELL_PULSE(SQ_DOORBELL_PULSE),

                .SQ_BASE_ADDR     (SQ_BASE_LO),
                .SQ_SIZE          (SQ_SIZE[3:0]),
                .SQ_TAIL_SW       (SQ_TAIL[3:0]),
                .SQ_HEAD_HW       (HW_SQ_HEAD[3:0]),

                .CMD_CTRL_READY   (CMD_CTRL_READY),
                .CMD_CTRL_START   (CMD_CTRL_START),
                .CMD_CTRL_SRC_ADDR(CMD_CTRL_SRC_ADDR),
                .CMD_CTRL_DST_ADDR(CMD_CTRL_DST_ADDR),
                .CMD_CTRL_BTT     (CMD_CTRL_BTT),
                .CMD_CTRL_IS_READ (CMD_IS_READ),
                .READ_COMPLETE    (mm2s_rd_xfer_cmplt)
            );

        endmodule