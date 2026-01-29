
module RefModule(
    input              clk_fast    , 
    input              clk_slow    ,   
    input              rst_n       ,
    input               data_in     ,
 
    output           data_out
);
reg     Q_fast;
always @(posedge clk_fast or negedge rst_n) begin
    if(~rst_n) begin
        Q_fast <= 'd0;
    end 
    else if(data_in)begin
        Q_fast <= ~Q_fast;
    end
    else if(~data_in)begin
        Q_fast <= Q_fast;
    end
end
reg    Q_buff0;
reg    Q_buff1;
always @(posedge clk_slow or negedge rst_n) begin 
    if(~rst_n) begin
        Q_buff0 <= 'd0;
        Q_buff1 <= 'd0;
    end 
    else begin
        Q_buff0 <= Q_fast;
        Q_buff1 <= Q_buff0;
    end
end
reg     Q_slow;
always @(posedge clk_slow or negedge rst_n) begin
    if(~rst_n) begin
        Q_slow <= 'd0;
    end 
    else begin
        Q_slow <= Q_buff1;
    end
end
 
assign data_out = Q_buff1 ^ Q_slow;
endmodule