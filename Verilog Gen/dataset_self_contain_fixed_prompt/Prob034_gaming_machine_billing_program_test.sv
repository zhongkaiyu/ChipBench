`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13


module stimulus_gen (
	input clk,
    // === Start your code here ===
	output logic rst_n,
	output logic [9:0] money,
	output logic set,
	output logic boost
    // === End your code here ===
);
	// === Start your code here ===
	initial begin
		rst_n = 0;
		money = 0;
		set = 0;
		boost = 0;
		repeat(10) @(posedge clk);
		rst_n = 1;
		@(posedge clk);
		
		// Test normal mode charging
		set = 1;
		money = 10'd50; @(posedge clk); // Charge 50 yuan
		set = 0;
		@(posedge clk);
		
		// Test normal mode consumption (1 yuan per cycle)
		boost = 0;
		repeat(20) @(posedge clk); // Consume 20 yuan
		
		// Test charging during gameplay
		boost = 0;
		set = 1;
		money = 10'd20; @(posedge clk); // Charge while playing
		set = 0;
		@(posedge clk);

        boost = 1;
        repeat(25) @(posedge clk); // Consume 50 yuan
				
		// Test insufficient funds in normal mode
		boost = 0;
		repeat(10) @(posedge clk); // Try to consume more than available
		
		// Test insufficient funds in boost mode
		set = 1;
		money = 10'd3; @(posedge clk); // Charge small amount
		set = 0;
		@(posedge clk);
		boost = 1;
		repeat(5) @(posedge clk); // Try to consume in boost mode
		
		// Random testing
		repeat(200) @(posedge clk, negedge clk) begin
			set <= $random;
			boost <= $random;
			money <= $random % 1024;
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
		int errors_remain;
		int errortime_remain;
		int errors_yellow;
		int errortime_yellow;
		int errors_red;
		int errortime_red;

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
	logic [9:0] money;
	logic set;
	logic boost;
	logic [9:0] remain_ref;
	logic yellow_ref;
	logic red_ref;
	logic [9:0] remain_dut;
	logic yellow_dut;
	logic red_dut;
	// === End your code here ===

	initial begin 
		$dumpfile("wave.vcd");
		// === Start your code here ===
		$dumpvars(1, stim1.clk, tb_mismatch, clk, rst_n, money, set, boost, remain_ref, yellow_ref, red_ref, remain_dut, yellow_dut, red_dut );
		// === End your code here ===
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	// === Start your code here ===
	stimulus_gen stim1 (
		.clk,
		.rst_n,
		.money,
		.set,
		.boost );
		
	RefModule good1 (
		.clk,
		.rst_n,
		.money,
		.set,
		.boost,
		.remain(remain_ref),
		.yellow(yellow_ref),
		.red(red_ref) );
		
	TopModule top_module1 (
		.clk,
		.rst_n,
		.money,
		.set,
		.boost,
		.remain(remain_dut),
		.yellow(yellow_dut),
		.red(red_dut) );
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
		if (stats1.errors_remain) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "remain", stats1.errors_remain, stats1.errortime_remain);
		else $display("Hint: Output '%s' has no mismatches.", "remain");
		if (stats1.errors_yellow) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "yellow", stats1.errors_yellow, stats1.errortime_yellow);
		else $display("Hint: Output '%s' has no mismatches.", "yellow");
		if (stats1.errors_red) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "red", stats1.errors_red, stats1.errortime_red);
		else $display("Hint: Output '%s' has no mismatches.", "red");
        // === End your code here ===

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { remain_ref, yellow_ref, red_ref } === ( { remain_ref, yellow_ref, red_ref } ^ { remain_dut, yellow_dut, red_dut } ^ { remain_ref, yellow_ref, red_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		// === Start your code here ===
		if (remain_ref !== ( remain_ref ^ remain_dut ^ remain_ref ))
		begin if (stats1.errors_remain == 0) stats1.errortime_remain = $time;
			stats1.errors_remain = stats1.errors_remain+1'b1; end
		if (yellow_ref !== ( yellow_ref ^ yellow_dut ^ yellow_ref ))
		begin if (stats1.errors_yellow == 0) stats1.errortime_yellow = $time;
			stats1.errors_yellow = stats1.errors_yellow+1'b1; end
		if (red_ref !== ( red_ref ^ red_dut ^ red_ref ))
		begin if (stats1.errors_red == 0) stats1.errortime_red = $time;
			stats1.errors_red = stats1.errors_red+1'b1; end
         // === End your code here ===

	end

   // add timeout after 100K cycles
   initial begin
     #1000000
     $display("TIMEOUT");
     $finish();
   end

endmodule
