module sync_adder #(
    parameter   RSA_DW = 16
) (
    input clk,
    input sys_rst,

    input [1:0] mode,

    input [RSA_DW-1:0]    adder_M,
    input [RSA_DW-1:0]    adder_C,

    output  reg [RSA_DW-1:0]  sum
);
parameter NONE = 2'b00;
parameter ADD = 2'b01;
parameter M_MINUS_C = 2'b10;
parameter C_MINUS_M = 2'b11;

    always @(posedge clk) begin
        if(sys_rst)
            sum <= 0;
        else begin
            case(mode)
                NONE: sum <= adder_C;
                ADD:  sum <= adder_M + adder_C;
                M_MINUS_C: sum <= adder_M - adder_C;
                C_MINUS_M: sum <= adder_M - adder_C;        //只是为了与M_in_sel对应
            endcase
        end
    end
endmodule