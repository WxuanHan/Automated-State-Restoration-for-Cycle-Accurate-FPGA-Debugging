# RNN

This directory contains the RNN-based anomaly detection part of the project.

It includes the data preparation flow, anomaly injection scripts, model training and validation scripts, saved model files, and result outputs built around CORDIC square-root input/output sequences.

---

## Overview

The purpose of this directory is to support the Host-side anomaly detection workflow of the project.

This part of the work focuses on:
- preparing CORDIC square-root input/output data for model training and validation
- generating shuffled training pairs
- injecting different anomaly types into reference sequences
- training an RNN model on golden-reference behavior
- validating the trained model on faulty sequences
- exporting result plots and summary statistics for different anomaly categories

In the overall project flow, this directory represents the data-driven analysis side that complements the hardware and software debugging framework.

---

## Directory Structure

This directory contains two main subdirectories:

- 'cordic_series/'
- 'result/'

In addition, several Python scripts and model files are located directly in the root of 'RNN/'.

---

## 'cordic_series/'

The 'cordic_series/' directory contains CORDIC square-root data used for training, validation, and anomaly-injection experiments.

These files include:
- paired input/output data
- shuffled input/output pairs
- datasets of different lengths
- anomaly-injected sequences
- corresponding mask files
- mixed-anomaly ownership labels

### Main purposes of the data

The shuffled datasets are used for training the RNN. Their purpose is to ensure that the model learns the functional relationship between input and output rather than memorizing sequence order.

The datasets with different lengths are used to study how data size and injected error ratio influence model accuracy. These datasets are useful for comparative analyses such as heatmaps and sensitivity studies across different validation settings.

Overall, this directory serves as the main data source for both model development and anomaly-evaluation experiments.

---

## 'result/'

The 'result/' directory stores validation outputs grouped by anomaly type.

The result categories correspond to the different injected error types, including:
- random error
- structural error
- data-based aperiodic error
- data-based periodic error

Typical result files include:
- local prediction-versus-reference plots
- ROC / PR figures
- scored CSV files
- summary text files
- summary JSON files

This structure allows the validation results to be inspected separately for each anomaly category.

---

## Root-Level Files

The root of 'RNN/' contains the main scripts and model files used in the workflow.

Important files include:
- 'rnn_xy_shuffle.keras'
- 'shuffle.py'
- 'training_field_sqrt.py'
- 'validation_field.py'
- 'anomaly_injector_0.5mixed_error.py'
- 'anomaly_injector_0.5single_error.py'
- 'Format_Converter_for_RNN.py'

### Main roles of these files

- 'shuffle.py'  
  shuffles paired CORDIC input/output data while preserving input-output correspondence

- 'training_field_sqrt.py'  
  trains the RNN model on shuffled CORDIC square-root data

- 'validation_field.py'  
  validates the trained model on anomaly-injected sequences and exports evaluation results

- 'anomaly_injector_0.5single_error.py'  
  generates single-category anomaly datasets

- 'anomaly_injector_0.5mixed_error.py'  
  generates mixed-anomaly datasets together with ownership labels

- 'Format_Converter_for_RNN.py'  
  converts raw logged output into a clean single-column numeric series suitable for model processing

- 'rnn_xy_shuffle.keras'  
  stores the trained RNN model used in the validation workflow

---

## Workflow Summary

The RNN workflow in this directory can be understood as the following sequence:

1. prepare or convert raw CORDIC data  
2. shuffle paired input/output sequences for training
3. train the RNN model on golden-reference square-root behavior
4. generate anomaly-injected validation sequences
5. validate the trained model on anomalous data
6. save plots, scored outputs, and summary statistics by anomaly type

This workflow supports both binary anomaly detection and more detailed analysis across different error categories.

---

## Relationship to the Rest of the Project

The files in this directory are intended to work together with:
- '../hardware/' – FPGA-side debugging and capture framework
- '../software/' – ARM-side and MicroBlaze-side control software

In the complete project flow:
- the hardware captures and structures execution-related data
- the software coordinates data movement and control behavior
- the RNN workflow performs Host-side anomaly analysis and result generation

---

## Notes

This directory preserves the data preparation, model training, anomaly injection, validation, and result-generation parts of the project. It serves as the Host-side analysis component of the overall debugging workflow.
