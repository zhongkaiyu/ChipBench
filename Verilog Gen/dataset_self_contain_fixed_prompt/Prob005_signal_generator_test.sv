`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13


module stimulus_gen (
	input clk,
    // === Start your code here ===
	output logic rst_n,
	output logic [1:0] wave_choice
    // === End your code here ===
);

	
	initial begin
		rst_n = 0;
		wave_choice = 0;
		repeat(20) @(posedge clk);
		rst_n = 1;
		@(posedge clk);
		// Test square wave (wave_choice = 0)
		wave_choice = 0;
		repeat(800) @(posedge clk);
		
		// Test sawtooth wave (wave_choice = 1)
		wave_choice = 1;
		repeat(800) @(posedge clk);
		
		// Test triangular wave (wave_choice = 2)
		wave_choice = 2;
		repeat(800) @(posedge clk);

        wave_choice = 0;
        repeat(800) @(posedge clk);
		
		
		#1 $finish;
	end
	// === End your code here ===
	
endmodule

module tb();

	// === Start your code here ===
	typedef struct packed {
		int errors;
		int errortime;
		int errors_wave;
		int errortime_wave;

		int clocks;
	} stats;
	// === End your code here ===
	
	stats stats1;
		
	reg clk=0;
	initial forever
		#5 clk = ~clk;

	// === Start your code here ===
	logic rst_n;
	logic [1:0] wave_choice;
	logic [4:0] wave_ref;
	logic [4:0] wave_dut;
	// === End your code here ===

	initial begin 
		$dumpfile("wave.vcd");
		// === Start your code here ===
		$dumpvars(1, stim1.clk, tb_mismatch, clk, rst_n, wave_choice, wave_ref, wave_dut );
		// === End your code here ===
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	// === Start your code here ===
	stimulus_gen stim1 (
		.clk,
		.rst_n,
		.wave_choice );
		
	RefModule good1 (
		.clk,
		.rst_n,
		.wave_choice(wave_choice),
		.wave(wave_ref) );
		
	TopModule top_module1 (
		.clk,
		.rst_n,
		.wave_choice,
		.wave(wave_dut) );
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
		if (stats1.errors_wave) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "wave", stats1.errors_wave, stats1.errortime_wave);
		else $display("Hint: Output '%s' has no mismatches.", "wave");
        // === End your code here ===

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { wave_ref } === ( { wave_ref } ^ { wave_dut } ^ { wave_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		// === Start your code here ===
		if (wave_ref !== ( wave_ref ^ wave_dut ^ wave_ref ))
		begin if (stats1.errors_wave == 0) stats1.errortime_wave = $time;
			stats1.errors_wave = stats1.errors_wave+1'b1; end
         // === End your code here ===

	end

   // add timeout after 100K cycles
   initial begin
     #1000000
     $display("TIMEOUT");
     $finish();
   end

endmodule
