module RefModule(
	input clk,
	input rst_n,
	input a,
	output match
	);

	reg [8:0] a_tem;
	reg match_f;
	reg match_b;
	
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			begin 
				match_f <= 1'b0;
			end
		else if (a_tem[8:6] == 3'b011)
			begin
				match_f <= 1'b1;
			end
		else 
			begin	
				match_f <= 1'b0;
			end

	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			begin 
				match_b <= 1'b0;
			end
		else if (a_tem[2:0] == 3'b110)
			begin
				match_b <= 1'b1;
			end
		else 
			begin	
				match_b <= 1'b0;
			end
			
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			begin 
				a_tem <= 9'b0;
			end
		else 
			begin
				a_tem <= {a_tem[7:0],a};
			end
			
	assign match = match_b && match_f;
endmodule