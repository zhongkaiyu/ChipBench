
module RefModule(
	input clk,
	input rst_n,
	
	input write_en,
	input [7:0]write_addr,
    input [3:0]write_data,
	
	input read_en,
	input [7:0]read_addr,
	output reg [3:0]read_data
);
    reg [3:0] myRAM [7:0];
    
    reg [8:0] i;
  	// integer i; // Not synthesizable
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n)
            for(i=0;i<256;i=i+1)
                myRAM[i] <= 0;
        else
            myRAM[write_addr] <= write_en? write_data: myRAM[write_addr];
    end
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n)
            read_data <= 0;
        else
            read_data <= read_en? myRAM[read_addr]: read_data;
    end
endmodule
