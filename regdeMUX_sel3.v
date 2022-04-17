module regdeMUX_sel3
#(
    parameter   RSA_DW = 16
)
(
    input   clk,
    input   sys_rst,
    input   en,

    input  [2:0] sel,
    input  [RSA_DW-1:0]  din,

    output reg   [RSA_DW-1:0]  dout_000,
    output reg   [RSA_DW-1:0]  dout_001,
    output reg   [RSA_DW-1:0]  dout_010,
    output reg   [RSA_DW-1:0]  dout_011,
    output reg   [RSA_DW-1:0]  dout_100,
    output reg   [RSA_DW-1:0]  dout_101,
    output reg   [RSA_DW-1:0]  dout_110,
    output reg   [RSA_DW-1:0]  dout_111
);
    always @(posedge clk) begin
        if(sys_rst == 1'b1 || en == 1'b0) begin
            dout_000 <= 0;
            dout_001 <= 0;            
            dout_010 <= 0;
            dout_011 <= 0;  
            dout_100 <= 0;
            dout_101 <= 0;            
            dout_110 <= 0;
            dout_111 <= 0;  
        end
        else begin
            case(sel)
                3'b000: dout_000 <= din;
                3'b001: dout_001 <= din;
                3'b010: dout_010 <= din;
                3'b011: dout_011 <= din;
                3'b100: dout_100 <= din;
                3'b101: dout_101 <= din;
                3'b110: dout_110 <= din;
                3'b111: dout_111 <= din;
            endcase
        end      
    end
endmodule