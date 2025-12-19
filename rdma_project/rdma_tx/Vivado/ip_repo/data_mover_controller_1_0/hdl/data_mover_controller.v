`timescale 1 ns / 1 ps

	module data_mover_controller #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 7,

		// Parameters of Axi Slave Bus Interface S00_AXIS
		parameter integer C_S00_AXIS_TDATA_WIDTH	= 32,

		// Parameters of Axi Master Bus Interface M00_AXIS
		parameter integer C_M00_AXIS_TDATA_WIDTH	= 32,
		parameter integer C_M00_AXIS_START_COUNT	= 32
	)
	(
		// Users to add ports here

		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S00_AXI
		input wire  s00_axi_aclk,
		input wire  s00_axi_aresetn,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
		input wire [2 : 0] s00_axi_awprot,
		input wire  s00_axi_awvalid,
		output wire  s00_axi_awready,
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
		output wire [1 : 0] s00_axi_rresp,
		output wire  s00_axi_rvalid,
		input wire  s00_axi_rready,

		// Ports of Axi Slave Bus Interface S00_AXIS
		input wire  s00_axis_aclk,
		input wire  s00_axis_aresetn,
		output wire  s00_axis_tready,
		input wire [C_S00_AXIS_TDATA_WIDTH-1 : 0] s00_axis_tdata,
		input wire [(C_S00_AXIS_TDATA_WIDTH/8)-1 : 0] s00_axis_tstrb,
		input wire  s00_axis_tlast,
		input wire  s00_axis_tvalid,

		// Ports of Axi Master Bus Interface M00_AXIS
		input wire  m00_axis_aclk,
		input wire  m00_axis_aresetn,
		output wire  m00_axis_tvalid,
		output wire [C_M00_AXIS_TDATA_WIDTH-1 : 0] m00_axis_tdata,
		output wire [(C_M00_AXIS_TDATA_WIDTH/8)-1 : 0] m00_axis_tstrb,
		output wire  m00_axis_tlast,
		input wire  m00_axis_tready,

		// Ports of AXI MM2S and S2MM CMD Master interface for DATA MOVER
		output wire [71:0]	m_axis_mm2s_cmd_tdata,
		output wire m_axis_mm2s_cmd_tvalid,
		output wire [71:0]	m_axis_s2mm_cmd_tdata,
		output wire m_axis_s2mm_cmd_tvalid,
		input wire s2mm_wr_xfer_cmplt,
		input wire mm2s_rd_xfer_cmplt,
		output wire IS_READ,
		
		// TX Streamer Interface
		output wire                     tx_cmd_valid,
		input  wire                     tx_cmd_ready,
		output wire [7:0]               tx_cmd_sq_index,
		output wire [31:0]              tx_cmd_ddr_addr,
		output wire [31:0]              tx_cmd_length,
		output wire [7:0]               tx_cmd_opcode,
		output wire [23:0]              tx_cmd_dest_qp,
		output wire [63:0]              tx_cmd_remote_addr,
		output wire [31:0]              tx_cmd_rkey,
		output wire [15:0]              tx_cmd_partition_key,
		output wire [7:0]               tx_cmd_service_level,
		output wire [23:0]              tx_cmd_psn,
		input  wire                     tx_cpl_valid,
		output wire                     tx_cpl_ready,
		input  wire [7:0]               tx_cpl_sq_index,
		input  wire [7:0]               tx_cpl_status,
		input  wire [31:0]              tx_cpl_bytes_sent,
		output wire [3:0]                 STATE_REG,
		
		// CQ Entry Register Outputs (for ILA debugging)
		output wire [31:0]              cq_entry_reg_0,
		output wire [31:0]              cq_entry_reg_1,
		output wire [31:0]              cq_entry_reg_2,
		output wire [31:0]              cq_entry_reg_3,
		output wire [31:0]              cq_entry_reg_4,
		output wire [31:0]              cq_entry_reg_5,
		output wire [31:0]              cq_entry_reg_6,
		output wire [31:0]              cq_entry_reg_7
	);
// Instantiation of Axi Bus Interface S00_AXI
	data_mover_controller_slave_lite_v1_0_S00_AXI # ( 
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) data_mover_controller_slave_lite_v1_0_S00_AXI_inst (
		.S_AXI_ACLK(s00_axi_aclk),
		.S_AXI_ARESETN(s00_axi_aresetn),
		.S_AXI_AWADDR(s00_axi_awaddr),
		.S_AXI_AWPROT(s00_axi_awprot),
		.S_AXI_AWVALID(s00_axi_awvalid),
		.S_AXI_AWREADY(s00_axi_awready),
		.S_AXI_WDATA(s00_axi_wdata),
		.S_AXI_WSTRB(s00_axi_wstrb),
		.S_AXI_WVALID(s00_axi_wvalid),
		.S_AXI_WREADY(s00_axi_wready),
		.S_AXI_BRESP(s00_axi_bresp),
		.S_AXI_BVALID(s00_axi_bvalid),
		.S_AXI_BREADY(s00_axi_bready),
		.S_AXI_ARADDR(s00_axi_araddr),
		.S_AXI_ARPROT(s00_axi_arprot),
		.S_AXI_ARVALID(s00_axi_arvalid),
		.S_AXI_ARREADY(s00_axi_arready),
		.S_AXI_RDATA(s00_axi_rdata),
		.S_AXI_RRESP(s00_axi_rresp),
		.S_AXI_RVALID(s00_axi_rvalid),
		.S_AXI_RREADY(s00_axi_rready),

		// RDMA-facing ports (connected to default simulation nets)
		.SQ_BASE_LO(SQ_BASE_LO),
		.SQ_BASE_HI(SQ_BASE_HI),
		.SQ_SIZE(SQ_SIZE),
		.SQ_TAIL(SQ_TAIL),
		.SQ_FLAGS(SQ_FLAGS),
		.SQ_STRIDE(SQ_STRIDE),
		.CQ_BASE_LO(CQ_BASE_LO),
		.CQ_BASE_HI(CQ_BASE_HI),
		.CQ_SIZE(CQ_SIZE),
		.CQ_HEAD_SW(CQ_HEAD_SW),
		.CQ_FLAGS(CQ_FLAGS),
		.SQ_DOORBELL_PULSE(SQ_DOORBELL_PULSE),
		.CQ_DOORBELL_PULSE(CQ_DOORBELL_PULSE),
		.GLOBAL_ENABLE(GLOBAL_ENABLE),
		.SOFT_RESET(SOFT_RESET),
		.PAUSE(PAUSE),
		.MODE(MODE),
		.GLOBAL_IRQ_EN(GLOBAL_IRQ_EN),
		.IRQ_OUT(IRQ_OUT),

		.HW_SQ_HEAD(HW_SQ_HEAD),
		.HW_CQ_TAIL(HW_CQ_TAIL),
		.HW_STATUS_WORD(HW_STATUS_WORD),
		.HW_BYTES_LO(HW_BYTES_LO),
		.HW_BYTES_HI(HW_BYTES_HI),
		.HW_WQE_PROCESSED(HW_WQE_PROCESSED),
		.HW_CQE_WRITTEN(HW_CQE_WRITTEN),
		.HW_CYCLES_BUSY_LO(HW_CYCLES_BUSY_LO),
		.HW_CYCLES_BUSY_HI(HW_CYCLES_BUSY_HI),
		.rdma_id(rdma_id),
		.rdma_opcode(rdma_opcode),
		.rdma_flags(rdma_flags),
		.rdma_local_key(rdma_local_key),
		.rdma_remote_key(rdma_remote_key),
		.rdma_btt(rdma_btt),
		.rdma_reserved(rdma_reserved),
		.rdma_entry_valid(rdma_entry_valid),
		.rdma_state(state_reg),
		.cmd_state(cmd_state_reg)
	);

	wire [31:0] SQ_BASE_LO;
	wire [31:0] SQ_BASE_HI;
	wire [31:0] SQ_SIZE;
	wire [31:0] SQ_TAIL;
	wire [31:0] SQ_FLAGS;
	wire [31:0] SQ_STRIDE;
	wire [31:0] CQ_BASE_LO;
	wire [31:0] CQ_BASE_HI;
	wire [31:0] CQ_SIZE;
	wire [31:0] CQ_HEAD_SW;
	wire [31:0] CQ_FLAGS;

	wire SQ_DOORBELL_PULSE;
	wire CQ_DOORBELL_PULSE;

	wire GLOBAL_ENABLE;
	wire SOFT_RESET;
	wire PAUSE;
	wire [3:0] MODE;
	wire GLOBAL_IRQ_EN;
	wire IRQ_OUT;

	wire [31:0] HW_SQ_HEAD;
	wire [31:0] HW_CQ_TAIL;
	wire [31:0] HW_STATUS_WORD;
	wire [31:0] HW_BYTES_LO;
	wire [31:0] HW_BYTES_HI;
	wire [31:0] HW_WQE_PROCESSED;
	wire [31:0] HW_CQE_WRITTEN;
	wire [31:0] HW_CYCLES_BUSY_LO;
	wire [31:0] HW_CYCLES_BUSY_HI;
	wire [31:0]   rdma_id;
	wire [15:0]   rdma_opcode;
	wire [15:0]   rdma_flags;
	wire [63:0]   rdma_local_key;
	wire [63:0]   rdma_remote_key;
	wire [127:0]  rdma_btt;
	wire [191:0]  rdma_reserved;
	wire          rdma_entry_valid;


// Instantiation of Axi Bus Interface S00_AXIS
	data_mover_controller_slave_stream_v1_0_S00_AXIS # ( 
		.C_S_AXIS_TDATA_WIDTH(C_S00_AXIS_TDATA_WIDTH)
	) data_mover_controller_slave_stream_v1_0_S00_AXIS_inst (
		.S_AXIS_ACLK(s00_axis_aclk),
		.S_AXIS_ARESETN(s00_axis_aresetn),
		.S_AXIS_TREADY(s00_axis_tready),
		.S_AXIS_TDATA(s00_axis_tdata),
		.S_AXIS_TSTRB(s00_axis_tstrb),
		.S_AXIS_TLAST(s00_axis_tlast),
		.S_AXIS_TVALID(s00_axis_tvalid),
		.rdma_id(rdma_id),
		.rdma_opcode(rdma_opcode),
		.rdma_flags(rdma_flags),
		.rdma_local_key(rdma_local_key),
		.rdma_remote_key(rdma_remote_key),
		.rdma_btt(rdma_btt),
		.rdma_reserved(rdma_reserved),
		.rdma_entry_valid(rdma_entry_valid)
	);

// Instantiation of Axi Bus Interface M00_AXIS
	data_mover_controller_master_stream_v1_0_M00_AXIS # ( 
		.C_M_AXIS_TDATA_WIDTH(C_M00_AXIS_TDATA_WIDTH),
		.C_M_START_COUNT(C_M00_AXIS_START_COUNT)
	) data_mover_controller_master_stream_v1_0_M00_AXIS_inst (
		.M_AXIS_ACLK(m00_axis_aclk),
		.M_AXIS_ARESETN(m00_axis_aresetn),
		.M_AXIS_TVALID(m00_axis_tvalid),
		.M_AXIS_TDATA(m00_axis_tdata),
		.M_AXIS_TSTRB(m00_axis_tstrb),
		.M_AXIS_TLAST(m00_axis_tlast),
		.M_AXIS_TREADY(m00_axis_tready),
		.start(WRITE_STREAM_START),
		.input_data_0(DATA_IN_0),
		.input_data_1(DATA_IN_1),
		.input_data_2(DATA_IN_2),
		.input_data_3(DATA_IN_3),
		.input_data_4(DATA_IN_4),
		.input_data_5(DATA_IN_5),
		.input_data_6(DATA_IN_6),
		.input_data_7(DATA_IN_7),
		.busy(WRITE_STREAM_BUSY)
	);
	wire WRITE_STREAM_START;
	wire [31:0] DATA_IN_0;
	wire [31:0] DATA_IN_1;
	wire [31:0] DATA_IN_2;
	wire [31:0] DATA_IN_3;
	wire [31:0] DATA_IN_4;
	wire [31:0] DATA_IN_5;
	wire [31:0] DATA_IN_6;
	wire [31:0] DATA_IN_7;
	wire WRITE_STREAM_BUSY;
	wire IS_WRITTEN;
	
	// CQ entry wires from rdma_controller
	wire [31:0] cq_entry_0;
	wire [31:0] cq_entry_1;
	wire [31:0] cq_entry_2;
	wire [31:0] cq_entry_3;
	wire [31:0] cq_entry_4;
	wire [31:0] cq_entry_5;
	wire [31:0] cq_entry_6;
	wire [31:0] cq_entry_7;

	// Map CQ entry to stream master inputs (32 bytes total)
	assign DATA_IN_0 = cq_entry_0;
	assign DATA_IN_1 = cq_entry_1;
	assign DATA_IN_2 = cq_entry_2;
	assign DATA_IN_3 = cq_entry_3;
	assign DATA_IN_4 = cq_entry_4;
	assign DATA_IN_5 = cq_entry_5;
	assign DATA_IN_6 = cq_entry_6;
	assign DATA_IN_7 = cq_entry_7;
	
	// Export CQ entries to top-level for ILA debugging
	assign cq_entry_reg_0 = cq_entry_0;
	assign cq_entry_reg_1 = cq_entry_1;
	assign cq_entry_reg_2 = cq_entry_2;
	assign cq_entry_reg_3 = cq_entry_3;
	assign cq_entry_reg_4 = cq_entry_4;
	assign cq_entry_reg_5 = cq_entry_5;
	assign cq_entry_reg_6 = cq_entry_6;
	assign cq_entry_reg_7 = cq_entry_7;
	// Add user logic here
	data_mover_axi_cmd_master #
	(

	) data_mover_axi_cmd_master_inst
    (
        .clk(s00_axi_aclk),
        .rst_n(s00_axi_aresetn),
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
        .mm2s_rd_xfer_cmplt(mm2s_rd_xfer_cmplt),
        .STATE_REG(cmd_state_reg)
    );
	wire CMD_CTRL_READY;
	wire CMD_CTRL_START;
	wire CMD_IS_READ;
	wire [31:0] CMD_CTRL_SRC_ADDR;
	wire [31:0] CMD_CTRL_DST_ADDR;
	wire [31:0] CMD_CTRL_BTT;
	wire READ_COMPLETE;
	wire WRITE_COMPLETE;

	// Internal state wires from modules
	wire [3:0] state_reg;        // From rdma_controller
	wire [2:0] cmd_state_reg;    // From data_mover_axi_cmd_master
	wire has_work;               // From rdma_controller
    assign STATE_REG = state_reg;
	// Connect internal wires to top-level outputs
    assign IS_READ = CMD_IS_READ;
    assign READ_COMPLETE = mm2s_rd_xfer_cmplt;
    assign WRITE_COMPLETE = s2mm_wr_xfer_cmplt;

    rdma_controller #(
        .SQ_IDX_WIDTH(16),
        .ADDR_WIDTH  (32)
    ) rdma_controller_inst (
        .clk             (s00_axi_aclk),
        .rst             (~s00_axi_aresetn),
        .START_RDMA      (GLOBAL_ENABLE),
        .RESET_RDMA      (SOFT_RESET),

        .SQ_BASE_ADDR    (SQ_BASE_LO),
        .CQ_BASE_ADDR    (CQ_BASE_LO),
        .SQ_SIZE         (SQ_SIZE[15:0]),
        .CQ_SIZE         (CQ_SIZE[15:0]),
        .SQ_TAIL_SW      (SQ_TAIL[15:0]),
        .SQ_HEAD_HW      (HW_SQ_HEAD[15:0]),
        .CQ_HEAD_SW      (CQ_HEAD_SW[15:0]),
        .CQ_TAIL_HW      (HW_CQ_TAIL[15:0]),

        // RDMA entry inputs from stream parser
        .rdma_id         (rdma_id),
        .rdma_opcode     (rdma_opcode),
        .rdma_flags      (rdma_flags),
        .rdma_local_key  (rdma_local_key),
        .rdma_remote_key (rdma_remote_key),
        .rdma_btt        (rdma_btt),
        .rdma_entry_valid(rdma_entry_valid),

        // Unified command controller (for SQ/CQ operations)
        .CMD_CTRL_READY    (CMD_CTRL_READY),
        .CMD_CTRL_START    (CMD_CTRL_START),
        .CMD_CTRL_SRC_ADDR (CMD_CTRL_SRC_ADDR),
        .CMD_CTRL_DST_ADDR (CMD_CTRL_DST_ADDR),
        .CMD_CTRL_BTT      (CMD_CTRL_BTT),
        .CMD_CTRL_IS_READ  (CMD_IS_READ),
        .READ_COMPLETE     (READ_COMPLETE),
        .WRITE_COMPLETE    (WRITE_COMPLETE),

        // TX Streamer interface
        .tx_cmd_valid          (tx_cmd_valid),
        .tx_cmd_ready          (tx_cmd_ready),
        .tx_cmd_sq_index       (tx_cmd_sq_index),
        .tx_cmd_ddr_addr       (tx_cmd_ddr_addr),
        .tx_cmd_length         (tx_cmd_length),
        .tx_cmd_opcode         (tx_cmd_opcode),
        .tx_cmd_dest_qp        (tx_cmd_dest_qp),
        .tx_cmd_remote_addr    (tx_cmd_remote_addr),
        .tx_cmd_rkey           (tx_cmd_rkey),
        .tx_cmd_partition_key  (tx_cmd_partition_key),
        .tx_cmd_service_level  (tx_cmd_service_level),
        .tx_cmd_psn            (tx_cmd_psn),
        .tx_cpl_valid          (tx_cpl_valid),
        .tx_cpl_ready          (tx_cpl_ready),
        .tx_cpl_sq_index       (tx_cpl_sq_index),
        .tx_cpl_status         (tx_cpl_status),
        .tx_cpl_bytes_sent     (tx_cpl_bytes_sent),

        .STATE_REG       (state_reg),
        .HAS_WORK        (has_work),
        .START_STREAM    (WRITE_STREAM_START),
        .IS_STREAM_BUSY  (WRITE_STREAM_BUSY),

        // CQ Entry outputs
        .cq_entry_0      (cq_entry_0),
        .cq_entry_1      (cq_entry_1),
        .cq_entry_2      (cq_entry_2),
        .cq_entry_3      (cq_entry_3),
        .cq_entry_4      (cq_entry_4),
        .cq_entry_5      (cq_entry_5),
        .cq_entry_6      (cq_entry_6),
        .cq_entry_7      (cq_entry_7)
    );
	// User logic ends

	endmodule