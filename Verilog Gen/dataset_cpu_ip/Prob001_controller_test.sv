`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13

module stimulus_gen (
	input clk,
	output logic [6:0] Opcode
);

	initial begin
		// Test each RISC-V instruction type
		// R-Type instruction (add, sub, etc.)
		Opcode = 7'b0110011;
		repeat(5) @(posedge clk, negedge clk);
		
		// Load Word (LW)
		Opcode = 7'b0000011;
		repeat(5) @(posedge clk, negedge clk);
		
		// Store Word (SW)
		Opcode = 7'b0100011;
		repeat(5) @(posedge clk, negedge clk);
		
		// I-Type ALU (addi, ori, etc.)
		Opcode = 7'b0010011;
		repeat(5) @(posedge clk, negedge clk);
		
		// Branch (beq, bne, etc.)
		Opcode = 7'b1100011;
		repeat(5) @(posedge clk, negedge clk);
		
		// JAL
		Opcode = 7'b1101111;
		repeat(5) @(posedge clk, negedge clk);
		
		// JALR
		Opcode = 7'b1100111;
		repeat(5) @(posedge clk, negedge clk);
		
		// LUI
		Opcode = 7'b0110111;
		repeat(5) @(posedge clk, negedge clk);
		
		// AUIPC
		Opcode = 7'b0010111;
		repeat(5) @(posedge clk, negedge clk);
		
		// Test some invalid/random opcodes
		repeat(500) @(negedge clk) begin
			Opcode <= $random;
		end

		#1 $finish;
	end
	
endmodule

module tb();

	typedef struct packed {
		int errors;
		int errortime;
		int errors_ALUSrc;
		int errortime_ALUSrc;
		int errors_MemtoReg;
		int errortime_MemtoReg;
		int errors_RegWrite;
		int errortime_RegWrite;
		int errors_MemRead;
		int errortime_MemRead;
		int errors_MemWrite;
		int errortime_MemWrite;
		int errors_ALUOp;
		int errortime_ALUOp;
		int errors_Branch;
		int errortime_Branch;
		int errors_JalrSel;
		int errortime_JalrSel;
		int errors_RWSel;
		int errortime_RWSel;

		int clocks;
	} stats;
	
	stats stats1;
	
	
	wire[511:0] wavedrom_title;
	wire wavedrom_enable;
	int wavedrom_hide_after_time;
	
	reg clk=0;
	initial forever
		#5 clk = ~clk;

	logic [6:0] Opcode;
	logic ALUSrc_ref;
	logic ALUSrc_dut;
	logic MemtoReg_ref;
	logic MemtoReg_dut;
	logic RegWrite_ref;
	logic RegWrite_dut;
	logic MemRead_ref;
	logic MemRead_dut;
	logic MemWrite_ref;
	logic MemWrite_dut;
	logic [1:0] ALUOp_ref;
	logic [1:0] ALUOp_dut;
	logic Branch_ref;
	logic Branch_dut;
	logic JalrSel_ref;
	logic JalrSel_dut;
	logic [1:0] RWSel_ref;
	logic [1:0] RWSel_dut;

	initial begin 
		$dumpfile("wave.vcd");
		$dumpvars(1, stim1.clk, tb_mismatch, clk, Opcode, ALUSrc_ref, ALUSrc_dut, MemtoReg_ref, MemtoReg_dut, RegWrite_ref, RegWrite_dut, MemRead_ref, MemRead_dut, MemWrite_ref, MemWrite_dut, ALUOp_ref, ALUOp_dut, Branch_ref, Branch_dut, JalrSel_ref, JalrSel_dut, RWSel_ref, RWSel_dut);
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	stimulus_gen stim1 (
		.clk,
		.Opcode );
	RefModule good1 (
		.Opcode,
		.ALUSrc(ALUSrc_ref),
		.MemtoReg(MemtoReg_ref),
		.RegWrite(RegWrite_ref),
		.MemRead(MemRead_ref),
		.MemWrite(MemWrite_ref),
		.ALUOp(ALUOp_ref),
		.Branch(Branch_ref),
		.JalrSel(JalrSel_ref),
		.RWSel(RWSel_ref) );
		
	TopModule top_module1 (
		.Opcode,
		.ALUSrc(ALUSrc_dut),
		.MemtoReg(MemtoReg_dut),
		.RegWrite(RegWrite_dut),
		.MemRead(MemRead_dut),
		.MemWrite(MemWrite_dut),
		.ALUOp(ALUOp_dut),
		.Branch(Branch_dut),
		.JalrSel(JalrSel_dut),
		.RWSel(RWSel_dut) );

	
	bit strobe = 0;
	task wait_for_end_of_timestep;
		repeat(5) begin
			strobe <= !strobe;  // Try to delay until the very end of the time step.
			@(strobe);
		end
	endtask	
	

	final begin
		if (stats1.errors_ALUSrc) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "ALUSrc", stats1.errors_ALUSrc, stats1.errortime_ALUSrc);
		else $display("Hint: Output '%s' has no mismatches.", "ALUSrc");
		if (stats1.errors_MemtoReg) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "MemtoReg", stats1.errors_MemtoReg, stats1.errortime_MemtoReg);
		else $display("Hint: Output '%s' has no mismatches.", "MemtoReg");
		if (stats1.errors_RegWrite) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "RegWrite", stats1.errors_RegWrite, stats1.errortime_RegWrite);
		else $display("Hint: Output '%s' has no mismatches.", "RegWrite");
		if (stats1.errors_MemRead) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "MemRead", stats1.errors_MemRead, stats1.errortime_MemRead);
		else $display("Hint: Output '%s' has no mismatches.", "MemRead");
		if (stats1.errors_MemWrite) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "MemWrite", stats1.errors_MemWrite, stats1.errortime_MemWrite);
		else $display("Hint: Output '%s' has no mismatches.", "MemWrite");
		if (stats1.errors_ALUOp) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "ALUOp", stats1.errors_ALUOp, stats1.errortime_ALUOp);
		else $display("Hint: Output '%s' has no mismatches.", "ALUOp");
		if (stats1.errors_Branch) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "Branch", stats1.errors_Branch, stats1.errortime_Branch);
		else $display("Hint: Output '%s' has no mismatches.", "Branch");
		if (stats1.errors_JalrSel) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "JalrSel", stats1.errors_JalrSel, stats1.errortime_JalrSel);
		else $display("Hint: Output '%s' has no mismatches.", "JalrSel");
		if (stats1.errors_RWSel) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "RWSel", stats1.errors_RWSel, stats1.errortime_RWSel);
		else $display("Hint: Output '%s' has no mismatches.", "RWSel");

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { ALUSrc_ref, MemtoReg_ref, RegWrite_ref, MemRead_ref, MemWrite_ref, ALUOp_ref, Branch_ref, JalrSel_ref, RWSel_ref } === ( { ALUSrc_ref, MemtoReg_ref, RegWrite_ref, MemRead_ref, MemWrite_ref, ALUOp_ref, Branch_ref, JalrSel_ref, RWSel_ref } ^ { ALUSrc_dut, MemtoReg_dut, RegWrite_dut, MemRead_dut, MemWrite_dut, ALUOp_dut, Branch_dut, JalrSel_dut, RWSel_dut } ^ { ALUSrc_ref, MemtoReg_ref, RegWrite_ref, MemRead_ref, MemWrite_ref, ALUOp_ref, Branch_ref, JalrSel_ref, RWSel_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin
		wait_for_end_of_timestep();

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		if (ALUSrc_ref !== ( ALUSrc_ref ^ ALUSrc_dut ^ ALUSrc_ref ))
		begin if (stats1.errors_ALUSrc == 0) stats1.errortime_ALUSrc = $time;
			stats1.errors_ALUSrc = stats1.errors_ALUSrc+1'b1; end
		if (MemtoReg_ref !== ( MemtoReg_ref ^ MemtoReg_dut ^ MemtoReg_ref ))
		begin if (stats1.errors_MemtoReg == 0) stats1.errortime_MemtoReg = $time;
			stats1.errors_MemtoReg = stats1.errors_MemtoReg+1'b1; end
		if (RegWrite_ref !== ( RegWrite_ref ^ RegWrite_dut ^ RegWrite_ref ))
		begin if (stats1.errors_RegWrite == 0) stats1.errortime_RegWrite = $time;
			stats1.errors_RegWrite = stats1.errors_RegWrite+1'b1; end
		if (MemRead_ref !== ( MemRead_ref ^ MemRead_dut ^ MemRead_ref ))
		begin if (stats1.errors_MemRead == 0) stats1.errortime_MemRead = $time;
			stats1.errors_MemRead = stats1.errors_MemRead+1'b1; end
		if (MemWrite_ref !== ( MemWrite_ref ^ MemWrite_dut ^ MemWrite_ref ))
		begin if (stats1.errors_MemWrite == 0) stats1.errortime_MemWrite = $time;
			stats1.errors_MemWrite = stats1.errors_MemWrite+1'b1; end
		if (ALUOp_ref !== ( ALUOp_ref ^ ALUOp_dut ^ ALUOp_ref ))
		begin if (stats1.errors_ALUOp == 0) stats1.errortime_ALUOp = $time;
			stats1.errors_ALUOp = stats1.errors_ALUOp+1'b1; end
		if (Branch_ref !== ( Branch_ref ^ Branch_dut ^ Branch_ref ))
		begin if (stats1.errors_Branch == 0) stats1.errortime_Branch = $time;
			stats1.errors_Branch = stats1.errors_Branch+1'b1; end
		if (JalrSel_ref !== ( JalrSel_ref ^ JalrSel_dut ^ JalrSel_ref ))
		begin if (stats1.errors_JalrSel == 0) stats1.errortime_JalrSel = $time;
			stats1.errors_JalrSel = stats1.errors_JalrSel+1'b1; end
		if (RWSel_ref !== ( RWSel_ref ^ RWSel_dut ^ RWSel_ref ))
		begin if (stats1.errors_RWSel == 0) stats1.errortime_RWSel = $time;
			stats1.errors_RWSel = stats1.errors_RWSel+1'b1; end

	end

   // add timeout after 100K cycles
   initial begin
     #1000000
     $display("TIMEOUT");
     $finish();
   end

endmodule
