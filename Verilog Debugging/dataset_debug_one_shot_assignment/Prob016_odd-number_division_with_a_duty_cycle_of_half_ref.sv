
module RefModule
  #(parameter N = 7)
   (
    input    wire  rst ,
    input    wire  clk_in,
    output   wire  clk_out7
    );



   reg [3:0]            cnt ;
   always @(posedge clk_in or negedge rst) begin
      if (!rst) begin
         cnt    <= 'b0 ;
      end
      else if (cnt == N-1) begin
         cnt    <= 'b0 ;
      end
      else begin
         cnt    <= cnt + 1'b1 ;
      end
   end

   reg                  clkp ;
   always @(posedge clk_in or negedge rst) begin
      if (!rst) begin
         clkp <= 1'b0 ;
      end
      else if (cnt == (N>>1)) begin 
        clkp <= 1 ;
      end
      else if (cnt == N-1) begin 
        clkp <= 0 ;
      end
   end
  

   reg                  clkn ;
   always @(negedge clk_in or negedge rst) begin
      if (!rst) begin
         clkn <= 1'b0 ;
      end
      else if (cnt == (N>>1) ) begin 
        clkn <= 1 ;
      end
      else if (cnt == N-1) begin 
        clkn <= 0 ;
      end
   end


   assign clk_out7 = clkp | clkn ;


endmodule