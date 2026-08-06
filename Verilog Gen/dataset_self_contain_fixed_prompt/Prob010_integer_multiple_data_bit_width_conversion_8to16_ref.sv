module RefModule(
    input                  clk      ,  
    input                  rst_n    ,
    input                  valid_in ,
    input       [7:0]      data_in  ,
  
    output  reg            valid_out,
    output  reg [15:0]     data_out
);
    reg [7:0] data_r;
    reg       flag;
     
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n)
            flag <= 0;
        else
            flag <= valid_in? ~flag: flag;
    end
     
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n)
            data_r <= 0;
        else
            data_r <= valid_in? data_in: data_r;
    end
     
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n)
            data_out <= 0;
        else
            data_out <= flag&&valid_in? {data_r, data_in}: data_out;
    end
     
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n)
            valid_out <= 0;
        else
            valid_out <= flag&&valid_in;
    end
endmodule