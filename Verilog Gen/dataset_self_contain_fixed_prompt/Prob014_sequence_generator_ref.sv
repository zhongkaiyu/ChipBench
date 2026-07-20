
module RefModule(
    input clk,
    input rst_n,
    output reg data
    );
     
    reg [5:0] q;
     
    always@(posedge clk or negedge rst_n)
        if (!rst_n)
            q <= 6'b001011;
        else
            q <= {q[4:0],q[5]};
     
    always@(posedge clk or negedge rst_n)
        if (!rst_n)
            data <= 1'd0;
        else
            data <= q[5];
endmodule