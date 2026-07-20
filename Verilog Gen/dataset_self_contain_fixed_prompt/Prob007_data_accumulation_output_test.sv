`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13

module stimulus_gen (
	input clk,
    // === Start your code here ===
	output logic rst_n,
	output logic [7:0] data_in,
	output logic valid_a,
	output logic ready_b
    // === End your code here ===
);
	// === Start your code here ===
	initial begin
		rst_n = 0;
		data_in = 0;
		valid_a = 0;
		ready_b = 0;
		repeat(10) @(posedge clk);
		rst_n = 1;
		@(posedge clk);
		
		// Test first group of 4 values: 1, 2, 3, 4 (sum = 10)
		valid_a = 1;
		data_in = 8'd1; @(posedge clk);
		data_in = 8'd2; @(posedge clk);
		data_in = 8'd3; @(posedge clk);
		data_in = 8'd4; @(posedge clk);
		
		data_in = 8'd5; @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        ready_b = 1;

		data_in = 8'd6; @(posedge clk);
		data_in = 8'd7; @(posedge clk);
		data_in = 8'd8; @(posedge clk);
		
		// Test with valid_a low (should ignore data)
		valid_a = 0;
		data_in = 8'd10; @(posedge clk);
		data_in = 8'd20; @(posedge clk);
		
		// Test with ready_b low (backpressure)
		valid_a = 1;
		ready_b = 0;
		data_in = 8'd1; @(posedge clk);
		data_in = 8'd2; @(posedge clk);
		
		// Test third group: 10, 20, 30, 40 (sum = 100)
		ready_b = 1;
		data_in = 8'd10; @(posedge clk);
		data_in = 8'd20; @(posedge clk);
		data_in = 8'd30; @(posedge clk);
		data_in = 8'd40; @(posedge clk);
		
		// Random testing
		repeat(300) @(posedge clk or negedge clk) begin
			valid_a <= $random;
			ready_b <= $random;
			data_in <= $random % 256;
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
	logic rst_n;
	logic [7:0] data_in;
	logic valid_a;
	logic ready_b;
	logic ready_a_ref;
	logic ready_a_dut;
	logic valid_b_ref;
	logic valid_b_dut;
	logic [9:0] data_out_ref;
	logic [9:0] data_out_dut;
	// === End your code here ===

	initial begin 
		$dumpfile("wave.vcd");
		// === Start your code here ===
		$dumpvars(1, stim1.clk, tb_mismatch, clk, rst_n, data_in, valid_a, ready_b, ready_a_ref, ready_a_dut, valid_b_ref, valid_b_dut, data_out_ref, data_out_dut );
		// === End your code here ===
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	// === Start your code here ===
	stimulus_gen stim1 (
		.clk,
		.rst_n,
		.data_in,
		.valid_a,
		.ready_b );
		
	RefModule good1 (
		.clk,
		.rst_n,
		.data_in,
		.valid_a,
		.ready_b,
		.ready_a(ready_a_ref),
		.valid_b(valid_b_ref),
		.data_out(data_out_ref) );
		
	TopModule top_module1 (
		.clk,
		.rst_n,
		.data_in,
		.valid_a,
		.ready_b,
		.ready_a(ready_a_dut),
		.valid_b(valid_b_dut),
		.data_out(data_out_dut) );
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
		if (stats1.errors_data_out) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "data_out", stats1.errors_data_out, stats1.errortime_data_out);
		else $display("Hint: Output '%s' has no mismatches.", "data_out");
        // === End your code here ===

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { ready_a_ref, valid_b_ref, data_out_ref } === ( { ready_a_ref, valid_b_ref, data_out_ref } ^ { ready_a_dut, valid_b_dut, data_out_dut } ^ { ready_a_ref, valid_b_ref, data_out_ref } ) );
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
