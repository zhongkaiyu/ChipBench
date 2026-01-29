`timescale 1ns/1ns

module RefModule(
	input 				   clk 		,   
	input 			      rst_n		,
	input				      valid_in	,
	input	[7:0]			   data_in	,
 
 	output  reg			   valid_out,
	output  reg [11:0]   data_out
);
reg 	[7:0]		data_lock;
reg 	[1:0]		valid_cnt		;
always @(posedge clk or negedge rst_n ) begin
	if(!rst_n) 
		data_lock <= 'd0;
	else if(valid_in )
		data_lock <= data_in;
end
always @(posedge clk or negedge rst_n ) begin
	if(!rst_n) 
		valid_cnt <= 'd0;
	else if(valid_in)begin
		if(valid_cnt == 2'd2)
			valid_cnt <= 2'd0;
		else
			valid_cnt <= valid_cnt + 1'd1;
	end 
end
always @(posedge clk or negedge rst_n ) begin
	if(!rst_n) 
		valid_out <= 'd0;
	else if(valid_in && valid_cnt == 2'd1)
		valid_out <= 1'd1;
	else if(valid_in && valid_cnt == 2'd2)
		valid_out <= 1'd1;
	else
		valid_out <= 'd0;
end
always @(posedge clk or negedge rst_n ) begin
	if(!rst_n) 
		data_out <= 'd0;
	else if(valid_in && valid_cnt == 2'd1)
		data_out <= {data_lock, data_in[7:4]};
	else if(valid_in && valid_cnt == 2'd2)
		data_out <= {data_lock[3:0], data_in};
end
endmodule