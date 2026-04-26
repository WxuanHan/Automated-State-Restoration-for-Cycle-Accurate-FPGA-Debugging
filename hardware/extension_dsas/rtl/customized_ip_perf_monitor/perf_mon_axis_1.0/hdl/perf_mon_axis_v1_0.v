`timescale 1ns / 1ps
// ============================================================================
//  perf_mon_axis_v1_0.v  (Top of AXI-Lite peripheral + AXIS monitor taps)
//  - Adds 3 user ports: mon_tvalid, mon_tready, mon_tlast
//  - Instantiates axi_bp_mon (backpressure/throughput counters)
//  - Wires S00_AXI (AXI-Lite) control to axi_bp_mon
//  Registers (via S00_AXI):
//    0x00 CONTROL  (W): bit0=CLR, bit1=START, bit2=STOP  (one-shot)
//    0x04 ACTIVE   (R): bit0=active
//    0x10 BEATS    (R)
//    0x14 STALL_UP (R)
//    0x18 STALL_DN (R)
//    0x1C CYCLES   (R)
// ============================================================================

module perf_mon_axis_v1_0 #
(
  // Users to add parameters here
  // User parameters ends

  // Do not modify the parameters beyond this line
  parameter integer C_S00_AXI_DATA_WIDTH = 32,
  parameter integer C_S00_AXI_ADDR_WIDTH = 6   // need cover 0x00..0x1C
)
(
  // Users to add ports here (AXIS monitor taps)
  input  wire mon_tvalid,
  input  wire mon_tready,
  input  wire mon_tlast,
  // User ports ends

  // Do not modify the ports beyond this line
  input  wire                               S_AXI_ACLK,
  input  wire                               S_AXI_ARESETN,
  input  wire [C_S00_AXI_ADDR_WIDTH-1 : 0]  S_AXI_AWADDR,
  input  wire [2 : 0]                       S_AXI_AWPROT,
  input  wire                               S_AXI_AWVALID,
  output wire                               S_AXI_AWREADY,
  input  wire [C_S00_AXI_DATA_WIDTH-1 : 0]  S_AXI_WDATA,
  input  wire [(C_S00_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
  input  wire                               S_AXI_WVALID,
  output wire                               S_AXI_WREADY,
  output wire [1 : 0]                       S_AXI_BRESP,
  output wire                               S_AXI_BVALID,
  input  wire                               S_AXI_BREADY,
  input  wire [C_S00_AXI_ADDR_WIDTH-1 : 0]  S_AXI_ARADDR,
  input  wire [2 : 0]                       S_AXI_ARPROT,
  input  wire                               S_AXI_ARVALID,
  output wire                               S_AXI_ARREADY,
  output wire [C_S00_AXI_DATA_WIDTH-1 : 0]  S_AXI_RDATA,
  output wire [1 : 0]                       S_AXI_RRESP,
  output wire                               S_AXI_RVALID,
  input  wire                               S_AXI_RREADY
);

  // ============================================================
  // Wires between AXI-Lite wrapper (S00_AXI) and the monitor
  // ============================================================
  wire        mon_clr, mon_start, mon_stop;    // one-shot controls from S00_AXI
  wire [31:0] beats, stall_up, stall_down, cycles_meas; // status to S00_AXI
  wire        active;

  // ============================================================
  // AXI-Lite submodule instance (registers & bus)
  // ============================================================
  perf_mon_axis_v1_0_S00_AXI #(
    .C_S_AXI_DATA_WIDTH (C_S00_AXI_DATA_WIDTH),
    .C_S_AXI_ADDR_WIDTH (C_S00_AXI_ADDR_WIDTH)
  ) u_s00_axi (
    .S_AXI_ACLK   (S_AXI_ACLK),
    .S_AXI_ARESETN(S_AXI_ARESETN),
    .S_AXI_AWADDR (S_AXI_AWADDR),
    .S_AXI_AWPROT (S_AXI_AWPROT),
    .S_AXI_AWVALID(S_AXI_AWVALID),
    .S_AXI_AWREADY(S_AXI_AWREADY),
    .S_AXI_WDATA  (S_AXI_WDATA),
    .S_AXI_WSTRB  (S_AXI_WSTRB),
    .S_AXI_WVALID (S_AXI_WVALID),
    .S_AXI_WREADY (S_AXI_WREADY),
    .S_AXI_BRESP  (S_AXI_BRESP),
    .S_AXI_BVALID (S_AXI_BVALID),
    .S_AXI_BREADY (S_AXI_BREADY),
    .S_AXI_ARADDR (S_AXI_ARADDR),
    .S_AXI_ARPROT (S_AXI_ARPROT),
    .S_AXI_ARVALID(S_AXI_ARVALID),
    .S_AXI_ARREADY(S_AXI_ARREADY),
    .S_AXI_RDATA  (S_AXI_RDATA),
    .S_AXI_RRESP  (S_AXI_RRESP),
    .S_AXI_RVALID (S_AXI_RVALID),
    .S_AXI_RREADY (S_AXI_RREADY),

    // user control/status connections
    .mon_clr      (mon_clr),
    .mon_start    (mon_start),
    .mon_stop     (mon_stop),
    .beats        (beats),
    .stall_up     (stall_up),
    .stall_down   (stall_down),
    .cycles_meas  (cycles_meas),
    .active       (active)
  );

  // ============================================================
  // Monitor instance: counts AXIS utilization/backpressure
  // Clock domain recommended to be the same as observed AXIS
  // Here we reuse S_AXI clock/reset for simplicity
  // ============================================================
  axi_bp_mon #(
    .W(32)
  ) u_bp_mon (
    .clk         (S_AXI_ACLK),
    .rstn        (S_AXI_ARESETN),
    .mon_tvalid  (mon_tvalid),
    .mon_tready  (mon_tready),
    .mon_tlast   (mon_tlast),
    .mon_clr     (mon_clr),
    .mon_start   (mon_start),
    .mon_stop    (mon_stop),
    .beats       (beats),
    .stall_up    (stall_up),
    .stall_down  (stall_down),
    .cycles_meas (cycles_meas),
    .active      (active)
  );

endmodule


// ============================================================================
//  axi_bp_mon : pure-Verilog AXIS backpressure/throughput monitor
//  - Counts valid&ready (beats), valid&~ready (stall_up), ~valid&ready (stall_down)
//  - active region gated by (clr/start/stop)
//  - width W=32 by default
// ============================================================================
module axi_bp_mon #(
  parameter W = 32
)(
  input  wire clk,
  input  wire rstn,
  input  wire mon_tvalid,
  input  wire mon_tready,
  input  wire mon_tlast,   // not required for counting; keep for future use
  input  wire mon_clr,
  input  wire mon_start,
  input  wire mon_stop,
  output reg  [W-1:0] beats,
  output reg  [W-1:0] stall_up,
  output reg  [W-1:0] stall_down,
  output reg  [W-1:0] cycles_meas,
  output reg          active
);
  always @(posedge clk or negedge rstn) begin
    if(!rstn) begin
      beats <= {W{1'b0}};
      stall_up <= {W{1'b0}};
      stall_down <= {W{1'b0}};
      cycles_meas <= {W{1'b0}};
      active <= 1'b0;
    end else begin
      if (mon_clr) begin
        beats <= {W{1'b0}};
        stall_up <= {W{1'b0}};
        stall_down <= {W{1'b0}};
        cycles_meas <= {W{1'b0}};
        active <= 1'b0;
      end else begin
        if (mon_start) active <= 1'b1;
        if (mon_stop)  active <= 1'b0;

        if (active) begin
          cycles_meas <= cycles_meas + {{(W-1){1'b0}}, 1'b1};
          if (mon_tvalid &  mon_tready) beats      <= beats      + {{(W-1){1'b0}}, 1'b1};
          if (mon_tvalid & ~mon_tready) stall_up   <= stall_up   + {{(W-1){1'b0}}, 1'b1};
          if (~mon_tvalid & mon_tready) stall_down <= stall_down + {{(W-1){1'b0}}, 1'b1};
        end
      end
    end
  end
endmodule
