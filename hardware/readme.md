This hardware file corresponds to two hardware projects: the rebuilt DSAS system; and the rebuilt DSAS system with extension. It contains the corresponding IP, RTL code, testbench code, and TCL scripts for project reproduction.


In extension_dsas folder:
performance monitor is a customized IP (as shown in rtl folder). When using the performance monitor, add the following module to the block design: `axi_stream_thin_shim.v` and add the following customized IP to the block design: `perf_mon_axis_v1_0`. Manually connect the `tap_tlast`, `_tvalid`, and `_ready` signals from `axi_stream_thin_shim` to the corresponding `mon_tlast`, `_tvalid`, and `_ready` signals in `perf_mon_axis_v1_0.v`. Connect clk and restn as with other modules. Connect the m_axis interface of axi_stream_thin_shim to S_AXIS_S2MM of the DMA. The s_axis interface of axi_stream_thin_shim connects to M_AXIS of the FIFO generator. perf_mon_axis_v1_0's S_AXI connects to M05_AXIS of microblaze_0_axi_periph (requires adding this interface).

