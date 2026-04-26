`timescale 1ns/1ps
// tb_dsas_with_fm.v
// Visualization of binary-search style window narrowing with numeric step signals.

module tb_dsas_with_fm;

  // ---------------------------------------------------------------------------
  // Clock & reset
  // ---------------------------------------------------------------------------
  real CLK_NS = 10.0; // 100 MHz
  reg  clk  = 1'b0;
  reg  rstn = 1'b0;
  always #(CLK_NS/2.0) clk = ~clk;

  integer cyc = 0;
  always @(posedge clk) if (rstn) cyc <= cyc + 1;

  initial begin
    rstn = 1'b0;
    repeat (20) @(posedge clk);
    rstn = 1'b1;
  end

  // ---------------------------------------------------------------------------
  // Parameters
  // ---------------------------------------------------------------------------
  localparam integer DATA_W     = 32;
  localparam integer FRAME_LEN  = 1;
  localparam integer ERR_TRAN   = 200;
  localparam integer MODE       = 1;
  localparam [DATA_W-1:0] MARK  = 32'd1515886490;
  localparam integer EXTRA_WINDOWS_AFTER = 5;
  localparam integer SRC_WRAP   = 64; // 1~64??

  // ---------------------------------------------------------------------------
  // AXIS Source (manual version with synchronized counters & marker string)
  // ---------------------------------------------------------------------------
  reg                  src_tvalid;
  wire                 src_tready;
  reg  [DATA_W-1:0]    src_tdata;
  reg                  src_tlast;
  reg  [31:0]          glb_tran_idx;
  reg  [31:0]          src_tran_idx;
  reg                  err_event_pulse;

  // 40-bit ASCII?"64x1 "?"64x2 " ...
  reg  [39:0]          Frame_Length_s1;
  reg  [7:0]           s1_round;  // ???????? 1~64

  assign src_tready = 1'b1; // always ready

  
  function [39:0] make_s1_tag;
    input [7:0] round;  // 1..9
    reg   [7:0] digit;
  begin
    digit = "0" + round[3:0];
    // 5 chars: "6","4","x",digit," "
    make_s1_tag = {8'h36, 8'h34, 8'h78, digit, 8'h20};
  end
  endfunction

  // source behavior: one beat per cycle after reset
  // glb_tran_idx / src_tran_idx / Frame_Length_s1
  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      src_tvalid      <= 1'b0;
      src_tdata       <= 32'd0;
      glb_tran_idx    <= 32'd0;
      src_tran_idx    <= 32'd0;
      src_tlast       <= 1'b0;
      err_event_pulse <= 1'b0;
      s1_round        <= 8'd0;
      Frame_Length_s1 <= 40'd0;
    end else begin
      src_tvalid <= 1'b1;

      if (src_tvalid && src_tready) begin
        // -------------------------------
        // 1) glb_tran_idx: 0 -> 1 -> 2...
        // -------------------------------
        if (glb_tran_idx == 32'd0)
          glb_tran_idx <= 32'd1;
        else
          glb_tran_idx <= glb_tran_idx + 1;

        // ---------------------------------------------------
        // 2) src_tran_idx: 0 -> 1..64 -> 1..64 -> ...
        // ---------------------------------------------------
        if (src_tran_idx == 32'd0) begin
          // ??????0 -> 1
          src_tran_idx <= 32'd1;
          s1_round     <= 8'd1;                  
          Frame_Length_s1 <= make_s1_tag(8'd1);  
        end else if (src_tran_idx == SRC_WRAP) begin

          src_tran_idx <= 32'd1;
          s1_round     <= s1_round + 1;
          Frame_Length_s1 <= make_s1_tag(s1_round + 1);  
        end else begin
          
          src_tran_idx <= src_tran_idx + 1;
          Frame_Length_s1 <= Frame_Length_s1;
        end

        // -------------------------------
        // 3) src_tdata
        // -------------------------------
        src_tdata <= (src_tdata == 32'd0) ? 32'd1 : src_tdata + 1;

        // -------------------------------
        // 4) error injection pulse
        // -------------------------------
        if (glb_tran_idx == ERR_TRAN)
          err_event_pulse <= 1'b1;
        else
          err_event_pulse <= 1'b0;

        // TLAST: always 1 since FRAME_LEN=1
        src_tlast <= 1'b1;
      end
    end
  end

  // ---------------------------------------------------------------------------
  // Detector: use data MARKER as the error indicator (det_pulse)
  // ---------------------------------------------------------------------------
  wire det_old, det_pulse;
  new_dsas_edge_checker #(
    .DATA_W            (DATA_W),
    .FRAME_LEN         (FRAME_LEN),
    .TIMEOUT_TH        (16),
    .CHECK_TLAST       (0),
    .CHECK_DATA_MARKER (1),
    .MARKER            (MARK)
  ) u_chk (
    .aclk     (clk),
    .aresetn  (rstn),
    .s_tvalid (src_tvalid),
    .s_tready (src_tready),
    .s_tdata  (src_tdata),
    .s_tlast  (src_tlast),
    .det_old  (det_old),
    .det_pulse(det_pulse)
  );

  // ---------------------------------------------------------------------------
  // Precomputed bases for each step window that contains ERR_TRAN
  // ---------------------------------------------------------------------------
  localparam integer S1 = 64;
  localparam integer S2 = 32;
  localparam integer S3 = 16;
  localparam integer S4 = 8;
  localparam integer S5 = 4;
  localparam integer S6 = 2;
  localparam integer S7 = 1;

  localparam integer BASE64 = (ERR_TRAN / S1) * S1;
  localparam integer BASE32 = BASE64 + (((ERR_TRAN - BASE64) >= S2) ? S2 : 0);
  localparam integer BASE16 = BASE32 + (((ERR_TRAN - BASE32) >= S3) ? S3 : 0);
  localparam integer BASE8  = BASE16 + (((ERR_TRAN - BASE16) >= S4) ? S4 : 0);
  localparam integer BASE4  = BASE8  + (((ERR_TRAN - BASE8 ) >= S5) ? S5 : 0);
  localparam integer BASE2  = BASE4  + (((ERR_TRAN - BASE4 ) >= S6) ? S6 : 0);
  localparam integer BASE1  = ERR_TRAN;

  // ---------------------------------------------------------------------------
  // Other step visualization signals (keep old style, use glb_tran_idx)
  // ---------------------------------------------------------------------------
  reg [31:0] Frame_Length_s2;
  reg [31:0] Frame_Length_s3;
  reg [31:0] Frame_Length_s4;
  reg [31:0] Frame_Length_s5;
  reg [31:0] Frame_Length_s6;
  reg [31:0] Frame_Length_s7;

  wire in_s1 = (glb_tran_idx < (BASE64 + S1));
  wire in_s2 = (glb_tran_idx >= BASE32) && (glb_tran_idx < BASE32 + S2);
  wire in_s3 = (glb_tran_idx >= BASE16) && (glb_tran_idx < BASE16 + S3);
  wire in_s4 = (glb_tran_idx >= BASE8 ) && (glb_tran_idx < BASE8  + S4);
  wire in_s5 = (glb_tran_idx >= BASE4 ) && (glb_tran_idx < BASE4  + S5);
  wire in_s6 = (glb_tran_idx >= BASE2 ) && (glb_tran_idx < BASE2  + S6);
  wire in_s7 = (glb_tran_idx == BASE1);

  wire [31:0] ALL_X = {32{1'bx}};

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      Frame_Length_s2 <= ALL_X;
      Frame_Length_s3 <= ALL_X;
      Frame_Length_s4 <= ALL_X;
      Frame_Length_s5 <= ALL_X;
      Frame_Length_s6 <= ALL_X;
      Frame_Length_s7 <= ALL_X;
    end else begin
      Frame_Length_s2 <= in_s2 ? S2 : ALL_X;
      Frame_Length_s3 <= in_s3 ? S3 : ALL_X;
      Frame_Length_s4 <= in_s4 ? S4 : ALL_X;
      Frame_Length_s5 <= in_s5 ? S5 : ALL_X;
      Frame_Length_s6 <= in_s6 ? S6 : ALL_X;
      Frame_Length_s7 <= in_s7 ? S7 : ALL_X;
    end
  end

  // ---------------------------------------------------------------------------
  // Optional timing correlation
  // ---------------------------------------------------------------------------
  integer t_err = -1, t_det = -1;
  reg err_d, det_d;
  always @(posedge clk) begin
    err_d <= err_event_pulse;
    det_d <= det_pulse;
  end
  always @(posedge clk) begin
    if (rstn && (t_err < 0) && (err_event_pulse && !err_d)) t_err <= cyc;
    if (rstn && (t_err >= 0) && (t_det < 0) && (det_pulse && !det_d)) t_det <= cyc;
  end

  // ---------------------------------------------------------------------------
  // VCD dump
  // ---------------------------------------------------------------------------
  initial begin
    $dumpfile("tb_dsas_with_fm.vcd");
    $dumpvars(0, tb_dsas_with_fm);
  end

  // ---------------------------------------------------------------------------
  // Finish condition
  // ---------------------------------------------------------------------------
  localparam integer STOP_AT_TRAN = BASE64 + S1*(1 + EXTRA_WINDOWS_AFTER);
  always @(posedge clk) begin
    if (rstn && (glb_tran_idx >= STOP_AT_TRAN)) begin
      $display("[TB][INFO] ERR_TRAN=%0d  BASE64=%0d  BASE32=%0d  BASE16=%0d  BASE8=%0d  BASE4=%0d  BASE2=%0d  BASE1=%0d",
               ERR_TRAN, BASE64, BASE32, BASE16, BASE8, BASE4, BASE2, BASE1);
      $display("[TB][SUM]  t_err=%0d  t_det=%0d  dT=%0d cycles (%.3f ns)",
               t_err, t_det,
               (t_det>=0 && t_err>=0)?(t_det-t_err):-1,
               (t_det>=0 && t_err>=0)?((t_det-t_err)*CLK_NS):-1.0);
      $finish;
    end
  end

endmodule
