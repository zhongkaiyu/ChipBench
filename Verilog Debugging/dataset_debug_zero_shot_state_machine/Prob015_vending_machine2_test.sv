`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13


module stimulus_gen (
	input clk,
    // === Start your code here ===
	output logic rst,
	output logic d1,
	output logic d2,
	output logic sel
    // === End your code here ===
);
	// === Start your code here ===
	initial begin
		rst = 0;
		d1 = 0;
		d2 = 0;
		sel = 0;
		repeat(10) @(posedge clk);
		rst = 1;
		@(posedge clk);
		
		// Test case 1: Insert 1.5 yuan and select beverage 1 (sel=0)
		d1 = 1; @(posedge clk);  // Insert 0.5 yuan
		d1 = 0; @(posedge clk);
		d1 = 1; @(posedge clk);  // Insert another 0.5 yuan
		d1 = 0; @(posedge clk);
		d1 = 1; @(posedge clk);  // Insert third 0.5 yuan
		d1 = 0; @(posedge clk);
		sel = 0; @(posedge clk);  // Select beverage 1
		sel = 0; @(posedge clk);  // Should dispense beverage 1
		
		// Test case 2: Insert 2.5 yuan and select beverage 2 (sel=1)
		d2 = 1; @(posedge clk);  // Insert 1 yuan
		d2 = 0; @(posedge clk);
		d2 = 1; @(posedge clk);  // Insert another 1 yuan
		d2 = 0; @(posedge clk);
		d1 = 1; @(posedge clk);  // Insert 0.5 yuan
		d1 = 0; @(posedge clk);
		sel = 1; @(posedge clk);  // Select beverage 2
		sel = 1; @(posedge clk);  // Should dispense beverage 2
		
		// Test case 3: Insert 2 yuan and select beverage 1 (sel=0) - should get change
		d2 = 1; @(posedge clk);  // Insert 1 yuan
		d2 = 0; @(posedge clk);
		d2 = 1; @(posedge clk);  // Insert another 1 yuan
		d2 = 0; @(posedge clk);
		sel = 0; @(posedge clk);  // Select beverage 1
		sel = 0; @(posedge clk);  // Should dispense beverage 1 + 0.5 yuan change
		
		// Test case 4: Insert 3 yuan and select beverage 2 (sel=1) - should get change
		d2 = 1; @(posedge clk);  // Insert 1 yuan
		d2 = 0; @(posedge clk);
		d2 = 1; @(posedge clk);  // Insert another 1 yuan
		d2 = 0; @(posedge clk);
		d2 = 1; @(posedge clk);  // Insert third 1 yuan
		d2 = 0; @(posedge clk);
		sel = 1; @(posedge clk);  // Select beverage 2
		sel = 1; @(posedge clk);  // Should dispense beverage 2 + 0.5 yuan change
		
		// Random testing
		repeat(100) @(posedge clk, negedge clk) begin
			d1 <= $random;
			d2 <= $random;
			sel <= $random;
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
		int errors_out1;
		int errortime_out1;
		int errors_out2;
		int errortime_out2;
		int errors_out3;
		int errortime_out3;

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
	logic rst;
	logic d1;
	logic d2;
	logic sel;
	logic out1_ref;
	logic out2_ref;
	logic out3_ref;
	logic out1_dut;
	logic out2_dut;
	logic out3_dut;
	// === End your code here ===

	initial begin 
		$dumpfile("wave.vcd");
		// === Start your code here ===
		$dumpvars(1, stim1.clk, tb_mismatch, clk, rst, d1, d2, sel, out1_ref, out2_ref, out3_ref, out1_dut, out2_dut, out3_dut );
		// === End your code here ===
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	// === Start your code here ===
	stimulus_gen stim1 (
		.clk,
		.rst,
		.d1,
		.d2,
		.sel );
		
	RefModule good1 (
		.clk,
		.rst,
		.d1,
		.d2,
		.sel,
		.out1(out1_ref),
		.out2(out2_ref),
		.out3(out3_ref) );
		
	TopModule top_module1 (
		.clk,
		.rst,
		.d1,
		.d2,
		.sel,
		.out1(out1_dut),
		.out2(out2_dut),
		.out3(out3_dut) );
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
		if (stats1.errors_out1) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "out1", stats1.errors_out1, stats1.errortime_out1);
		else $display("Hint: Output '%s' has no mismatches.", "out1");
		if (stats1.errors_out2) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "out2", stats1.errors_out2, stats1.errortime_out2);
		else $display("Hint: Output '%s' has no mismatches.", "out2");
		if (stats1.errors_out3) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "out3", stats1.errors_out3, stats1.errortime_out3);
		else $display("Hint: Output '%s' has no mismatches.", "out3");
        // === End your code here ===

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { out1_ref, out2_ref, out3_ref } === ( { out1_ref, out2_ref, out3_ref } ^ { out1_dut, out2_dut, out3_dut } ^ { out1_ref, out2_ref, out3_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		// === Start your code here ===
		if (out1_ref !== ( out1_ref ^ out1_dut ^ out1_ref ))
		begin if (stats1.errors_out1 == 0) stats1.errortime_out1 = $time;
			stats1.errors_out1 = stats1.errors_out1+1'b1; end
		if (out2_ref !== ( out2_ref ^ out2_dut ^ out2_ref ))
		begin if (stats1.errors_out2 == 0) stats1.errortime_out2 = $time;
			stats1.errors_out2 = stats1.errors_out2+1'b1; end
		if (out3_ref !== ( out3_ref ^ out3_dut ^ out3_ref ))
		begin if (stats1.errors_out3 == 0) stats1.errortime_out3 = $time;
			stats1.errors_out3 = stats1.errors_out3+1'b1; end
         // === End your code here ===

	end

   // add timeout after 100K cycles
   initial begin
     #1000000
     $display("TIMEOUT");
     $finish();
   end

endmodule
