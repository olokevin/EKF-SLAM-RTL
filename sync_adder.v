module sync_adder #(
    parameter   RSA_DW = 16
) (
    input clk,
    input sys_rst,

    input [1:0] mode,

    input signed [RSA_DW-1:0]    adder_M,
    input signed [RSA_DW-1:0]    adder_C,

    output reg signed [RSA_DW-1:0]  sum
);
localparam NONE = 2'b00;
localparam ADD = 2'b01;
localparam C_MINUS_M = 2'b10;
localparam M_MINUS_C = 2'b11;

    always @(posedge clk) begin
        if(sys_rst)
            sum <= 0;
        else begin
            case(mode)
                NONE: sum <= adder_C;
                ADD:  sum <= adder_M + adder_C;
                C_MINUS_M: sum <= adder_C - adder_M;
                M_MINUS_C: sum <= adder_M - adder_C;        
            endcase
        end
    end
endmodule