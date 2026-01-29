`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13


module stimulus_gen (
    input clk,
    output logic [31:0] SrcA,
    output logic [31:0] SrcB,
    output logic [3:0] Operation
);


// Add two ports to module stimulus_gen:
//    output [511:0] wavedrom_title
//    output reg wavedrom_enable



    initial begin
        // Directed sweep of opcodes with representative operands
        SrcA <= 32'h8000_0001; // negative with LSB 1
        SrcB <= 32'h0000_001f; // cover max logical shift amount 31
        Operation <= 4'h0;
            @(posedge clk) Operation <= 4'h0;   // AND
            @(posedge clk) Operation <= 4'h1;   // OR
            @(posedge clk) Operation <= 4'h2;   // ADD
            @(posedge clk) Operation <= 4'h3;   // XOR (exists in RefModule)
            @(posedge clk) Operation <= 4'h4;   // SLL
            @(posedge clk) Operation <= 4'h5;   // SRL
            @(posedge clk) Operation <= 4'h6;   // SUB
            @(posedge clk) Operation <= 4'h7;   // SRA
            @(posedge clk) Operation <= 4'h8;   // EQ
            @(posedge clk) Operation <= 4'h9;   // NE
            @(posedge clk) Operation <= 4'hA;   // ALWAYS TRUE (jal)
            @(posedge clk) Operation <= 4'hC;   // SLT
            @(posedge clk) Operation <= 4'hD;   // SGE
            @(posedge clk) Operation <= 4'hE;   // SLTU
            @(posedge clk) Operation <= 4'hF;   // SGEU

        // Additional directed tests for shifts and signedness
        @(posedge clk) begin
            SrcA <= 32'hffff_fffe; // -2
            SrcB <= 32'h0000_0001; // shift by 1
            Operation <= 4'h7;     // SRA should replicate sign
        end
        @(posedge clk) begin
            SrcA <= 32'h7fff_ffff; // largest positive
            SrcB <= 32'h0000_0001;
            Operation <= 4'h5;     // SRL should zero-fill
        end
        @(posedge clk) begin
            SrcA <= 32'hffff_ffff; // -1
            SrcB <= 32'h0000_001f; // shift by 31
            Operation <= 4'h4;     // SLL
        end

        // Randomized testing
        repeat(1000) @(posedge clk) begin
            SrcA <= $urandom;
            SrcB <= $urandom;
            // Bias ops toward all supported encodings seen in RefModule
            unique case ($urandom_range(0,14))
                0: Operation <= 4'h0; // AND
                1: Operation <= 4'h1; // OR
                2: Operation <= 4'h2; // ADD
                3: Operation <= 4'h3; // XOR
                4: Operation <= 4'h4; // SLL
                5: Operation <= 4'h5; // SRL
                6: Operation <= 4'h6; // SUB
                7: Operation <= 4'h7; // SRA
                8: Operation <= 4'h8; // EQ
                9: Operation <= 4'h9; // NE
                10: Operation <= 4'hA; // ALWAYS TRUE
                11: Operation <= 4'hC; // SLT
                12: Operation <= 4'hD; // SGE
                13: Operation <= 4'hE; // SLTU
                14: Operation <= 4'hF; // SGEU
            endcase
        end

        #1 $finish;
    end

endmodule

module tb();

    typedef struct packed {
        int errors;
        int errortime;
        int errors_ALUResult;
        int errortime_ALUResult;

        int clocks;
    } stats;
    
    stats stats1;
    
    
    wire[511:0] wavedrom_title;
    wire wavedrom_enable;
    int wavedrom_hide_after_time;
    
    reg clk=0;
    initial forever
        #5 clk = ~clk;

    logic [31:0] SrcA;
    logic [31:0] SrcB;
    logic [3:0] Operation;
    logic [31:0] ALUResult_ref;
    logic [31:0] ALUResult_dut;

    initial begin 
        $dumpfile("wave.vcd");
        $dumpvars(1, stim1.clk, tb_mismatch ,clk,SrcA,SrcB,Operation,ALUResult_ref,ALUResult_dut );
    end


    wire tb_match;      // Verification
    wire tb_mismatch = ~tb_match;
    
    stimulus_gen stim1 (
        .clk,
        .*,
        .SrcA,
        .SrcB,
        .Operation );
    RefModule good1 (
        .SrcA,
        .SrcB,
        .Operation,
        .ALUResult(ALUResult_ref) );
        
    TopModule top_module1 (
        .SrcA,
        .SrcB,
        .Operation,
        .ALUResult(ALUResult_dut) );

    
    bit strobe = 0;
    task wait_for_end_of_timestep;
        repeat(5) begin
            strobe <= !strobe;  // Try to delay until the very end of the time step.
            @(strobe);
        end
    endtask 

    
    final begin
        if (stats1.errors_ALUResult) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "ALUResult", stats1.errors_ALUResult, stats1.errortime_ALUResult);
        else $display("Hint: Output '%s' has no mismatches.", "ALUResult");

        $display("Hint: Total mismatched samples is %1d out of %1d samples\n", stats1.errors, stats1.clocks);
        $display("Simulation finished at %0d ps", $time);
        $display("Mismatches: %1d in %1d samples", stats1.errors, stats1.clocks);
    end
    
    // Verification: XORs on the right makes any X in good_vector match anything, but X in dut_vector will only match X.
    assign tb_match = ( { ALUResult_ref } === ( { ALUResult_ref } ^ { ALUResult_dut } ^ { ALUResult_ref } ) );
    // Use explicit sensitivity list here. @(*) causes NetProc::nex_input() to be called when trying to compute
    // the sensitivity list of the @(strobe) process, which isn't implemented.
    always @(posedge clk, negedge clk) begin

        stats1.clocks++;
        if (!tb_match) begin
            if (stats1.errors == 0) stats1.errortime = $time;
            stats1.errors++;
        end
        if (ALUResult_ref !== ( ALUResult_ref ^ ALUResult_dut ^ ALUResult_ref ))
        begin if (stats1.errors_ALUResult == 0) stats1.errortime_ALUResult = $time;
            stats1.errors_ALUResult = stats1.errors_ALUResult+1'b1; end

    end

   // add timeout after 100K cycles
   initial begin
     #1000000
     $display("TIMEOUT");
     $finish();
   end

endmodule


