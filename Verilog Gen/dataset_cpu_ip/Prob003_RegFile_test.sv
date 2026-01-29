`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13

module stimulus_gen (
    input clk,
    output logic        rst,
    output logic        rg_wrt_en,
    output logic [4:0]  rg_wrt_dest,
    output logic [4:0]  rg_rd_addr1,
    output logic [4:0]  rg_rd_addr2,
    output logic [31:0] rg_wrt_data
);

    initial begin
        // Initialize
        rst <= 1'b1; rg_wrt_en <= 1'b0; rg_wrt_dest <= '0; rg_rd_addr1 <= '0; rg_rd_addr2 <= '0; rg_wrt_data <= '0;

        @(posedge clk); rst <= 1'b0;

        // After reset, all registers should be zero; probe a few
        @(posedge clk); rg_rd_addr1 <= 5'd0; rg_rd_addr2 <= 5'd31;
        @(posedge clk); rg_rd_addr1 <= 5'd1; rg_rd_addr2 <= 5'd2;

        // Write to a register and read it on subsequent cycles
        @(posedge clk); rg_wrt_en <= 1'b1; rg_wrt_dest <= 5'd3; rg_wrt_data <= 32'hDEADBEEF;
        // Same-cycle read-during-write should return old value (pre-write)
        rg_rd_addr1 <= 5'd3; rg_rd_addr2 <= 5'd0;
        @(posedge clk); rg_wrt_en <= 1'b0; // now value becomes visible
        rg_rd_addr1 <= 5'd3; rg_rd_addr2 <= 5'd31;

        // Multiple writes
        @(posedge clk); rg_wrt_en <= 1'b1; rg_wrt_dest <= 5'd10; rg_wrt_data <= 32'h12345678; rg_rd_addr1 <= 5'd10; rg_rd_addr2 <= 5'd3;
        @(posedge clk); rg_wrt_en <= 1'b1; rg_wrt_dest <= 5'd31; rg_wrt_data <= 32'hCAFEBABE; rg_rd_addr1 <= 5'd31; rg_rd_addr2 <= 5'd10;
        @(posedge clk); rg_wrt_en <= 1'b0; rg_rd_addr1 <= 5'd31; rg_rd_addr2 <= 5'd10;

        // Read-after-write same cycle to different ports
        @(posedge clk); rg_wrt_en <= 1'b1; rg_wrt_dest <= 5'd15; rg_wrt_data <= 32'h0; rg_rd_addr1 <= 5'd15; rg_rd_addr2 <= 5'd15;
        @(posedge clk); rg_wrt_en <= 1'b0; rg_rd_addr1 <= 5'd15; rg_rd_addr2 <= 5'd15;

        // Randomized stress
        repeat (500) @(posedge clk) begin
            // randomize write enable with ~25% probability
            rg_wrt_en   <= ($urandom & 8'h3) == 0;
            rg_wrt_dest <= $urandom_range(0,31);
            rg_wrt_data <= $urandom;
            rg_rd_addr1 <= $urandom_range(0,31);
            rg_rd_addr2 <= $urandom_range(0,31);
        end

        #1 $finish;
    end

endmodule

module tb();

    typedef struct packed {
        int errors;
        int errortime;
        int errors_rd1;
        int errortime_rd1;
        int errors_rd2;
        int errortime_rd2;

        int clocks;
    } stats;
    
    stats stats1;
    
    reg clk=0;
    initial forever
        #5 clk = ~clk;

    logic        rst;
    logic        rg_wrt_en;
    logic [4:0]  rg_wrt_dest;
    logic [4:0]  rg_rd_addr1;
    logic [4:0]  rg_rd_addr2;
    logic [31:0] rg_wrt_data;

    logic [31:0] rg_rd_data1_ref;
    logic [31:0] rg_rd_data2_ref;
    logic [31:0] rg_rd_data1_dut;
    logic [31:0] rg_rd_data2_dut;

    initial begin 
        $dumpfile("wave.vcd");
        $dumpvars(1, stim1.clk, tb_mismatch ,clk,rst,rg_wrt_en,rg_wrt_dest,rg_rd_addr1,rg_rd_addr2,rg_wrt_data,rg_rd_data1_ref,rg_rd_data2_ref,rg_rd_data1_dut,rg_rd_data2_dut );
    end

    wire tb_match;      // Verification
    wire tb_mismatch = ~tb_match;
    assign tb_match = ( { rg_rd_data1_ref, rg_rd_data2_ref } ===
                        ( { rg_rd_data1_ref, rg_rd_data2_ref } ^ { rg_rd_data1_dut, rg_rd_data2_dut } ^ { rg_rd_data1_ref, rg_rd_data2_ref } ) );

    stimulus_gen stim1 (
        .clk,
        .rst,
        .rg_wrt_en,
        .rg_wrt_dest,
        .rg_rd_addr1,
        .rg_rd_addr2,
        .rg_wrt_data );

    RefModule good1 (
        .clk,
        .rst,
        .rg_wrt_en,
        .rg_wrt_dest,
        .rg_rd_addr1,
        .rg_rd_addr2,
        .rg_wrt_data,
        .rg_rd_data1(rg_rd_data1_ref),
        .rg_rd_data2(rg_rd_data2_ref) );
        
    TopModule top_module1 (
        .clk,
        .rst,
        .rg_wrt_en,
        .rg_wrt_dest,
        .rg_rd_addr1,
        .rg_rd_addr2,
        .rg_wrt_data,
        .rg_rd_data1(rg_rd_data1_dut),
        .rg_rd_data2(rg_rd_data2_dut) );

    bit strobe = 0;
    task wait_for_end_of_timestep;
        repeat(5) begin
            strobe <= !strobe;  // Try to delay until the very end of the time step.
            @(strobe);
        end
    endtask 

    always @(posedge clk, negedge clk) begin
        stats1.clocks++;
        if (!tb_match) begin
            if (stats1.errors == 0) stats1.errortime = $time;
            stats1.errors++;
        end
        if (rg_rd_data1_ref !== ( rg_rd_data1_ref ^ rg_rd_data1_dut ^ rg_rd_data1_ref )) begin
            if (stats1.errors_rd1 == 0) stats1.errortime_rd1 = $time;
            stats1.errors_rd1 = stats1.errors_rd1 + 1'b1;
        end
        if (rg_rd_data2_ref !== ( rg_rd_data2_ref ^ rg_rd_data2_dut ^ rg_rd_data2_ref )) begin
            if (stats1.errors_rd2 == 0) stats1.errortime_rd2 = $time;
            stats1.errors_rd2 = stats1.errors_rd2 + 1'b1;
        end
    end

    final begin
        if (stats1.errors_rd1) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "rg_rd_data1", stats1.errors_rd1, stats1.errortime_rd1);
        else $display("Hint: Output '%s' has no mismatches.", "rg_rd_data1");
        if (stats1.errors_rd2) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "rg_rd_data2", stats1.errors_rd2, stats1.errortime_rd2);
        else $display("Hint: Output '%s' has no mismatches.", "rg_rd_data2");

        $display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
        $display("Simulation finished at %0d ps", $time);
        $display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
    end

    // add timeout after 100K cycles
    initial begin
        #1000000
        $display("TIMEOUT");
        $finish();
    end

endmodule


