`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13
`define RstEnable 1'b1
`define RstDisable 1'b0
`define NoStop 1'b0
`define RegBus 31:0
`define InstAddrBus 31:0
`define Branch 1'b1
`define ChipDisable 1'b0
`define ChipEnable 1'b1

module stimulus_gen (
	input clk,
	// === Start your code here ===
	output reg rst,
	output reg [5:0] stall,
	output reg flush,
	output reg [31:0] new_pc,
	output reg branch_flag_i,
	output reg [31:0] branch_target_address_i
	// === End your code here ===
);


	initial begin
		// Initialize all signals
		rst = `RstEnable;
		stall = 6'b0;
		flush = 1'b0;
		new_pc = 32'h0;
		branch_flag_i = 1'b0;
		branch_target_address_i = 32'h0;
		
		// Test reset - hold reset for a few cycles
		@(posedge clk);
		@(posedge clk);
		@(posedge clk);
		
		// Release reset
		rst = `RstDisable;
		@(posedge clk);
		
		// Test normal PC increment (should increment by 4 each cycle)
		stall = 6'b0;
		flush = 1'b0;
		branch_flag_i = 1'b0;
		repeat(10) @(posedge clk);
		
		// Test stall - PC should not increment when stall[0] = 1
		stall = 6'b000001; // stall[0] = 1
		repeat(5) @(posedge clk);
		stall = 6'b0;
		repeat(5) @(posedge clk);
		
		// Test flush - PC should jump to new_pc
		new_pc = 32'h00001000;
		flush = 1'b1;
		@(posedge clk);
		flush = 1'b0;
		repeat(5) @(posedge clk);
		
		// Test branch - PC should jump to branch_target_address_i
        stall = 6'b0;
		branch_target_address_i = 32'h00002000;
		branch_flag_i = `Branch;
		@(posedge clk);
		branch_flag_i = 1'b0;
		repeat(5) @(posedge clk);
		
		
		// Test stall with branch - stall should prevent PC update
		branch_target_address_i = 32'h00005000;
		branch_flag_i = `Branch;
		stall = 6'b000001; // stall[0] = 1
		@(posedge clk);
		stall = 6'b0;
		branch_flag_i = 1'b0;
		repeat(5) @(posedge clk);
		
		// Random testing
		repeat(1000) @(posedge clk) begin
			stall <= $urandom;
			flush <= ($urandom % 20 == 0) ? 1'b1 : 1'b0;
			new_pc <= $urandom;
			branch_flag_i <= ($urandom % 15 == 0) ? `Branch : 1'b0;
			branch_target_address_i <= $urandom;
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
		int errors_pc;
		int errortime_pc;
		int errors_ce;
		int errortime_ce;

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
	logic [5:0] stall;
	logic flush;
	logic [31:0] new_pc;
	logic branch_flag_i;
	logic [31:0] branch_target_address_i;
	logic [31:0] pc_ref;
	logic [31:0] pc_dut;
	logic ce_ref;
	logic ce_dut;
	// === End your code here ===

	initial begin 
		$dumpfile("wave.vcd");
		// === Start your code here ===
		$dumpvars(1, stim1.clk, tb_mismatch, clk, rst, stall, flush, new_pc, branch_flag_i, branch_target_address_i, pc_ref, pc_dut, ce_ref, ce_dut);
		// === End your code here ===
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	// === Start your code here ===
	stimulus_gen stim1 (
		.clk(clk),
		.rst(rst),
		.stall(stall),
		.flush(flush),
		.new_pc(new_pc),
		.branch_flag_i(branch_flag_i),
		.branch_target_address_i(branch_target_address_i)
	);
		
	RefModule good1 (
		.clk(clk),
		.rst(rst),
		.stall(stall),
		.flush(flush),
		.new_pc(new_pc),
		.branch_flag_i(branch_flag_i),
		.branch_target_address_i(branch_target_address_i),
		.pc(pc_ref),
		.ce(ce_ref)
	);
		
	TopModule top_module1 (
		.clk(clk),
		.rst(rst),
		.stall(stall),
		.flush(flush),
		.new_pc(new_pc),
		.branch_flag_i(branch_flag_i),
		.branch_target_address_i(branch_target_address_i),
		.pc(pc_dut),
		.ce(ce_dut)
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
		if (stats1.errors_pc) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "pc", stats1.errors_pc, stats1.errortime_pc);
		else $display("Hint: Output '%s' has no mismatches.", "pc");
		if (stats1.errors_ce) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "ce", stats1.errors_ce, stats1.errortime_ce);
		else $display("Hint: Output '%s' has no mismatches.", "ce");
		// === End your code here ===

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { pc_ref, ce_ref } === ( { pc_ref, ce_ref } ^ { pc_dut, ce_dut } ^ { pc_ref, ce_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		// === Start your code here ===
		if (pc_ref !== ( pc_ref ^ pc_dut ^ pc_ref ))
		begin 
			if (stats1.errors_pc == 0) stats1.errortime_pc = $time;
			stats1.errors_pc = stats1.errors_pc+1'b1; 
		end
		if (ce_ref !== ( ce_ref ^ ce_dut ^ ce_ref ))
		begin 
			if (stats1.errors_ce == 0) stats1.errortime_ce = $time;
			stats1.errors_ce = stats1.errors_ce+1'b1; 
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
