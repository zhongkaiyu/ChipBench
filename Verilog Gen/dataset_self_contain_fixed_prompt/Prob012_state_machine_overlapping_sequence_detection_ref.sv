module RefModule(
	input wire clk  ,
	input wire rst  ,
	input wire data ,
	output reg flag
);
//*************code***********//
    parameter S0=0, S1=1, S2=2, S3=3, S4=4;
    reg [2:0] state, nstate;
    
    always@(posedge clk or negedge rst) begin
        if(~rst)
            state <= S0;
        else
            state <= nstate;
    end
    
    always@(*) begin
        if(~rst)
            nstate <= S0;
        else
            case(state)
                S0     : nstate <= data? S1: S0;
                S1     : nstate <= data? S1: S2;
                S2     : nstate <= data? S3: S0;
                S3     : nstate <= data? S4: S2;
                S4     : nstate <= data? S1: S2;
                default: nstate <= S0;
            endcase
    end
    
    always@(posedge clk or negedge rst) begin
        if(~rst)
            flag <= 0;
        else
            flag <= state==S4;
    end

//*************code***********//
endmodule
