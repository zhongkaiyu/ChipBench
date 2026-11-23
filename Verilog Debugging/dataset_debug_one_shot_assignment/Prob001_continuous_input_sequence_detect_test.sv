`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13
`default_nettype none

module stimulus_gen (
    input wire clk,
    output reg rst_n,
    output reg a,
    input wire tb_match,
    input wire match_dut
);
    bit failed = 0;
    // additional check stimulus vectors (applied left to right)
    localparam bit [13:0] OVL_BITS = 14'b01110001110001;
    localparam bit [6:0]  PRE_BITS = 7'b0111000;
    bit ovl [14];
    bit pre [7];
    initial begin
        for (int i = 0; i < 14; i++) ovl[i] = OVL_BITS[13-i];
        for (int i = 0; i < 7; i++)  pre[i] = PRE_BITS[6-i];
    end

    always @(posedge clk, negedge clk)
        if (!tb_match)
            failed <= 1;

    initial begin
        @(posedge clk);
        failed <= 0;
        rst_n <= 0;
        a <= 0;

        // Initial reset
        @(posedge clk);
        rst_n <= 1;

        // Test Case 1: No match
        @(posedge clk) a <= 0;
        @(posedge clk) a <= 1;
        @(posedge clk) a <= 1;
        @(posedge clk) a <= 0;
        @(posedge clk) a <= 1;
        @(posedge clk) a <= 0;
        @(posedge clk) a <= 0;
        @(posedge clk) a <= 0;

        // Test Case 2: Matching sequence (0111_0001)
        @(posedge clk) a <= 0;
        @(posedge clk) a <= 1;
        @(posedge clk) a <= 1;
        @(posedge clk) a <= 1;
        @(posedge clk) a <= 0;
        @(posedge clk) a <= 0;
        @(posedge clk) a <= 0;
        @(posedge clk) a <= 1;

        // Test Case 3: Randomized input
        repeat (100) @(posedge clk) begin
            a <= $random;
        end

        // Test Case 4: Edge cases with reset
        @(posedge clk);
        rst_n <= 0;
        @(posedge clk);
        rst_n <= 1;
        repeat (8) @(posedge clk) a <= 1;

        // Add delay to observe outputs
        repeat (100) @(posedge clk);

        // Additional checks, added after all original stimulus:
        // (1) overlapping occurrences: the spec asserts match whenever a_tem equals 8'b0111_0001,
        //     so 0111_0001_110001 must give two matches six cycles apart.
        foreach (ovl[i]) @(posedge clk) a <= ovl[i];
        repeat (10) @(posedge clk) a <= 1;
        // (2) reset clears a_tem: shift in the first seven pattern bits, reset (match is 0 and a_tem is
        //     not the pattern when rst_n falls), then shift the last pattern bit. A cleared a_tem holds
        //     8'b0000_0001 (no match); an uncleared one would complete the pattern.
        foreach (pre[i]) @(posedge clk) a <= pre[i];
        @(posedge clk) begin rst_n <= 0; a <= 1; end
        @(posedge clk) rst_n <= 1;
        repeat (12) @(posedge clk) a <= 1;
        // (3) long random run (more pattern occurrences than the original 100 random bits).
        repeat (3000) @(posedge clk) a <= $urandom;
        repeat (10) @(posedge clk) a <= 0;

        #1 $finish;
    end
endmodule

module tb();

    typedef struct packed {
        int errors;
        int errortime;
        int errors_match;
        int errortime_match;

        int clocks;
    } stats;

    stats stats1;

    wire [511:0] wavedrom_title;
    wire wavedrom_enable;
    int wavedrom_hide_after_time;

    reg clk = 0;
    initial forever #5 clk = ~clk;

    logic rst_n;
    logic a;
    logic match_ref;
    logic match_dut;

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(1, stim1.clk, tb_mismatch, clk, rst_n, a, match_ref, match_dut);
    end

    wire tb_match;  // Verification
    wire tb_mismatch = ~tb_match;

    stimulus_gen stim1 (
        .clk(clk),
        .rst_n(rst_n),
        .a(a),
        .tb_match(tb_match),
        .match_dut(match_dut)
    );

    RefModule good1 (
        .clk(clk),
        .rst_n(rst_n),
        .a(a),
        .match(match_ref)
    );

    TopModule top_module1 (
        .clk(clk),
        .rst_n(rst_n),
        .a(a),
        .match(match_dut)
    );

    bit strobe = 0;
    task wait_for_end_of_timestep;
        repeat (5) begin
            strobe <= !strobe;  // Try to delay until the very end of the time step.
            @(strobe);
        end
    endtask

    final begin
        if (stats1.errors_match) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "match", stats1.errors_match, stats1.errortime_match);
        else $display("Hint: Output '%s' has no mismatches.", "match");

        $display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
        $display("Simulation finished at %0d ps", $time);
        $display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
    end

    // Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
    assign tb_match = (
        {match_ref} ===
        ({match_ref} ^ {match_dut} ^ {match_ref})
    );

    always @(posedge clk, negedge clk) begin
        stats1.clocks++;
        if (!tb_match) begin
            if (stats1.errors == 0) stats1.errortime = $time;
            stats1.errors++;
        end
        if (match_ref !== (match_ref ^ match_dut ^ match_ref)) begin
            if (stats1.errors_match == 0) stats1.errortime_match = $time;
            stats1.errors_match++;
        end
    end

    // Add timeout after 100K cycles
    initial begin
        #1000000
        $display("TIMEOUT");
        $finish();
    end

endmodule