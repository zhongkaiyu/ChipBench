module lfsr_core(
    input [3:0] Q_in,
    output [3:0] Q_out
);
    assign Q_out = {~Q_in[0], Q_in[3:1]};
endmodule

module TopModule(
    input clk,
    input rst_n,
    output reg [3:0] Q
);
    wire [3:0] next_Q;
    lfsr_core core(.Q_in(Q), .Q_out(next_Q));

    always @(posedge clk or negedge rst_n)
        if (!rst_n) Q <= 4'd0;
        else Q <= next_Q;
endmodule
