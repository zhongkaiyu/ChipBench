
module RefModule#(
parameter DATA_W = 8)
(
input [DATA_W-1:0]               A,
input [DATA_W-1:0]                      B,
input                          vld_in,
input                           rst_n,
input                          clk,
output  wire    [DATA_W*2-1:0]             lcm_out,
output  wire   [DATA_W-1:0]            mcd_out,
output  reg                     vld_out
);
    reg [DATA_W*2-1:0]    A_reg;
    reg [DATA_W*2-1:0]    B_reg;
    reg [DATA_W*2-1:0]    mcd_out_r1;
    reg [DATA_W*2-1:0]    mult_reg;
    reg [1:0]             c_state, n_state;
    parameter IDLE = 'd0, lcm1 = 'd1, Finish = 'd2;
 
    always @(posedge clk , negedge rst_n) begin
        if(~rst_n)                  c_state <= IDLE;
        else                        c_state <= n_state;
    end
 
    always @(*) begin
        case(c_state)
        IDLE : if(vld_in)           n_state = lcm1;
               else                 n_state = IDLE;
        lcm1 : if(A_reg == B_reg)   n_state = Finish;
               else                 n_state = lcm1;
        Finish :                    n_state = IDLE;
        default :                   n_state = IDLE;
        endcase
    end
 
    always @(posedge clk , negedge rst_n) begin
        if(~rst_n) begin
            A_reg               <= 'b0;
            B_reg               <= 'b0;
            mcd_out_r1          <= 'b0;
            mult_reg            <= 'b0;
        end
        else begin
            case(c_state)
            IDLE : 
                if(vld_in) begin
                    A_reg       <= A;
                    B_reg       <= B;
                    mult_reg    <= A * B;
                    mcd_out_r1  <= 0;
                end
                else begin
                    A_reg       <= A_reg;
                    B_reg       <= B_reg;
                    mult_reg    <= mult_reg;
                    mcd_out_r1  <= 0;
                end
            lcm1 : 
                if(A_reg > B_reg) begin
                    A_reg   <= A_reg - B_reg;
                    B_reg   <= B_reg;
                end
                else if(A_reg < B_reg) begin
                    B_reg   <= B_reg - A_reg;
                    A_reg   <= A_reg;
                end
                else begin
                    A_reg       <= A_reg;
                    B_reg       <= B_reg;
                end
            Finish  : mcd_out_r1 <= A_reg;
             
            default : begin
                A_reg           <= 'b0;
                B_reg           <= 'b0;
                mcd_out_r1      <= 'b0;
                mult_reg        <= 'b0;
            end
        endcase
    end
    end
    assign mcd_out = mcd_out_r1;
    assign lcm_out = (mcd_out_r1 == 'd0) ? 'hz : (mult_reg / mcd_out_r1); // If the GCD register is 0, output high impedance, otherwise the circuit will have issues
 
    always @(posedge clk , negedge rst_n) begin
        if(~rst_n)                 vld_out <= 1'b0;
        else if(c_state == Finish) vld_out <= 1'b1;
        else                       vld_out <= 1'b0;
    end
 
endmodule