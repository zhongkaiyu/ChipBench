`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13


module stimulus_gen (
	input clk,
    // === Start your code here ===
	output logic [3:0] A_in,
	output logic [3:0] B_in,
	output logic C_1
    // === End your code here ===
);
	// === Start your code here ===
    initial begin
		A_in <= 0;
		B_in <= 0;
		C_1 <= 0;
		
		// Test basic addition cases
		@(posedge clk);
		A_in <= 4'b0001;
		B_in <= 4'b0001;
		C_1 <= 0;
		@(posedge clk);
		
		A_in <= 4'b0010;
		B_in <= 4'b0011;
		C_1 <= 0;
		@(posedge clk);
		
		A_in <= 4'b0100;
		B_in <= 4'b0100;
		C_1 <= 1;
		@(posedge clk);
		
		A_in <= 4'b1000;
		B_in <= 4'b1000;
		C_1 <= 0;
		@(posedge clk);
		
		A_in <= 4'b1111;
		B_in <= 4'b0001;
		C_1 <= 0;
		@(posedge clk);
		
		A_in <= 4'b1111;
		B_in <= 4'b1111;
		C_1 <= 1;
		@(posedge clk);
		
		A_in <= 4'b1010;
		B_in <= 4'b0101;
		C_1 <= 0;
		@(posedge clk);
		
		A_in <= 4'b0110;
		B_in <= 4'b1001;
		C_1 <= 1;
		@(posedge clk);
		
		// Test edge cases
		A_in <= 4'b0000;
		B_in <= 4'b0000;
		C_1 <= 0;
		@(posedge clk);
		
		A_in <= 4'b0000;
		B_in <= 4'b0000;
		C_1 <= 1;
		@(posedge clk);
		
		A_in <= 4'b1111;
		B_in <= 4'b0000;
		C_1 <= 0;
		@(posedge clk);
		
		A_in <= 4'b0000;
		B_in <= 4'b1111;
		C_1 <= 1;
		@(posedge clk);
		
		// Random test sequence
		repeat(200) @(posedge clk) begin
			A_in <= $random & 15;  // 4-bit random
			B_in <= $random & 15;  // 4-bit random
			C_1 <= $random & 1;    // 1-bit random
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
		int errors_S;
		int errortime_S;
		int errors_CO;
		int errortime_CO;

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
	logic [3:0] A_in;
	logic [3:0] B_in;
	logic C_1;
	logic [3:0] S_ref;
	logic [3:0] S_dut;
	logic CO_ref;
	logic CO_dut;
	// === End your code here ===

	initial begin 
		$dumpfile("wave.vcd");
		// === Start your code here ===
		$dumpvars(1, stim1.clk, tb_mismatch, clk, A_in, B_in, C_1, S_ref, S_dut, CO_ref, CO_dut);
		// === End your code here ===
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	// === Start your code here ===
	stimulus_gen stim1 (
		.clk,
		.A_in,
		.B_in,
		.C_1
	);
		
	RefModule good1 (
		.A_in,
		.B_in,
		.C_1,
		.CO(CO_ref),
		.S(S_ref)
	);
		
	TopModule top_module1 (
		.A_in,
		.B_in,
		.C_1,
		.CO(CO_dut),
		.S(S_dut)
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
		if (stats1.errors_S) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "S", stats1.errors_S, stats1.errortime_S);
		else $display("Hint: Output '%s' has no mismatches.", "S");
		if (stats1.errors_CO) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "CO", stats1.errors_CO, stats1.errortime_CO);
		else $display("Hint: Output '%s' has no mismatches.", "CO");
        // === End your code here ===

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { S_ref, CO_ref } === ( { S_ref, CO_ref } ^ { S_dut, CO_dut } ^ { S_ref, CO_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		// === Start your code here ===
		if (S_ref !== ( S_ref ^ S_dut ^ S_ref ))
		begin if (stats1.errors_S == 0) stats1.errortime_S = $time;
			stats1.errors_S = stats1.errors_S+1'b1; end
		if (CO_ref !== ( CO_ref ^ CO_dut ^ CO_ref ))
		begin if (stats1.errors_CO == 0) stats1.errortime_CO = $time;
			stats1.errors_CO = stats1.errors_CO+1'b1; end
         // === End your code here ===

	end

   // add timeout after 100K cycles
   initial begin
     #1000000
     $display("TIMEOUT");
     $finish();
   end

endmodule
