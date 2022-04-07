module regdeMUX_sel2
#(
    parameter   RSA_DW = 16
)
(
    input   clk,
    input   sys_rst,
    input   en,

    input  [1:0] sel,
    input  [RSA_DW-1:0]  din,

    output reg   [RSA_DW-1:0]  dout_00,
    output reg   [RSA_DW-1:0]  dout_01,
    output reg   [RSA_DW-1:0]  dout_10,
    output reg   [RSA_DW-1:0]  dout_11
);
    always @(posedge clk) begin
        if(sys_rst == 1'b1 || en == 1'b0) begin
            dout_00 <= 0;
            dout_01 <= 0;            
            dout_10 <= 0;
            dout_11 <= 0;  
        end
        else begin
            case(sel)
                2'b00: dout_00 <= din;
                2'b01: dout_01 <= din;
                2'b10: dout_10 <= din;
                2'b11: dout_11 <= din;
            endcase
        end      
    end
endmodule