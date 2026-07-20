`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13


module stimulus_gen (
	input clk,
    // === Start your code here ===
	output logic rst_n
    // === End your code here ===
);
	// === Start your code here ===
	initial begin
		rst_n = 0;
		repeat(10) @(posedge clk);
		rst_n = 1;
		@(posedge clk);
		
		// Test Gray code counter for multiple cycles
		repeat(200) @(posedge clk);
		
		#1 $finish;
	end
	// === End your code here ===
	
endmodule

module tb();

	// === Start your code here ===
	typedef struct packed {
		int errors;
		int errortime;
		int errors_gray_out;
		int errortime_gray_out;

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
	logic [3:0] gray_out_ref;
	logic [3:0] gray_out_dut;
	// === End your code here ===

	initial begin 
		$dumpfile("wave.vcd");
		// === Start your code here ===
		$dumpvars(1, stim1.clk, tb_mismatch, clk, rst_n, gray_out_ref, gray_out_dut );
		// === End your code here ===
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	// === Start your code here ===
	stimulus_gen stim1 (
		.clk,
		.rst_n );
		
	RefModule good1 (
		.clk,
		.rst_n,
		.gray_out(gray_out_ref) );
		
	TopModule top_module1 (
		.clk,
		.rst_n,
		.gray_out(gray_out_dut) );
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
		if (stats1.errors_gray_out) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "gray_out", stats1.errors_gray_out, stats1.errortime_gray_out);
		else $display("Hint: Output '%s' has no mismatches.", "gray_out");
        // === End your code here ===

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { gray_out_ref } === ( { gray_out_ref } ^ { gray_out_dut } ^ { gray_out_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		// === Start your code here ===
		if (gray_out_ref !== ( gray_out_ref ^ gray_out_dut ^ gray_out_ref ))
		begin if (stats1.errors_gray_out == 0) stats1.errortime_gray_out = $time;
			stats1.errors_gray_out = stats1.errors_gray_out+1'b1; end
         // === End your code here ===

	end

   // add timeout after 100K cycles
   initial begin
     #1000000
     $display("TIMEOUT");
     $finish();
   end

endmodule
