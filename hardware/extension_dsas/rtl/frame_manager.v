`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/09/01 16:27:55
// Design Name: 
// Module Name: frame_manager
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


module frame_manager(
	input				clk,
	input				rstn,
	input				s_axis_tvalid,
	input				s_axis_tready,
	input				fifo_stream_empty,
	output reg [31:0]	transaction_num,
	output reg [31:0]	dsas_cycle_num
);
reg [1:0]	fifo_stream_empty_pip;
wire		fifo_stream_empty_neg;
always@(posedge clk or negedge rstn)begin
	if(~rstn)begin
		fifo_stream_empty_pip <= 2'd0;
	end
	else begin
		fifo_stream_empty_pip <= {fifo_stream_empty_pip[0],fifo_stream_empty};
	end
end
assign fifo_stream_empty_neg = (~fifo_stream_empty_pip[0]) && fifo_stream_empty_pip[1];
always@(posedge clk or negedge rstn)begin
	if(~rstn)begin
		transaction_num <= 32'd0;
	end
	else if(fifo_stream_empty)begin
		transaction_num <= 32'd0;
	end
	else if(s_axis_tready && s_axis_tvalid)begin
		transaction_num <= transaction_num + 32'd1;
	end
	else begin
		transaction_num <= transaction_num;
	end
end
always@(posedge clk or negedge rstn)begin
	if(~rstn)begin
		dsas_cycle_num <= 32'd0;
	end
	else if(fifo_stream_empty_neg)begin
		dsas_cycle_num <= dsas_cycle_num + 32'd1;
	end
	else begin
		dsas_cycle_num <= dsas_cycle_num;
	end
end
endmodule
