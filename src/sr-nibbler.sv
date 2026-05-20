// Copyright (c) 2026 Stanley Booth
// For enquiries: contact@stanleybooth.uk
//
// sr-nibbler.sv
//
// SR-Nibbler (formerly the SR-S4)
// An extremely simple 4-bit CPU (with logically faithful Logic World visualisation - some minor implementation differences)
// Called the SR-Nibbler because it only operates on nibbles.
// Specs:
// 4x4b Register file
// 4B (8x4b) of DMEM (with some memory mapped features)
// Supports up to 64 IMEM instructions (IMEM hosted externally)
// Very minimal with only 8 supported instructions.
//
// Instruction Set
// |-|-------------|-------------------------|-----------------------------------------------------|
// |0| NOP         | Does nothing            | No Operation										   |
// |1| ADD R1 R2 W | W = R1 + R2             | Addition											   |
// |2| SUB R1 R2 W | W = R1 - R2             | Subtraction										   |
// |3| LW R1 ADDR  | R1 = DMEM[ADDR]         | Load Word										   |
// |4| SW R1 ADDR  | DMEM[ADDR] = R1         | Store Word										   |
// |5| J ADDR      | IMEM -> ADDR            | Jump (sets entire PC)							   |
// |6| BEZ R1 ADDR | IMEM -> ADDR IF R1 == 0 | Branch if R1 equals zero (Sets bottom 4 bits of PC) |
// |7| LI R1 VALUE | R1 = VALUE              | Load Immediate									   |
// |-|-------------|-------------------------|-----------------------------------------------------|
//
// Memory Structure
// |-|------------------------------------------------------------------------|----ALIAS----|
// |0| Normal Nibble         												  |     N/A     |
// |1| Normal Nibble 														  |     N/A     |
// |2| Normal Nibble 														  |     N/A     |
// |3| Normal Nibble (with fully observable output)							  | o_nibble_3  |
// |4| Normal Nibble (with fully observable output)  						  | o_nibble_4  |
// |5| Normal Nibble (with fully observable output)     					  | o_nibble_5  |
// |6| Arithmetic right shift (saved value is arithmetic right shift of input)|     N/A     | 
// |7| Input Nibble 														  | i_nibble_7  |
// |-|------------------------------------------------------------------------|-------------|
//

module SR_Nibbler (
	input	logic [8:0]	instruction,	// Instruction from IMEM
	input	logic [3:0] i_nibble_7,		// Data input for processing - located in DMEM[7]
	input 	logic 		clk, 			// Clock (positive edge triggered)
	input 	logic 		reset,			// Reset (asynchronous active-high)
	output	logic [5:0] line_addr,		// Instruction line address
	output	logic [3:0] o_nibble5,		// First  memory output - located in DMEM[5]
	output	logic [3:0] o_nibble4,		// Second memory output - located in DMEM[4]
	output	logic [3:0] o_nibble3		// Third  memory output - located in DMEM[3]
);

	//Internal Connections
	logic [3:0]	r1, r2, alu_result, w_data, dmem_data_out, immed_val;
	logic 		branch_en; 
	
	//Control signals (from control unit)
	logic [8:0] jump_addr;
	logic [3:0] dmem_addr;
	logic [1:0] r1_addr;
	logic [1:0] r2_addr;
	logic [1:0] w_addr;
	logic 		sub, jump, branch, dmem_we, dmem_re, load_gprs, r2en, wren;
	
	ProgramCounter pc0 (
		.j_addr(jump_addr),	
		.jump(jump),	
		.branch(branch),	
		.branch_en(branch_en),	
		.clk(clk),	
		.reset(reset),
		.line_addr(line_addr)
	);
	
	always_comb
	begin : W_Data_Source_OR
		w_data = alu_result | dmem_data_out | immed_val;
	end
	
	GPRs gpr0 (
		.w_data(w_data),
		.r1_addr(r1_addr),
		.r2_addr(r2_addr),
		.w_addr(w_addr),
		.clk(clk),
		.reset(reset),
		.r1en(!load_gprs), //Note the inversion
		.r2en(r2en),
		.wren(wren),
		.w_addr_src(load_gprs),
		.r1_data(r1),
		.r2_data(r2)	
	);

	ALU alu0 (
		.r1(r1),
		.r2(r2),
		.sub(sub),
		.alu_result(alu_result)
	);
	
	Comparator comp0 (
		.alu_result(alu_result),
		.branch_en(branch_en)
	);
	
	DMEM dmem0 (
		.data_in(r1),
		.i_nibble_7(i_nibble_7),
		.addr(dmem_addr),
		.write_en(dmem_we),
		.read_en(dmem_re),
		.clk(clk),
		.reset(reset),
		.data_out(dmem_data_out),
		.o_nibble5(o_nibble5),
		.o_nibble4(o_nibble4),
		.o_nibble3(o_nibble3)
	);
	
	ControlUnit cu0 (
		.instruction(instruction),
		.jump_addr(jump_addr),
		.imm_value(immed_val),
		.dmem_addr(dmem_addr),
		.r1_addr(r1_addr),
		.r2_addr(r2_addr),
		.w_addr(w_addr),
		.sub(sub),
		.jump(jump),
		.branch(branch),
		.dmem_we(dmem_we),
		.dmem_re(dmem_re),
		.load_gprs(load_gprs),
		.r2en(r2en),
		.wren(wren)
	);

endmodule

module ALU (
	input 	logic [3:0]	r1,			// Register 1 value
	input 	logic [3:0]	r2,			// Register 2 value
	input	logic 		sub,		// Subtract signal (active-high) - otherwise add
	output 	logic [3:0]	alu_result	// ALU result
);
	
	always_comb
	begin
		case (sub)
			1'b0 : begin
				alu_result = r1 + r2;
			end
			
			1'b1 : begin
				alu_result = r1 - r2;
			end
		endcase
	end

endmodule

module Comparator (
	input 	logic [3:0]	alu_result,	// ALU result
	output 	logic 		branch_en	// Branch enable signal
);
	
	assign branch_en = alu_result == '0;

endmodule

module ProgramCounter (
	input	logic [5:0] j_addr,		// Address to jump to
	input 	logic		jump,		// Jump signal
	input 	logic		branch,		// Branch signal
	input 	logic		branch_en,	// Branch enable signal (branch condition met or not)
	input 	logic		clk,		// Clock (positive edge triggered)
	input 	logic		reset,		// Reset (asynchronous active-high)
	output	logic [5:0] line_addr	// Line address (to IMEM)
);

	always_ff @ (posedge clk, posedge reset)
	begin
		if (reset)
		begin
			line_addr <= '0;
		end
		else
		begin
			if (jump)
			begin
				line_addr <= j_addr;
			end
			else if (branch && branch_en) //Only sets lower nibble
			begin
				line_addr[3:0] <= j_addr[3:0];
			end
			else
			begin
				line_addr <= line_addr + 6'd1;
			end
		end
	end

endmodule

// 8 Nibbles of Data memory
// Includes the memory mapped switches and output nibbles
// Layout (from perspective of the CPU):
// 0 - Normal Nibble
// 1 - Normal Nibble
// 2 - Normal Nibble
// 3 - Normal Nibble (with fully observable output)
// 4 - Normal Nibble (with fully observable output)
// 5 - Normal Nibble (with fully observable output)
// 6 - Arithmetic right shift (saved value is arithmetic right shift of input)
// 7 - Input Nibble

module DMEM (
	input	logic [3:0] data_in,	// Data to be written to DMEM[addr]
	input	logic [3:0] i_nibble_7,	// Memory mapped input nibble (DMEM[7])
	input	logic [3:0] addr,		// Address to read/write at
	input 	logic		write_en,	// Write enable signal
	input 	logic		read_en,	// Read enable signal
	input 	logic		clk,		// Clock (positive edge triggered)
	input 	logic		reset,		// Reset (asynchronous active-high)
	output	logic [3:0] data_out,	// Data from DMEM[addr]
	output	logic [3:0] o_nibble5,	// Data from DMEM[5]
	output	logic [3:0] o_nibble4,	// Data from DMEM[4]
	output	logic [3:0] o_nibble3	// Data from DMEM[3][2:0]
);
	
	logic [3:0] nibbles [16];
	logic [3:0] nibble_regs [6];
	logic [3:0] nibble_regs_ext [7];
	logic [3:0] MM_ALU_result;
	logic [2:0] shift_reg;
	
	//Input nibble
	assign nibbles[7] = i_nibble_7;
	
	//Arithmetic right shift
	assign nibbles[6] = {shift_reg[2], shift_reg};
	
	//Normal nibbles
	assign nibbles[5] = nibble_regs[5];
	assign nibbles[4] = nibble_regs[4];
	assign nibbles[3] = nibble_regs[3];
	assign nibbles[2] = nibble_regs[2];
	assign nibbles[1] = nibble_regs[1];
	assign nibbles[0] = nibble_regs[0];
	
	//DMEM EXTENSION
	assign nibbles[15] = MM_ALU_result;
	assign nibbles[14] = nibble_regs_ext[6];
	assign nibbles[13] = nibble_regs_ext[5];
	assign nibbles[12] = nibble_regs_ext[4];
	assign nibbles[11] = nibble_regs_ext[3];
	assign nibbles[10] = nibble_regs_ext[2];
	assign nibbles[9] = nibble_regs_ext[1];
	assign nibbles[8] = nibble_regs_ext[0];
	
	//Output nibbles
	assign o_nibble5 = nibbles[5];
	assign o_nibble4 = nibbles[4];
	assign o_nibble3 = nibbles[3];
	
	always_ff @ (posedge clk, posedge reset)
	begin
		if (reset)
		begin
			nibble_regs[0] <= '0;
			nibble_regs[1] <= '0;
			nibble_regs[2] <= '0;
			nibble_regs[3] <= '0;
			nibble_regs[4] <= '0;
			nibble_regs[5] <= '0;
			
			nibble_regs_ext[0] <= '0;
			nibble_regs_ext[1] <= '0;
			nibble_regs_ext[2] <= '0;
			nibble_regs_ext[3] <= '0;
			nibble_regs_ext[4] <= '0;
			nibble_regs_ext[5] <= '0;
			nibble_regs_ext[6] <= '0;
			
			shift_reg <= '0;
		end
		else
		begin
			if (write_en)
			begin
				case (addr)
					default : begin
						/* Do nothing */
					end
					
					4'd0, 4'd1, 4'd2, 4'd3, 4'd4, 4'd5: begin
						nibble_regs[addr[2:0]] <= data_in;
					end
					
					4'd6 : begin
						shift_reg <= data_in[3:1];
					end
					
					4'd8, 4'd9, 4'd10, 4'd11, 4'd12, 4'd13, 4'd14 : begin
						nibble_regs_ext[addr[2:0]] <= data_in;
					end
				endcase
			end
		end
	end
	
	always_comb
	begin
		data_out = '0;
		
		if (read_en)
		begin
			data_out = nibbles[addr];
		end
	end
	
	//DMEM MEMORY MAPPED ALU EXTENSION
	logic [3:0] a, b;
	logic [7:0] mul_result;
	
	always_comb
	begin
		MM_ALU_result = '0;
		a = nibble_regs_ext[5];
		b = nibble_regs_ext[4];
		
		mul_result = a * b;
		
		if (nibble_regs_ext[6][3:2] == 2'b00)
		begin
		end
			case (nibble_regs_ext[6][1:0])
				2'd0 : begin //Bitwise AND
					MM_ALU_result = a & b;
				end
				
				2'd1 : begin //Bitwise OR
					MM_ALU_result = a | b;
				end
				
				2'd2 : begin //Bitwise XOR
					MM_ALU_result = a ^ b;
				end
				
				2'd3 : begin //Bitwise NOT
					MM_ALU_result = ~a;
				end
			endcase
		end
		else if (nibble_regs_ext[6][3:2] == 2'b01)
		begin //Multiplier with shiftable output
			MM_ALU_result = {mul_result >> nibble_regs_ext[6][1:0]}[3:0];
		end
		else if (nibble_regs_ext[6][3:2] == 2'b10)
		begin
			case (nibble_regs_ext[6][1:0])
				2'd0 : begin //Set 0 if A > B
					MM_ALU_result = (a > b) ? '0 : '1;
				end
				
				2'd1 : begin //Set 0 if A < B
					MM_ALU_result = (a < b) ? '0 : '1;
				end
				
				2'd2 : begin //Set 0 if A >= B
					MM_ALU_result = (a >= b) ? '0 : '1;
				end
				
				2'd3 : begin //Set 0 if A <= B
					MM_ALU_result = (a <= b) ? '0 : '1;
				end
			endcase
		end
	end

endmodule

module GPRs (
	input 	logic [3:0]	w_data,		// Data to be written to the W register
	input	logic [1:0] r1_addr,	// R1 register address
	input	logic [1:0] r2_addr,	// R2 register address
	input	logic [1:0] w_addr,		// Write register address
	input 	logic		clk,		// Clock (positive edge triggered)
	input 	logic		reset,		// Reset (asynchronous active-high)
	input	logic		r1en,		// Enable reading from R1
	input	logic		r2en,		// Enable reading from R2
	input	logic		wren,		// Enable writing to W
	input	logic		w_addr_src,	// Switch between write address sources (0: w_addr, 1: r1_addr)
	output	logic [3:0] r1_data,	// Data read from R1	
	output	logic [3:0] r2_data		// Data read from R2	
);
	
	logic [3:0] registers [4];
	logic [1:0] internal_write_addr;
	
	always_ff @ (posedge clk, posedge reset)
	begin
		if (reset)
		begin
			registers[0] <= '0;
			registers[1] <= '0;
			registers[2] <= '0;
			registers[3] <= '0;
		end
		else
		begin
			if (wren)
			begin
				registers[internal_write_addr] <= w_data;
			end
		end
	end
	
	always_comb
	begin
		r1_data = '0;
		r2_data = '0;
		
		if (r1en)
		begin
			r1_data = registers[r1_addr];
		end
		
		if (r2en)
		begin
			r2_data = registers[r2_addr];
		end
		
		internal_write_addr = w_addr_src ? r1_addr : w_addr;
	end
	
endmodule

//Combinational decoder based control unit
module ControlUnit (
	input	logic [8:0] instruction,	// The instruction to decode
	output	logic [5:0] jump_addr,		// The address to jump/branch to
	output	logic [3:0] imm_value,		// Immediate data output to W bus
	output	logic [3:0] dmem_addr,		// The address to read/write at in DMEM
	output	logic [1:0] r1_addr,		// The GPR R1 address
	output	logic [1:0] r2_addr,		// The GPR R2 address
	output	logic [1:0] w_addr,			// The GPR W address
	output 	logic		sub, 			// Subtract (ALU)
	output 	logic		jump, 			// Jump (PC)
	output 	logic		branch, 		// Branch (PC)
	output 	logic		dmem_we, 		// DMEM write enable (DMEM)
	output 	logic		dmem_re, 		// DMEM read enable (DMEM)
	output 	logic		load_gprs, 		// GPR write address mux and r1 disable (for GPR load from IMEM/DMEM) (GPRs)
	output 	logic		r2en, 			// R2 read enable (GPRs)
	output 	logic		wren			// GPR write enable (GPRs)
);
	
	logic load_imm;
	
	always_comb
	begin
		sub = '0;
		jump = '0;
		branch = '0;
		dmem_we = '0;
		dmem_re = '0;
		load_gprs = '0;
		r2en = '0;
		wren = '0;
		load_imm = '0;
		
		case (instruction[8:6])
			3'd0 : begin //No Operation
				/* Do nothing */
			end
			
			3'd1 : begin //Addition
				r2en = '1;
				wren = '1;
			end
			
			3'd2 : begin //Subtraction
				sub = '1;
				r2en = '1;
				wren = '1;
			end
			
			3'd3 : begin //Load Word
				dmem_re = '1;
				load_gprs = '1;
				wren = '1;
			end
			
			3'd4 : begin //Store Word
				dmem_we = '1;
			end
			
			3'd5 : begin //Jump
				jump = '1;
			end
			
			3'd6 : begin //Branch equal to zero
				branch = '1;
			end
			
			3'd7 : begin //Load Immediate
				load_gprs = '1;
				wren = '1;
				load_imm = '1;
			end
		endcase
		
		jump_addr = instruction[5:0];
		imm_value = load_imm ? instruction[3:0] : '0;
		dmem_addr = instruction[3:0];
		r1_addr = instruction[5:4];
		r2_addr = instruction[3:2];
		w_addr = instruction[1:0];
	end

endmodule