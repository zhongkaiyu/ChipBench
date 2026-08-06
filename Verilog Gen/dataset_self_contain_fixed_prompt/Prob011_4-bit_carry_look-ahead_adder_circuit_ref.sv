
module RefModule(
    input       [3:0]       A_in  ,
    input       [3:0]       B_in  ,
    input                   C_1   ,
  
    output   wire           CO    ,
    output   wire [3:0]     S
);
    wire [3:0] G,P,C;
    assign P=A_in^B_in;
    assign G=A_in&B_in;
     
    assign C={G[3]|(P[3]&C[2]), G[2]|(P[2]&C[1]), G[1]|(P[1]&C[0]), G[0]|(P[0]&C_1)};
    assign S={P[3]^C[2], P[2]^C[1], P[1]^C[0], P[0]^C_1};
    assign CO=C[3];
     
endmodule