
module RefModule(
     input  wire clk_in,
     input  wire rst,
     output wire clk_out
);
    parameter M_N = 8'd87; 
    parameter c89 = 8'd24;  // 8/9 clock switching point
    parameter div_e = 5'd8; //Even period
    parameter div_o = 5'd9; //Odd period
//*************code***********//
    reg [3:0] clk_cnt;
    reg [6:0] cyc_cnt;
    reg div_flag;
    reg clk_out_r;
    
    always@(posedge clk_in or negedge rst) begin
        if(~rst)
            clk_cnt <= 0;
        else if(~div_flag)
            clk_cnt <= clk_cnt==(div_e-1)? 0: clk_cnt+1;
        else
            clk_cnt <= clk_cnt==(div_o-1)? 0: clk_cnt+1;
    end
    
    always@(posedge clk_in or negedge rst) begin
        if(~rst)
            cyc_cnt <= 0;
        else
            cyc_cnt <= cyc_cnt==(M_N-1)? 0: cyc_cnt+1;
    end
    
    always@(posedge clk_in or negedge rst) begin
        if(~rst)
            div_flag <= 0;
        else
            div_flag <= cyc_cnt==(M_N-1)||cyc_cnt==(c89-1)? ~div_flag: div_flag;
    end
    
    always@(posedge clk_in or negedge rst) begin
        if(~rst)
            clk_out_r <= 0;
        else if(~div_flag)
            clk_out_r <= clk_cnt<=((div_e>>2)+1);
        else
            clk_out_r <= clk_cnt<=((div_o>>2)+1);
    end
    
    assign clk_out = clk_out_r;
//*************code***********//
endmodule
