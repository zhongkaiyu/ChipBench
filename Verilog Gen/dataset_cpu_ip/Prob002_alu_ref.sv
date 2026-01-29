module RefModule#(
        parameter DATA_WIDTH = 32,
        parameter OPCODE_LENGTH = 4
        )
        (
        input logic [DATA_WIDTH-1:0]    SrcA,
        input logic [DATA_WIDTH-1:0]    SrcB,

        input logic [OPCODE_LENGTH-1:0]    Operation,
        output logic[DATA_WIDTH-1:0] ALUResult
        );
    
        always_comb
        begin
            case(Operation)
            4'b0000:        // AND
                    ALUResult = SrcA & SrcB;
            4'b0001:        // OR
                    ALUResult = SrcA | SrcB;
            4'b0010:        // ADD
                    ALUResult = $signed(SrcA) + $signed(SrcB);
            4'b0011:        // XOR
                    ALUResult = SrcA ^ SrcB;
            4'b0100:        // Left Shift
                    ALUResult = SrcA << SrcB[4:0];
            4'b0101:        // Right Shift
                    ALUResult = SrcA >> SrcB[4:0];
            4'b0110:        // Subtract
                    ALUResult = $signed(SrcA) - $signed(SrcB);
            4'b0111:        // Right Shift Arithm
                    ALUResult = $signed(SrcA) >>> SrcB[4:0];

            4'b1000:        // Equal
                    ALUResult = (SrcA == SrcB) ? 1 : 0;
            4'b1001:        // Not Equal
                    ALUResult = (SrcA != SrcB) ? 1 : 0;
            4'b1100:        // Less Than
                    ALUResult = ($signed(SrcA) < $signed(SrcB)) ? 1 : 0;
            4'b1101:        // Greater/Equal Than
                    ALUResult = ($signed(SrcA) >= $signed(SrcB)) ? 1 : 0;
            4'b1110:        // Unsigned Less Than
                    ALUResult = (SrcA < SrcB) ? 1 : 0;
            4'b1111:        // Unsigned Greater/Equal Than
                    ALUResult = (SrcA >= SrcB) ? 1 : 0;
            4'b1010:        // Always True, for jal
                    ALUResult = 1;
            default:
                    ALUResult = 0;
            endcase
        end
endmodule