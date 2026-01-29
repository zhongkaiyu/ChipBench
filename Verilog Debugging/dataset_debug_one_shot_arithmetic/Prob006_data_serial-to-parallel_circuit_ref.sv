module RefModule(
    input               clk         ,  
    input               rst_n       ,
    input               valid_a     ,
    input               data_a      ,
  
    output  reg         ready_a     ,
    output  reg         valid_b     ,
    output  reg [5:0]   data_b
);
    reg [5:0] data_r;
    reg [2:0] cnt;
 
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n)
            cnt <= 0;
        else
            cnt <= ~ready_a||~valid_a? cnt:
                   cnt      ==      5? 0  :
                   cnt+1;
    end
     
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n)
            data_r <= 6'b0;
        else
            data_r <= ready_a&&valid_a? {data_a, data_r[5:1]}: data_r;
    end
     
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n)
            data_b <= 6'b0;
        else
            data_b <= cnt==5&&valid_a? {data_a, data_r[5:1]}: data_b;
    end
     
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n)
            valid_b <= 0;
        else
            valid_b <= cnt==5;
    end
     
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n)
            ready_a <= 0;
        else
            ready_a <= 1;
    end
endmodule