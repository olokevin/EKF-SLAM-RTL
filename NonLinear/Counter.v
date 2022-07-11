module Counter #( parameter M = 100, W = 7 )(
    input wire clk, rst, en,
    
    output reg [W - 1 : 0] cnt,
    output wire co
);
    assign co = en & (cnt == M - 1);
    always@(posedge clk) begin
        if(rst) begin
            cnt <= 'd0;
        end
        else if(en) begin
            if(cnt < M - 1) cnt <= cnt + 1'b1;
            else cnt <= 'd0;
        end
    end
endmodule