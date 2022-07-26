`include "macro.v"

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
    `ifdef LANDMARK_NUM_IN
      input   [ROW_LEN-1 : 0]  landmark_num,    
    `endif
  //当前地标编号
    input   [ROW_LEN-1 : 0]  l_k, 

  //预测步数据
    input signed [RSA_DW - 1 : 0] vlr,
    input signed [RSA_AW - 1 : 0] alpha,

  //更新步数据
    input signed [RSA_DW - 1 : 0] rk,
    input signed [RSA_AW - 1 : 0] phi,

  //输出S矩阵
    output signed [RSA_DW - 1 : 0] S_data

);

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
  .S_data       (S_data       ),

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
  .alpha        (alpha        ),
  .xita         ({xita[31],xita[19 -: 16]}),
  .phi          (phi          ),
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

