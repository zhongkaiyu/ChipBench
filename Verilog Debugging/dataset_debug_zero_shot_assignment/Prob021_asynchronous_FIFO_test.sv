`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13


module stimulus_gen (
	input clk,
    // === Start your code here ===
	output logic wclk,
	output logic rclk,
	output logic wrstn,
	output logic rrstn,
	output logic winc,
	output logic rinc,
	output logic [7:0] wdata
    // === End your code here ===
);
	// === Start your code here ===
	reg wclk_reg = 0;
	reg rclk_reg = 0;
	assign wclk = wclk_reg;
	assign rclk = rclk_reg;
	
	initial forever #10 wclk_reg = ~wclk_reg;  // 50MHz write clock
	initial forever #15 rclk_reg = ~rclk_reg; // 33.3MHz read clock
	
	initial begin
		wrstn = 0;
		rrstn = 0;
		winc = 0;
		rinc = 0;
		wdata = 0;
		repeat(20) @(posedge wclk); @(posedge rclk);
		wrstn = 1;
		rrstn = 1;
		@(posedge wclk); @(posedge rclk);
		
		// Test basic write and read operations
		winc = 1;
		wdata = 8'hAA; @(posedge wclk); 
		wdata = 8'h55; @(posedge wclk); 
		wdata = 8'h33; @(posedge wclk);
		wdata = 8'hCC; @(posedge wclk);
		winc = 0;
		@(posedge wclk);
		
		// Test read operations
		rinc = 1;
		repeat(4) @(posedge rclk);
		rinc = 0;
		@(posedge rclk);
		
		// Test simultaneous write and read
		winc = 1;
		rinc = 1;
		wdata = 8'h11; @(posedge wclk); @(posedge rclk);
		wdata = 8'h22; @(posedge wclk); @(posedge rclk);
		wdata = 8'h44; @(posedge wclk); @(posedge rclk);
		wdata = 8'h88; @(posedge wclk); @(posedge rclk);
		winc = 0;
		rinc = 0;
		@(posedge wclk);
		
		// Test FIFO full condition
		winc = 1;
		wdata = 8'hF0; @(posedge wclk);
		wdata = 8'hF1; @(posedge wclk);
		wdata = 8'hF2; @(posedge wclk);
		wdata = 8'hF3; @(posedge wclk);
		wdata = 8'hF4; @(posedge wclk);
		wdata = 8'hF5; @(posedge wclk);
		wdata = 8'hF6; @(posedge wclk);
		wdata = 8'hF7; @(posedge wclk);
		wdata = 8'hF8; @(posedge wclk);
		wdata = 8'hF9; @(posedge wclk);
		wdata = 8'hFA; @(posedge wclk);
		wdata = 8'hFB; @(posedge wclk);
		wdata = 8'hFC; @(posedge wclk);
		wdata = 8'hFD; @(posedge wclk);
		wdata = 8'hFE; @(posedge wclk);
		wdata = 8'hFF; @(posedge wclk);
		winc = 0;
		@(posedge wclk);
		
		// Test FIFO empty condition
		rinc = 1;
		repeat(20) @(posedge rclk); // Should trigger rempty
		rinc = 0;
		@(posedge rclk);
		
		// Random testing
		repeat(200) @(posedge wclk, posedge rclk) begin
			winc <= $random;
			rinc <= $random;
			wdata <= $random % 256;
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
		int errors_wfull;
		int errortime_wfull;
		int errors_rempty;
		int errortime_rempty;
		int errors_rdata;
		int errortime_rdata;

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
	logic wclk;
	logic rclk;
	logic wrstn;
	logic rrstn;
	logic winc;
	logic rinc;
	logic [7:0] wdata;
	logic wfull_ref;
	logic rempty_ref;
	logic [7:0] rdata_ref;
	logic wfull_dut;
	logic rempty_dut;
	logic [7:0] rdata_dut;
	// === End your code here ===

	initial begin 
		$dumpfile("wave.vcd");
		// === Start your code here ===
		$dumpvars(1, stim1.clk, tb_mismatch, clk, wclk, rclk, wrstn, rrstn, winc, rinc, wdata, wfull_ref, rempty_ref, rdata_ref, wfull_dut, rempty_dut, rdata_dut );
		// === End your code here ===
	end


	wire tb_match;		// Verification
	wire tb_mismatch = ~tb_match;
	
	// === Start your code here ===
	stimulus_gen stim1 (
		.clk,
		.wclk,
		.rclk,
		.wrstn,
		.rrstn,
		.winc,
		.rinc,
		.wdata );
		
	RefModule good1 (
		.wclk,
		.rclk,
		.wrstn,
		.rrstn,
		.winc,
		.rinc,
		.wdata,
		.wfull(wfull_ref),
		.rempty(rempty_ref),
		.rdata(rdata_ref) );
		
	TopModule top_module1 (
		.wclk,
		.rclk,
		.wrstn,
		.rrstn,
		.winc,
		.rinc,
		.wdata,
		.wfull(wfull_dut),
		.rempty(rempty_dut),
		.rdata(rdata_dut) );
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
		if (stats1.errors_wfull) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "wfull", stats1.errors_wfull, stats1.errortime_wfull);
		else $display("Hint: Output '%s' has no mismatches.", "wfull");
		if (stats1.errors_rempty) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "rempty", stats1.errors_rempty, stats1.errortime_rempty);
		else $display("Hint: Output '%s' has no mismatches.", "rempty");
		if (stats1.errors_rdata) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "rdata", stats1.errors_rdata, stats1.errortime_rdata);
		else $display("Hint: Output '%s' has no mismatches.", "rdata");
        // === End your code here ===

		$display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
		$display("Simulation finished at %0d ps", $time);
		$display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
	end
	
	// Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
	assign tb_match = ( { wfull_ref, rempty_ref, rdata_ref } === ( { wfull_ref, rempty_ref, rdata_ref } ^ { wfull_dut, rempty_dut, rdata_dut } ^ { wfull_ref, rempty_ref, rdata_ref } ) );
	// Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
	// the sensitivity list of the @(strobe) process, which isn't implemented.
	always @(posedge clk, negedge clk) begin

		stats1.clocks++;
		if (!tb_match) begin
			if (stats1.errors == 0) stats1.errortime = $time;
			stats1.errors++;
		end
		// === Start your code here ===
		if (wfull_ref !== ( wfull_ref ^ wfull_dut ^ wfull_ref ))
		begin if (stats1.errors_wfull == 0) stats1.errortime_wfull = $time;
			stats1.errors_wfull = stats1.errors_wfull+1'b1; end
		if (rempty_ref !== ( rempty_ref ^ rempty_dut ^ rempty_ref ))
		begin if (stats1.errors_rempty == 0) stats1.errortime_rempty = $time;
			stats1.errors_rempty = stats1.errors_rempty+1'b1; end
		if (rdata_ref !== ( rdata_ref ^ rdata_dut ^ rdata_ref ))
		begin if (stats1.errors_rdata == 0) stats1.errortime_rdata = $time;
			stats1.errors_rdata = stats1.errors_rdata+1'b1; end
         // === End your code here ===

	end

   // add timeout after 100K cycles
   initial begin
     #1000000
     $display("TIMEOUT");
     $finish();
   end

endmodule
