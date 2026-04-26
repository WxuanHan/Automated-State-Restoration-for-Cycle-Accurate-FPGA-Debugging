`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/07/02 14:17:09
// Design Name: 
// Module Name: fifo_stream
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


module fifo_stream(
	input			clk,
	input			rstn,
	input  [31:0]	din_0,
	input  [31:0]	din_1,
	input  [31:0]	din_2,
	input  [31:0]	din_3,
	input  [31:0]	din_4,
	input  [31:0]	din_5,
	input  [31:0]	din_6,
	input  [31:0]	din_7,
	input  [31:0]	din_8,
	input  [31:0]	din_9,
	input  [31:0]	din_10,
	input  [31:0]	din_11,
	input  [31:0]	din_12,
	input  [31:0]	din_13,
	input  [31:0]	din_14,
	input  [31:0]	din_15,
	input			wr_en,
	output			empty,
	output			full,
	output			m_axis_tvalid,		
	input			m_axis_tready,
	output [31:0]	m_axis_tdata,
	output			m_axis_tlast
);
wire [15:0]	wv_full;
wire [15:0]	wv_almost_full;
wire [15:0]	wv_empty;
wire [15:0]	wv_almost_empty;

wire [15:0]	wv_rd_en;
wire [31:0]	dout_0;
wire [31:0]	dout_1;
wire [31:0]	dout_2;
wire [31:0]	dout_3;
wire [31:0]	dout_4;
wire [31:0]	dout_5;
wire [31:0]	dout_6;
wire [31:0]	dout_7;
wire [31:0]	dout_8;
wire [31:0]	dout_9;
wire [31:0]	dout_10;
wire [31:0]	dout_11;
wire [31:0]	dout_12;
wire [31:0]	dout_13;
wire [31:0]	dout_14;
wire [31:0]	dout_15;

assign empty = &wv_empty;
assign full = &wv_full;

fifo_64x32 fifo_64x32_inst0 (
  .clk					(clk),                    // input wire clk
  .srst					(~rstn),                  // input wire srst
  .din					(din_0),                    // input wire [31 : 0] din
  .wr_en				(wr_en),                // input wire wr_en
  .rd_en				(wv_rd_en[0]),                // input wire rd_en
  .dout					(dout_0),                  // output wire [31 : 0] dout
  .full					(wv_full[0]),                  // output wire full
  .almost_full			(wv_almost_full[0]),    // output wire almost_full
  .empty				(wv_empty[0]),                // output wire empty
  .almost_empty			(wv_almost_empty[0])  // output wire almost_empty
);

fifo_64x32 fifo_64x32_inst1 (
  .clk					(clk),                    // input wire clk
  .srst					(~rstn),                  // input wire srst
  .din					(din_1),                    // input wire [31 : 0] din
  .wr_en				(wr_en),                // input wire wr_en
  .rd_en				(wv_rd_en[1]),                // input wire rd_en
  .dout					(dout_1),                  // output wire [31 : 0] dout
  .full					(wv_full[1]),                  // output wire full
  .almost_full			(wv_almost_full[1]),    // output wire almost_full
  .empty				(wv_empty[1]),                // output wire empty
  .almost_empty			(wv_almost_empty[1])  // output wire almost_empty
);

fifo_64x32 fifo_64x32_inst2 (
  .clk					(clk),                    // input wire clk
  .srst					(~rstn),                  // input wire srst
  .din					(din_2),                    // input wire [31 : 0] din
  .wr_en				(wr_en),                // input wire wr_en
  .rd_en				(wv_rd_en[2]),                // input wire rd_en
  .dout					(dout_2),                  // output wire [31 : 0] dout
  .full					(wv_full[2]),                  // output wire full
  .almost_full			(wv_almost_full[2]),    // output wire almost_full
  .empty				(wv_empty[2]),                // output wire empty
  .almost_empty			(wv_almost_empty[2])  // output wire almost_empty
);

fifo_64x32 fifo_64x32_inst3 (
  .clk					(clk),                    // input wire clk
  .srst					(~rstn),                  // input wire srst
  .din					(din_3),                    // input wire [31 : 0] din
  .wr_en				(wr_en),                // input wire wr_en
  .rd_en				(wv_rd_en[3]),                // input wire rd_en
  .dout					(dout_3),                  // output wire [31 : 0] dout
  .full					(wv_full[3]),                  // output wire full
  .almost_full			(wv_almost_full[3]),    // output wire almost_full
  .empty				(wv_empty[3]),                // output wire empty
  .almost_empty			(wv_almost_empty[3])  // output wire almost_empty
);

fifo_64x32 fifo_64x32_inst4 (
  .clk					(clk),                    // input wire clk
  .srst					(~rstn),                  // input wire srst
  .din					(din_4),                    // input wire [31 : 0] din
  .wr_en				(wr_en),                // input wire wr_en
  .rd_en				(wv_rd_en[4]),                // input wire rd_en
  .dout					(dout_4),                  // output wire [31 : 0] dout
  .full					(wv_full[4]),                  // output wire full
  .almost_full			(wv_almost_full[4]),    // output wire almost_full
  .empty				(wv_empty[4]),                // output wire empty
  .almost_empty			(wv_almost_empty[4])  // output wire almost_empty
);

fifo_64x32 fifo_64x32_inst5 (
  .clk					(clk),                    // input wire clk
  .srst					(~rstn),                  // input wire srst
  .din					(din_5),                    // input wire [31 : 0] din
  .wr_en				(wr_en),                // input wire wr_en
  .rd_en				(wv_rd_en[5]),                // input wire rd_en
  .dout					(dout_5),                  // output wire [31 : 0] dout
  .full					(wv_full[5]),                  // output wire full
  .almost_full			(wv_almost_full[5]),    // output wire almost_full
  .empty				(wv_empty[5]),                // output wire empty
  .almost_empty			(wv_almost_empty[5])  // output wire almost_empty
);

fifo_64x32 fifo_64x32_inst6 (
  .clk					(clk),                    // input wire clk
  .srst					(~rstn),                  // input wire srst
  .din					(din_6),                    // input wire [31 : 0] din
  .wr_en				(wr_en),                // input wire wr_en
  .rd_en				(wv_rd_en[6]),                // input wire rd_en
  .dout					(dout_6),                  // output wire [31 : 0] dout
  .full					(wv_full[6]),                  // output wire full
  .almost_full			(wv_almost_full[6]),    // output wire almost_full
  .empty				(wv_empty[6]),                // output wire empty
  .almost_empty			(wv_almost_empty[6])  // output wire almost_empty
);

fifo_64x32 fifo_64x32_inst7 (
  .clk					(clk),                    // input wire clk
  .srst					(~rstn),                  // input wire srst
  .din					(din_7),                    // input wire [31 : 0] din
  .wr_en				(wr_en),                // input wire wr_en
  .rd_en				(wv_rd_en[7]),                // input wire rd_en
  .dout					(dout_7),                  // output wire [31 : 0] dout
  .full					(wv_full[7]),                  // output wire full
  .almost_full			(wv_almost_full[7]),    // output wire almost_full
  .empty				(wv_empty[7]),                // output wire empty
  .almost_empty			(wv_almost_empty[7])  // output wire almost_empty
);

fifo_64x32 fifo_64x32_inst8 (
  .clk					(clk),                    // input wire clk
  .srst					(~rstn),                  // input wire srst
  .din					(din_8),                    // input wire [31 : 0] din
  .wr_en				(wr_en),                // input wire wr_en
  .rd_en				(wv_rd_en[8]),                // input wire rd_en
  .dout					(dout_8),                  // output wire [31 : 0] dout
  .full					(wv_full[8]),                  // output wire full
  .almost_full			(wv_almost_full[8]),    // output wire almost_full
  .empty				(wv_empty[8]),                // output wire empty
  .almost_empty			(wv_almost_empty[8])  // output wire almost_empty
);

fifo_64x32 fifo_64x32_inst9 (
  .clk					(clk),                    // input wire clk
  .srst					(~rstn),                  // input wire srst
  .din					(din_9),                    // input wire [31 : 0] din
  .wr_en				(wr_en),                // input wire wr_en
  .rd_en				(wv_rd_en[9]),                // input wire rd_en
  .dout					(dout_9),                  // output wire [31 : 0] dout
  .full					(wv_full[9]),                  // output wire full
  .almost_full			(wv_almost_full[9]),    // output wire almost_full
  .empty				(wv_empty[9]),                // output wire empty
  .almost_empty			(wv_almost_empty[9])  // output wire almost_empty
);

fifo_64x32 fifo_64x32_inst10 (
  .clk					(clk),                    // input wire clk
  .srst					(~rstn),                  // input wire srst
  .din					(din_10),                    // input wire [31 : 0] din
  .wr_en				(wr_en),                // input wire wr_en
  .rd_en				(wv_rd_en[10]),                // input wire rd_en
  .dout					(dout_10),                  // output wire [31 : 0] dout
  .full					(wv_full[10]),                  // output wire full
  .almost_full			(wv_almost_full[10]),    // output wire almost_full
  .empty				(wv_empty[10]),                // output wire empty
  .almost_empty			(wv_almost_empty[10])  // output wire almost_empty
);

fifo_64x32 fifo_64x32_inst11 (
  .clk					(clk),                    // input wire clk
  .srst					(~rstn),                  // input wire srst
  .din					(din_11),                    // input wire [31 : 0] din
  .wr_en				(wr_en),                // input wire wr_en
  .rd_en				(wv_rd_en[11]),                // input wire rd_en
  .dout					(dout_11),                  // output wire [31 : 0] dout
  .full					(wv_full[11]),                  // output wire full
  .almost_full			(wv_almost_full[11]),    // output wire almost_full
  .empty				(wv_empty[11]),                // output wire empty
  .almost_empty			(wv_almost_empty[11])  // output wire almost_empty
);

fifo_64x32 fifo_64x32_inst12 (
  .clk					(clk),                    // input wire clk
  .srst					(~rstn),                  // input wire srst
  .din					(din_12),                    // input wire [31 : 0] din
  .wr_en				(wr_en),                // input wire wr_en
  .rd_en				(wv_rd_en[12]),                // input wire rd_en
  .dout					(dout_12),                  // output wire [31 : 0] dout
  .full					(wv_full[12]),                  // output wire full
  .almost_full			(wv_almost_full[12]),    // output wire almost_full
  .empty				(wv_empty[12]),                // output wire empty
  .almost_empty			(wv_almost_empty[12])  // output wire almost_empty
);

fifo_64x32 fifo_64x32_inst13 (
  .clk					(clk),                    // input wire clk
  .srst					(~rstn),                  // input wire srst
  .din					(din_13),                    // input wire [31 : 0] din
  .wr_en				(wr_en),                // input wire wr_en
  .rd_en				(wv_rd_en[13]),                // input wire rd_en
  .dout					(dout_13),                  // output wire [31 : 0] dout
  .full					(wv_full[13]),                  // output wire full
  .almost_full			(wv_almost_full[13]),    // output wire almost_full
  .empty				(wv_empty[13]),                // output wire empty
  .almost_empty			(wv_almost_empty[13])  // output wire almost_empty
);

fifo_64x32 fifo_64x32_inst14 (
  .clk					(clk),                    // input wire clk
  .srst					(~rstn),                  // input wire srst
  .din					(din_14),                    // input wire [31 : 0] din
  .wr_en				(wr_en),                // input wire wr_en
  .rd_en				(wv_rd_en[14]),                // input wire rd_en
  .dout					(dout_14),                  // output wire [31 : 0] dout
  .full					(wv_full[14]),                  // output wire full
  .almost_full			(wv_almost_full[14]),    // output wire almost_full
  .empty				(wv_empty[14]),                // output wire empty
  .almost_empty			(wv_almost_empty[14])  // output wire almost_empty
);

fifo_64x32 fifo_64x32_inst15 (
  .clk					(clk),                    // input wire clk
  .srst					(~rstn),                  // input wire srst
  .din					(din_15),                    // input wire [31 : 0] din
  .wr_en				(wr_en),                // input wire wr_en
  .rd_en				(wv_rd_en[15]),                // input wire rd_en
  .dout					(dout_15),                  // output wire [31 : 0] dout
  .full					(wv_full[15]),                  // output wire full
  .almost_full			(wv_almost_full[15]),    // output wire almost_full
  .empty				(wv_empty[15]),                // output wire empty
  .almost_empty			(wv_almost_empty[15])  // output wire almost_empty
);

components_read components_read_inst(
	.clk				(clk),
	.rstn				(rstn),
	.full				(full),
	.almost_empty		(wv_almost_empty),
	.dout_0				(dout_0),
	.dout_1				(dout_1),
	.dout_2				(dout_2),
	.dout_3				(dout_3),
	.dout_4				(dout_4),
	.dout_5				(dout_5),
	.dout_6				(dout_6),
	.dout_7				(dout_7),
	.dout_8				(dout_8),
	.dout_9				(dout_9),
	.dout_10			(dout_10),
	.dout_11			(dout_11),
	.dout_12			(dout_12),
	.dout_13			(dout_13),
	.dout_14			(dout_14),
	.dout_15			(dout_15),
	.rd_en				(wv_rd_en),
	.m_axis_tvalid		(m_axis_tvalid),		
	.m_axis_tready		(m_axis_tready),
	.m_axis_tdata		(m_axis_tdata),
	.m_axis_tlast		(m_axis_tlast)
);
endmodule
