
module RefModule(
	input clk,
	input rst_n,
	input set,
	input [3:0] set_num,
	output reg [3:0]number,
	output reg zero
	);

	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			begin 
				number <= 4'd0;
				zero <= 1'b1;
			end
		else if(set)
			begin
				number <= set_num;
				zero <= (set_num == 4'd0);
			end
		else 
			begin
				number <= number + 1'd1;
				zero <= (number == 4'hf);
			end			

endmodule
