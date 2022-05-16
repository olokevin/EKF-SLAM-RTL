module regMUX_sel1 
#(
    parameter   RSA_DW = 16
)
(
    input   clk,
    input   sys_rst,

    input   en,
    input   sel,
    input   signed [RSA_DW-1:0]  din_0,
    input   signed [RSA_DW-1:0]  din_1,

    output  reg signed [RSA_DW-1:0]  dout
);
    always @(posedge clk) begin
        if(sys_rst == 1'b1 || en == 1'b0)
            dout <= 0;
        else begin
            case(sel)
                1'b0: dout <= din_0;
                1'b1: dout <= din_1;
            endcase
        end      
    end
endmodule