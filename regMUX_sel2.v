module regMUX_sel2 
#(
    parameter   RSA_DW = 16
)
(
    input   clk,
    input   sys_rst,
    input   en,

    input   [1:0]           sel,
    input   signed [RSA_DW-1:0]  din_00,
    input   signed [RSA_DW-1:0]  din_01,
    input   signed [RSA_DW-1:0]  din_10,
    input   signed [RSA_DW-1:0]  din_11,

    output  reg signed [RSA_DW-1:0]  dout
);
    always @(posedge clk) begin
        if(sys_rst == 1'b1 || en == 1'b0)
            dout <= 0;
        else begin
            case(sel)
                2'b00: dout <= din_00;
                2'b01: dout <= din_01;
                2'b10: dout <= din_10;
                2'b11: dout <= din_11;
            endcase
        end      
    end
endmodule