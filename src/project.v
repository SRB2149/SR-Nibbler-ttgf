/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

// Pin Mappings:
// IN:
// 0 - Serial Instruction bit 0
// 1 - Serial Instruction bit 1
// 2 - Serial Instruction bit 2
// 3 - Serial Instruction bit 3
// 4 - Serial Instruction bit 4
// 5 - Memory mapped input nibble (DMEM 7) bit 0
// 6 - Memory mapped input nibble (DMEM 7) bit 1
// 7 - Memory mapped input nibble (DMEM 7) bit 2
//
// INOUT:
// 0 - IN  - Memory mapped input nibble (DMEM 7) bit 3
// 1 - OUT - Serial Line Address bit 0
// 2 - OUT - Serial Line Address bit 1
// 3 - OUT - Serial Line Address bit 2
// 4 - OUT - Memory mapped output nibble (DMEM 5) bit 0
// 5 - OUT - Memory mapped output nibble (DMEM 5) bit 1
// 6 - OUT - Memory mapped output nibble (DMEM 5) bit 2
// 7 - OUT - Memory mapped output nibble (DMEM 5) bit 3
//
// OUT:
// 0 - Memory mapped output nibble (DMEM 4) bit 0
// 1 - Memory mapped output nibble (DMEM 4) bit 1
// 2 - Memory mapped output nibble (DMEM 4) bit 2
// 3 - Memory mapped output nibble (DMEM 4) bit 3
// 4 - Memory mapped output nibble (DMEM 3) bit 0
// 5 - Memory mapped output nibble (DMEM 3) bit 1
// 6 - Memory mapped output nibble (DMEM 3) bit 2
// 7 - Memory mapped output nibble (DMEM 3) bit 3

module tt_um_sr_nibbler_srb2149 (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
  
	TT_Nibbler_interface tt_n0 (
		.in(ui_in),
		.io_in(uio_in[0]),
		.clk(clk),
		.n_rst(rst_n),
		.out(uo_out),
		.io_out(uio_out[7:1])
	);
	
	//Bidir pins direction
	assign uio_oe[0] = '0;
	assign uio_oe[7:1] = '1;
	
	//Unused
	assign uio_out[0] = '0;
	wire _unused = &{uio_in[7:1], 1'b0};

endmodule
