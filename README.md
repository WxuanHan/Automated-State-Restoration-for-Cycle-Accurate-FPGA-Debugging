# Automated-State-Restoration-for-Cycle-Accurate-FPGA-Debugging

This repository contains a project on automated state restoration for cycle-accurate FPGA debugging in heterogeneous FPGA-based SoC systems.

The work extends the original Device Start and Stop (DSAS) debugging concept into a broader hardware-software framework that combines:
- DSAS-based trace capture and controlled execution
- frame-oriented transaction localization and rollback coordination
- bare-metal ARM and MicroBlaze control software
- Host-side RNN-based anomaly detection and validation

This repository serves as a backup and reference archive for the source files, implementation variants, supporting scripts, generated datasets, and evaluation results associated with this project.

---

## Overview

This project addresses the problem of restoring and re-executing hardware behavior after anomalous events in FPGA-based debugging workflows. The central idea is to combine deterministic DSAS-style capture on the hardware side with Host-assisted anomaly analysis and rollback control, so that suspicious execution windows can be identified and replayed without relying on full global checkpoints.

The project is organized around three closely related components:
- hardware infrastructure for DSAS-based capture and replay support
- bare-metal software running on ARM and MicroBlaze processors
- an RNN-based anomaly detection workflow built on CORDIC square-root data

Compared with the original DSAS approach, which focuses on start-stop trace capture, trace buffering, and offloading data to external memory, this work further develops the debugging flow toward automated state restoration, frame-based anomaly localization, and Host-guided replay coordination.

---

## Repository Structure

At the top level, the repository contains three main folders:

- 'hardware/'  
  Hardware implementation of the DSAS-based debugging framework, including both an extension-oriented version and a rebuilt version

- 'software/'  
  Bare-metal ARM and MicroBlaze software used to control acquisition, communication, and replay-related behavior

- 'RNN/'  
  Data preparation, anomaly injection, model training, validation, and result files for RNN-based anomaly detection

This repository is intended to be read hierarchically. Each main directory corresponds to one part of the overall project workflow.

---

## Folder Guide

### 'hardware/'

The 'hardware/' directory contains the FPGA-side implementation of the debugging framework and is divided into two subdirectories:

- 'extension_dsas/'  
  an extended DSAS-oriented version used for architectural exploration and module-level enhancement

- 'rebuild_dsas/'  
  a more streamlined rebuilt version of the hardware framework

Both subdirectories follow a similar organization, typically including:
- 'rtl/' for hardware source files
- 'tb/' for testbenches
- 'tcl/' for project scripts
- 'xdc/' for constraints

The hardware side includes modules related to:
- clock management
- FIFO-based stream aggregation
- arbitration logic
- data path coordination
- wrapper integration
- frame-oriented transaction control

Within the extended version, two Frame Manager variants are present. The earlier version mainly performs basic counting and relies on later bare-metal software processing to derive cycle-level anomaly positions, while the later draft version moves toward directly filtering irrelevant data in hardware. This reflects the transition from software-assisted post-processing toward tighter hardware-side support for anomaly localization.

### 'software/'

The 'software/' directory contains the bare-metal control software for the processing elements of the system and is also divided into:
- 'extension_dsas/'
- 'rebuild_dsas/'

The software side includes:
- ARM-side control entry points
- MicroBlaze-side control entry points
- performance-monitoring support in the extended version
- Ethernet / UDP communication support for Host interaction in the extended version

The extended version contains a broader software support layer, including communication and monitoring helpers, while the rebuilt version keeps a more compact structure centered on the main ARM-side and MicroBlaze-side control programs.

### 'RNN/'

The 'RNN/' directory contains the data-driven anomaly detection part of the project.

It includes:
- 'cordic_series/' for CORDIC square-root input/output data and injected-anomaly series
- 'result/' for validation outputs grouped by anomaly category
- standalone Python scripts and model files in the root of 'RNN/'

This part of the project supports:
- formatting raw logged data into single-column numeric series
- shuffling paired input/output data for training
- training an RNN model on shuffled CORDIC input/output data
- injecting multiple anomaly types into reference sequences
- validating the trained model on anomalous sequences
- exporting figures and summary metrics such as ROC/PR plots and scored CSV files

---

## Project Workflow

The overall workflow of the project can be understood as three connected stages.

### 1. Hardware Capture and Controlled Execution

On the hardware side, the project builds on a DSAS-style debugging flow in which execution is started and stopped in a controlled manner, trace data is captured through FIFO-based logic, and the resulting stream is offloaded to memory. This provides deterministic observation windows while preserving the order of transactions.

### 2. Software Coordination Across ARM and MicroBlaze

On the software side, bare-metal programs running on the ARM processing system and the MicroBlaze soft processor coordinate execution, logging, communication, and replay-related behavior. The ARM side is responsible for higher-level control and interaction with data movement or Host communication, while the MicroBlaze side is closer to the PL-side data generation and deterministic control path.

### 3. Host-Side RNN-Based Anomaly Detection and Validation

On the Host side, an RNN is trained on golden-reference CORDIC square-root behavior and later used to detect deviations in sequences that include injected anomalies. The workflow includes shuffled training data, anomaly injection across several categories, validation scripts, and result export. The anomaly categories include random, structural, data-based aperiodic, data-based periodic, and mixed errors, with evaluation covering detection accuracy and class-specific results.

Together, these three stages form a unified project flow that links deterministic hardware capture, software-managed coordination, and learned anomaly analysis.

---

## Key Characteristics of the Work

The project is characterized by the following features:

- extension of the original DSAS idea beyond trace capture alone
- coordinated interaction among Host, PS, and PL domains
- exploration of frame-based rollback and anomaly localization mechanisms
- support for both an extended and a rebuilt implementation path
- use of CORDIC square-root data as a concrete DUT-oriented signal source for anomaly modeling
- integration of RNN-based analysis with the debugging workflow
- combination of hardware modules, bare-metal software, and Python-based data analysis in one project repository

---

## Notes on the Hardware Variants

The repository intentionally preserves two hardware/software tracks:

- 'extension_dsas/'  
  represents an extension-oriented stage with richer experimentation, additional helper logic, and architectural exploration

- 'rebuild_dsas/'  
  represents a cleaner rebuilt stage with a more compact structure and a more consolidated implementation path

This separation is useful for understanding the evolution of the project from DSAS-based extension work toward a more focused rebuilt framework.

---

## Notes on the RNN Data

The 'RNN/cordic_series/' directory contains multiple forms of CORDIC square-root data:
- paired input/output files
- shuffled training pairs
- datasets of different lengths such as '1e3', '1e4', and '1e5'
- anomaly-injected sequences
- corresponding masks and, for mixed anomalies, ownership labels

The shuffled datasets are used for model training so that the network learns the input-output relationship rather than sequence position. The different dataset lengths are useful for studying how data length and injected error ratio affect validation performance and for generating comparative analyses such as heatmaps.

The 'RNN/result/' directory stores validation outputs grouped by anomaly type, including plots, CSV summaries, and text or JSON summaries.

---

## Suggested Reading Order

For a quick overview of the project, the recommended reading order is:

1. 'README.md'  
   for the overall project structure

2. 'hardware/'  
   for the hardware framework and DSAS-related implementation variants

3. 'software/'  
   for the ARM-side and MicroBlaze-side control programs

4. 'RNN/'  
   for the anomaly-detection pipeline, generated datasets, and result summaries

---

## Tools and Technologies

This project involves:
- Verilog / RTL design
- bare-metal C
- Python
- TensorFlow / Keras
- FIFO- and AXI-oriented FPGA integration
- ARM + MicroBlaze heterogeneous control
- UDP / Ethernet-based Host communication
- RNN-based anomaly detection on CORDIC square-root data

---

## Notes

This repository is intended as a project backup and reference archive. It preserves the hardware, software, and RNN-related components of a DSAS-extended FPGA debugging workflow and its rebuilt implementation path, together with supporting data and evaluation outputs.
