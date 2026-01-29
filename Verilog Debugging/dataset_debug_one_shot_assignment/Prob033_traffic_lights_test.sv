`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13


module stimulus_gen (
	input clk,
    // === Start your code here ===
	output logic rst_n,
	output logic pass_request
    // === End your code here ===
);
	// === Start your code here ===
	initial begin
		rst_n = 0;
		pass_request = 0;
		repeat(10) @(posedge clk);
		rst_n = 1;
		@(posedge clk);
		
		// Test normal traffic light cycle
		pass_request = 0;
		repeat(100) @(posedge clk); // Let it cycle through red->green->yellow->red
		
		// Test pedestrian request during green phase
		pass_request = 1;
		repeat(20) @(posedge clk); // Request during green
		pass_request = 0;
		@(posedge clk);
		
		// Test pedestrian request during red phase (should not affect)
		pass_request = 1;
		repeat(15) @(posedge clk); // Request during red
		pass_request = 0;
		@(posedge clk);
		
		// Test pedestrian request during yellow phase (should not affect)
		pass_request = 1;
		repeat(10) @(posedge clk); // Request during yellow
		pass_request = 0;
		@(posedge clk);
		
		// Random testing
		repeat(200) @(posedge clk, negedge clk) begin
			pass_request <= $random;
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
		int errors_clock;
		int errortime_clock;
		int errors_red;
		int errortime_red;
		int errors_yellow;
		int errortime_yellow;
		int errors_green;
		int errortime_green;

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
	logic pass_request;
	logic [7:0] clock_ref;
	logic red_ref;
	logic yellow_ref;
	logic green_ref;
	logic [7:0] clock_dut;
	logic red_dut;
	logic yellow_dut;
	logic green_dut;
	// === End your code here ===

	initial begin 
		$dumpfile("wave.vcd");
		// === Start your code here ===
		$dumpvars(1, stim1.clk, tb_mismatch, clk, rst_n, pass_request, clock_ref, red_ref, yellow_ref, green_ref, clock_dut, red_dut, yellow_dut, green_dut );
		// === End your code here ===
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	// === Start your code here ===
	stimulus_gen stim1 (
		.clk,
		.rst_n,
		.pass_request );
		
	RefModule good1 (
		.clk,
		.rst_n,
		.pass_request,
		.clock(clock_ref),
		.red(red_ref),
		.yellow(yellow_ref),
		.green(green_ref) );
		
	TopModule top_module1 (
		.clk,
		.rst_n,
		.pass_request,
		.clock(clock_dut),
		.red(red_dut),
		.yellow(yellow_dut),
		.green(green_dut) );
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
		if (stats1.errors_clock) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "clock", stats1.errors_clock, stats1.errortime_clock);
		else $display("Hint: Output '%s' has no mismatches.", "clock");
		if (stats1.errors_red) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "red", stats1.errors_red, stats1.errortime_red);
		else $display("Hint: Output '%s' has no mismatches.", "red");
		if (stats1.errors_yellow) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "yellow", stats1.errors_yellow, stats1.errortime_yellow);
		else $display("Hint: Output '%s' has no mismatches.", "yellow");
		if (stats1.errors_green) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "green", stats1.errors_green, stats1.errortime_green);
		else $display("Hint: Output '%s' has no mismatches.", "green");
        // === End your code here ===

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { clock_ref, red_ref, yellow_ref, green_ref } === ( { clock_ref, red_ref, yellow_ref, green_ref } ^ { clock_dut, red_dut, yellow_dut, green_dut } ^ { clock_ref, red_ref, yellow_ref, green_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		// === Start your code here ===
		if (clock_ref !== ( clock_ref ^ clock_dut ^ clock_ref ))
		begin if (stats1.errors_clock == 0) stats1.errortime_clock = $time;
			stats1.errors_clock = stats1.errors_clock+1'b1; end
		if (red_ref !== ( red_ref ^ red_dut ^ red_ref ))
		begin if (stats1.errors_red == 0) stats1.errortime_red = $time;
			stats1.errors_red = stats1.errors_red+1'b1; end
		if (yellow_ref !== ( yellow_ref ^ yellow_dut ^ yellow_ref ))
		begin if (stats1.errors_yellow == 0) stats1.errortime_yellow = $time;
			stats1.errors_yellow = stats1.errors_yellow+1'b1; end
		if (green_ref !== ( green_ref ^ green_dut ^ green_ref ))
		begin if (stats1.errors_green == 0) stats1.errortime_green = $time;
			stats1.errors_green = stats1.errors_green+1'b1; end
         // === End your code here ===

	end

   // add timeout after 100K cycles
   initial begin
     #1000000
     $display("TIMEOUT");
     $finish();
   end

endmodule
