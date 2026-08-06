`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13


module stimulus_gen (
	input clk,
	output logic rst_n,
	output logic data,
	output logic data_valid
);

	initial begin
		rst_n = 0;
		data = 0;
		data_valid = 0;
		@(posedge clk);
		@(posedge clk);
		rst_n = 1;
		@(posedge clk);
		@(posedge clk);
		
		// Test specific sequence: 0110
		data_valid = 1;
		data = 0; @(posedge clk);
		data = 1; @(posedge clk);
		data = 1; @(posedge clk);
		data = 0; @(posedge clk);
		data_valid = 0;
		@(posedge clk);
		@(posedge clk);
		
		// Test with data_valid low (should ignore data)
		data_valid = 0;
		data = 0; @(posedge clk);
		data = 1; @(posedge clk);
		data = 1; @(posedge clk);
		data = 0; @(posedge clk);
		@(posedge clk);
		
		// Test overlapping sequences
		data_valid = 1;
		data = 0; @(posedge clk);
		data = 1; @(posedge clk);
		data = 1; @(posedge clk);
		data = 0; @(posedge clk);
		data = 1; @(posedge clk);
		data = 1; @(posedge clk);
		data = 0; @(posedge clk);
		@(posedge clk);
		
		// Random testing
		repeat(500) @(negedge clk) begin
			data_valid <= $random;
			data <= $random;
		end
		
		#1 $finish;
	end
	
endmodule

module tb();

	typedef struct packed {
		int errors;
		int errortime;
		int errors_match;
		int errortime_match;

		int clocks;
	} stats;
	
	stats stats1;
	
	
	wire[511:0] wavedrom_title;
	wire wavedrom_enable;
	int wavedrom_hide_after_time;
	
	reg clk=0;
	initial forever
		#5 clk = ~clk;

	logic rst_n;
	logic data;
	logic data_valid;
	logic match_ref;
	logic match_dut;

	initial begin 
		$dumpfile("wave.vcd");
		$dumpvars(1, stim1.clk, tb_mismatch, clk, rst_n, data, data_valid, match_ref, match_dut );
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	stimulus_gen stim1 (
		.clk,
		.* ,
		.rst_n,
		.data,
		.data_valid );
	RefModule good1 (
		.clk,
		.rst_n,
		.data,
		.data_valid,
		.match(match_ref) );
		
	TopModule top_module1 (
		.clk,
		.rst_n,
		.data,
		.data_valid,
		.match(match_dut) );

	
	bit strobe = 0;
	task wait_for_end_of_timestep;
		repeat(5) begin
			strobe <= !strobe;  // Try to delay until the very end of the time step.
			@(strobe);
		end
	endtask	

	
	final begin
		if (stats1.errors_match) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "match", stats1.errors_match, stats1.errortime_match);
		else $display("Hint: Output '%s' has no mismatches.", "match");

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
		if (match_ref !== ( match_ref ^ match_dut ^ match_ref ))
		begin if (stats1.errors_match == 0) stats1.errortime_match = $time;
			stats1.errors_match = stats1.errors_match+1'b1; end

	end

   // add timeout after 100K cycles
   initial begin
     #1000000
     $display("TIMEOUT");
     $finish();
   end

endmodule
