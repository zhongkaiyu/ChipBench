`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13


module stimulus_gen (
	input clk,
    // === Start your code here ===
	output logic A,
	output logic B,
	output logic Ci
    // === End your code here ===
);
	// === Start your code here ===
    initial begin
		A <= 0;
		B <= 0;
		Ci <= 0;
		
		// Test all 8 possible combinations
		@(posedge clk);
		A <= 0; B <= 0; Ci <= 0;
		@(posedge clk);
		
		A <= 0; B <= 0; Ci <= 1;
		@(posedge clk);
		
		A <= 0; B <= 1; Ci <= 0;
		@(posedge clk);
		
		A <= 0; B <= 1; Ci <= 1;
		@(posedge clk);
		
		A <= 1; B <= 0; Ci <= 0;
		@(posedge clk);
		
		A <= 1; B <= 0; Ci <= 1;
		@(posedge clk);
		
		A <= 1; B <= 1; Ci <= 0;
		@(posedge clk);
		
		A <= 1; B <= 1; Ci <= 1;
		@(posedge clk);
		
		repeat(20) @(posedge clk);
		
		#1 $finish;
	end
	// === End your code here ===
	
endmodule

module tb();

	// === Start your code here ===
	typedef struct packed {
		int errors;
		int errortime;
		int errors_D;
		int errortime_D;
		int errors_Co;
		int errortime_Co;

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
	logic A;
	logic B;
	logic Ci;
	logic D_ref;
	logic D_dut;
	logic Co_ref;
	logic Co_dut;
	// === End your code here ===

	initial begin 
		$dumpfile("wave.vcd");
		// === Start your code here ===
		$dumpvars(1, stim1.clk, tb_mismatch, clk, A, B, Ci, D_ref, D_dut, Co_ref, Co_dut);
		// === End your code here ===
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	// === Start your code here ===
	stimulus_gen stim1 (
		.clk,
		.A,
		.B,
		.Ci
	);
		
	RefModule good1 (
		.A,
		.B,
		.Ci,
		.D(D_ref),
		.Co(Co_ref)
	);
		
	TopModule top_module1 (
		.A,
		.B,
		.Ci,
		.D(D_dut),
		.Co(Co_dut)
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
		if (stats1.errors_D) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "D", stats1.errors_D, stats1.errortime_D);
		else $display("Hint: Output '%s' has no mismatches.", "D");
		if (stats1.errors_Co) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "Co", stats1.errors_Co, stats1.errortime_Co);
		else $display("Hint: Output '%s' has no mismatches.", "Co");
        // === End your code here ===

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { D_ref, Co_ref } === ( { D_ref, Co_ref } ^ { D_dut, Co_dut } ^ { D_ref, Co_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		// === Start your code here ===
		if (D_ref !== ( D_ref ^ D_dut ^ D_ref ))
		begin if (stats1.errors_D == 0) stats1.errortime_D = $time;
			stats1.errors_D = stats1.errors_D+1'b1; end
		if (Co_ref !== ( Co_ref ^ Co_dut ^ Co_ref ))
		begin if (stats1.errors_Co == 0) stats1.errortime_Co = $time;
			stats1.errors_Co = stats1.errors_Co+1'b1; end
         // === End your code here ===

	end

   // add timeout after 100K cycles
   initial begin
     #1000000
     $display("TIMEOUT");
     $finish();
   end

endmodule
