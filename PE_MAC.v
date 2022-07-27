/*
    PE_MAC with only one mode, no inout ports
*/
`include "macro.v"
module PE_MAC 
#(
    parameter RSA_DW = 32
)
(
    input       clk                      ,
    input       sys_rst                  , 

    input       [1:0]             PE_mode,

//Vertical
    input                         cal_en_N,
    output                        cal_en_S,
    input                         cal_done_N,
    output                        cal_done_S,

    input           signed [RSA_DW-1:0]  v_data_N,
    output          signed [RSA_DW-1:0]  v_data_S,

//Horizontal
    input           signed [RSA_DW-1:0]  h_data_W,
    output          signed [RSA_DW-1:0]  h_data_E,

    output                        mulres_val_W,
    input                         mulres_val_E,
    output          signed [RSA_DW-1:0]  mulres_W,
    input           signed [RSA_DW-1:0]  mulres_E
);
    localparam W_2_E = 1'b0;
    localparam E_2_W = 1'b1;
    localparam N_2_S = 1'b0;
    localparam S_2_N = 1'b1;

    wire cal_en;
    reg  cal_en_r;
    wire cal_done;
    reg  cal_done_r;

    wire signed [RSA_DW-1:0] v_data;
    reg  signed [RSA_DW-1:0] v_data_r;
    wire signed [RSA_DW-1:0] h_data;
    reg  signed [RSA_DW-1:0] h_data_r;

    wire mulres_val;
    reg  mulres_val_r;
    wire signed [RSA_DW-1:0] mulres;
    reg  signed [RSA_DW-1:0] mulres_r;

/*
    mode == 1'b0: North to South, West to East
    mode == 1'b1: South to North, East to West
*/
//Vertical
    assign cal_en_S   = cal_en_r;
    assign cal_en     = cal_en_N;

    assign cal_done   = cal_done_N;
    assign cal_done_S = cal_done_r;

    assign v_data   = v_data_N;
    assign v_data_S = v_data_r;

//Horizontal
    assign h_data   = h_data_W;
    assign h_data_E = h_data_r;

    //输入模式为W_2_E时，结果mulres从east传向west
    assign mulres_val   = mulres_val_E;
    assign mulres_val_W = mulres_val_r;
    
    assign mulres   = mulres_E;
    assign mulres_W = mulres_r;

//乘积 部分和  32-bit signed (Q1.12.19) multiplier
    localparam  INT_BIT = 12;
    localparam  DEC_BIT = 19;
    reg signed [2*RSA_DW-1:0] product_temp;
    wire signed [RSA_DW-1:0] product;
    reg signed [RSA_DW-1:0] partial_sum;
  `ifdef USE_QUANT
    assign product = {product_temp[2*RSA_DW-1], product_temp[DEC_BIT+RSA_DW-2 : DEC_BIT]};
  `else 
    assign product = product_temp[RSA_DW-1:0];
  `endif


//mode的一级缓存，用于判断mode跳变
    reg [1:0] PE_mode_r;
    always @(posedge clk) begin
        if(sys_rst)
            PE_mode_r <= 0;
        else 
            PE_mode_r <= PE_mode;
    end

//下一模块的cal_en: cal_en_r
    always @(posedge clk) begin
        if(sys_rst)  begin
            cal_en_r <= 0;
        end
        else  begin
            cal_en_r <= cal_en;
        end
    end

    always @(posedge clk) begin
        if(sys_rst)  begin
            cal_done_r <= 0;
        end
        else  begin
            cal_done_r <= cal_done;
        end
    end

//multiply
    always @(posedge clk) begin
        if(sys_rst)
            product_temp <= 0;
        else if(cal_en == 1'b1)
            product_temp <= h_data * v_data;
        else
            product_temp <= 0;        
    end

//add on partial sum
    always @(posedge clk) begin
        if(sys_rst)  begin
            partial_sum <= 0; 
        end
        //未发生mode跳变
        else if((PE_mode == PE_mode_r) && cal_en == 1'b1 && cal_done == 1'b0)
            partial_sum <= partial_sum + product;
        //发生mode跳变，将部分和置零
        else 
            partial_sum <= 0; 
    end

//mulres_r 1:输出乘积+求和 2:传递mulres
    always @(posedge clk) begin
        if(sys_rst)  begin
            mulres_r <= 0; 
        end
        else if(cal_done == 1'b1)
            mulres_r <= partial_sum + product;
        else if(mulres_val == 1'b1)
            mulres_r <= mulres;
        else 
            mulres_r <= 0; 
    end

//mulres_val_r 输出有效
    always @(posedge clk) begin
        if(sys_rst)  begin
            mulres_val_r <= 1'b0;
        end
        else if(cal_done == 1'b1 || mulres_val == 1'b1) begin
            mulres_val_r <= 1'b1;
        end
        else
            mulres_val_r <= 1'b0;
    end

//h_data_r行数据复用
    always @(posedge clk) begin
        if(sys_rst)  begin
            h_data_r <= 0;
        end
        else if(cal_en == 1'b1) begin
            h_data_r <= h_data;
        end
        else
            h_data_r <= 0;
    end

//v_data_r数据复用
    always @(posedge clk) begin
        if(sys_rst)  begin
            v_data_r <= 0;
        end
        else if(cal_en == 1'b1) begin
            v_data_r <= v_data;
        end
        else
            v_data_r <= 0;
    end
endmodule