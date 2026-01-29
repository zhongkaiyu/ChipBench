
module RefModule(
	input 				clk 		,   
	input 				rst_n		,
	input				valid_in	,
	input	[23:0]		data_in		,
 
 	output	reg			valid_out	,
	output  reg [127:0]	data_out
);
    reg [3:0]   cnt;
    reg [127:0] data_lock;
    
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n)
            cnt <= 0;
        else
            cnt <= ~valid_in? cnt:cnt+1;
    end
    
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n)
            valid_out <= 0;
        else
            valid_out <= (cnt==5 || cnt==10 || cnt==15)&&valid_in;
    end
    
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n)
            data_lock <= 0;
        else
            data_lock <= valid_in? {data_lock[103:0], data_in}: data_lock;
    end
    
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n)
            data_out <= 0;
        else if(cnt==5)
            data_out <= valid_in? {data_lock[119:0], data_in[23:16]}: data_out;
        else if(cnt==10)
            data_out <= valid_in? {data_lock[111:0], data_in[23: 8]}: data_out;
        else if(cnt==15)
            data_out <= valid_in? {data_lock[103:0], data_in[23: 0]}: data_out;
        else
            data_out <= data_out;
    end
endmodule
