`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13


module stimulus_gen (
	input clk,
    // === Start your code here ===
	output logic rst_n,
	output logic mode
    // === End your code here ===
);
	// === Start your code here ===
	initial begin
		rst_n = 0;
		mode = 0;
		repeat(10) @(posedge clk);
		rst_n = 1;
		@(posedge clk);
		
		// Test up counting (mode = 1)
		mode = 1;
		repeat(15) @(posedge clk); // Count up: 0,1,2,3,4,5,6,7,8,9,0,1,2,3,4
		
		// Test down counting (mode = 0)
		mode = 0;
		repeat(15) @(posedge clk); // Count down: 5,4,3,2,1,0,9,8,7,6,5,4,3,2,1
		
		// Test mode switching
		mode = 1; @(posedge clk); // Count up
		mode = 0; @(posedge clk); // Count down
		mode = 1; @(posedge clk); // Count up
		mode = 0; @(posedge clk); // Count down
		
		// Random testing
		repeat(200) @(posedge clk, negedge clk) begin
			mode <= $random;
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
		int errors_number;
		int errortime_number;
		int errors_zero;
		int errortime_zero;

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
	logic mode;
	logic [3:0] number_ref;
	logic zero_ref;
	logic [3:0] number_dut;
	logic zero_dut;
	// === End your code here ===

	initial begin 
		$dumpfile("wave.vcd");
		// === Start your code here ===
		$dumpvars(1, stim1.clk, tb_mismatch, clk, rst_n, mode, number_ref, zero_ref, number_dut, zero_dut );
		// === End your code here ===
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	// === Start your code here ===
	stimulus_gen stim1 (
		.clk,
		.rst_n,
		.mode );
		
	RefModule good1 (
		.clk,
		.rst_n,
		.mode,
		.number(number_ref),
		.zero(zero_ref) );
		
	TopModule top_module1 (
		.clk,
		.rst_n,
		.mode,
		.number(number_dut),
		.zero(zero_dut) );
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
		if (stats1.errors_number) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "number", stats1.errors_number, stats1.errortime_number);
		else $display("Hint: Output '%s' has no mismatches.", "number");
		if (stats1.errors_zero) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "zero", stats1.errors_zero, stats1.errortime_zero);
		else $display("Hint: Output '%s' has no mismatches.", "zero");
        // === End your code here ===

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { number_ref, zero_ref } === ( { number_ref, zero_ref } ^ { number_dut, zero_dut } ^ { number_ref, zero_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		// === Start your code here ===
		if (number_ref !== ( number_ref ^ number_dut ^ number_ref ))
		begin if (stats1.errors_number == 0) stats1.errortime_number = $time;
			stats1.errors_number = stats1.errors_number+1'b1; end
		if (zero_ref !== ( zero_ref ^ zero_dut ^ zero_ref ))
		begin if (stats1.errors_zero == 0) stats1.errortime_zero = $time;
			stats1.errors_zero = stats1.errors_zero+1'b1; end
         // === End your code here ===

	end

   // add timeout after 100K cycles
   initial begin
     #1000000
     $display("TIMEOUT");
     $finish();
   end

endmodule
