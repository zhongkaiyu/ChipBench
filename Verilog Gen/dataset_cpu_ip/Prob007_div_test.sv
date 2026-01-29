`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13
`define RstEnable 1'b1
`define RstDisable 1'b0
`define DivFree 2'b00
`define DivByZero 2'b01
`define DivOn 2'b10
`define DivEnd 2'b11
`define DivResultReady 1'b1
`define DivResultNotReady 1'b0
`define DivStart 1'b1
`define DivStop 1'b0
`define ZeroWord 32'h00000000

module stimulus_gen (
	input clk,
	// === Start your code here ===
	output reg rst,
	output reg signed_div_i,
	output reg [31:0] opdata1_i,
	output reg [31:0] opdata2_i,
	output reg start_i,
	output reg annul_i
	// === End your code here ===
);
	// === Start your code here ===
	initial begin
		// Initialize all signals
		rst = `RstEnable;
		signed_div_i = 1'b0;
		opdata1_i = 32'h0;
		opdata2_i = 32'h0;
		start_i = `DivStop;
		annul_i = 1'b0;
		
		// Hold reset for a few cycles
		@(posedge clk);
		@(posedge clk);
		@(posedge clk);
		
		// Release reset
		rst = `RstDisable;
		@(posedge clk);
		
		// Test 1: Simple unsigned division (100 / 5 = 20 remainder 0)
		signed_div_i = 1'b0;
		opdata1_i = 32'd100;
		opdata2_i = 32'd5;
		start_i = `DivStart;
		annul_i = 1'b0;
		// Keep start_i asserted for 33 cycles (32 cycles for calculation + 1 for DivEnd)
		repeat(33) @(posedge clk);
		start_i = `DivStop;
		@(posedge clk); // Wait for result to be cleared
		repeat(5) @(posedge clk);
		
		// Test 2: Unsigned division with remainder (100 / 7 = 14 remainder 2)
		opdata1_i = 32'd100;
		opdata2_i = 32'd7;
		start_i = `DivStart;
		repeat(33) @(posedge clk);
		start_i = `DivStop;
		@(posedge clk);
		repeat(5) @(posedge clk);
		
		// Test 3: Division by zero
		opdata1_i = 32'd100;
		opdata2_i = `ZeroWord;
		start_i = `DivStart;
		repeat(33) @(posedge clk);
		start_i = `DivStop;
		@(posedge clk);
		repeat(5) @(posedge clk);
		
		// Test 4: Signed division (positive / positive)
		signed_div_i = 1'b1;
		opdata1_i = 32'd100;
		opdata2_i = 32'd5;
		start_i = `DivStart;
		repeat(33) @(posedge clk);
		start_i = `DivStop;
		@(posedge clk);
		repeat(5) @(posedge clk);
		
		// Test 5: Signed division (negative / positive)
		opdata1_i = 32'hFFFFFF9C; // -100 in two's complement
		opdata2_i = 32'd5;
		start_i = `DivStart;
		repeat(33) @(posedge clk);
		start_i = `DivStop;
		@(posedge clk);
		repeat(5) @(posedge clk);
		
		// Test 6: Signed division (positive / negative)
		opdata1_i = 32'd100;
		opdata2_i = 32'hFFFFFFFB; // -5 in two's complement
		start_i = `DivStart;
		repeat(33) @(posedge clk);
		start_i = `DivStop;
		@(posedge clk);
		repeat(5) @(posedge clk);
		
		// Test 7: Signed division (negative / negative)
		opdata1_i = 32'hFFFFFF9C; // -100
		opdata2_i = 32'hFFFFFFFB; // -5
		start_i = `DivStart;
		repeat(33) @(posedge clk);
		start_i = `DivStop;
		@(posedge clk);
		repeat(5) @(posedge clk);
		
		// Test 8: Annul test - cancel during calculation
		opdata1_i = 32'd1000;
		opdata2_i = 32'd3;
		start_i = `DivStart;
		annul_i = 1'b0;
		repeat(10) @(posedge clk); // Wait a bit
		annul_i = 1'b1; // Cancel the operation
		@(posedge clk);
		annul_i = 1'b0;
		start_i = `DivStop;
		repeat(5) @(posedge clk);
		
		// Test 9: Large numbers
		opdata1_i = 32'hFFFFFFFF;
		opdata2_i = 32'd1;
		start_i = `DivStart;
		repeat(33) @(posedge clk);
		start_i = `DivStop;
		@(posedge clk);
		repeat(5) @(posedge clk);
		
		
		// Random testing
		repeat(200) @(posedge clk) begin
			signed_div_i <= $urandom % 2;
			opdata1_i <= $urandom;
			opdata2_i <= $urandom;
			start_i <= ($urandom % 10 == 0) ? `DivStart : `DivStop;
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
		int errors_result_o;
		int errortime_result_o;
		int errors_ready_o;
		int errortime_ready_o;

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
	logic signed_div_i;
	logic [31:0] opdata1_i;
	logic [31:0] opdata2_i;
	logic start_i;
	logic annul_i;
	logic [63:0] result_o_ref;
	logic [63:0] result_o_dut;
	logic ready_o_ref;
	logic ready_o_dut;
	// === End your code here ===

	initial begin 
		$dumpfile("wave.vcd");
		// === Start your code here ===
		$dumpvars(1, stim1.clk, tb_mismatch, clk, rst, signed_div_i, opdata1_i, opdata2_i, start_i, annul_i, result_o_ref, result_o_dut, ready_o_ref, ready_o_dut);
		// === End your code here ===
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	// === Start your code here ===
	stimulus_gen stim1 (
		.clk(clk),
		.rst(rst),
		.signed_div_i(signed_div_i),
		.opdata1_i(opdata1_i),
		.opdata2_i(opdata2_i),
		.start_i(start_i),
		.annul_i(annul_i)
	);
		
	RefModule good1 (
		.clk(clk),
		.rst(rst),
		.signed_div_i(signed_div_i),
		.opdata1_i(opdata1_i),
		.opdata2_i(opdata2_i),
		.start_i(start_i),
		.annul_i(annul_i),
		.result_o(result_o_ref),
		.ready_o(ready_o_ref)
	);
		
	TopModule top_module1 (
		.clk(clk),
		.rst(rst),
		.signed_div_i(signed_div_i),
		.opdata1_i(opdata1_i),
		.opdata2_i(opdata2_i),
		.start_i(start_i),
		.annul_i(annul_i),
		.result_o(result_o_dut),
		.ready_o(ready_o_dut)
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
		if (stats1.errors_result_o) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "result_o", stats1.errors_result_o, stats1.errortime_result_o);
		else $display("Hint: Output '%s' has no mismatches.", "result_o");
		if (stats1.errors_ready_o) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "ready_o", stats1.errors_ready_o, stats1.errortime_ready_o);
		else $display("Hint: Output '%s' has no mismatches.", "ready_o");
		// === End your code here ===

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { result_o_ref, ready_o_ref } === ( { result_o_ref, ready_o_ref } ^ { result_o_dut, ready_o_dut } ^ { result_o_ref, ready_o_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		// === Start your code here ===
		if (result_o_ref !== ( result_o_ref ^ result_o_dut ^ result_o_ref ))
		begin 
			if (stats1.errors_result_o == 0) stats1.errortime_result_o = $time;
			stats1.errors_result_o = stats1.errors_result_o+1'b1; 
		end
		if (ready_o_ref !== ( ready_o_ref ^ ready_o_dut ^ ready_o_ref ))
		begin 
			if (stats1.errors_ready_o == 0) stats1.errortime_ready_o = $time;
			stats1.errors_ready_o = stats1.errors_ready_o+1'b1; 
		end
		// === End your code here ===

	end

   // add timeout after 100K cycles
   initial begin
     #1000000
     $display("TIMEOUT");
     $finish();
   end

endmodule
