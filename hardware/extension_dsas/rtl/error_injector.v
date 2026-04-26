`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/09/01 15:25:36
// Design Name: 
// Module Name: error_injector
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


module error_injector(
	// error inject
	input			error_inject_enable,
	// mb if
	input  [31:0]	s_axis_tdata,
	input			s_axis_tvalid,
	input			s_axis_tlast,
	output 			s_axis_tready,
	// cordic if
	output [31:0]	m_axis_tdata,
	output			m_axis_tvalid,
	output			m_axis_tlast,
	input			m_axis_tready
);

assign s_axis_tready = m_axis_tready;
assign m_axis_tdata = error_inject_enable ? 32'hFFFF_FFFF : s_axis_tdata;
assign m_axis_tvalid = s_axis_tvalid;
assign m_axis_tlast = s_axis_tlast;

endmodule
