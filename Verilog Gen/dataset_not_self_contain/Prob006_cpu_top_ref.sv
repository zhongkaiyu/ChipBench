
module RefModule (
    output reg readM,                       // read from memory
    output reg [`WORD_SIZE-1:0] address,    // current address for data
    inout [`WORD_SIZE-1:0] data,            // data being input or output
    input inputReady,                       // indicates that data is ready from the input port
    input reset_n,                          // active-low RESET signal
    input clk,                              // clock signal

    // for debuging/testing purpose
    output reg [`WORD_SIZE-1:0] num_inst,   // number of instruction during execution
    output [`WORD_SIZE-1:0] output_port // this will be used for a "WWD" instruction
);

    // General CPU declarations
    localparam FETCH = 3'd0;
    localparam EXECUTE = 3'd1;
    localparam MEMORY_READ = 3'd2;
    localparam MEMORY_WRITE = 3'd3;
    localparam WRITE_BACK = 3'd4;
    localparam INPUT_READ = 3'd5;
    localparam HALT = 3'd6;

    reg [2:0] state;
    reg [`WORD_SIZE-1:0] PC, nextPC;
    reg [`WORD_SIZE-1:0] instruction, dataReg;  // Because data is only available for a short time, we need to save it.
    
    // Control signals from control module
    wire RegDst, Jump, Branch, MemRead, MemtoReg, MemWrite, ALUSrc, RegWrite, OpenPort;
    wire [3:0] ALUOp;
    
    // RF related declarations
    wire [`WORD_SIZE-1:0] ReadData1, ReadData2;
    wire [1:0] WriteAddress;
    wire [`WORD_SIZE-1:0] WriteData;
    wire WriteEnable;
    
    // ALU related declarations
    wire bcond;
    wire [`WORD_SIZE-1:0] ALUResult;
    
    // Actual modul declarations
    Control control(.opcode(instruction[15:12]),
                    .func(instruction[5:0]),
                    .RegDst(RegDst),
                    .Jump(Jump),
                    .Branch(Branch),
                    .MemRead(MemRead),
                    .MemtoReg(MemtoReg),
                    .ALUOp(ALUOp),
                    .MemWrite(MemWrite),
                    .ALUSrc(ALUSrc),
                    .RegWrite(RegWrite),
                    .OpenPort(OpenPort));
                    
    assign WriteAddress = (instruction[15:12] == `OPCODE_JAL) ? 2'd3 :
                          (RegDst ? instruction[7:6] : instruction[9:8]);
    assign WriteData = (instruction[15:12] == `OPCODE_JAL ||
                        (instruction[15:12] == `OPCODE_R && instruction[5:0] == `FUNC_JRL)) ? PC + 1'b1 :
                       ((state == WRITE_BACK) ? dataReg : ALUResult);
    assign WriteEnable = (state == WRITE_BACK) ||
                         (state == EXECUTE && RegWrite && !MemtoReg && !MemWrite &&
                          !(instruction[15:12] == `OPCODE_R &&
                            (instruction[5:0] == `FUNC_RWD || instruction[5:0] == `FUNC_WWD ||
                             instruction[5:0] == `FUNC_JPR || instruction[5:0] == `FUNC_HLT ||
                             instruction[5:0] == `FUNC_ENI || instruction[5:0] == `FUNC_DSI)));

    RF rf(.write(WriteEnable),
          .clk(clk),
          .reset_n(reset_n),
          .addr1(instruction[11:10]),
          .addr2(instruction[9:8]),
          .addr3(WriteAddress),
          .data1(ReadData1),
          .data2(ReadData2),
          .data3(WriteData));
          
    ALU alu(.A(ReadData1),
            .B(ALUSrc ? {{8{instruction[7]}}, instruction[7:0]} : ReadData2),   // Either sign-extended immediate or second register read from RF.
            .OP(ALUOp),
            .C(ALUResult),
            .bcond(bcond));
    
    always @(*) begin
        if (instruction[15:12] == `OPCODE_R &&
            (instruction[5:0] == `FUNC_JPR || instruction[5:0] == `FUNC_JRL))
            nextPC = ReadData1;
        else if (Jump) nextPC = {PC[15:12], instruction[11:0]};  // Jumping to target (12 bit), concatenated with the upper 4 bits of PC.
        else if (Branch & bcond) nextPC = PC + {{8{instruction[7]}}, instruction[7:0]}; // Branching to PC + sign-extend(immediate)
        else nextPC = PC + 1;   // Next instruction
    end

    always @(*) begin
        readM = 1'b0;
        address = PC;

        if (reset_n) begin
            case (state)
                FETCH: readM = 1'b1;
                MEMORY_READ: begin
                    readM = 1'b1;
                    address = ALUResult;
                end
                MEMORY_WRITE: address = ALUResult;
            endcase
        end
    end

    assign data = (state == MEMORY_WRITE) ? ReadData2 : `WORD_SIZE'bz;

    // Only open when OpenPort is asserted by the control module
    assign output_port = (state == EXECUTE && OpenPort) ? ReadData1 : `WORD_SIZE'bz;

    always @(posedge clk, negedge reset_n) begin
        if (!reset_n) begin     // Asynchronous active low reset
            PC <= 0;
            instruction <= 0;
            dataReg <= 0;
            num_inst <= 0;
            state <= FETCH;
        end else begin
            case (state)
                FETCH: begin
                    if (inputReady) begin
                        instruction <= data;
                        state <= EXECUTE;
                    end
                end
                EXECUTE: begin
                    if (instruction[15:12] == `OPCODE_R && instruction[5:0] == `FUNC_HLT) begin
                        num_inst <= num_inst + 1'b1;
                        state <= HALT;
                    end else if (MemtoReg) begin
                        state <= MEMORY_READ;
                    end else if (MemWrite) begin
                        state <= MEMORY_WRITE;
                    end else if (instruction[15:12] == `OPCODE_R && instruction[5:0] == `FUNC_RWD) begin
                        state <= INPUT_READ;
                    end else begin
                        PC <= nextPC;
                        num_inst <= num_inst + 1'b1;
                        state <= FETCH;
                    end
                end
                MEMORY_READ, INPUT_READ: begin
                    if (inputReady) begin
                        dataReg <= data;
                        state <= WRITE_BACK;
                    end
                end
                MEMORY_WRITE: begin
                    PC <= nextPC;
                    num_inst <= num_inst + 1'b1;
                    state <= FETCH;
                end
                WRITE_BACK: begin
                    PC <= nextPC;
                    num_inst <= num_inst + 1'b1;
                    state <= FETCH;
                end
                HALT: state <= HALT;
                default: state <= FETCH;
            endcase
        end
    end

endmodule
