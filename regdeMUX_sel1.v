module regdeMUX_sel1 
#(
    parameter   RSA_DW = 16
)
(
    input   clk,
    input   sys_rst,
    input   en,

    input   sel,
    input  [RSA_DW-1:0]  din,

    output reg   [RSA_DW-1:0]  dout_0,
    output reg   [RSA_DW-1:0]  dout_1
);
    always @(posedge clk) begin
        if(sys_rst == 1'b1 || en == 1'b0) begin
            dout_0 <= 0;
            dout_1 <= 0;            
        end
        else begin
            case(sel)
                1'b0: dout_0 <= din;
                1'b1: dout_1 <= din;
            endcase
        end      
    end
endmodule