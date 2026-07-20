`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13


module stimulus_gen (
	input clk,
    // === Start your code here ===
	output logic a,
	output logic rst_n,
	output reg[511:0] wavedrom_title,
	output reg wavedrom_enable,
	input tb_match
    // === End your code here ===
);
	// === Start your code here ===
	reg reset;
	assign rst_n = ~reset;
	
	task wavedrom_start(input[511:0] title = "");
	endtask
	
	task wavedrom_stop;
		#1;
	endtask
	
	initial begin
		reset = 1;
		a = 0;
		@(posedge clk);
		reset = 0;
		
		wavedrom_start("Sequence Detection Test");
		
		// Test specific sequences for "011XXX110" pattern
		@(posedge clk) a = 0;  // Start of 011101110
		@(posedge clk) a = 1;
		@(posedge clk) a = 1;
		@(posedge clk) a = 1;  // Middle bit 1
		@(posedge clk) a = 0;  // Middle bit 0
		@(posedge clk) a = 1;  // Middle bit 1
		@(posedge clk) a = 1;
		@(posedge clk) a = 1;
		@(posedge clk) a = 0;  // Should detect pattern here
		
		@(posedge clk) a = 0;  // Start of 011001110
		@(posedge clk) a = 1;
		@(posedge clk) a = 1;
		@(posedge clk) a = 0;  // Middle bit 0
		@(posedge clk) a = 0;  // Middle bit 0
		@(posedge clk) a = 1;  // Middle bit 1
		@(posedge clk) a = 1;
		@(posedge clk) a = 1;
		@(posedge clk) a = 0;  // Should detect pattern here
		
		wavedrom_stop();
		
		// Random testing
		repeat(200) @(posedge clk, negedge clk) begin
			a <= $random;
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
		int errors_match;
		int errortime_match;

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
	logic a;
	logic rst_n;
	logic match_ref;
	logic match_dut;
	// === End your code here ===

	initial begin 
		$dumpfile("wave.vcd");
		// === Start your code here ===
		$dumpvars(1, stim1.clk, tb_mismatch, clk, a, rst_n, match_ref, match_dut );
		// === End your code here ===
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	// === Start your code here ===
	stimulus_gen stim1 (
		.clk,
		.* ,
		.a,
		.rst_n );
		
	RefModule good1 (
		.clk,
		.rst_n,
		.a,
		.match(match_ref) );
		
	TopModule top_module1 (
		.clk,
		.rst_n,
		.a,
		.match(match_dut) );
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
		if (stats1.errors_match) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "match", stats1.errors_match, stats1.errortime_match);
		else $display("Hint: Output '%s' has no mismatches.", "match");
        // === End your code here ===

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { match_ref } === ( { match_ref } ^ { match_dut } ^ { match_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		// === Start your code here ===
		if (match_ref !== ( match_ref ^ match_dut ^ match_ref ))
		begin if (stats1.errors_match == 0) stats1.errortime_match = $time;
			stats1.errors_match = stats1.errors_match+1'b1; end
         // === End your code here ===

	end

   // add timeout after 100K cycles
   initial begin
     #1000000
     $display("TIMEOUT");
     $finish();
   end

endmodule
