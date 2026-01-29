`timescale 1 ps/1 ps
`define OK 12
`define INCORRECT 13


module stimulus_gen (
    input clk,
    output logic [1:0] ALUOp,
    output logic [6:0] Funct7,
    output logic [2:0] Funct3
);

    task drive(input [1:0] aluop, input [2:0] f3, input [6:0] f7);
        begin
            ALUOp <= aluop; Funct3 <= f3; Funct7 <= f7;
            @(posedge clk);
        end
    endtask

    initial begin
        ALUOp <= 2'b00; Funct3 <= 3'b000; Funct7 <= 7'b0000000;

        // ALUOp=00 -> ADD regardless of functs
        drive(2'b00, 3'b000, 7'b0000000);
        drive(2'b00, 3'b101, 7'b0100000);

        // Branch class ALUOp=01 (BEQ/BNE/BLT/BGE/BLTU/BGEU)
        drive(2'b01, 3'b000, 7'b0000000); // BEQ
        drive(2'b01, 3'b001, 7'b0000000); // BNE
        drive(2'b01, 3'b100, 7'b0000000); // BLT
        drive(2'b01, 3'b101, 7'b0000000); // BGE
        drive(2'b01, 3'b110, 7'b0000000); // BLTU
        drive(2'b01, 3'b111, 7'b0000000); // BGEU

        // R/I class ALUOp=10 covering all Funct3/Funct7 combos
        // ADD/SUB
        drive(2'b10, 3'b000, 7'b0000000); // ADD/ADDI
        drive(2'b10, 3'b000, 7'b0100000); // SUB
        // AND/OR/XOR
        drive(2'b10, 3'b111, 7'b0000000); // AND/ANDI
        drive(2'b10, 3'b110, 7'b0000000); // OR/ORI
        drive(2'b10, 3'b100, 7'b0000000); // XOR/XORI
        // Shifts
        drive(2'b10, 3'b001, 7'b0000000); // SLL/SLLI
        drive(2'b10, 3'b101, 7'b0000000); // SRL/SRLI
        drive(2'b10, 3'b101, 7'b0100000); // SRA/SRAI
        // Set-less-than
        drive(2'b10, 3'b010, 7'b0000000); // SLT/SLTI
        drive(2'b10, 3'b011, 7'b0000000); // SLTU/SLTIU

        // Jumps/LUI group ALUOp=11 -> ALWAYS_TRUE in our encoding
        drive(2'b11, 3'b000, 7'b0000000);
        drive(2'b11, 3'b101, 7'b0100000);

        // Random sweep
        repeat (500) begin
            ALUOp  <= $urandom_range(0,3);
            Funct3 <= $urandom_range(0,7);
            // Only two legal values of Funct7 for the ambiguous fields (0000000 or 0100000);
            // pick randomly between them, otherwise use random for variety.
            if (Funct3 == 3'b101 || Funct3 == 3'b000)
                Funct7 <= ($urandom & 1) ? 7'b0100000 : 7'b0000000;
            else
                Funct7 <= $urandom;
            @(posedge clk);
        end

        #1 $finish;
    end

endmodule

module tb();

    typedef struct packed {
        int errors;
        int errortime;
        int errors_Operation;
        int errortime_Operation;

        int clocks;
    } stats;
    
    stats stats1;
    
    reg clk=0;
    initial forever
        #5 clk = ~clk;

    logic [1:0] ALUOp;
    logic [6:0] Funct7;
    logic [2:0] Funct3;
    logic [3:0] Operation_ref;
    logic [3:0] Operation_dut;

    initial begin 
        $dumpfile("wave.vcd");
        $dumpvars(1, stim1.clk, tb_mismatch ,clk,ALUOp,Funct7,Funct3,Operation_ref,Operation_dut );
    end

    wire tb_match;      // Verification
    wire tb_mismatch = ~tb_match;
    assign tb_match = ( { Operation_ref } === ( { Operation_ref } ^ { Operation_dut } ^ { Operation_ref } ) );

    stimulus_gen stim1 (
        .clk,
        .ALUOp,
        .Funct7,
        .Funct3 );

    RefModule good1 (
        .ALUOp,
        .Funct7,
        .Funct3,
        .Operation(Operation_ref) );
        
    TopModule top_module1 (
        .ALUOp,
        .Funct7,
        .Funct3,
        .Operation(Operation_dut) );

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
        if (Operation_ref !== ( Operation_ref ^ Operation_dut ^ Operation_ref )) begin
            if (stats1.errors_Operation == 0) stats1.errortime_Operation = $time;
            stats1.errors_Operation = stats1.errors_Operation + 1'b1;
        end
    end

    final begin
        if (stats1.errors_Operation) $display("Hint: Output '%s' has %0d mismatches. First mismatch occurred at time %0d.", "Operation", stats1.errors_Operation, stats1.errortime_Operation);
        else $display("Hint: Output '%s' has no mismatches.", "Operation");

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


