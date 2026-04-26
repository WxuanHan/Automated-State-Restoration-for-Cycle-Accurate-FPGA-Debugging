`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/07/03 09:37:27
// Design Name: 
// Module Name: first_count
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


module first_count(
	input		clk,
	input		rstn,
	input		en,
	output [31:0] count_out
);

reg  [31:0]	rv_count_out;

always@(posedge clk or negedge rstn)begin
	if(~rstn)begin
		rv_count_out <= 32'd0;
	end
	else if(en)begin
		rv_count_out <= rv_count_out + 32'd1;
	end
	else begin
		rv_count_out <= rv_count_out;
	end
end

assign count_out = rv_count_out;

endmodule
