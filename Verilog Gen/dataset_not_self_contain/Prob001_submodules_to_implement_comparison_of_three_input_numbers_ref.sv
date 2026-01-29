
module RefModule(
    input clk,
    input rst_n,
    input [7:0]a,
    input [7:0]b,
    input [7:0]c,
    
    output [7:0]d
);

    wire [7:0] c_out1;
    slave_mod s1(
        .clk(clk),
        .rst_n(rst_n),
        .a(a),
        .b(b),
        .c_out(c_out1)
    );
 
    reg [7:0] c1;
    always @(posedge clk, negedge rst_n) begin
        if(!rst_n)
            c1 <= 8'b0;
        else
            c1 <= c;
    end

        slave_mod s2(
        .clk(clk),
        .rst_n(rst_n),
        .a(c_out1),
        .b(c1),
        .c_out(d)
    );   
           
endmodule

module slave_mod(
    input clk,
    input rst_n,
    input [7:0]a,
    input [7:0]b,
    output reg [7:0] c_out
);
    always @(posedge clk,negedge rst_n) begin
        if(!rst_n)
            c_out <= 8'b0;
        else
            if(a>b)
                c_out <= b;
            else
                c_out <= a;
    end
            
endmodule