`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13


module stimulus_gen (
	input clk,
    // === Start your code here ===
	output logic rst_n,
	output logic [3:0] mul_a,
	output logic [3:0] mul_b
    // === End your code here ===
);
	// === Start your code here ===
	initial begin
		rst_n = 0;
		mul_a = 0;
		mul_b = 0;
		repeat(10) @(posedge clk);
		rst_n = 1;
		@(posedge clk);
		
		// Test basic multiplication cases
		mul_a = 4'd2; mul_b = 4'd3; @(posedge clk); // 2 * 3 = 6
		mul_a = 4'd4; mul_b = 4'd5; @(posedge clk); // 4 * 5 = 20
		mul_a = 4'd7; mul_b = 4'd8; @(posedge clk); // 7 * 8 = 56
		mul_a = 4'd9; mul_b = 4'd10; @(posedge clk); // 9 * 10 = 90
		mul_a = 4'd12; mul_b = 4'd13; @(posedge clk); // 12 * 13 = 156
		mul_a = 4'd15; mul_b = 4'd15; @(posedge clk); // 15 * 15 = 225
		
		// Test edge cases
		mul_a = 4'd0; mul_b = 4'd5; @(posedge clk); // 0 * 5 = 0
		mul_a = 4'd3; mul_b = 4'd0; @(posedge clk); // 3 * 0 = 0
		mul_a = 4'd1; mul_b = 4'd1; @(posedge clk); // 1 * 1 = 1
		mul_a = 4'd15; mul_b = 4'd1; @(posedge clk); // 15 * 1 = 15
		mul_a = 4'd1; mul_b = 4'd15; @(posedge clk); // 1 * 15 = 15
		
		#1 $finish;
	end
	// === End your code here ===
	
endmodule

module tb();

	// === Start your code here ===
	typedef struct packed {
		int errors;
		int errortime;
		int errors_mul_out;
		int errortime_mul_out;

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
	logic rst_n;
	logic [3:0] mul_a;
	logic [3:0] mul_b;
	logic [7:0] mul_out_ref;
	logic [7:0] mul_out_dut;
	// === End your code here ===

	initial begin 
		$dumpfile("wave.vcd");
		// === Start your code here ===
		$dumpvars(1, stim1.clk, tb_mismatch, clk, rst_n, mul_a, mul_b, mul_out_ref, mul_out_dut );
		// === End your code here ===
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	// === Start your code here ===
	stimulus_gen stim1 (
		.clk,
		.rst_n,
		.mul_a,
		.mul_b );
		
	RefModule good1 (
		.clk,
		.rst_n,
		.mul_a,
		.mul_b,
		.mul_out(mul_out_ref) );
		
	TopModule top_module1 (
		.clk,
		.rst_n,
		.mul_a,
		.mul_b,
		.mul_out(mul_out_dut) );
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
		if (stats1.errors_mul_out) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "mul_out", stats1.errors_mul_out, stats1.errortime_mul_out);
		else $display("Hint: Output '%s' has no mismatches.", "mul_out");
        // === End your code here ===

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { mul_out_ref } === ( { mul_out_ref } ^ { mul_out_dut } ^ { mul_out_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		// === Start your code here ===
		if (mul_out_ref !== ( mul_out_ref ^ mul_out_dut ^ mul_out_ref ))
		begin if (stats1.errors_mul_out == 0) stats1.errortime_mul_out = $time;
			stats1.errors_mul_out = stats1.errors_mul_out+1'b1; end
         // === End your code here ===

	end

   // add timeout after 100K cycles
   initial begin
     #1000000
     $display("TIMEOUT");
     $finish();
   end

endmodule
