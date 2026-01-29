`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13


module stimulus_gen (
	input clk,
    // === Start your code here ===
	output logic rst,
	output logic data
    // === End your code here ===
);
	// === Start your code here ===
	initial begin
		rst = 0;
		data = 0;
		repeat(10) @(posedge clk);
		rst = 1;
		@(posedge clk);
		
		// Test state transitions: S0->S1->S2->S3->S4 (flag=1)
		data = 1; @(posedge clk);  // S0->S1
		data = 1; @(posedge clk);  // S1->S2
		data = 1; @(posedge clk);  // S2->S3
		data = 1; @(posedge clk);  // S3->S4 (flag should be 1)
		
		// Test S4->S1 transition (data=1)
		data = 1; @(posedge clk);  // S4->S1
		
		// Test S4->S0 transition (data=0)
		data = 1; @(posedge clk);  // S1->S2
		data = 1; @(posedge clk);  // S2->S3
		data = 1; @(posedge clk);  // S3->S4
		data = 0; @(posedge clk);  // S4->S0
		
		// Test staying in S0 (data=0)
		data = 0; @(posedge clk);  // S0->S0
		data = 0; @(posedge clk);  // S0->S0
		
		// Test staying in S1 (data=0)
		data = 1; @(posedge clk);  // S0->S1
		data = 0; @(posedge clk);  // S1->S1
		data = 0; @(posedge clk);  // S1->S1
		
		// Test staying in S2 (data=0)
		data = 1; @(posedge clk);  // S1->S2
		data = 0; @(posedge clk);  // S2->S2
		data = 0; @(posedge clk);  // S2->S2
		
		// Test staying in S3 (data=0)
		data = 1; @(posedge clk);  // S2->S3
		data = 0; @(posedge clk);  // S3->S3
		data = 0; @(posedge clk);  // S3->S3
		
		// Random testing
		repeat(200) @(posedge clk, negedge clk) begin
			data <= $random;
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
		int errors_flag;
		int errortime_flag;

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
	logic data;
	logic flag_ref;
	logic flag_dut;
	// === End your code here ===

	initial begin 
		$dumpfile("wave.vcd");
		// === Start your code here ===
		$dumpvars(1, stim1.clk, tb_mismatch, clk, rst, data, flag_ref, flag_dut );
		// === End your code here ===
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	// === Start your code here ===
	stimulus_gen stim1 (
		.clk,
		.rst,
		.data );
		
	RefModule good1 (
		.clk,
		.rst,
		.data,
		.flag(flag_ref) );
		
	TopModule top_module1 (
		.clk,
		.rst,
		.data,
		.flag(flag_dut) );
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
		if (stats1.errors_flag) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "flag", stats1.errors_flag, stats1.errortime_flag);
		else $display("Hint: Output '%s' has no mismatches.", "flag");
        // === End your code here ===

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { flag_ref } === ( { flag_ref } ^ { flag_dut } ^ { flag_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		// === Start your code here ===
		if (flag_ref !== ( flag_ref ^ flag_dut ^ flag_ref ))
		begin if (stats1.errors_flag == 0) stats1.errortime_flag = $time;
			stats1.errors_flag = stats1.errors_flag+1'b1; end
         // === End your code here ===

	end

   // add timeout after 100K cycles
   initial begin
     #1000000
     $display("TIMEOUT");
     $finish();
   end

endmodule
