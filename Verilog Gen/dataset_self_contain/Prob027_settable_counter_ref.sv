
module RefModule(
	input clk,
	input rst_n,
	input set,
	input [3:0] set_num,
	output reg [3:0]number,
	output reg zero
	);
	reg [3:0]num;
	
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			begin 
				zero <= 1'd0;
			end
		else if (num == 4'd0)
			begin
				zero <= 1'b1;
			end
		else 
			begin	
				zero <= 1'b0;
			end
		
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			begin 
				num <= 4'b0;
			end
		else if(set)
			begin
				num <= set_num;
			end
		else 
			begin
				num <= num + 1'd1;
			end

	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			begin 
				number <= 1'd0;
			end
		else 
			begin
				number <= num;
			end			

endmodule