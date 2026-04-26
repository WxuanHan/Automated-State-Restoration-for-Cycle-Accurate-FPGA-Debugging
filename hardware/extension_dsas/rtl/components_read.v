`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/07/02 15:06:04
// Design Name: 
// Module Name: components_read
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


module components_read(
	input			clk,
	input			rstn,
	input			full,
	input  [15:0]	almost_empty,
	input  [31:0]	dout_0,
	input  [31:0]	dout_1,
	input  [31:0]	dout_2,
	input  [31:0]	dout_3,
	input  [31:0]	dout_4,
	input  [31:0]	dout_5,
	input  [31:0]	dout_6,
	input  [31:0]	dout_7,
	input  [31:0]	dout_8,
	input  [31:0]	dout_9,
	input  [31:0]	dout_10,
	input  [31:0]	dout_11,
	input  [31:0]	dout_12,
	input  [31:0]	dout_13,
	input  [31:0]	dout_14,
	input  [31:0]	dout_15,
	output [15:0]	rd_en,
	output			m_axis_tvalid,		
	input			m_axis_tready,
	output [31:0]	m_axis_tdata,
	output			m_axis_tlast	
);

reg  [15:0]	rv_rd_en;
reg	 [15:0]	rv_rd_en_d0;
reg			tvalid;
reg			tlast;
reg  [31:0]	tdata;

wire 		wr_rst_busy;
wire 		rd_rst_busy;
wire 		s_axis_tready;

always@(posedge clk or negedge rstn)begin
	if(~rstn)begin
		rv_rd_en[0] <= 1'b0;
	end
	else if(full & s_axis_tready)begin
		rv_rd_en[0] <= 1'b1;
	end
	else if(almost_empty[0])begin
		rv_rd_en[0] <= 1'b0;
	end
	else begin
		rv_rd_en[0] <= rv_rd_en[0];
	end
end

always@(posedge clk or negedge rstn)begin
	if(~rstn)begin
		rv_rd_en[1] <= 1'b0;
	end
	else if(almost_empty[1])begin
		rv_rd_en[1] <= 1'b0;
	end
	else if(almost_empty[0])begin
		rv_rd_en[1] <= 1'b1;
	end
	else begin
		rv_rd_en[1] <= rv_rd_en[1];
	end
end

always@(posedge clk or negedge rstn)begin
	if(~rstn)begin
		rv_rd_en[2] <= 1'b0;
	end
	else if(almost_empty[2])begin
		rv_rd_en[2] <= 1'b0;
	end
	else if(almost_empty[1])begin
		rv_rd_en[2] <= 1'b1;
	end
	else begin
		rv_rd_en[2] <= rv_rd_en[2];
	end
end

always@(posedge clk or negedge rstn)begin
	if(~rstn)begin
		rv_rd_en[3] <= 1'b0;
	end
	else if(almost_empty[3])begin
		rv_rd_en[3] <= 1'b0;
	end
	else if(almost_empty[2])begin
		rv_rd_en[3] <= 1'b1;
	end
	else begin
		rv_rd_en[3] <= rv_rd_en[3];
	end
end

always@(posedge clk or negedge rstn)begin
	if(~rstn)begin
		rv_rd_en[4] <= 1'b0;
	end
	else if(almost_empty[4])begin
		rv_rd_en[4] <= 1'b0;
	end
	else if(almost_empty[3])begin
		rv_rd_en[4] <= 1'b1;
	end
	else begin
		rv_rd_en[4] <= rv_rd_en[4];
	end
end

always@(posedge clk or negedge rstn)begin
	if(~rstn)begin
		rv_rd_en[5] <= 1'b0;
	end
	else if(almost_empty[5])begin
		rv_rd_en[5] <= 1'b0;
	end
	else if(almost_empty[4])begin
		rv_rd_en[5] <= 1'b1;
	end
	else begin
		rv_rd_en[5] <= rv_rd_en[5];
	end
end

always@(posedge clk or negedge rstn)begin
	if(~rstn)begin
		rv_rd_en[6] <= 1'b0;
	end
	else if(almost_empty[6])begin
		rv_rd_en[6] <= 1'b0;
	end
	else if(almost_empty[5])begin
		rv_rd_en[6] <= 1'b1;
	end
	else begin
		rv_rd_en[6] <= rv_rd_en[6];
	end
end

always@(posedge clk or negedge rstn)begin
	if(~rstn)begin
		rv_rd_en[7] <= 1'b0;
	end
	else if(almost_empty[7])begin
		rv_rd_en[7] <= 1'b0;
	end
	else if(almost_empty[6])begin
		rv_rd_en[7] <= 1'b1;
	end
	else begin
		rv_rd_en[7] <= rv_rd_en[7];
	end
end

always@(posedge clk or negedge rstn)begin
	if(~rstn)begin
		rv_rd_en[8] <= 1'b0;
	end
	else if(almost_empty[8])begin
		rv_rd_en[8] <= 1'b0;
	end
	else if(almost_empty[7])begin
		rv_rd_en[8] <= 1'b1;
	end
	else begin
		rv_rd_en[8] <= rv_rd_en[8];
	end
end

always@(posedge clk or negedge rstn)begin
	if(~rstn)begin
		rv_rd_en[9] <= 1'b0;
	end
	else if(almost_empty[9])begin
		rv_rd_en[9] <= 1'b0;
	end
	else if(almost_empty[8])begin
		rv_rd_en[9] <= 1'b1;
	end
	else begin
		rv_rd_en[9] <= rv_rd_en[9];
	end
end

always@(posedge clk or negedge rstn)begin
	if(~rstn)begin
		rv_rd_en[10] <= 1'b0;
	end
	else if(almost_empty[10])begin
		rv_rd_en[10] <= 1'b0;
	end
	else if(almost_empty[9])begin
		rv_rd_en[10] <= 1'b1;
	end
	else begin
		rv_rd_en[10] <= rv_rd_en[10];
	end
end

always@(posedge clk or negedge rstn)begin
	if(~rstn)begin
		rv_rd_en[11] <= 1'b0;
	end
	else if(almost_empty[11])begin
		rv_rd_en[11] <= 1'b0;
	end
	else if(almost_empty[10])begin
		rv_rd_en[11] <= 1'b1;
	end
	else begin
		rv_rd_en[11] <= rv_rd_en[11];
	end
end

always@(posedge clk or negedge rstn)begin
	if(~rstn)begin
		rv_rd_en[12] <= 1'b0;
	end
	else if(almost_empty[12])begin
		rv_rd_en[12] <= 1'b0;
	end
	else if(almost_empty[11])begin
		rv_rd_en[12] <= 1'b1;
	end
	else begin
		rv_rd_en[12] <= rv_rd_en[12];
	end
end

always@(posedge clk or negedge rstn)begin
	if(~rstn)begin
		rv_rd_en[13] <= 1'b0;
	end
	else if(almost_empty[13])begin
		rv_rd_en[13] <= 1'b0;
	end
	else if(almost_empty[12])begin
		rv_rd_en[13] <= 1'b1;
	end
	else begin
		rv_rd_en[13] <= rv_rd_en[13];
	end
end

always@(posedge clk or negedge rstn)begin
	if(~rstn)begin
		rv_rd_en[14] <= 1'b0;
	end
	else if(almost_empty[14])begin
		rv_rd_en[14] <= 1'b0;
	end
	else if(almost_empty[13])begin
		rv_rd_en[14] <= 1'b1;
	end
	else begin
		rv_rd_en[14] <= rv_rd_en[14];
	end
end

always@(posedge clk or negedge rstn)begin
	if(~rstn)begin
		rv_rd_en[15] <= 1'b0;
	end
	else if(almost_empty[15])begin
		rv_rd_en[15] <= 1'b0;
	end
	else if(almost_empty[14])begin
		rv_rd_en[15] <= 1'b1;
	end
	else begin
		rv_rd_en[15] <= rv_rd_en[15];
	end
end

assign rd_en = rv_rd_en;

always@(posedge clk or negedge rstn)begin
	if(~rstn)begin
		tvalid <= 1'b0;
	end
	else if(|rv_rd_en)begin
		tvalid <= 1'b1;
	end
	else begin
		tvalid <= 1'b0;
	end
end

always@(posedge clk or negedge rstn)begin
	if(~rstn)begin
		tlast <= 1'b0;
	end
	else if(rv_rd_en[15] && almost_empty[15])begin
		tlast <= 1'b1;
	end
	else begin
		tlast <= 1'b0;
	end
end

always@(posedge clk or negedge rstn)begin
	if(~rstn)begin
		rv_rd_en_d0 <= 32'd0;
	end
	else begin
		rv_rd_en_d0 <= rv_rd_en;
	end
end

always@(posedge clk or negedge rstn)begin
	if(~rstn)begin
		tdata <= 32'd0;
	end
	else if(rv_rd_en_d0[0])begin
		tdata <= dout_0;
	end
	else if(rv_rd_en_d0[1])begin
		tdata <= dout_1;
	end
	else if(rv_rd_en_d0[2])begin
		tdata <= dout_2;
	end
	else if(rv_rd_en_d0[3])begin
		tdata <= dout_3;
	end
	else if(rv_rd_en_d0[4])begin
		tdata <= dout_4;
	end
	else if(rv_rd_en_d0[5])begin
		tdata <= dout_5;
	end
	else if(rv_rd_en_d0[6])begin
		tdata <= dout_6;
	end
	else if(rv_rd_en_d0[7])begin
		tdata <= dout_7;
	end
	else if(rv_rd_en_d0[8])begin
		tdata <= dout_8;
	end
	else if(rv_rd_en_d0[9])begin
		tdata <= dout_9;
	end
	else if(rv_rd_en_d0[10])begin
		tdata <= dout_10;
	end
	else if(rv_rd_en_d0[11])begin
		tdata <= dout_11;
	end
	else if(rv_rd_en_d0[12])begin
		tdata <= dout_12;
	end
	else if(rv_rd_en_d0[13])begin
		tdata <= dout_13;
	end
	else if(rv_rd_en_d0[14])begin
		tdata <= dout_14;
	end
	else if(rv_rd_en_d0[15])begin
		tdata <= dout_15;
	end
	else begin
		tdata <= tdata;
	end
end


fifo_axis_cache fifo_axis_cache_inst (
  .wr_rst_busy			(wr_rst_busy),      // output wire wr_rst_busy
  .rd_rst_busy			(rd_rst_busy),      // output wire rd_rst_busy
  .s_aclk				(clk),                // input wire s_aclk
  .s_aresetn			(rstn),          // input wire s_aresetn
  .s_axis_tvalid		(tvalid),  // input wire s_axis_tvalid
  .s_axis_tready		(s_axis_tready),  // output wire s_axis_tready
  .s_axis_tdata			(tdata),    // input wire [31 : 0] s_axis_tdata
  .s_axis_tlast			(tlast),    // input wire s_axis_tlast
  .m_axis_tvalid		(m_axis_tvalid),  // output wire m_axis_tvalid
  .m_axis_tready		(m_axis_tready),  // input wire m_axis_tready
  .m_axis_tdata			(m_axis_tdata),   // output wire [31 : 0] m_axis_tdata
  .m_axis_tlast			(m_axis_tlast)    // output wire m_axis_tlast
);

endmodule
