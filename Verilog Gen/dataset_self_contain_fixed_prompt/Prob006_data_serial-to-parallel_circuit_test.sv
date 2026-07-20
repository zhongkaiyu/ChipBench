`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13


module stimulus_gen (
	input clk,
    // === Start your code here ===
	output logic rst_n,
	output logic valid_a,
	output logic data_a
    // === End your code here ===
);
	// === Start your code here ===
	initial begin
		rst_n = 0;
		valid_a = 0;
		data_a = 0;
		repeat(4)@(posedge clk);
		rst_n = 1;
		@(posedge clk);
		
		// Test serial data input: 6 bits per group
		// First group: 101010
		valid_a = 1;
		data_a = 1; @(posedge clk);
		data_a = 0; @(posedge clk);
		data_a = 1; @(posedge clk);
		data_a = 0; @(posedge clk);
		data_a = 1; @(posedge clk);
		data_a = 0; @(posedge clk);
		
		// Second group: 110011
		data_a = 1; @(posedge clk);
		data_a = 1; @(posedge clk);
		data_a = 0; @(posedge clk);
		data_a = 0; @(posedge clk);
		data_a = 1; @(posedge clk);
		data_a = 1; @(posedge clk);
		
		// Test with valid_a low (should ignore data)
		valid_a = 0;
		data_a = 1; @(posedge clk);
		data_a = 0; @(posedge clk);
		data_a = 1; @(posedge clk);
		
		// Third group: 111000
		valid_a = 1;
		data_a = 1; @(posedge clk);
		data_a = 1; @(posedge clk);
		data_a = 1; @(posedge clk);
		data_a = 0; @(posedge clk);
		data_a = 0; @(posedge clk);
		data_a = 0; @(posedge clk);
		
		// Random testing
		repeat(100) @(posedge clk, negedge clk) begin
			valid_a <= $random;
			data_a <= $random;
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
		int errors_ready_a;
		int errortime_ready_a;
		int errors_valid_b;
		int errortime_valid_b;
		int errors_data_b;
		int errortime_data_b;

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
	logic valid_a;
	logic data_a;
	logic ready_a_ref;
	logic ready_a_dut;
	logic valid_b_ref;
	logic valid_b_dut;
	logic [5:0] data_b_ref;
	logic [5:0] data_b_dut;
	// === End your code here ===

	initial begin 
		$dumpfile("wave.vcd");
		// === Start your code here ===
		$dumpvars(1, stim1.clk, tb_mismatch, clk, rst_n, valid_a, data_a, ready_a_ref, ready_a_dut, valid_b_ref, valid_b_dut, data_b_ref, data_b_dut );
		// === End your code here ===
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	// === Start your code here ===
	stimulus_gen stim1 (
		.clk,
		.rst_n,
		.valid_a,
		.data_a );
		
	RefModule good1 (
		.clk,
		.rst_n,
		.valid_a,
		.data_a,
		.ready_a(ready_a_ref),
		.valid_b(valid_b_ref),
		.data_b(data_b_ref) );
		
	TopModule top_module1 (
		.clk,
		.rst_n,
		.valid_a,
		.data_a,
		.ready_a(ready_a_dut),
		.valid_b(valid_b_dut),
		.data_b(data_b_dut) );
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
		if (stats1.errors_ready_a) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "ready_a", stats1.errors_ready_a, stats1.errortime_ready_a);
		else $display("Hint: Output '%s' has no mismatches.", "ready_a");
		if (stats1.errors_valid_b) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "valid_b", stats1.errors_valid_b, stats1.errortime_valid_b);
		else $display("Hint: Output '%s' has no mismatches.", "valid_b");
		if (stats1.errors_data_b) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "data_b", stats1.errors_data_b, stats1.errortime_data_b);
		else $display("Hint: Output '%s' has no mismatches.", "data_b");
        // === End your code here ===

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { ready_a_ref, valid_b_ref, data_b_ref } === ( { ready_a_ref, valid_b_ref, data_b_ref } ^ { ready_a_dut, valid_b_dut, data_b_dut } ^ { ready_a_ref, valid_b_ref, data_b_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		// === Start your code here ===
		if (ready_a_ref !== ( ready_a_ref ^ ready_a_dut ^ ready_a_ref ))
		begin if (stats1.errors_ready_a == 0) stats1.errortime_ready_a = $time;
			stats1.errors_ready_a = stats1.errors_ready_a+1'b1; end
		if (valid_b_ref !== ( valid_b_ref ^ valid_b_dut ^ valid_b_ref ))
		begin if (stats1.errors_valid_b == 0) stats1.errortime_valid_b = $time;
			stats1.errors_valid_b = stats1.errors_valid_b+1'b1; end
		if (data_b_ref !== ( data_b_ref ^ data_b_dut ^ data_b_ref ))
		begin if (stats1.errors_data_b == 0) stats1.errortime_data_b = $time;
			stats1.errors_data_b = stats1.errors_data_b+1'b1; end
         // === End your code here ===

	end

   // add timeout after 100K cycles
   initial begin
     #1000000
     $display("TIMEOUT");
     $finish();
   end

endmodule
