

proc generate {drv_handle} {
	xdefine_include_file $drv_handle "xparameters.h" "RDMA_core_AXI_LITE_slave_master" "NUM_INSTANCES" "DEVICE_ID"  "C_S00_AXI_BASEADDR" "C_S00_AXI_HIGHADDR" "C_S01_AXI_BASEADDR" "C_S01_AXI_HIGHADDR"
}
