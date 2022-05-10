/*
    PE_MAC with 4 modes, using inout ports(need to designate as IOBUF primitives)
*/
module PE_MAC 
#(
    parameter RSA_DW = 16
)
(
    input       clk                      ,
    input       sys_rst                  , 

    input       [1:0]             PE_mode,

//Vertical
    inout                         cal_en_N,
    inout                         cal_en_S,
    inout                         cal_done_N,
    inout                         cal_done_S,

    inout           [RSA_DW-1:0]  v_data_N,
    inout           [RSA_DW-1:0]  v_data_S,

//Horizontal
    inout           [RSA_DW-1:0]  h_data_W,
    inout           [RSA_DW-1:0]  h_data_E,

    inout                         mulres_val_W,
    inout                         mulres_val_E,
    inout           [RSA_DW-1:0]  mulres_W,
    inout           [RSA_DW-1:0]  mulres_E
);
    localparam W_2_E = 1'b0;
    localparam E_2_W = 1'b1;
    localparam N_2_S = 1'b0;
    localparam S_2_N = 1'b1;

    wire cal_en;
    reg  cal_en_r;
    wire cal_done;
    reg  cal_done_r;

    wire [RSA_DW-1:0] v_data;
    reg  [RSA_DW-1:0] v_data_r;
    wire [RSA_DW-1:0] h_data;
    reg  [RSA_DW-1:0] h_data_r;

    wire mulres_val;
    reg  mulres_val_r;
    wire [RSA_DW-1:0] mulres;
    reg  [RSA_DW-1:0] mulres_r;

/*
    mode == 1'b0: North to South, West to East
    mode == 1'b1: South to North, East to West
*/
//Vertical
    assign cal_en   = (PE_mode[1] == N_2_S)  ? cal_en_N : cal_en_S;
    assign cal_en_N = (PE_mode[1] == S_2_N)  ? cal_en_r : 1'bz;
    assign cal_en_S = (PE_mode[1] == N_2_S)  ? cal_en_r : 1'bz;

    assign cal_done   = (PE_mode[1] == N_2_S)  ? cal_done_N : cal_done_S;
    assign cal_done_N = (PE_mode[1] == S_2_N)  ? cal_done_r : 1'bz;
    assign cal_done_S = (PE_mode[1] == N_2_S)  ? cal_done_r : 1'bz;

    assign v_data   = (PE_mode[1] == N_2_S)  ? v_data_N : v_data_S;
    assign v_data_N = (PE_mode[1] == S_2_N)  ? v_data_r : {RSA_DW{1'bz}};
    assign v_data_S = (PE_mode[1] == N_2_S)  ? v_data_r : {RSA_DW{1'bz}};

//Horizontal
    assign h_data   = (PE_mode[0] == W_2_E)  ? h_data_W : h_data_E;
    assign h_data_W = (PE_mode[0] == E_2_W)  ? h_data_r : {RSA_DW{1'bz}};
    assign h_data_E = (PE_mode[0] == W_2_E)  ? h_data_r : {RSA_DW{1'bz}};

    //输入模式为W_2_E时，结果mulres从east传向west
    assign mulres_val   = (PE_mode[0] == W_2_E)  ? mulres_val_E : mulres_val_W;
    assign mulres_val_W = (PE_mode[0] == W_2_E)  ? mulres_val_r : 1'bz;
    assign mulres_val_E = (PE_mode[0] == E_2_W)  ? mulres_val_r : 1'bz;
    
    assign mulres   = (PE_mode[0] == W_2_E)  ? mulres_E : mulres_W;
    assign mulres_W = (PE_mode[0] == W_2_E)  ? mulres_r : {RSA_DW{1'bz}};
    assign mulres_E = (PE_mode[0] == E_2_W)  ? mulres_r : {RSA_DW{1'bz}};

//乘积 部分和
    reg [RSA_DW-1:0] product;
    reg [RSA_DW-1:0] partial_sum;

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
            product <= 0;
        else if(cal_en == 1'b1)
            product <= h_data * v_data;
        else
            product <= 0;        
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
        else if(cal_done == 1'b1 || mulres_val == 1) begin
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