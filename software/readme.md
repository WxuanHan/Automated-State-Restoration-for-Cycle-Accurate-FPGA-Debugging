This document contains two types of bare-metal software programs: 

- The program for the rebuilt DSAS architecture (with on-board LED monitoring) has completed on-board verification. 

- The program for the extended DSAS architecture (Frame configuration + Rollback + Communication) has had its relevant algorithms deployed but has not yet undergone on-board verification. This part still requires further refinement.

The perf_monitor program has been verified on-board. This throughput monitoring program requires the use of axi_bp_mon.v and axi_stream_thin_shim.v in hardware to form a performance monitor inserted between the FIFO generator and DMA.
