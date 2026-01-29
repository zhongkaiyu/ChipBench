module RefModule(
	input clk,
	input rst_n,
	input data,
	output reg match,
	output reg not_match
	);


reg [3:0] pstate,nstate;

parameter idle=4'd0,
		  s1=4'd1,
          s2=4'd2,
          s3=4'd3,
          s4=4'd4,
          s5=4'd5,
          s6=4'd6,
		  sf1=4'd7,
          sf2=4'd8,
          sf3=4'd9,
          sf4=4'd10,
          sf5=4'd11,
          sf6=4'd12;

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        pstate<=idle;
    else
        pstate<=nstate;
end

always @(pstate or data)
begin
    case(pstate)
        idle:
            if(data==0)
                nstate=s1;			//第一位匹配
            else
                nstate=sf1;
        s1:
            nstate=data?s2:sf2;
        s2:
            nstate=data?s3:sf3;
        s3:
            nstate=data?s4:sf4;
        s4:
            nstate=data?sf5:s5;
        s5:
            nstate=data?sf6:s6;
        s6:
            nstate=data?sf1:s1;
        sf1:
            nstate=sf2;
        sf2:
            nstate=sf3;
        sf3:
            nstate=sf4;
        sf4:
            nstate=sf5;
        sf5:
            nstate=sf6;
        sf6:
			nstate=data?sf1:s1;
        default:
            nstate=idle;
        endcase
end

always @(pstate or data or rst_n)
begin
    if(!rst_n==1) 
		begin
			match=1'b0;
			not_match = 1'b0;
		end
    else if(pstate==s6)
		begin
			match=1'b1;
			not_match = 1'b0;
		end
	else if(pstate==sf6)
		begin
			match=1'b0;
			not_match = 1'b1;
		end
    else
		begin
			match=1'b0;
			not_match = 1'b0;
		end
end

endmodule