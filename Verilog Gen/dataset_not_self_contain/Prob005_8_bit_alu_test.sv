`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13


module stimulus_gen (
	input clk,
    // === Start your code here ===
	output reg [7:0] in_A,
	output reg [7:0] in_B,
	output reg [1:0] in_operation
    // === End your code here ===
);
	// === Start your code here ===
	initial begin
		// Initialize signals
		in_A = 8'b0;
		in_B = 8'b0;
		in_operation = 2'b0;
		
		@(posedge clk);
		
		// Test AND operation (in_operation = 00)
		in_operation = 2'b00;
		in_A = 8'b10101100;
		in_B = 8'b00111010;
		repeat(2) @(posedge clk);
		
		in_A = 8'b11111111;
		in_B = 8'b00000000;
		repeat(2) @(posedge clk);
		
		in_A = 8'b11111111;
		in_B = 8'b11111111;
		repeat(2) @(posedge clk);
		
		in_A = 8'b01010101;
		in_B = 8'b10101010;
		repeat(2) @(posedge clk);
		
		// Test OR operation (in_operation = 01)
		in_operation = 2'b01;
		in_A = 8'b10101100;
		in_B = 8'b00111010;
		repeat(2) @(posedge clk);
		
		in_A = 8'b11111111;
		in_B = 8'b00000000;
		repeat(2) @(posedge clk);
		
		in_A = 8'b00000000;
		in_B = 8'b00000000;
		repeat(2) @(posedge clk);
		
		in_A = 8'b01010101;
		in_B = 8'b10101010;
		repeat(2) @(posedge clk);
		
		// Test ADD operation (in_operation = 10)
		in_operation = 2'b10;
		in_A = 8'b00000001;
		in_B = 8'b00000001;
		repeat(2) @(posedge clk);
		
		in_A = 8'b11111111;
		in_B = 8'b00000001;
		repeat(2) @(posedge clk);
		
		in_A = 8'b01111111;
		in_B = 8'b00000001;
		repeat(2) @(posedge clk);
		
		in_A = 8'b10101100;
		in_B = 8'b00111010;
		repeat(2) @(posedge clk);
		
		in_A = 8'b00000000;
		in_B = 8'b00000000;
		repeat(2) @(posedge clk);
		
		// Test SUB operation (in_operation = 11)
		in_operation = 2'b11;
		in_A = 8'b00000010;
		in_B = 8'b00000001;
		repeat(2) @(posedge clk);
		
		in_A = 8'b00000001;
		in_B = 8'b00000001;
		repeat(2) @(posedge clk);
		
		in_A = 8'b10101100;
		in_B = 8'b00111010;
		repeat(2) @(posedge clk);
		
		in_A = 8'b11111111;
		in_B = 8'b11111111;
		repeat(2) @(posedge clk);
		
		in_A = 8'b00000000;
		in_B = 8'b00000001;
		repeat(2) @(posedge clk);	
		
		// Random testing
		repeat(1000) @(posedge clk) begin
			in_A <= $urandom;
			in_B <= $urandom;
			in_operation <= $urandom;
		end
		
		#1 $finish;
	end
	// === End your code here ===
	
endmodule

module tb();

	// === Start your code here ===
	typedef struct packed {
		int errors;
		int errortime;
		int errors_out_c;
		int errortime_out_c;

		int clocks;
	} stats;
	// === End your code here ===
	
	stats stats1;
	
	
	wire[511:0] wavedrom_title;
	wire wavedrom_enable;
	int wavedrom_hide_after_time;
	
	reg clk=0;
	initial forever
		#5 clk = ~clk;

	// === Start your code here ===
	logic [7:0] in_A;
	logic [7:0] in_B;
	logic [1:0] in_operation;
	logic [7:0] out_c_ref;
	logic [7:0] out_c_dut;
	// === End your code here ===

	initial begin 
		$dumpfile("wave.vcd");
		// === Start your code here ===
		$dumpvars(1, stim1.clk, tb_mismatch, clk, in_A, in_B, in_operation, out_c_ref, out_c_dut);
		// === End your code here ===
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	// === Start your code here ===
	stimulus_gen stim1 (
		.clk(clk),
		.in_A(in_A),
		.in_B(in_B),
		.in_operation(in_operation)
	);
		
	RefModule good1 (
		.in_A(in_A),
		.in_B(in_B),
		.in_operation(in_operation),
		.out_c(out_c_ref)
	);
		
	TopModule top_module1 (
		.in_A(in_A),
		.in_B(in_B),
		.in_operation(in_operation),
		.out_c(out_c_dut)
	);
	// === End your code here ===

	
	bit strobe = 0;
	task wait_for_end_of_timestep;
		repeat(5) begin
			strobe <= !strobe;  // Try to delay until the very end of the time step.
			@(strobe);
		end
	endtask	
	

	final begin
		// === Start your code here ===
		if (stats1.errors_out_c) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "out_c", stats1.errors_out_c, stats1.errortime_out_c);
		else $display("Hint: Output '%s' has no mismatches.", "out_c");
		// === End your code here ===

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { out_c_ref } === ( { out_c_ref } ^ { out_c_dut } ^ { out_c_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		// === Start your code here ===
		if (out_c_ref !== ( out_c_ref ^ out_c_dut ^ out_c_ref ))
		begin 
			if (stats1.errors_out_c == 0) stats1.errortime_out_c = $time;
			stats1.errors_out_c = stats1.errors_out_c+1'b1; 
		end
		// === End your code here ===

	end

   // add timeout after 100K cycles
   initial begin
     #1000000
     $display("TIMEOUT");
     $finish();
   end

endmodule

