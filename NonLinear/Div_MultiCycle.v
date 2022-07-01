module Div_MultiCycle #( parameter W = 16, BW = 4 )(
    input clk, rst,
    input [W - 1 : 0] dividend,
    input [W - 1 : 0] divisor,
    input init,

    output reg [W - 1 : 0] quotient,
    output reg [W - 1 : 0] remainder,
    output reg valid, busy
);
    reg [W - 1 : 0] ddend, quot;
    reg [W * 2 - 2 : 0] dsor;
    wire bit_co;
    wire [BW : 0] bit_cnt;

    Counter #(W, BW) cntBit(clk, rst | init & ~busy, busy, bit_cnt, bit_co);
    always@(posedge clk) begin
        if(rst) busy <= 'd0;
        else if(bit_co) busy <= 'd0;
        else if(init) busy <= 'd1;
    end
    always@(posedge clk) begin
        if(busy) begin
           dsor <= dsor >> 1;
           if(ddend >= dsor) begin
               ddend <= ddend - dsor;
               quot <= (quot << 1) | 1'b1;
           end
           else quot <= quot << 1; 
        end
        else if(init) begin
            ddend <= dividend;
            dsor <= {divisor, 'd0};
            quot <= 'd0;
        end
    end
    always@(posedge clk) begin
        if(bit_co) begin
            if(ddend >= dsor) begin
                remainder <= ddend - dsor;
                quotient <= (quot << 1) | 1'b1;
            end
            else begin
                remainder <= ddend;
                quotient <= quot << 1;
            end
        end
    end
    always@(posedge clk) begin
        valid <= bit_co;
    end
endmodule