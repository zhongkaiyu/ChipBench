`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13


module stimulus_gen (
	input clk,
    // === Start your code here ===
	output logic rst_n,
	output logic read_en,
	output logic write_en,
	output logic [7:0] read_addr,
	output logic [7:0] write_addr,
	output logic [3:0] write_data
    // === End your code here ===
);
	// === Start your code here ===
    initial begin
		rst_n <= 0;
		read_en <= 0;
		write_en <= 0;
		read_addr <= 0;
		write_addr <= 0;
		write_data <= 0;
		
		// Reset sequence
		@(posedge clk);
		@(posedge clk);
		rst_n <= 1;
		@(posedge clk);
		
		// Test basic write operations
		write_en <= 1;
		write_addr <= 0;
		write_data <= 4'b1010;
		@(posedge clk);
		
		write_addr <= 1;
		write_data <= 4'b0101;
		@(posedge clk);
		
		write_addr <= 2;
		write_data <= 4'b1111;
		@(posedge clk);
		
		write_en <= 0;
		@(posedge clk);
		
		// Test basic read operations
		read_en <= 1;
		read_addr <= 0;
		@(posedge clk); // 1010
		
		read_addr <= 1;
		@(posedge clk); // 0101
		
		read_addr <= 2;
		@(posedge clk); // 1111
		
		read_en <= 0;
		@(posedge clk);
		
		// Test simultaneous read and write
		read_en <= 1;
		write_en <= 1;
		read_addr <= 0;
		write_addr <= 3;
		write_data <= 4'b1100;
		@(posedge clk);
		
		read_addr <= 1;
		write_addr <= 4;
		write_data <= 4'b0011;
		@(posedge clk);
		
		read_en <= 0;
		write_en <= 0;
		@(posedge clk);
		
		// Random test sequence
		repeat(200) @(posedge clk) begin
			read_en <= $random & 1;
			write_en <= $random & 1;
			read_addr <= $random & 7;  // Only use addresses 0-7 for depth 8
			write_addr <= $random & 7;
			write_data <= $random & 15; // 4-bit data
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
		int errors_read_data;
		int errortime_read_data;

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
	logic read_en;
	logic write_en;
	logic [7:0] read_addr;
	logic [7:0] write_addr;
	logic [3:0] write_data;
	logic [3:0] read_data_ref;
	logic [3:0] read_data_dut;
	// === End your code here ===

	initial begin 
		$dumpfile("wave.vcd");
		// === Start your code here ===
		$dumpvars(1, stim1.clk, tb_mismatch, clk, rst_n, read_en, write_en, read_addr, write_addr, write_data, read_data_ref, read_data_dut);
		// === End your code here ===
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	// === Start your code here ===
	stimulus_gen stim1 (
		.clk,
		.rst_n,
		.read_en,
		.write_en,
		.read_addr,
		.write_addr,
		.write_data
	);
		
	RefModule good1 (
		.clk,
		.rst_n,
		.write_en,
		.write_addr,
		.write_data,
		.read_en,
		.read_addr,
		.read_data(read_data_ref)
	);
		
	TopModule top_module1 (
		.clk,
		.rst_n,
		.read_en,
		.write_en,
		.read_addr,
		.write_addr,
		.write_data,
		.read_data(read_data_dut)
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
		if (stats1.errors_read_data) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "read_data", stats1.errors_read_data, stats1.errortime_read_data);
		else $display("Hint: Output '%s' has no mismatches.", "read_data");
        // === End your code here ===

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { read_data_ref } === ( { read_data_ref } ^ { read_data_dut } ^ { read_data_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		// === Start your code here ===
		if (read_data_ref !== ( read_data_ref ^ read_data_dut ^ read_data_ref ))
		begin if (stats1.errors_read_data == 0) stats1.errortime_read_data = $time;
			stats1.errors_read_data = stats1.errors_read_data+1'b1; end
         // === End your code here ===

	end

   // add timeout after 100K cycles
   initial begin
     #1000000
     $display("TIMEOUT");
     $finish();
   end

endmodule
