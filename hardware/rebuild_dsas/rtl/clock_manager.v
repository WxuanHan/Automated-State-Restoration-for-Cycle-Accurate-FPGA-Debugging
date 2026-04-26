`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/07/02 15:59:18
// Design Name: 
// Module Name: clock_manager
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


module clock_manager(
	input			clk,
	input			rstn,
	input			full,
	input			enable,
	output			clk_out
);

reg  clk_dis;

always@(posedge clk or negedge rstn)begin
	if(~rstn)begin
		clk_dis <= 1'b0;
	end
	else if(full)begin
		clk_dis <= 1'b1;
	end
	else if(enable)begin
		clk_dis <= 1'b0;
	end
	else begin
		clk_dis <= clk_dis;
	end
end

assign clk_out = clk_dis ? 1'b0 : clk;

endmodule
