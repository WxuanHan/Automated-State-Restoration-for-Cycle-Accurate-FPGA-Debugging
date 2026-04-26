# software

This directory contains the bare-metal software used to coordinate the hardware-side debugging framework.

The software part of the project is organized into two implementation tracks:
- 'extension_dsas/'
- 'rebuild_dsas/'

These programs run on the ARM processing system and the MicroBlaze soft processor, and are responsible for execution control, data movement, monitoring support, and communication-related tasks in the overall debugging flow.

---

## Overview

The software in this directory supports the DSAS-based debugging framework from the control side.

Its main responsibilities include:
- coordinating execution between ARM and MicroBlaze
- supporting DMA-based data capture and transfer
- interacting with hardware-side debugging logic
- providing communication-prototype support for Host interaction
- assisting replay- or rollback-related control paths

Compared with the hardware directory, which focuses on trace capture and stream handling in the PL, this directory contains the software-side logic that drives and supervises those mechanisms.

---

## Directory Structure

This directory contains two subdirectories:

- 'extension_dsas/'
- 'rebuild_dsas/'

---

## 'extension_dsas/'

The 'extension_dsas/' directory contains the more feature-rich software support layer used together with the extended hardware version.

Important files include:
- 'arm_main.c'
- 'arm_perf_monitor.c'
- 'mb_main.c'
- 'mb_perf_monitor.c'
- 'Ethernet.h'
- 'udp_perf_client.c'
- 'udp_perf_client.h'

### Main roles

In this version:
- the ARM-side files provide PS-side control logic and communication-prototype support
- the MicroBlaze-side files provide PL-side control logic closer to the local execution path
- the communication-related files represent a Host-facing communication prototype
- the Ethernet / UDP related code is kept at the software stage as a communication prototype rather than a fully deployed on-board communication path

In addition, the two monitoring-related bare-metal programs:
- 'arm_perf_monitor.c'
- 'mb_perf_monitor.c'

are used to evaluate the behavior of the data path between the FIFO and the DMA. Their purpose is to monitor whether the transfer remains continuous and well-coordinated, including throughput-related behavior and handshake activity along the FIFO-to-DMA path. This makes the extended software track useful not only for functional control, but also for observing transmission continuity and debugging streaming performance.

Overall, this version contains a broader software environment that matches the more exploratory nature of 'hardware/extension_dsas/'.

---

## 'rebuild_dsas/'

The 'rebuild_dsas/' directory contains the streamlined software setup used together with the rebuilt hardware version.

Its core files are:
- 'arm_dsas_main.c'
- 'mb_dsas_main.c'

This version keeps the software structure more compact and focuses on the main ARM-side and MicroBlaze-side entry points.

A practical debugging feature in this rebuilt path is the use of UART-based diagnostics on the ARM side. The ARM bare-metal program can print DMA-related values and buffer addresses through the UART interface, which can then be observed in PuTTY. This is used to check whether DMA data is being transferred correctly and whether the expected values are reaching the target memory locations as intended.

---

## ARM and MicroBlaze Roles

Across both implementation tracks, the software follows a heterogeneous control model:

- the ARM side is responsible for higher-level system coordination, control, diagnostics, and communication-prototype handling
- the MicroBlaze side is responsible for local control closer to the programmable-logic execution path

This division mirrors the overall project structure, where the PS and PL cooperate to support deterministic capture, analysis, and replay-related behavior.

---

## Relationship to the Rest of the Project

The software files in this directory are intended to work together with:
- '../hardware/' – FPGA-side RTL implementation and testbenches
- '../RNN/' – Host-side anomaly detection, validation, and result analysis

In the complete project flow:
- the hardware provides deterministic capture and trace infrastructure
- the software coordinates execution and data movement
- the communication-related code remains at the prototype stage
- the RNN workflow provides anomaly analysis on the Host side

---

## Notes

This directory preserves both the extension-oriented and rebuilt software implementations of the project. The two-track structure reflects the development path from a broader experimental software environment toward a more focused and compact control setup.
