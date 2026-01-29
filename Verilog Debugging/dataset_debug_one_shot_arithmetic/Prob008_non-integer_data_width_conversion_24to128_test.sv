`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13


module stimulus_gen (
	input clk,
    // === Start your code here ===
	output logic rst_n,
	output logic valid_in,
	output logic [23:0] data_in
    // === End your code here ===
);
	// === Start your code here ===
	initial begin
		rst_n = 0;
		valid_in = 0;
		data_in = 0;
		repeat(10) @(posedge clk);
		rst_n = 1;
		@(posedge clk);
		
		// Test first group: 6 x 24-bit inputs to form 128-bit output
		// Inputs: 0x111111, 0x222222, 0x333333, 0x444444, 0x555555, 0x666666
		valid_in = 1;
		data_in = 24'h111111; @(posedge clk);
		data_in = 24'h222222; @(posedge clk);
		data_in = 24'h333333; @(posedge clk);
		data_in = 24'h444444; @(posedge clk);
		data_in = 24'h555555; @(posedge clk);
		data_in = 24'h666666; @(posedge clk);
		
		// Test second group: 6 x 24-bit inputs
		data_in = 24'h777777; @(posedge clk);
		data_in = 24'h888888; @(posedge clk);
		data_in = 24'h999999; @(posedge clk);
		data_in = 24'haaaaaa; @(posedge clk);
		data_in = 24'hbbbbbb; @(posedge clk);
		data_in = 24'hcccccc; @(posedge clk);
		
		// Test with valid_in low (should ignore data)
		valid_in = 0;
		data_in = 24'hdddddd; @(posedge clk);
		data_in = 24'heeeeee; @(posedge clk);
		
		// Test third group: 6 x 24-bit inputs
		valid_in = 1;
		data_in = 24'hffffff; @(posedge clk);
		data_in = 24'h000000; @(posedge clk);
		data_in = 24'h123456; @(posedge clk);
		data_in = 24'h789abc; @(posedge clk);
		data_in = 24'hdef012; @(posedge clk);
		data_in = 24'h345678; @(posedge clk);
		
		// Random testing
		repeat(200) @(posedge clk, negedge clk) begin
			valid_in <= $random;
			data_in <= $random % (1<<24);
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
		int errors_valid_out;
		int errortime_valid_out;
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
	logic valid_in;
	logic [23:0] data_in;
	logic valid_out_ref;
	logic valid_out_dut;
	logic [127:0] data_out_ref;
	logic [127:0] data_out_dut;
	// === End your code here ===

	initial begin 
		$dumpfile("wave.vcd");
		// === Start your code here ===
		$dumpvars(1, stim1.clk, tb_mismatch, clk, rst_n, valid_in, data_in, valid_out_ref, valid_out_dut, data_out_ref, data_out_dut );
		// === End your code here ===
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	// === Start your code here ===
	stimulus_gen stim1 (
		.clk,
		.rst_n,
		.valid_in,
		.data_in );
		
	RefModule good1 (
		.clk,
		.rst_n,
		.valid_in,
		.data_in,
		.valid_out(valid_out_ref),
		.data_out(data_out_ref) );
		
	TopModule top_module1 (
		.clk,
		.rst_n,
		.valid_in,
		.data_in,
		.valid_out(valid_out_dut),
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
		if (stats1.errors_valid_out) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "valid_out", stats1.errors_valid_out, stats1.errortime_valid_out);
		else $display("Hint: Output '%s' has no mismatches.", "valid_out");
		if (stats1.errors_data_out) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "data_out", stats1.errors_data_out, stats1.errortime_data_out);
		else $display("Hint: Output '%s' has no mismatches.", "data_out");
        // === End your code here ===

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { valid_out_ref, data_out_ref } === ( { valid_out_ref, data_out_ref } ^ { valid_out_dut, data_out_dut } ^ { valid_out_ref, data_out_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		// === Start your code here ===
		if (valid_out_ref !== ( valid_out_ref ^ valid_out_dut ^ valid_out_ref ))
		begin if (stats1.errors_valid_out == 0) stats1.errortime_valid_out = $time;
			stats1.errors_valid_out = stats1.errors_valid_out+1'b1; end
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
