`timescale 1ns/1ps
// ------------------------------------------------------------
// Verilog testbench for frame_manager (with VCD + monitor)
// File : frame_manager_tb.v
// Top  : frame_manager_tb
// DUT  : frame_manager
// ------------------------------------------------------------

module frame_manager_tb;

  // -----------------------------
  // Parameters / clock / reset
  // -----------------------------
  parameter CLK_PER = 10;  // 100 MHz

  reg clk = 1'b0;
  always #(CLK_PER/2) clk = ~clk;

  reg rstn;

  // -----------------------------
  // DUT I/O
  // -----------------------------
  reg          s_axis_tvalid;
  reg          s_axis_tready;
  reg          fifo_stream_empty;
  wire [31:0]  transition_num;
  wire [31:0]  dsas_cycle_num;

  // -----------------------------
  // DUT instance (??????????)
  // -----------------------------
  frame_manager dut (
    .clk               (clk),
    .rstn              (rstn),
    .s_axis_tvalid     (s_axis_tvalid),
    .s_axis_tready     (s_axis_tready),
    .fifo_stream_empty (fifo_stream_empty),
    .transition_num    (transition_num),
    .dsas_cycle_num    (dsas_cycle_num)
  );

  // -----------------------------
  // Reference Model / Scoreboard
  // -----------------------------
  reg [31:0] exp_transition_num;
  reg [31:0] exp_dsas_cycle_num;

  reg  [1:0] fifo_empty_pip;
  wire       fifo_empty_fall;
  assign fifo_empty_fall = (~fifo_empty_pip[0]) & fifo_empty_pip[1];

  always @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      fifo_empty_pip      <= 2'b00;
      exp_transition_num  <= 32'd0;
      exp_dsas_cycle_num  <= 32'd0;
    end else begin
      fifo_empty_pip      <= {fifo_empty_pip[0], fifo_stream_empty};

      // transition_num: ??????????? +1
      if (fifo_stream_empty) begin
        exp_transition_num <= 32'd0;
      end else if (s_axis_tvalid & s_axis_tready) begin
        exp_transition_num <= exp_transition_num + 32'd1;
      end

      // dsas_cycle_num: ?->?? ?“???”??
      if (fifo_empty_fall) begin
        exp_dsas_cycle_num <= exp_dsas_cycle_num + 32'd1;
      end
    end
  end

  // ????????????
  integer error_cnt;
  always @(negedge clk) begin
    if (rstn) begin
      if (transition_num !== exp_transition_num) begin
        $display("[ERR] transition_num mismatch: DUT=%0d EXP=%0d @%0t",
                 transition_num, exp_transition_num, $time);
        error_cnt = error_cnt + 1;
      end
      if (dsas_cycle_num !== exp_dsas_cycle_num) begin
        $display("[ERR] dsas_cycle_num mismatch: DUT=%0d EXP=%0d @%0t",
                 dsas_cycle_num, exp_dsas_cycle_num, $time);
        error_cnt = error_cnt + 1;
      end
    end
  end

  // -----------------------------
  // Helper Tasks?? Verilog?
  // -----------------------------
  task drive_handshake;
    input integer beats;
    input integer ready_prob; // 0~100
    input integer valid_prob; // 0~100
    integer i;
    integer r1, r2;
  begin
    for (i=0; i<beats; i=i+1) begin
      @(posedge clk);
      r1 = $random; r2 = $random;

      if (ready_prob >= 100) s_axis_tready <= 1'b1;
      else if (ready_prob <= 0) s_axis_tready <= 1'b0;
      else s_axis_tready <= ((r1 % 100) < ready_prob);

      if (valid_prob >= 100) s_axis_tvalid <= 1'b1;
      else if (valid_prob <= 0) s_axis_tvalid <= 1'b0;
      else s_axis_tvalid <= ((r2 % 100) < valid_prob);
    end

    @(posedge clk);
    s_axis_tvalid <= 1'b0;
    s_axis_tready <= 1'b0;
  end
  endtask

  task set_fifo_empty;
    input empty;
  begin
    @(posedge clk);
    fifo_stream_empty <= empty;
  end
  endtask

  // -----------------------------
  // VCD ?? + ????
  // -----------------------------
  initial begin
    // 1) ?? VCD ???xsim ????
    $dumpfile("frame_manager_tb.vcd");
    // ?? dump ???
    $dumpvars(0, frame_manager_tb);

    // 2) ??????????????“???”???????
    $display("time\t rstn  empty  valid  ready  |  trans_num  dsas_cycle");
    $monitor("%0t\t %b     %b      %b      %b    |  %0d         %0d",
             $time, rstn, fifo_stream_empty, s_axis_tvalid, s_axis_tready,
             transition_num, dsas_cycle_num);
  end

  // -----------------------------
  // Test sequence?????????
  // -----------------------------
  initial begin
    s_axis_tvalid     = 1'b0;
    s_axis_tready     = 1'b0;
    fifo_stream_empty = 1'b1;  // ????
    rstn              = 1'b0;
    error_cnt         = 0;

    // ??
    repeat (10) @(posedge clk);
    rstn = 1'b1;
    repeat (5)  @(posedge clk);

    // ??0???“????”10 ???????????
    fifo_stream_empty = 1'b0;   // ??????????
    @(posedge clk);
    s_axis_tvalid     = 1'b1;
    s_axis_tready     = 1'b1;
    repeat (10) @(posedge clk);
    s_axis_tvalid     = 1'b0;
    s_axis_tready     = 1'b0;
    repeat (4) @(posedge clk);

    // ??1??????70% ready, 75% valid?
    drive_handshake(40, 70, 75);
    repeat (4) @(posedge clk);

    // ??2??? -> ??????? dsas_cycle ??
    set_fifo_empty(1'b1);
    repeat (3) @(posedge clk);
    set_fifo_empty(1'b0);
    drive_handshake(20, 100, 100); // ?? 20 ??????
    repeat (4) @(posedge clk);

    // ??3?valid=1, ready=0 ???
    set_fifo_empty(1'b0);
    s_axis_tvalid <= 1'b1;
    s_axis_tready <= 1'b0;
    repeat (8) @(posedge clk);
    s_axis_tvalid <= 1'b0;
    repeat (3) @(posedge clk);

    // ??4??????
    drive_handshake(50, 60, 80);
    repeat (10) @(posedge clk);

    // ????
    if (error_cnt==0) begin
      $display("\n[TB] PASS: no mismatches. transition_num=%0d, dsas_cycle_num=%0d\n",
               transition_num, dsas_cycle_num);
    end else begin
      $display("\n[TB] FAIL: total mismatches = %0d\n", error_cnt);
    end

    $finish;
  end

endmodule
