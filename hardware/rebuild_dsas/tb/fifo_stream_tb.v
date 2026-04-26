`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/07/07 09:55:02
// Design Name: 
// Module Name: fifo_stream_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module fifo_stream_tb();

reg  [31:0]	din_0,din_1,din_2,din_3,din_4,din_5,din_6,din_7;
reg  [31:0]	din_8,din_9,din_10,din_11,din_12,din_13,din_14,din_15;
reg			clk,rstn;
reg			enable;

wire 		empty,full,wr_en,s_axis_tvalid,s_axis_tlast,s_axis_tready;
wire [31:0]	s_axis_tdata;

wire 		wr_rst_busy,rd_rst_busy;

reg			m_axis_tready;
wire		m_axis_tvalid,m_axis_tlast;
wire [31:0] m_axis_tdata;

initial begin
	clk = 1'b0;
	rstn = 1'b0;
	m_axis_tready = 1'b0;
	enable = 1'b0;
	din_0 = 32'd0;
	din_1 = 32'd1;
	din_2 = 32'd2;
	din_3 = 32'd3;
	din_4 = 32'd4;
	din_5 = 32'd5;
	din_6 = 32'd6;
	din_7 = 32'd7;
	din_8 = 32'd8;
	din_9 = 32'd9;
	din_10 = 32'd10;
	din_11 = 32'd11;
	din_12 = 32'd12;
	din_13 = 32'd13;
	din_14 = 32'd14;
	din_15 = 32'd15;
	repeat(10) @(posedge clk);
	rstn = 1'b1;
	repeat(10) @(posedge clk);
	wait(empty);
	enable = 1'b1;
	repeat(2) @(posedge clk);
	enable = 1'b0;
	repeat(100) begin
		din_gen;
	end
	wait(s_axis_tlast);
	repeat(100) @(posedge clk);
	enable = 1'b1;
	repeat(2) @(posedge clk);
	enable = 1'b0;
	repeat(100) begin
		din_gen;
	end
	wait(s_axis_tlast);
	repeat(100) @(posedge clk);
	$stop;
end

always #5 clk = ~clk;

task din_gen;
	begin
		@(posedge clk);
		din_0 = din_0 + 32'd1;
		din_1 = din_1 + 32'd1;
		din_2 = din_2 + 32'd1;
		din_3 = din_3 + 32'd1;
		din_4 = din_4 + 32'd1;
		din_5 = din_5 + 32'd1;
		din_6 = din_6 + 32'd1;
		din_7 = din_7 + 32'd1;
		din_8 = din_8 + 32'd1;
		din_9 = din_9 + 32'd1;
		din_10 = din_10 + 32'd1;
		din_11 = din_11 + 32'd1;
		din_12 = din_12 + 32'd1;
		din_13 = din_13 + 32'd1;
		din_14 = din_14 + 32'd1;
		din_15 = din_15 + 32'd1;
	end
endtask

fifo_stream dut(
	.clk					(clk),
	.rstn					(rstn),
	.din_0					(din_0),
	.din_1					(din_1),
	.din_2					(din_2),
	.din_3					(din_3),
	.din_4					(din_4),
	.din_5					(din_5),
	.din_6					(din_6),
	.din_7					(din_7),
	.din_8					(din_8),
	.din_9					(din_9),
	.din_10					(din_10),
	.din_11					(din_11),
	.din_12					(din_12),
	.din_13					(din_13),
	.din_14					(din_14),
	.din_15					(din_15),
	.wr_en					(wr_en),
	.empty					(empty),
	.full					(full),
	.m_axis_tvalid			(s_axis_tvalid),		
	.m_axis_tready			(s_axis_tready),
	.m_axis_tdata			(s_axis_tdata),
	.m_axis_tlast			(s_axis_tlast)
);

write_arbiter write_arbiter_inst(
	.clk					(clk),
	.rstn					(rstn),
	.empty					(empty),
	.full					(full),
	.enable					(enable),
	.wr_en					(wr_en)
);

fifo_buffer fifo_buffer_inst(
  .wr_rst_busy				(wr_rst_busy),      // output wire wr_rst_busy
  .rd_rst_busy				(rd_rst_busy),      // output wire rd_rst_busy
  .s_aclk					(clk),                // input wire s_aclk
  .s_aresetn				(rstn),          // input wire s_aresetn
  .s_axis_tvalid			(s_axis_tvalid),  // input wire s_axis_tvalid
  .s_axis_tready			(s_axis_tready),  // output wire s_axis_tready
  .s_axis_tdata				(s_axis_tdata),    // input wire [31 : 0] s_axis_tdata
  .s_axis_tlast				(s_axis_tlast),    // input wire s_axis_tlast
  
  .m_axis_tvalid			(m_axis_tvalid),  // output wire m_axis_tvalid
  .m_axis_tready			(m_axis_tready),  // input wire m_axis_tready
  .m_axis_tdata				(m_axis_tdata),    // output wire [31 : 0] m_axis_tdata
  .m_axis_tlast				(m_axis_tlast)    // output wire m_axis_tlast
);

endmodule
