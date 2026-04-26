// ============================================================================
//  AXI-Stream Thin Shim with Robust Phase Lock (CORDIC-only Tap)
//  - Pass-through AXIS (no extra latency)
//  - Phase counter (0..PHASES-1). Auto realign by anchors 9..15.
//  - Export tap_* for CORDIC sub-stream only (phase == PHASE_CORDIC)
// ============================================================================

`timescale 1ns/1ps

module axi_stream_thin_shim #(
  parameter integer DATA_WIDTH     = 32,    // === ASIC: stream width
  parameter integer PHASES         = 16,    // === ASIC: lanes per frame
  parameter integer PHASE_CORDIC   = 4,     // === ASIC: CORDIC lane index (din4)
  parameter integer HAS_TLAST      = 1,     // 1: TLAST valid; 0: no TLAST
  parameter integer ANCHOR_MIN_HIT = 5      // ?????????5 ???
)(
  // --------------------------------------------------------------------------
  // AXIS Clock & Reset
  // --------------------------------------------------------------------------
  input  wire                     aclk,
  input  wire                     aresetn,

  // --------------------------------------------------------------------------
  // AXIS Slave (from FIFO generator)
  // --------------------------------------------------------------------------
  input  wire [DATA_WIDTH-1:0]    s_axis_tdata,
  input  wire                     s_axis_tvalid,
  output wire                     s_axis_tready,
  input  wire                     s_axis_tlast,   // used only if HAS_TLAST!=0

  // --------------------------------------------------------------------------
  // AXIS Master (to AXI DMA S2MM)
  // --------------------------------------------------------------------------
  output wire [DATA_WIDTH-1:0]    m_axis_tdata,
  output wire                     m_axis_tvalid,
  input  wire                     m_axis_tready,
  output wire                     m_axis_tlast,

  // --------------------------------------------------------------------------
  // CORDIC-only Tap (to perf_mon / ILA / counters)
  //  - tap_tvalid: ?? phase==PHASE_CORDIC ????????
  //  - tap_tdata : CORDIC ??????? s_axis_tdata ???
  //  - tap_tlast : ?? TLAST???????? TLAST=1 ???
  //  - tap_tready: ???? ready??????
  //  - dbg_phase : ????????????
  // --------------------------------------------------------------------------
  output wire                     tap_tvalid,
  output wire [DATA_WIDTH-1:0]    tap_tdata,
  output wire                     tap_tlast,
  output wire                     tap_tready,
  output wire [3:0]               dbg_phase
);

  // ==========================================================================
  // 1) AXIS Pass-through (?????????)
  // ==========================================================================
  assign m_axis_tdata  = s_axis_tdata;
  assign m_axis_tvalid = s_axis_tvalid;
  assign s_axis_tready = m_axis_tready;
  assign m_axis_tlast  = (HAS_TLAST!=0) ? s_axis_tlast : 1'b0;

  // === ASIC: ??? ===
  wire hs = s_axis_tvalid & m_axis_tready;

  // ==========================================================================
  // 2) ???? + ???????9..15 ??????
  //    - ????????????? (0..PHASES-1 ??)
  //    - ????????????????????? 0?????? din0?
  // ==========================================================================
  reg  [3:0] phase;        // ???? [0..PHASES-1]
  reg  [2:0] anchor_run;   // ????????? (0..7)

  // === ASIC: ??"??????"
  wire is_anchor_val = (s_axis_tdata[31:0] >= 32'd9) && (s_axis_tdata[31:0] <= 32'd15);

  // ???phase 9..15 ??tdata ?? (phase - 9 + 9) ?????
  wire anchor_hit = is_anchor_val && (phase >= 4'd9) &&
                    (s_axis_tdata[3:0] == (phase - 4'd9));

  always @(posedge aclk or negedge aresetn) begin
    if (!aresetn) begin
      phase      <= 4'd0;
      anchor_run <= 3'd0;
    end else if (hs) begin
      // ???????
      if (anchor_hit) begin
        if (anchor_run != 3'd7)
          anchor_run <= anchor_run + 3'd1;
        else
          anchor_run <= 3'd7;
      end else begin
        anchor_run <= 3'd0;
      end

      // ??????????????????
      if (anchor_run >= ANCHOR_MIN_HIT[2:0]) begin
        phase      <= 4'd0;   // ???? din0
        anchor_run <= 3'd0;
      end else begin
        // ????
        if (phase == (PHASES[3:0]-1))
          phase <= 4'd0;
        else
          phase <= phase + 4'd1;
      end
    end
  end

  assign dbg_phase = phase;

  // ==========================================================================
  // 3) CORDIC-only Tap???????????????/??
  //    - tap_tvalid????? + hs
  //    - tap_tdata ??? s_axis_tdata
  //    - tap_tlast ?(HAS_TLAST? s_axis_tlast : 0) & ????
  // ==========================================================================
  wire phase_is_cordic = (phase == PHASE_CORDIC[3:0]);

  assign tap_tvalid = hs & phase_is_cordic;        // === ASIC: ??????
  assign tap_tdata  = s_axis_tdata;                // ??????
  assign tap_tready = m_axis_tready;               // ????/??
  assign tap_tlast  = (HAS_TLAST!=0) ? (s_axis_tlast & phase_is_cordic) : 1'b0;

endmodule
