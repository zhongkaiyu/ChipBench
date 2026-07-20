`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13


module stimulus_gen (
	input clk,
    // === Start your code here ===
	output logic rst_n,
	output logic [7:0] A,
	output logic [7:0] B,
	output logic vld_in
    // === End your code here ===
);
	// === Start your code here ===
    initial begin
		rst_n <= 0;
		A <= 0;
		B <= 0;
		vld_in <= 0;
		
		// Reset sequence
		@(posedge clk);
		@(posedge clk);
		rst_n <= 1;
		@(posedge clk);
		
		// Test basic cases
		A <= 8'd12;
		B <= 8'd8;
		vld_in <= 1;
		@(posedge clk);
		vld_in <= 0;
		repeat(20) @(posedge clk); // Wait for computation
		
		A <= 8'd15;
		B <= 8'd25;
		vld_in <= 1;
		@(posedge clk);
		vld_in <= 0;
		repeat(20) @(posedge clk);
		
		A <= 8'd7;
		B <= 8'd11;
		vld_in <= 1;
		@(posedge clk);
		vld_in <= 0;
		repeat(20) @(posedge clk);
		
		A <= 8'd16;
		B <= 8'd24;
		vld_in <= 1;
		@(posedge clk);
		vld_in <= 0;
		repeat(20) @(posedge clk);
		
		
		// Test edge cases
		A <= 8'd1;
		B <= 8'd1;
		vld_in <= 1;
		@(posedge clk);
		vld_in <= 0;
		repeat(20) @(posedge clk);
		
		A <= 8'd255;
		B <= 8'd1;
		vld_in <= 1;
		@(posedge clk);
		vld_in <= 0;
		repeat(20) @(posedge clk);
		
		A <= 8'd0;
		B <= 8'd5;
		vld_in <= 1;
		@(posedge clk);
		vld_in <= 0;
		repeat(20) @(posedge clk);
		
		// Random test sequence
		repeat(50) @(posedge clk) begin
			A <= $random & 255;  // 8-bit random
			B <= $random & 255;  // 8-bit random
			vld_in <= $random & 1;
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
		int errors_lcm_out;
		int errortime_lcm_out;
		int errors_mcd_out;
		int errortime_mcd_out;
		int errors_vld_out;
		int errortime_vld_out;

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
	logic [7:0] A;
	logic [7:0] B;
	logic vld_in;
	logic [15:0] lcm_out_ref;
	logic [15:0] lcm_out_dut;
	logic [7:0] mcd_out_ref;
	logic [7:0] mcd_out_dut;
	logic vld_out_ref;
	logic vld_out_dut;
	// === End your code here ===

	initial begin 
		$dumpfile("wave.vcd");
		// === Start your code here ===
		$dumpvars(1, stim1.clk, tb_mismatch, clk, rst_n, A, B, vld_in, lcm_out_ref, lcm_out_dut, mcd_out_ref, mcd_out_dut, vld_out_ref, vld_out_dut);
		// === End your code here ===
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	// === Start your code here ===
	stimulus_gen stim1 (
		.clk,
		.rst_n,
		.A,
		.B,
		.vld_in
	);
		
	RefModule good1 (
		.A,
		.B,
		.vld_in,
		.rst_n,
		.clk,
		.lcm_out(lcm_out_ref),
		.mcd_out(mcd_out_ref),
		.vld_out(vld_out_ref)
	);
		
	TopModule top_module1 (
		.clk,
		.rst_n,
		.A,
		.B,
		.vld_in,
		.lcm_out(lcm_out_dut),
		.mcd_out(mcd_out_dut),
		.vld_out(vld_out_dut)
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
		if (stats1.errors_lcm_out) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "lcm_out", stats1.errors_lcm_out, stats1.errortime_lcm_out);
		else $display("Hint: Output '%s' has no mismatches.", "lcm_out");
		if (stats1.errors_mcd_out) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "mcd_out", stats1.errors_mcd_out, stats1.errortime_mcd_out);
		else $display("Hint: Output '%s' has no mismatches.", "mcd_out");
		if (stats1.errors_vld_out) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "vld_out", stats1.errors_vld_out, stats1.errortime_vld_out);
		else $display("Hint: Output '%s' has no mismatches.", "vld_out");
        // === End your code here ===

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { lcm_out_ref, mcd_out_ref, vld_out_ref } === ( { lcm_out_ref, mcd_out_ref, vld_out_ref } ^ { lcm_out_dut, mcd_out_dut, vld_out_dut } ^ { lcm_out_ref, mcd_out_ref, vld_out_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		// === Start your code here ===
		if (lcm_out_ref !== ( lcm_out_ref ^ lcm_out_dut ^ lcm_out_ref ))
		begin if (stats1.errors_lcm_out == 0) stats1.errortime_lcm_out = $time;
			stats1.errors_lcm_out = stats1.errors_lcm_out+1'b1; end
		if (mcd_out_ref !== ( mcd_out_ref ^ mcd_out_dut ^ mcd_out_ref ))
		begin if (stats1.errors_mcd_out == 0) stats1.errortime_mcd_out = $time;
			stats1.errors_mcd_out = stats1.errors_mcd_out+1'b1; end
		if (vld_out_ref !== ( vld_out_ref ^ vld_out_dut ^ vld_out_ref ))
		begin if (stats1.errors_vld_out == 0) stats1.errortime_vld_out = $time;
			stats1.errors_vld_out = stats1.errors_vld_out+1'b1; end
         // === End your code here ===

	end

   // add timeout after 100K cycles
   initial begin
     #1000000
     $display("TIMEOUT");
     $finish();
   end

endmodule
