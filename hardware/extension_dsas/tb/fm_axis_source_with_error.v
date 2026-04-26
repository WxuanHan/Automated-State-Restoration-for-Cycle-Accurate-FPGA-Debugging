`timescale 1ns/1ps
// fm_axis_source_with_error.v
// - AXIS traffic generator with single-error injection at transaction ERR_TRAN.
// - Supports FRAME_LEN >= 1. When FRAME_LEN = 1: "1 sample = 1 transaction" and TLAST is asserted every beat.
// - The error is injected on the LAST beat of the target transaction by outputting MARKER_VALUE
//   and pulsing err_event_pulse in the same cycle as TLAST.

module fm_axis_source_with_error #(
  parameter integer DATA_W         = 32,
  parameter integer FRAME_LEN      = 1,               // L >= 1 now
  parameter integer ERR_TRAN       = 199,             // 0-based transaction index
  parameter        MODE            = 1,               // bit0=1 enables injection
  parameter [DATA_W-1:0] MARKER_VALUE = 32'd1515886490
)(
  input  wire                  aclk,
  input  wire                  aresetn,

  // Optional runtime override for error position
  input  wire                  cfg_err_en,
  input  wire [31:0]           cfg_err_tran,

  // AXI4-Stream Master
  output reg                   m_tvalid,
  input  wire                  m_tready,
  output reg  [DATA_W-1:0]     m_tdata,
  output reg                   m_tlast,

  // Status/monitors
  output reg  [31:0]           cur_tran_idx,
  output reg                   err_event_pulse
);

  // Allow FRAME_LEN = 1 (1-beat per transaction)
  localparam integer L = (FRAME_LEN < 1) ? 1 : FRAME_LEN;

  // Beat counter within a transaction: 0..L-1
  reg  [31:0] beat_idx;
  reg         inc_tran_d;     // post-increment transaction index after LAST beat is accepted
  reg  [31:0] sample_idx;     // running sample counter (for non-marker data pattern)

  wire        hs       = m_tvalid & m_tready;
  wire [31:0] err_tran = cfg_err_en ? cfg_err_tran : ERR_TRAN[31:0];

  // End-of-transaction (LAST beat within the transaction)
  wire at_last      = (beat_idx == (L-1));
  wire in_err_tran  = (cur_tran_idx == err_tran);
  wire need_inject  = (MODE[0] == 1'b1) && in_err_tran && at_last;

  // Stream generation
  always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      m_tvalid        <= 1'b0;
      m_tlast         <= 1'b0;
      m_tdata         <= {DATA_W{1'b0}};
      cur_tran_idx    <= 32'd0;
      beat_idx        <= 32'd0;
      inc_tran_d      <= 1'b0;
      sample_idx      <= 32'd0;
      err_event_pulse <= 1'b0;
    end else begin
      // Keep valid asserted after reset; TB/dut can backpressure via m_tready
      if (!m_tvalid) m_tvalid <= 1'b1;

      // Post-increment transaction index one cycle after LAST handshake
      if (inc_tran_d) begin
        cur_tran_idx <= cur_tran_idx + 1;
        inc_tran_d   <= 1'b0;
      end

      // Default: clear the one-cycle event pulse
      err_event_pulse <= 1'b0;

      // Drive TLAST according to beat position
      m_tlast <= at_last;

      // Data: inject marker on target transaction's LAST beat; otherwise emit a simple ramp
      m_tdata <= need_inject ? MARKER_VALUE : sample_idx[DATA_W-1:0];

      if (hs) begin
        // Raise the error event exactly when the marker is output (coincident with TLAST)
        if (need_inject) begin
          err_event_pulse <= 1'b1;
        end

        // Advance the sample pattern every handshake
        sample_idx <= sample_idx + 1;

        // Advance position within transaction
        if (at_last) begin
          beat_idx   <= 32'd0;
          inc_tran_d <= 1'b1;   // defer cur_tran_idx++ to next cycle
        end else begin
          beat_idx   <= beat_idx + 1;
        end
      end
    end
  end

endmodule
