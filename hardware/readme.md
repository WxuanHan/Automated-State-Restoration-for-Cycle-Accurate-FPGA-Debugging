# hardware

This directory contains the hardware-side implementation of the project. It covers the FPGA logic used to extend and rebuild a DSAS-based debugging framework for cycle-accurate trace capture, controlled execution, and replay-oriented coordination.

The hardware part of the work is organized into two implementation tracks:
- 'extension_dsas/'
- 'rebuild_dsas/'

---

## Overview

The hardware implementation is built around a DSAS-style execution model in which the Device Under Test is started and stopped in a controlled manner, trace data is captured through FIFO-based logic, and the resulting stream is transferred to memory for later analysis.

Compared with the original DSAS method, the hardware work in this repository further explores:
- clock gating and start-stop coordination
- FIFO-based stream aggregation
- arbitration logic
- wrapper-based integration
- frame-oriented transaction handling
- replay-related support

---

## Directory Structure

Both implementation tracks follow a similar internal structure:

- 'rtl/' – synthesizable Verilog / RTL source files
- 'tb/' – testbench files
- 'tcl/' – project scripts
- 'xdc/' – FPGA constraint files

---

## 'extension_dsas/'

The 'extension_dsas/' directory represents a richer exploratory version of the hardware framework. It contains a broader set of modules used to extend the original DSAS-style design toward more advanced debugging and anomaly-localization support.

Representative RTL files include:
- 'clock_manager.v'
- 'components_read.v'
- 'design_1_wrapper.v'
- 'error_injector.v'
- 'fifo_stream.v'
- 'axi_bp_mon.v'
- 'axi_stream_thin_shim.v'
- 'first_count.v'
- 'frame_manager.v'
- 'frame_manager_draft_v2.v'
- 'write_arbiter.v'

A particularly important detail in this directory is the presence of two Frame Manager variants:
- 'frame_manager.v' – an earlier version based mainly on counting, with later cycle-related processing handled in software
- 'frame_manager_draft_v2.v' – a later draft that moves toward filtering unnecessary data directly in hardware

This directory also includes a broader set of verification files, such as:
- 'fifo_stream_tb.v'
- 'fm_axis_source_with_error.v'
- 'frame_manager_tb.v'
- 'new_dsas_edge_checker.v'
- 'tb_dsas_with_fm.v'
- 'write_arbiter_tb.v'

### Using the customized performance monitor

The performance monitor in 'extension_dsas/' is implemented as a customized IP together with supporting RTL modules in 'rtl/'.

To use the monitor in the block design:

- add 'axi_stream_thin_shim.v' to the design
- add the customized IP 'perf_mon_axis_v1_0'
- manually connect the 'tap_tlast', 'tap_tvalid', and 'tap_tready' signals of 'axi_stream_thin_shim' to the corresponding 'mon_tlast', 'mon_tvalid', and 'mon_tready' signals of 'perf_mon_axis_v1_0'
- connect clock and reset signals in the same way as for the other modules
- connect the 'm_axis' interface of 'axi_stream_thin_shim' to 'S_AXIS_S2MM' of the DMA
- connect the 's_axis' interface of 'axi_stream_thin_shim' to the 'M_AXIS' output of the FIFO generator
- connect the 'S_AXI' interface of 'perf_mon_axis_v1_0' to 'M05_AXIS' of 'microblaze_0_axi_periph', which needs to be enabled or added in the block design

This setup allows the customized monitor to observe AXI-stream activity while remaining integrated into the existing DSAS data path.

---

## 'rebuild_dsas/'

The 'rebuild_dsas/' directory represents a more compact rebuilt version of the hardware framework.

Compared with 'extension_dsas/', this version keeps a smaller and cleaner set of core modules, including:
- 'clock_manager.v'
- 'components_read.v'
- 'design_1_wrapper.v'
- 'fifo_stream.v'
- 'first_count.v'
- 'write_arbiter.v'

The currently retained testbench files include:
- 'fifo_stream_tb.v'
- 'write_arbiter_tb.v'

This version appears to preserve the central capture-and-coordination path in a more consolidated form.

---

## Relationship to the Rest of the Project

The hardware files in this directory are intended to work together with:
- '../software/' – bare-metal ARM-side and MicroBlaze-side software
- '../RNN/' – Host-side anomaly detection, validation, and result generation

In the complete project flow, the hardware side is responsible for deterministic capture, controlled execution, and trace-related infrastructure.

---

## Notes

This directory preserves both the exploratory and rebuilt hardware implementations of the project. The two-track structure reflects the development path from a DSAS-based extension effort toward a cleaner rebuilt debugging framework.
