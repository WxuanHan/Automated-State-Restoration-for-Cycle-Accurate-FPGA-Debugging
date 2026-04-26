// axi_bp_mon.v — 统计 AXIS 的有效拍&背压拍&总周期（不改数流）
`timescale 1ns/1ps
module axi_bp_mon #(
  parameter W = 32
)(
  input  wire clk,
  input  wire rstn,

  // 只“观察”以下三根线（来自你要观察的那一段 AXIS）
  input  wire mon_tvalid,
  input  wire mon_tready,
  input  wire mon_tlast,  // 可接可不接

  // 控制（来自 AXI-Lite 寄存器写）
  input  wire mon_clr,    // 清零
  input  wire mon_start,  // 开始计数
  input  wire mon_stop,   // 停止计数

  // 输出（连到 AXI-Lite 读寄存器）
  output reg  [W-1:0] beats,
  output reg  [W-1:0] stall_up,
  output reg  [W-1:0] stall_down,
  output reg  [W-1:0] cycles_meas,
  output reg          active
);
  always @(posedge clk or negedge rstn) begin
    if(!rstn) begin
      beats <= 0; stall_up <= 0; stall_down <= 0; cycles_meas <= 0; active <= 1'b0;
    end else begin
      if (mon_clr) begin
        beats <= 0; stall_up <= 0; stall_down <= 0; cycles_meas <= 0; active <= 1'b0;
      end else begin
        if (mon_start) active <= 1'b1;
        if (mon_stop)  active <= 1'b0;

        if (active) begin
          cycles_meas <= cycles_meas + 1'b1;
          if (mon_tvalid &  mon_tready) beats      <= beats      + 1'b1;
          if (mon_tvalid & ~mon_tready) stall_up   <= stall_up   + 1'b1;  // 上游被挡
          if (~mon_tvalid & mon_tready) stall_down <= stall_down + 1'b1;  // 下游在等
        end
      end
    end
  end
endmodule
