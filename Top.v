module Top #(
  parameter X = 4,
  parameter Y = 4,
  parameter L = 4,

  parameter RSA_DW = 32,
  parameter RSA_AW = 17,
  parameter TB_AW = 11,
  parameter CB_AW = 17,
  parameter SEQ_CNT_DW = 5,
  parameter ROW_LEN = 10
) (
  input clk,
  input sys_rst,

  //模式控制
    input   [2:0]   stage_val,
    output  [2:0]   stage_rdy,
  //landmark numbers, 当前地图总坐标点数目
    input   [ROW_LEN-1 : 0]  landmark_num,    

  //当前地标编号
    input   [ROW_LEN-1 : 0]  l_k, 

  //预测步数据
    input signed [RSA_DW - 1 : 0] vlr,
    input signed [RSA_DW - 1 : 0] alpha,    //角度输入也为32位

  //更新步数据
    input signed [RSA_DW - 1 : 0] rk,
    input signed [RSA_DW - 1 : 0] phi,

  //AXI BRAM
    output          PLB_clk,
    output          PLB_rst,

    output          PLB_en,   
    output          PLB_we,   
    output  [9:0]   PLB_addr,
    input   [31:0]  PLB_din,
    output  [31:0]  PLB_dout

);
/******************RSA ->  PS*********************/
    assign PLB_clk = clk;
    assign PLB_rst = sys_rst;

/******************RSA ->  NonLinear*********************/
  //开始信号
    wire init_predict, init_newlm, init_update;
  //数据
    wire signed [RSA_DW-1 : 0] xk, yk;     //机器人坐标
    wire signed [RSA_DW-1 : 0] lkx, lky;   //地图坐标
    wire signed [RSA_DW-1 : 0] xita;       //机器人朝向
  
/******************NonLinear ->  RSA*********************/
  //完成信号
    wire done_predict, done_newlm, done_update;
  //数据
    wire signed [RSA_DW - 1 : 0] result_0, result_1, result_2, result_3, result_4, result_5;

RSA 
#(
  .X               (X               ),
  .Y               (Y               ),
  .L               (L               ),

  .RSA_DW          (RSA_DW          ),
  .RSA_AW          (RSA_AW          ),
  .TB_AW           (TB_AW           ),
  .CB_AW           (CB_AW           ),
  .SEQ_CNT_DW      (SEQ_CNT_DW      ),
  .ROW_LEN         (ROW_LEN         )
)
u_RSA(
  .clk          (clk          ),
  .sys_rst      (sys_rst      ),

  .stage_val    (stage_val    ),
  .stage_rdy    (stage_rdy    ),
  .landmark_num (landmark_num ),
  .l_k          (l_k          ),

  .PLB_en        (PLB_en        ),
  .PLB_we        (PLB_we        ),
  .PLB_addr      (PLB_addr      ),
  .PLB_din       (PLB_din       ),
  .PLB_dout      (PLB_dout      ),

  .init_predict (init_predict ),
  .init_newlm   (init_newlm   ),
  .init_update  (init_update  ),
  .xk           (xk           ),
  .yk           (yk           ),
  .lkx          (lkx          ),
  .lky          (lky          ),
  .xita         (xita         ),

  .done_predict (done_predict ),
  .done_newlm   (done_newlm   ),
  .done_update  (done_update  ),
  .result_0     (result_0     ),
  .result_1     (result_1     ),
  .result_2     (result_2     ),
  .result_3     (result_3     ),
  .result_4     (result_4     ),
  .result_5     (result_5     )
);

NonLinear 
#(
  .DW              (RSA_DW              ),
  .AW              (RSA_AW              ),
  .ITER            (4                   )
)
u_NonLinear(
  .clk          (clk          ),
  .rst          (sys_rst          ),
  .init_predict (init_predict ),
  .init_newlm   (init_newlm   ),
  .init_update  (init_update  ),
  .vlr          (vlr          ),
  .rk           (rk           ),
  .lkx          (lkx          ),
  .lky          (lky          ),
  .xk           (xk           ),
  .yk           (yk           ),
  .alpha        ({alpha[31],alpha[19 -: 16]}        ),    //实际输入时转为17位
  .xita         ({xita[31],xita[19 -: 16]}),
  .phi          ({phi[31],phi[19 -: 16]}          ),
  .done_predict (done_predict ),
  .done_newlm   (done_newlm   ),
  .done_update  (done_update  ),
  .result_0     (result_0     ),
  .result_1     (result_1     ),
  .result_2     (result_2     ),
  .result_3     (result_3     ),
  .result_4     (result_4     ),
  .result_5     (result_5     )
);

endmodule

