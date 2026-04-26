`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/07/03 09:56:01
// Design Name: 
// Module Name: write_arbiter
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


module write_arbiter(
	input			clk,
	input			rstn,
	input			empty,
	input			full,
	input			enable,
	output			wr_en
);

reg		r_wr_en;

always@(posedge clk or negedge rstn)begin
	if(~rstn)begin
		r_wr_en <= 1'b0;
	end
	else if(full)begin
		r_wr_en <= 1'b0;
	end
	else if(enable && empty)begin
		r_wr_en <= 1'b1;
	end
	else begin
		r_wr_en <= r_wr_en;
	end
end

assign wr_en = r_wr_en;

endmodule
