// Copyright (c) 2026 Stanley Booth
// For enquiries: contact@stanleybooth.uk
//
// tt-nibbler-interface.sv
//
// A very basic interface between the SR-Nibbler and the Tiny Tapeout IO pins.
// How to use:
// Clock in the high 4 bits of the instruction
// Clock in the low 5 bits of the instruction
// Clock the CPU (executes the instruction)
// Clock out the high 3 bits of the next line address
// Clock out the low 3 bits of the next line address
// Clock out the low 3 bits of the next line address
// Clock once more and repeat.

module TT_Nibbler_interface (
	input 	logic [7:0] in,
	input	logic 		io_in,
	input	logic 		clk,
	input	logic 		n_rst,
	output	logic [7:0] out,
	output	logic [6:0]	io_out
);

	typedef enum {
		LOAD_I_HIGH,
		LOAD_I_LOW,
		EXECUTE,
		WRITE_A_HIGH,
		WRITE_A_LOW,
		WAIT
	} IO_Controller_State_e;
	
	IO_Controller_State_e state, next_state;
	
	logic [8:0] instruction_sr, next_instr_sr;
	logic [5:0] line_addr;
	logic [2:0] pc_shift_out;
	logic 		cpu_clk;
	logic 		reset;

	SR_Nibbler (
		.instruction(instruction_sr),
		.i_nibble_7({io_in, in[7:5]}),
		.clk(cpu_clk),
		.reset(reset),
		.line_addr(line_addr),
		.o_nibble5(io_out[6:3]),
		.o_nibble4(out[3:0]),
		.o_nibble3(out[7:4])
	);
	
	assign reset = !n_rst;
	assign io_out[2:0] = pc_shift_out;
	
	always_ff @ (posedge clk, posedge reset)
	begin
		if (reset)
		begin
			state <= LOAD_I_HIGH;
		
			instruction_sr <= '0;
		end
		else
		begin
			state <= next_state;
		
			instruction_sr <= next_instr_sr;
		end
	end
	
	always_comb
	begin
		next_instr_sr = instruction_sr;
		cpu_clk = '0;
		pc_shift_out = '0;
		
		case (state)
			default : begin
				next_state = LOAD_I_HIGH;
			end
			
			LOAD_I_HIGH : begin
				next_state = LOAD_I_LOW;
				
				next_instr_sr = {instruction_sr[3:0], in[4:0]};
			end
			
			LOAD_I_LOW : begin
				next_state = EXECUTE;
				
				next_instr_sr = {instruction_sr[3:0], in[4:0]};
			end
			
			EXECUTE : begin
				next_state = WRITE_A_HIGH;
				
				cpu_clk = '1;
			end
			
			WRITE_A_HIGH : begin
				next_state = WRITE_A_LOW;
				
				pc_shift_out = line_addr[5:3];
			end
			
			WRITE_A_LOW : begin
				next_state = WAIT;
				
				pc_shift_out = line_addr[2:0];
			end
			
			WAIT : begin
				next_state = LOAD_I_HIGH;
			end
		endcase
	end
	
endmodule