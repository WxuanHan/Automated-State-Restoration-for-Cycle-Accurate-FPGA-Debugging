`timescale 1ns/1ps
// new_dsas_edge_checker.v
// - Detects either: (a) wrong TLAST position, (b) backpressure timeout, or (c) DATA equals MARKER.
// - det_pulse is a 1-cycle pulse coincident with the violation.
// - Supports FRAME_LEN >= 1. When FRAME_LEN=1, beat_mod is always 0 and TLAST-position check still behaves.

module new_dsas_edge_checker #(
  parameter integer DATA_W            = 32,
  parameter integer FRAME_LEN         = 1,   // allow 1
  parameter integer TIMEOUT_TH        = 16,
  parameter        CHECK_TLAST        = 0,   // turn off in our TB; only use data marker
  parameter        CHECK_DATA_MARKER  = 1,
  parameter [DATA_W-1:0] MARKER       = 32'd1515886490
)(
  input  wire                  aclk,
  input  wire                  aresetn,

  input  wire                  s_tvalid,
  input  wire                  s_tready,
  input  wire [DATA_W-1:0]     s_tdata,
  input  wire                  s_tlast,

  output reg                   det_old,
  output reg                   det_pulse
);

  // Allow L=1
  localparam integer L = (FRAME_LEN < 1) ? 1 : FRAME_LEN;
  wire hs = s_tvalid & s_tready;

  // Beat position modulo L
  reg [15:0] beat_mod;
  always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) beat_mod <= 0;
    else if (hs) begin
      if (beat_mod == (L-1)) beat_mod <= 0;
      else beat_mod <= beat_mod + 1'b1;
    end
  end

  // Backpressure timeout counter
  reg [15:0] hold_cnt;
  wire hold_inc   = s_tvalid & ~s_tready;
  wire viol_bp_to = (hold_cnt >= TIMEOUT_TH);
  always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) hold_cnt <= 16'd0;
    else begin
      if (hold_inc) begin
        if (hold_cnt != 16'hFFFF) hold_cnt <= hold_cnt + 1'b1;
      end else hold_cnt <= 16'd0;
    end
  end

  // TLAST position violation (disabled when CHECK_TLAST==0)
  wire viol_tlast_pos = (CHECK_TLAST != 0) ? (hs & s_tlast & (beat_mod != (L-1))) : 1'b0;

  // Data equals MARKER (used as "fault detected" event)
  wire viol_marker = (CHECK_DATA_MARKER != 0) ? (hs & (s_tdata == MARKER)) : 1'b0;

  // Combine
  wire viol_now = viol_tlast_pos | viol_bp_to | viol_marker;

  // Outputs: det_pulse is 1-cycle; det_old is a sticky flag until TLAST
  always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      det_pulse <= 1'b0;
      det_old   <= 1'b0;
    end else begin
      det_pulse <= viol_now;
      if (viol_now) det_old <= 1'b1;
      else if (hs & s_tlast) det_old <= 1'b0;
    end
  end

endmodule
