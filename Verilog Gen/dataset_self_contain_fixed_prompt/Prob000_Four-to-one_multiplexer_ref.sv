
module RefModule(
  input [1:0] d0, d1, d2, d3,
  input [1:0] sel,
  output [1:0] mux_out
);
  assign mux_out = sel[1] ? (sel[0] ? d3 : d2)
                          : (sel[0] ? d1 : d0);
endmodule
