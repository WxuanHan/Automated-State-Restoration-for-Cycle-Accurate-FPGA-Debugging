`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/07/04 15:32:24
// Design Name: 
// Module Name: write_arbiter_tb
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


module write_arbiter_tb();

reg  clk;
reg  rst;
reg  empty;
reg  full;
reg  enable;

wire wr_en;

initial begin
	clk = 1'b0;
	rst = 1'b1;
	empty = 1'b1;
	full = 1'b0;
	enable = 1'b0;
	
	repeat(10) @(posedge clk);
	rst = 1'b0;
	repeat(10) @(posedge clk);
	enable = 1'b1;
	repeat(100) @(posedge clk);
	$stop;
end

always #5 clk = ~clk;

write_arbiter dut(
	.clk			(clk),
	.rst			(rst),
	.empty			(empty),
	.full			(full),
	.enable			(enable),
	.wr_en			(wr_en)
);

endmodule
