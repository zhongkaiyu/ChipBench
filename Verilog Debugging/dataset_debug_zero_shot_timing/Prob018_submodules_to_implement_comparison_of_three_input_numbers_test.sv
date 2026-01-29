`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13


module stimulus_gen (
	input clk,
    // === Start your code here ===
	output logic rst_n,
	output logic [7:0] a,
	output logic [7:0] b,
	output logic [7:0] c
    // === End your code here ===
);
	// === Start your code here ===
    initial begin
		rst_n <= 0;
		a <= 0;
		b <= 0;
		c <= 0;
		
		// Reset sequence
		@(posedge clk);
		@(posedge clk);
		rst_n <= 1;
		@(posedge clk);
		
		// Test case 1: a is minimum
		a <= 8'd10;
		b <= 8'd20;
		c <= 8'd15;
		@(posedge clk);
		
		// Test case 2: b is minimum
		a <= 8'd25;
		b <= 8'd5;
		c <= 8'd30;
		@(posedge clk);
		
		// Test case 3: c is minimum
		a <= 8'd50;
		b <= 8'd40;
		c <= 8'd15;
		@(posedge clk);
		
		// Test case 4: all equal
		a <= 8'd100;
		b <= 8'd100;
		c <= 8'd100;
		@(posedge clk);
		
		// Test case 5: two values equal and minimum
		a <= 8'd5;
		b <= 8'd5;
		c <= 8'd10;
		@(posedge clk);
		
		// Test case 6: large values
		a <= 8'd255;
		b <= 8'd200;
		c <= 8'd150;
		@(posedge clk);
		
		// Test case 7: edge cases
		a <= 8'd0;
		b <= 8'd1;
		c <= 8'd2;
		@(posedge clk);
		
		a <= 8'd254;
		b <= 8'd255;
		c <= 8'd253;
		@(posedge clk);
		
		// Random test sequence
		repeat(200) @(posedge clk) begin
			a <= $random & 255;
			b <= $random & 255;
			c <= $random & 255;
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
		int errors_d;
		int errortime_d;

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
	logic [7:0] a;
	logic [7:0] b;
	logic [7:0] c;
	logic [7:0] d_ref;
	logic [7:0] d_dut;
	// === End your code here ===

	initial begin 
		$dumpfile("wave.vcd");
		// === Start your code here ===
		$dumpvars(1, stim1.clk, tb_mismatch, clk, rst_n, a, b, c, d_ref, d_dut);
		// === End your code here ===
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	// === Start your code here ===
	stimulus_gen stim1 (
		.clk,
		.rst_n,
		.a,
		.b,
		.c
	);
		
	RefModule good1 (
		.clk,
		.rst_n,
		.a,
		.b,
		.c,
		.d(d_ref)
	);
		
	TopModule top_module1 (
		.clk,
		.rst_n,
		.a,
		.b,
		.c,
		.d(d_dut)
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
		if (stats1.errors_d) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "d", stats1.errors_d, stats1.errortime_d);
		else $display("Hint: Output '%s' has no mismatches.", "d");
        // === End your code here ===

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { d_ref } === ( { d_ref } ^ { d_dut } ^ { d_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		// === Start your code here ===
		if (d_ref !== ( d_ref ^ d_dut ^ d_ref ))
		begin if (stats1.errors_d == 0) stats1.errortime_d = $time;
			stats1.errors_d = stats1.errors_d+1'b1; end
         // === End your code here ===

	end

   // add timeout after 100K cycles
   initial begin
     #1000000
     $display("TIMEOUT");
     $finish();
   end

endmodule
