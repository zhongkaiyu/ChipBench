
module RefModule(
   input                clk ,
   input                rst_n,
 
   output reg [3:0]     Q  
);
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n) Q <= 'd0;
        else Q <= {~Q[0], Q[3 : 1]};
    end
endmodule
