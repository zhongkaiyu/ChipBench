
module RefModule
(
    input rst_n, //Asynchronous reset signal, active low
    input clk, 	//Clock signal
    input [9:0]money,
    input set,
    input boost,
    output reg[9:0]remain,
    output reg yellow,
    output reg red
);
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            yellow <= 0;
            red    <= 0;
        end
        else begin
            yellow <= remain<10&&remain;
            red    <= boost? remain<2: remain<1;
        end
    end
    
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) 
            remain <= 0;
        else if(boost)
            remain <= set     ? remain+money:
                      remain<2? remain: 
                      remain-2;
        else
            remain <= set     ? remain+money:
                      remain<1? remain: 
                      remain-1;
    end
endmodule
