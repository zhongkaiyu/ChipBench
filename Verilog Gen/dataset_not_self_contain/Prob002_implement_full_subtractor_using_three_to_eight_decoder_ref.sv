
module RefModule(
   input             A     ,
   input             B     ,
   input             Ci    ,
    
   output wire       D     ,
   output wire       Co         
);
                   
wire       Y0_n   ;  
wire       Y1_n   ; 
wire       Y2_n   ; 
wire       Y3_n   ; 
wire       Y4_n   ; 
wire       Y5_n   ; 
wire       Y6_n   ; 
wire       Y7_n   ;
 
decoder_38 U0(
   .E      (1'b1),
   .A0     (Ci  ),
   .A1     (B   ),
   .A2     (A   ),
   
   .Y0n    (Y0_n),  
   .Y1n    (Y1_n), 
   .Y2n    (Y2_n), 
   .Y3n    (Y3_n), 
   .Y4n    (Y4_n), 
   .Y5n    (Y5_n), 
   .Y6n    (Y6_n), 
   .Y7n    (Y7_n)
);
 
assign D = ~(Y1_n & Y2_n & Y4_n & Y7_n);
assign Co = ~(Y1_n & Y2_n & Y3_n & Y7_n);
 
endmodule

// decoder_38 module is in prompt file.