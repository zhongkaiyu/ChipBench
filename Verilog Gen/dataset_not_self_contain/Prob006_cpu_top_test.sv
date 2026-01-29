`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13
`define WORD_SIZE 16

`define FUNC_ADD 6'd0
`define FUNC_SUB 6'd1
`define FUNC_AND 6'd2
`define FUNC_ORR 6'd3
`define FUNC_NOT 6'd4
`define FUNC_TCP 6'd5
`define FUNC_SHL 6'd6
`define FUNC_SHR 6'd7
`define FUNC_RWD 6'd27
`define FUNC_WWD 6'd28
`define FUNC_JPR 6'd25
`define FUNC_JRL 6'd26
`define FUNC_HLT 6'd29
`define FUNC_ENI 6'd30
`define FUNC_DSI 6'd31

`define OPCODE_ADI 4'd4
`define OPCODE_ORI 4'd5
`define OPCODE_LHI 4'd6
`define OPCODE_LWD 4'd7
`define OPCODE_SWD 4'd8
`define OPCODE_BNE 4'd0
`define OPCODE_BEQ 4'd1
`define OPCODE_BGZ 4'd2
`define OPCODE_BLZ 4'd3
`define OPCODE_JMP 4'd9
`define OPCODE_JAL 4'd10
`define OPCODE_R   4'd15


module stimulus_gen (
	input clk,
    // === Start your code here ===
	output reg reset_n,
	output reg inputReady,
	inout [`WORD_SIZE-1:0] data,
	input readM_ref,
	input readM_dut,
	input [`WORD_SIZE-1:0] address_ref,
	input [`WORD_SIZE-1:0] address_dut
    // === End your code here ===
);
	// === Start your code here ===
	reg [`WORD_SIZE-1:0] mem [0:65535];
	reg readM_ref_prev, readM_dut_prev;
	reg [`WORD_SIZE-1:0] data_out;
	reg driving;

	assign data = driving ? data_out : `WORD_SIZE'bz;

	initial begin
		integer i;
		for (i = 0; i < 65536; i = i + 1)
			mem[i] = '0;

		// Instruction program exercising arithmetic, branching, jumps, and WWD
		mem[0]  = {`OPCODE_ADI, 2'd0, 2'd1, 8'd5};        // R1 <- 5
		mem[1]  = {`OPCODE_ADI, 2'd0, 2'd2, 8'hFD};       // R2 <- -3
		mem[2]  = {`OPCODE_R,   2'd1, 2'd2, 2'd3, `FUNC_ADD}; // R3 <- R1 + R2 = 2
		mem[3]  = {`OPCODE_R,   2'd3, 2'd1, 2'd2, `FUNC_SUB}; // R2 <- R3 - R1 = -3 (consistency check)
		mem[4]  = {`OPCODE_R,   2'd3, 2'd1, 2'd3, `FUNC_ORR}; // R3 <- R3 | R1 = 7
		mem[5]  = {`OPCODE_R,   2'd3, 2'd0, 2'd0, `FUNC_WWD}; // Output R3
		mem[6]  = {`OPCODE_BEQ, 2'd3, 2'd3, 8'd3};        // Always taken -> jump to 9
		mem[7]  = {`OPCODE_ADI, 2'd0, 2'd1, 8'd99};       // Skipped when branch works
		mem[8]  = {`OPCODE_ADI, 2'd0, 2'd2, 8'd77};       // Skipped when branch works
		mem[9]  = {`OPCODE_LHI, 2'd0, 2'd1, 8'h12};       // R1 <- 0x1200
		mem[10] = {`OPCODE_ORI, 2'd1, 2'd1, 8'h34};       // R1 <- 0x1234
		mem[11] = {`OPCODE_R,   2'd1, 2'd0, 2'd0, `FUNC_WWD}; // Output R1
		mem[12] = {`OPCODE_JMP, 12'd9};                   // Loop within program

		// Example data memory locations for potential loads
		mem[256] = 16'hAAAA;
		mem[257] = 16'h5555;

		reset_n = 1'b0;
		inputReady = 1'b0;
		driving = 1'b0;
		readM_ref_prev = 1'b0;
		readM_dut_prev = 1'b0;
		data_out = '0;

		// Assert reset for a few cycles
		repeat (5) @(posedge clk);

		reset_n = 1'b1;

		// Allow CPU to execute for many cycles
		repeat (6000) @(posedge clk);

		// Pulse reset again to check restart behavior
		reset_n = 1'b0;
		repeat (4) @(posedge clk);
		reset_n = 1'b1;
		repeat (2000) @(posedge clk);

		#1 $finish;
	end

	always @(posedge clk) begin
		readM_ref_prev <= readM_ref;
		readM_dut_prev <= readM_dut;

		if (readM_ref && !readM_ref_prev) begin
			data_out <= mem[address_ref];
			driving <= 1'b1;
			inputReady <= 1'b1;
		end else if (readM_dut && !readM_dut_prev) begin
			data_out <= mem[address_dut];
			driving <= 1'b1;
			inputReady <= 1'b1;
		end else begin
			inputReady <= 1'b0;
			if (!readM_ref && !readM_dut)
				driving <= 1'b0;
		end
	end
	// === End your code here ===

endmodule


module tb();

	// === Start your code here ===
	typedef struct packed {
		int errors;
		int errortime;
		int errors_readM;
		int errortime_readM;
		int errors_address;
		int errortime_address;
		int errors_num_inst;
		int errortime_num_inst;
		int errors_output_port;
		int errortime_output_port;

		int clocks;
	} stats;
	// === End your code here ===

	stats stats1;

	wire[511:0] wavedrom_title;
	wire wavedrom_enable;
	int wavedrom_hide_after_time;

	reg clk = 0;
	initial forever #5 clk = ~clk;

	// === Start your code here ===
	logic reset_n;
	logic inputReady;
	wire [`WORD_SIZE-1:0] data;
	logic readM_ref;
	logic readM_dut;
	logic [`WORD_SIZE-1:0] address_ref;
	logic [`WORD_SIZE-1:0] address_dut;
	logic [`WORD_SIZE-1:0] num_inst_ref;
	logic [`WORD_SIZE-1:0] num_inst_dut;
	logic [`WORD_SIZE-1:0] output_port_ref;
	logic [`WORD_SIZE-1:0] output_port_dut;
	// === End your code here ===

	initial begin
		$dumpfile("wave.vcd");
		// === Start your code here ===
		$dumpvars(1, stim1.clk, tb_mismatch, clk, reset_n, inputReady, readM_ref, readM_dut, address_ref, address_dut, data, num_inst_ref, num_inst_dut, output_port_ref, output_port_dut);
		// === End your code here ===
	end

	wire tb_match;
	wire tb_mismatch = ~tb_match;

	// === Start your code here ===
	stimulus_gen stim1 (
		.clk(clk),
		.reset_n(reset_n),
		.inputReady(inputReady),
		.data(data),
		.readM_ref(readM_ref),
		.readM_dut(readM_dut),
		.address_ref(address_ref),
		.address_dut(address_dut)
	);

	RefModule good1 (
		.clk(clk),
		.reset_n(reset_n),
		.inputReady(inputReady),
		.data(data),
		.readM(readM_ref),
		.address(address_ref),
		.num_inst(num_inst_ref),
		.output_port(output_port_ref)
	);

	TopModule top_module1 (
		.clk(clk),
		.reset_n(reset_n),
		.inputReady(inputReady),
		.data(data),
		.readM(readM_dut),
		.address(address_dut),
		.num_inst(num_inst_dut),
		.output_port(output_port_dut)
	);
	// === End your code here ===


	bit strobe = 0;
	task wait_for_end_of_timestep;
		repeat (5) begin
			strobe <= !strobe;
			@(strobe);
		end
	endtask

	initial stats1 = '{default:0};

	final begin
		// === Start your code here ===
		if (stats1.errors_readM)
			$display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "readM", stats1.errors_readM, stats1.errortime_readM);
		else
			$display("Hint: Output '%s' has no mismatches.", "readM");

		if (stats1.errors_address)
			$display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "address", stats1.errors_address, stats1.errortime_address);
		else
			$display("Hint: Output '%s' has no mismatches.", "address");

		if (stats1.errors_num_inst)
			$display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "num_inst", stats1.errors_num_inst, stats1.errortime_num_inst);
		else
			$display("Hint: Output '%s' has no mismatches.", "num_inst");

		if (stats1.errors_output_port)
			$display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "output_port", stats1.errors_output_port, stats1.errortime_output_port);
		else
			$display("Hint: Output '%s' has no mismatches.", "output_port");
		// === End your code here ===

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end

	assign tb_match = ({readM_ref, address_ref, num_inst_ref, output_port_ref} ===
		({readM_ref, address_ref, num_inst_ref, output_port_ref} ^
		 {readM_dut, address_dut, num_inst_dut, output_port_dut} ^
		 {readM_ref, address_ref, num_inst_ref, output_port_ref}));

	always @(posedge clk, negedge clk) begin
		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0)
				stats1.errortime = $time;
			stats1.errors++;
		end

		// === Start your code here ===
		if (readM_ref !== (readM_ref ^ readM_dut ^ readM_ref)) begin
			if (stats1.errors_readM == 0)
				stats1.errortime_readM = $time;
			stats1.errors_readM++;
		end

		if (address_ref !== (address_ref ^ address_dut ^ address_ref)) begin
			if (stats1.errors_address == 0)
				stats1.errortime_address = $time;
			stats1.errors_address++;
		end

		if (num_inst_ref !== (num_inst_ref ^ num_inst_dut ^ num_inst_ref)) begin
			if (stats1.errors_num_inst == 0)
				stats1.errortime_num_inst = $time;
			stats1.errors_num_inst++;
		end

		if (output_port_ref !== (output_port_ref ^ output_port_dut ^ output_port_ref)) begin
			if (stats1.errors_output_port == 0)
				stats1.errortime_output_port = $time;
			stats1.errors_output_port++;
		end
		// === End your code here ===
	end

	initial begin
		#1000000;
		$display("TIMEOUT");
		$finish();
	end

endmodule

