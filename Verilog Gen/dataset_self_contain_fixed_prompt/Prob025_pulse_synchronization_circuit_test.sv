`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13


module stimulus_gen (
	input clk,
    // === Start your code here ===
	output logic clk_fast,
	output logic clk_slow,
	output logic rst_n,
	output logic data_in
    // === End your code here ===
);
	// === Start your code here ===
    initial begin
		clk_fast <= 0;
		clk_slow <= 0;
		rst_n <= 0;
		data_in <= 0;
		
		// Generate fast clock (10x faster than slow clock)
		forever begin
			#5 clk_fast <= ~clk_fast;
		end
	end
	
	initial begin
		// Generate slow clock
		forever begin
			#50 clk_slow <= ~clk_slow;
		end
	end
	
	initial begin
		// Reset sequence
		@(posedge clk_fast);
		@(posedge clk_fast);
		rst_n <= 1;
		@(posedge clk_fast);
		
		// Test basic pulse detection
		data_in <= 1;
		@(posedge clk_fast);
		data_in <= 0;
		@(posedge clk_fast);
		@(posedge clk_fast);
		@(posedge clk_fast);
		
		// Wait for slow clock to process
		repeat(20) @(posedge clk_slow);
		
		// Test multiple pulses
		data_in <= 1;
		@(posedge clk_fast);
		@(posedge clk_fast);
		@(posedge clk_fast);
		@(posedge clk_fast);
		data_in <= 0;
		@(posedge clk_fast);
		@(posedge clk_fast);
		
		// Wait for slow clock to process
		repeat(20) @(posedge clk_slow);
		
		// Random test sequence
		repeat(100) @(posedge clk_fast) begin
			data_in <= $random & 1;
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
		int errors_data_out;
		int errortime_data_out;

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
	logic clk_fast;
	logic clk_slow;
	logic rst_n;
	logic data_in;
	logic data_out_ref;
	logic data_out_dut;
	// === End your code here ===

	initial begin 
		$dumpfile("wave.vcd");
		// === Start your code here ===
		$dumpvars(1, stim1.clk, tb_mismatch, clk, clk_fast, clk_slow, rst_n, data_in, data_out_ref, data_out_dut);
		// === End your code here ===
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	// === Start your code here ===
	stimulus_gen stim1 (
		.clk,
		.clk_fast,
		.clk_slow,
		.rst_n,
		.data_in
	);
		
	RefModule good1 (
		.clk_fast,
		.clk_slow,
		.rst_n,
		.data_in,
		.data_out(data_out_ref)
	);
		
	TopModule top_module1 (
		.clk_fast,
		.clk_slow,
		.rst_n,
		.data_in,
		.data_out(data_out_dut)
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
		if (stats1.errors_data_out) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "data_out", stats1.errors_data_out, stats1.errortime_data_out);
		else $display("Hint: Output '%s' has no mismatches.", "data_out");
        // === End your code here ===

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { data_out_ref } === ( { data_out_ref } ^ { data_out_dut } ^ { data_out_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		// === Start your code here ===
		if (data_out_ref !== ( data_out_ref ^ data_out_dut ^ data_out_ref ))
		begin if (stats1.errors_data_out == 0) stats1.errortime_data_out = $time;
			stats1.errors_data_out = stats1.errors_data_out+1'b1; end
         // === End your code here ===

	end

   // add timeout after 100K cycles
   initial begin
     #1000000
     $display("TIMEOUT");
     $finish();
   end

endmodule
