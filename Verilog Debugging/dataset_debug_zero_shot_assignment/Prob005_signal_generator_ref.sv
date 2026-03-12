
module RefModule(
	input clk,
	input rst_n,
	input [1:0] wave_choice,
	output reg [4:0]wave
	);

    reg [4:0] cnt;
    reg flag;
    
  	// 方波模式下，计数器控制
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n)
            cnt <= 0;
        else
            cnt <= wave_choice!=0 ? 0:
                   cnt        ==19? 0:
                   cnt + 1;
    end
    
  	// 三角波模式下，标志位控制
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n)
            flag <= 0;
        else
            flag <= wave_choice!=2 ? 0:
                    wave       ==1 ? 1:
                    wave       ==19? 0:
                    flag;
    end
    
  
  	// 更新wave信号
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
