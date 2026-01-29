`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13


module stimulus_gen (
    input clk,
    output logic [8:0]  Cur_PC,
    output logic [31:0] Imm,
    output logic        JalrSel,
    output logic        Branch,
    output logic [31:0] AluResult
);

    initial begin
        // Init
        Cur_PC <= '0; Imm <= '0; JalrSel <= 1'b0; Branch <= 1'b0; AluResult <= '0;

        // Directed: basic PC increments
        @(posedge clk); Cur_PC <= 9'd0;  Imm <= 32'sd16; Branch <= 1'b0; JalrSel <= 1'b0; AluResult <= 32'hAAAA_0001; // AluResult[0]=1 for branch select tests later
        @(posedge clk); Cur_PC <= 9'd4;  Imm <= -32'sd8; Branch <= 1'b0; JalrSel <= 1'b0;
        @(posedge clk); Cur_PC <= 9'd255; Imm <= 32'sd4; Branch <= 1'b0; JalrSel <= 1'b0;

        // Directed: Branch behavior depends on Branch && AluResult[0]
        // Case: Branch=1 but AluResult[0]=0 -> not taken
        @(posedge clk); Cur_PC <= 9'd100; Imm <= 32'sd20; Branch <= 1'b1; JalrSel <= 1'b0; AluResult <= 32'h1234_5678; // LSB 0
        // Case: Branch=1 and AluResult[0]=1 -> taken to PC_Imm
        @(posedge clk); Cur_PC <= 9'd100; Imm <= -32'sd12; Branch <= 1'b1; JalrSel <= 1'b0; AluResult <= 32'h1234_5679; // LSB 1

        // Directed: JALR selection overrides branch path; BrPC = AluResult
        @(posedge clk); Cur_PC <= 9'd5; Imm <= 32'sd100; Branch <= 1'b1; JalrSel <= 1'b1; AluResult <= 32'h8000_0100;

        // Randomized stress
        repeat (500) @(posedge clk) begin
            Cur_PC   <= $urandom_range(0, (1<<9)-1);
            Imm      <= $urandom;
            JalrSel  <= $urandom_range(0,1);
            Branch   <= $urandom_range(0,1);
            AluResult<= $urandom;
        end

        #1 $finish;
    end

endmodule

module tb();

    typedef struct packed {
        int errors;
        int errortime;
        int errors_PC_Imm;
        int errortime_PC_Imm;
        int errors_PC_Four;
        int errortime_PC_Four;
        int errors_BrPC;
        int errortime_BrPC;
        int errors_PcSel;
        int errortime_PcSel;

        int clocks;
    } stats;
    
    stats stats1;
    
    reg clk=0;
    initial forever
        #5 clk = ~clk;

    logic [8:0]  Cur_PC;
    logic [31:0] Imm;
    logic        JalrSel;
    logic        Branch;
    logic [31:0] AluResult;

    logic [31:0] PC_Imm_ref,  PC_Four_ref,  BrPC_ref;  logic PcSel_ref;
    logic [31:0] PC_Imm_dut,  PC_Four_dut,  BrPC_dut;  logic PcSel_dut;

    initial begin 
        $dumpfile("wave.vcd");
        $dumpvars(1, stim1.clk, tb_mismatch ,clk,Cur_PC,Imm,JalrSel,Branch,AluResult,PC_Imm_ref,PC_Imm_dut,PC_Four_ref,PC_Four_dut,BrPC_ref,BrPC_dut,PcSel_ref,PcSel_dut );
    end

    wire tb_match;      // Verification (vector compare)
    wire tb_mismatch = ~tb_match;
    assign tb_match = ( { PC_Imm_ref, PC_Four_ref, BrPC_ref, PcSel_ref } ===
                        ( { PC_Imm_ref, PC_Four_ref, BrPC_ref, PcSel_ref } ^ { PC_Imm_dut, PC_Four_dut, BrPC_dut, PcSel_dut } ^ { PC_Imm_ref, PC_Four_ref, BrPC_ref, PcSel_ref } ) );

    stimulus_gen stim1 (
        .clk,
        .Cur_PC,
        .Imm,
        .JalrSel,
        .Branch,
        .AluResult );

    RefModule good1 (
        .Cur_PC,
        .Imm,
        .JalrSel,
        .Branch,
        .AluResult,
        .PC_Imm(PC_Imm_ref),
        .PC_Four(PC_Four_ref),
        .BrPC(BrPC_ref),
        .PcSel(PcSel_ref) );
        
    TopModule top_module1 (
        .Cur_PC,
        .Imm,
        .JalrSel,
        .Branch,
        .AluResult,
        .PC_Imm(PC_Imm_dut),
        .PC_Four(PC_Four_dut),
        .BrPC(BrPC_dut),
        .PcSel(PcSel_dut) );

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
        if (PC_Imm_ref !== ( PC_Imm_ref ^ PC_Imm_dut ^ PC_Imm_ref )) begin
            if (stats1.errors_PC_Imm == 0) stats1.errortime_PC_Imm = $time; stats1.errors_PC_Imm++;
        end
        if (PC_Four_ref !== ( PC_Four_ref ^ PC_Four_dut ^ PC_Four_ref )) begin
            if (stats1.errors_PC_Four == 0) stats1.errortime_PC_Four = $time; stats1.errors_PC_Four++;
        end
        if (BrPC_ref !== ( BrPC_ref ^ BrPC_dut ^ BrPC_ref )) begin
            if (stats1.errors_BrPC == 0) stats1.errortime_BrPC = $time; stats1.errors_BrPC++;
        end
        if (PcSel_ref !== ( PcSel_ref ^ PcSel_dut ^ PcSel_ref )) begin
            if (stats1.errors_PcSel == 0) stats1.errortime_PcSel = $time; stats1.errors_PcSel++;
        end
    end

    final begin
        if (stats1.errors_PC_Imm)  $display("Hint: Output '%s' has %0d mismatches. First mismatch at %0d.", "PC_Imm",  stats1.errors_PC_Imm,  stats1.errortime_PC_Imm);  else $display("Hint: Output '%s' has no mismatches.", "PC_Imm");
        if (stats1.errors_PC_Four) $display("Hint: Output '%s' has %0d mismatches. First mismatch at %0d.", "PC_Four", stats1.errors_PC_Four, stats1.errortime_PC_Four); else $display("Hint: Output '%s' has no mismatches.", "PC_Four");
        if (stats1.errors_BrPC)    $display("Hint: Output '%s' has %0d mismatches. First mismatch at %0d.", "BrPC",    stats1.errors_BrPC,    stats1.errortime_BrPC);    else $display("Hint: Output '%s' has no mismatches.", "BrPC");
        if (stats1.errors_PcSel)   $display("Hint: Output '%s' has %0d mismatches. First mismatch at %0d.", "PcSel",   stats1.errors_PcSel,   stats1.errortime_PcSel);   else $display("Hint: Output '%s' has no mismatches.", "PcSel");

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


