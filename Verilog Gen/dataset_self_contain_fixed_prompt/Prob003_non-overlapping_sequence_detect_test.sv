`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13

module stimulus_gen (
	input wire clk,
	output reg rst_n,
	output reg data
);

	initial begin
		// Initialize signals
		rst_n = 1'b0;
		data = 1'b0;

		// Apply reset
		@(posedge clk);
		rst_n = 1'b1;
		@(posedge clk)
		@(posedge clk)

		// Test sequence: Provide the sequence "011100"
		@(posedge clk) data = 1'b0; // First bit
		@(posedge clk) data = 1'b1; // Second bit
		@(posedge clk) data = 1'b1; // Third bit
		@(posedge clk) data = 1'b1; // Fourth bit
		@(posedge clk) data = 1'b0; // Fifth bit
		@(posedge clk) data = 1'b0; // Sixth bit

		// Additional test cases
		repeat(500) @(negedge clk) begin
			data <= $random;
		end

		// End simulation after sufficient cycles
		repeat(100) @(posedge clk);
		#1 $finish;
	end
	
endmodule

module tb();

	typedef struct packed {
		int errors;
		int errortime;
		int errors_match;
		int errortime_match;
		int errors_not_match;
		int errortime_not_match;

		int clocks;
	} stats;
	
	stats stats1;
	
	wire[511:0] wavedrom_title;
	wire wavedrom_enable;
	int wavedrom_hide_after_time;
	
	reg clk = 0;
	initial forever
		#5 clk = ~clk;

	logic rst_n;
	logic data;
	logic match_ref;
	logic match_dut;
	logic not_match_ref;
	logic not_match_dut;

	initial begin 
		$dumpfile("wave.vcd");
		$dumpvars(1, stim1.clk, tb_mismatch, clk, rst_n, data, match_ref, match_dut, not_match_ref, not_match_dut);
	end

	wire tb_match;  // Verification
	wire tb_mismatch = ~tb_match;
	
	// Instantiate stimulus generator
	stimulus_gen stim1 (
		.clk(clk),
		.rst_n(rst_n),
		.data(data)
	);

	// Instantiate reference module
	RefModule good1 (
		.clk(clk),
		.rst_n(rst_n),
		.data(data),
		.match(match_ref),
		.not_match(not_match_ref)
	);
		
	// Instantiate DUT (TopModule)
	TopModule top_module1 (
		.clk(clk),
		.rst_n(rst_n),
		.data(data),
		.match(match_dut),
		.not_match(not_match_dut)
	);

	bit strobe = 0;
	task wait_for_end_of_timestep;
		repeat(5) begin
			strobe <= !strobe;  // Delay until the end of the time step
			@(strobe);
		end
	endtask	

	final begin
		if (stats1.errors_match) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "match", stats1.errors_match, stats1.errortime_match);
		else $display("Hint: Output '%s' has no mismatches.", "match");
		if (stats1.errors_not_match) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "not_match", stats1.errors_not_match, stats1.errortime_not_match);
		else $display("Hint: Output '%s' has no mismatches.", "not_match");

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: Ensure outputs match the reference module
	assign tb_match = ( { match_ref, not_match_ref } === ( { match_ref, not_match_ref } ^ { match_dut, not_match_dut } ^ { match_ref, not_match_ref } ) );

	always @(posedge clk, negedge clk) begin
		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		if (match_ref !== ( match_ref ^ match_dut ^ match_ref )) begin
			if (stats1.errors_match == 0) stats1.errortime_match = $time;
			stats1.errors_match++;
		end
		if (not_match_ref !== ( not_match_ref ^ not_match_dut ^ not_match_ref )) begin
			if (stats1.errors_not_match == 0) stats1.errortime_not_match = $time;
			stats1.errors_not_match++;
		end
	end

   // Add timeout after 100K cycles
   initial begin
     #1000000
     $display("TIMEOUT");
     $finish();
   end

endmodule