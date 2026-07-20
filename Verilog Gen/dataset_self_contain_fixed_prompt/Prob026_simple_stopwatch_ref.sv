
module RefModule(
	input clk,
	input rst_n,

	output reg [5:0]second,
	output reg [5:0]minute
	);

	
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			begin 
				minute <= 6'd0;
			end
		else if (second == 6'd60)
			begin
				minute <= minute+1;
			end
		else 
			begin	
				minute <= minute;
			end
		
	always @(posedge clk or negedge rst_n)
		if (!rst_n)
			begin 
				second <= 6'd0;
			end
		else if(second == 6'd60)
			begin
				second <= 6'd1;
			end
		else if (minute == 60)
			second <= second;		
		else
			second <= second+1'd1;
endmodule