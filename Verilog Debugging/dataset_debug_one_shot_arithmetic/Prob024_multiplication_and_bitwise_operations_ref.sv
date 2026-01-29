
module RefModule(
    input  [7:0]    A,
    output [15:0]   B
    );

//*************code***********//

    assign B = (A<<8)-(A<<2)-A;
//*************code***********//

endmodule