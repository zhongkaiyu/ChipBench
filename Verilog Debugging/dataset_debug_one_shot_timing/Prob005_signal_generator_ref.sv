
module RefModule(
	input clk,
	input rst_n,
	input [1:0] wave_choice,
	output reg [4:0]wave
	);

    reg [4:0] cnt;
    reg flag;
    
  	// Square wave mode, counter control
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n)
            cnt <= 0;
        else
            cnt <= wave_choice!=0 ? 0:
                   cnt        ==19? 0:
                   cnt + 1;
    end
    
  	// Triangle wave mode, flag bit control
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n)
            flag <= 0;
        else
            flag <= wave_choice!=2 ? 0:
                    wave       ==1 ? 1:
                    wave       ==19? 0:
                    flag;
    end
    
  
  	// Update wave signal
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) 
            wave <= 0;
        else 
            case(wave_choice)
                0      : wave <= cnt == 9? 20    : 
                                 cnt ==19? 0     :
                                 wave;
                1      : wave <= wave==20? 0     : wave+1;
                2      : wave <= flag==0 ? wave-1: wave+1;
                default: wave <= 0;
            endcase
    end
endmodule
