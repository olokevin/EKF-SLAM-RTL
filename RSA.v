module RSA 
#(
  parameter X = 4,
  parameter Y = 4,
  parameter L = 4,

  parameter RSA_DW = 32,
  parameter RSA_AW = 17,
  parameter TB_AW = 11,
  parameter CB_AW = 17,
  parameter SEQ_CNT_DW = 5,
  parameter ROW_LEN = 10
) 
(

  input   clk,
  input   sys_rst,

/****************** PS -> RSA **************************/
  //handshake of stage change
    input   [2:0]   stage_val,
    output          stage_rdy,

  //更新步数据
    input signed [31 : 0] rk,
    input signed [31 : 0] phi,
  // //landmark numbers, 当前地图总坐标点数目
  //   input   [ROW_LEN-1 : 0]  landmark_num,    
  // //当前地标编号
  //   input   [ROW_LEN-1 : 0]  l_k,  

/****************** RSA -> PS **************************/
  //AXI BRAM
    output          PLB_en,   
    output          PLB_we,   
    output  [31:0]   PLB_addr,
    output  signed [31:0]  PLB_din,
    input   signed [31:0]  PLB_dout,

/******************RSA ->  NonLinear*********************/
  //开始信号
    output init_predict, init_newlm, init_update,
  //数据
    output signed [RSA_DW-1 : 0] xk, yk, xita,     //机器人状态
    output signed [RSA_DW-1 : 0] lkx, lky,        //地图坐标
  
/******************NonLinear ->  RSA*********************/
  //完成信号
    input done_predict, done_newlm, done_update,
  //数据
    input signed [RSA_DW - 1 : 0] result_0, result_1, result_2, result_3, result_4, result_5

);

//PE MUX deMUX数据位宽
  parameter A_IN_SEL_DW = 2;
  parameter B_IN_SEL_DW = 2;
  parameter M_IN_SEL_DW = 2;
  parameter C_OUT_SEL_DW = 2;

//BRAM map 控制信号数据位宽
  parameter TB_DINA_SEL_DW  = 5;
  parameter TB_DINB_SEL_DW  = 2;
  parameter TB_DOUTA_SEL_DW = 3;
  parameter TB_DOUTB_SEL_DW = 5;
  parameter CB_DINA_SEL_DW  = 2;
  parameter CB_DINB_SEL_DW  = 5;
  parameter CB_DOUTA_SEL_DW = 5;  //注意MUX deMUX需手动修改

/*
  ************************* 当前状态量 ***********************
*/
  wire   [ROW_LEN-1 : 0]  landmark_num;  //总地标数
  wire   [ROW_LEN-1 : 0]  l_k;           //当前地标编号
  
  wire l_k_0;
  assign l_k_0 = l_k[0];

  wire [SEQ_CNT_DW-1 : 0] seq_cnt_out;
  wire [2 : 0]            stage_cur_out;
  wire [3 : 0]            prd_cur_out;
  wire [5 : 0]            new_cur_out;
  wire [5 :0]             upd_cur_out;
  wire [5 :0]             assoc_cur_out;
  //stage
  localparam      STAGE_IDLE       = 3'b000 ;
  localparam      STAGE_PRD  = 3'b001 ;
  localparam      STAGE_NEW  = 3'b010 ;
  localparam      STAGE_UPD  = 3'b011 ;
  localparam      STAGE_ASSOC  = 3'b100 ;

/*
  ********************** 接收非线性发回的数据 *******************
*/
  //预测步
  reg signed [RSA_DW - 1 : 0] x_hat, y_hat, xita_hat;
  reg signed [RSA_DW - 1 : 0] Fxi_13, Fxi_23;
  //新地标步
  reg signed [RSA_DW - 1 : 0] lkx_hat, lky_hat;
  reg signed [RSA_DW - 1 : 0] Gxi_13, Gxi_23, Gz_11, Gz_12, Gz_21, Gz_22;
  //更新步
  reg signed [RSA_DW - 1 : 0] Hz_11, Hz_12, Hz_21, Hz_22;
  reg signed [RSA_DW - 1 : 0] Hxi_11, Hxi_12, Hxi_21, Hxi_22;
  reg signed [RSA_DW - 1 : 0] vt_1, vt_2;

//(old) sampling nonlinear data
  // always @(posedge clk) begin
  //   if(sys_rst) begin
  //         x_hat <= 0;
  //         y_hat <= 0;
  //         xita_hat <= 0;
  //         Fxi_13 <= 0;
  //         Fxi_23 <= 0;
  //         lkx_hat = 0;
  //         lky_hat = 0;
  //         Gxi_13 = 0;
  //         Gxi_23 = 0;
  //         Gz_11 = 0;
  //         Gz_12 = 0;
  //         Gz_21 = 0;
  //         Gz_22 = 0;
  //         Hxi_11 = 0;
  //         Hxi_12 = 0;
  //         Hxi_21 = 0;
  //         Hxi_22 = 0;
  //         Hz_11 = 0;
  //         Hz_12 = 0;
  //         Hz_21 = 0;
  //         Hz_22 = 0;
  //         vt_1 = 0;
  //         vt_2 = 0;
  //       end
  //   else begin
  //     case (stage_cur_out)
  //       STAGE_PRD: begin
  //         x_hat <= xk + result_2;
  //         y_hat <= yk + result_3;
  //         xita_hat <= xita + result_1;
  //         Fxi_13 <= - result_3;
  //         Fxi_23 <= result_2;
  //       end
  //       STAGE_NEW: begin
  //         lkx_hat = lkx + result_3;
  //         lky_hat = lky + result_2;
  //         Gxi_13 = -result_2;
  //         Gxi_23 = result_3;
  //         Gz_11 = result_0;
  //         Gz_12 = -result_2;
  //         Gz_21 = result_1;
  //         Gz_22 = result_3;
  //       end
  //       STAGE_UPD: begin
  //         Hxi_11 = -result_4;
  //         Hxi_12 = -result_5;
  //         Hxi_21 = result_2;
  //         Hxi_22 = -result_3;
  //         Hz_11 = result_4;
  //         Hz_12 = result_5;
  //         Hz_21 = -result_2;
  //         Hz_22 = result_3;
  //         vt_1 = result_0;
  //         vt_2 = result_1;
  //       end 
  //       default: begin
  //         x_hat <= 0;
  //         y_hat <= 0;
  //         xita_hat <= 0;
  //         Fxi_13 <= 0;
  //         Fxi_23 <= 0;
  //         lkx_hat = 0;
  //         lky_hat = 0;
  //         Gxi_13 = 0;
  //         Gxi_23 = 0;
  //         Gz_11 = 0;
  //         Gz_12 = 0;
  //         Gz_21 = 0;
  //         Gz_22 = 0;
  //         Hxi_11 = 0;
  //         Hxi_12 = 0;
  //         Hxi_21 = 0;
  //         Hxi_22 = 0;
  //         Hz_11 = 0;
  //         Hz_12 = 0;
  //         Hz_21 = 0;
  //         Hz_22 = 0;
  //         vt_1 = 0;
  //         vt_2 = 0;
  //       end
  //     endcase
  //   end
  // end

//(using) sampling
  always @(posedge clk) begin
    if(sys_rst) begin
      x_hat <= 0;
      y_hat <= 0;
      xita_hat <= 0;
      Fxi_13 <= 0;
      Fxi_23 <= 0;
    end
    else if(done_predict == 1'b1) begin
      x_hat <= xk + result_2;
      y_hat <= yk + result_3;
      xita_hat <= xita + result_1;
      Fxi_13 <= - result_3;
      Fxi_23 <= result_2;
    end
  end

  always @(posedge clk) begin
    if(sys_rst) begin
      lkx_hat <= 0;
      lky_hat <= 0;
      Gxi_13 <= 0;
      Gxi_23 <= 0;
      Gz_11 <= 0;
      Gz_12 <= 0;
      Gz_21 <= 0;
      Gz_22 <= 0;
    end
    else if(done_newlm == 1'b1) begin
      lkx_hat <= lkx + result_3;
      lky_hat <= lky + result_2;
      Gxi_13 <= -result_2;
      Gxi_23 <= result_3;
      Gz_11 <= result_0;
      Gz_12 <= -result_2;
      Gz_21 <= result_1;
      Gz_22 <= result_3;
    end
  end

  always @(posedge clk) begin
    if(sys_rst) begin
      Hxi_11 <= 0;
      Hxi_12 <= 0;
      Hxi_21 <= 0;
      Hxi_22 <= 0;
      Hz_11 <= 0;
      Hz_12 <= 0;
      Hz_21 <= 0;
      Hz_22 <= 0;
      vt_1 <= 0;
      vt_2 <= 0;
    end
    else if(done_update == 1'b1) begin
      Hxi_11 <= -result_4;
      Hxi_12 <= -result_5;
      Hxi_21 <= result_2;
      Hxi_22 <= -result_3;
      Hz_11 <= result_4;
      Hz_12 <= result_5;
      Hz_21 <= -result_2;
      Hz_22 <= result_3;
      vt_1 <= result_0 - rk;
      vt_2 <= result_1 - phi;
    end
  end

/*
  (old) PE_array
*/
  // //PE互连信号线
  // wire  [(X-1)*Y:0]     n_cal_en;   //由于输出可能接到模块，故将输出的坐标与PE坐标绑定，输入与来源的PE坐标绑定
  // wire  [(X-1)*Y:0]     n_cal_done;   //n_cal_en[0]接到(1,1)的PE 其余与PE坐标一致

  // wire  [X*RSA_DW*Y:1]  westin;
  // wire  [Y*RSA_DW*X:1]  southin;

  // wire  [X*Y:1]     dout_val;
  // wire  [X*RSA_DW*Y:1]   dout;
  // wire  [RSA_DW : 1]   dout_test;

  // //PE阵列
  // generate
  //   genvar i,j;
  //   for(i=1; i<=X; i=i+1) begin: PE_X
  //   for(j=1; j<=Y; j=j+1) begin: PE_Y
  //   /*
  //     第(i,j)个PE data：[ LEN*((i-1)*Y+j) : LEN*((i-1)*Y+j-1) + 1 ]
  //     第(i,j)个PE sig:  [(i-1)*Y+j]

  //     n_cal_en n_cal_done dout_val: PE sig, 对应本PE的坐标
  //     westin southin dout: PE data, 对应本PE的坐标

  //     westin 向右传递  -> eastout  对应 j+1 的westin
  //     southin 向上传递 -> northout 对应 i+1 的southin
  //     cal_en cal_done ->    对应 i-1 的n_cal_en
  //     din       对应 j+1 的dout

  //     定义：实际左下角的PE为PE11 对应第1行 第1列 结TB_0 CB_0

  //     最后一行的n_cal_en, n_cal_done 向右传递
  //     其他行的n_cal_en, n_cal_done   向上传递
  //     dout dout_val 向左传递
  //   */
  //     //第一行 cal_en cal_done
  //     //第一行的cal_en cal_done来自所在列上一列 j-1
  //     if(i==1 && j==1) begin
  //     PE_MAC 
  //     #(
  //       .RSA_DW (RSA_DW )
  //     )
  //     u_PE_MAC(
  //       .clk  (clk  ),
  //       .sys_rst  (sys_rst  ),
  //       .cal_en   (n_cal_en[j-1]   ),  //第一行的cal_en cal_done来自所在列上一列 j-1
  //       .cal_done   (n_cal_done[j-1]   ),
  //       .westin   (westin[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]   ),
  //       .southin  (southin[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]  ),
  //       .din_val  (dout_val[(i-1)*Y+j+1]  ),
  //       .din  (dout[RSA_DW*((i-1)*Y+j+1) : RSA_DW*((i-1)*Y+j)+1]  ),
  //       .n_cal_en   (n_cal_en[(i-1)*Y+j]   ),
  //       .n_cal_done (n_cal_done[(i-1)*Y+j] ),
  //       .eastout  (westin[RSA_DW*((i-1)*Y+j+1) : RSA_DW*((i-1)*Y+j)+1]  ),
  //       .northout   (southin[RSA_DW*(i*Y+j) : RSA_DW*(i*Y+j-1)+1]   ),
  //       .dout_val   (dout_val[(i-1)*Y+j]   ),  
  //       .dout   (dout[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]   )
  //     );
  //     end
  //     else if(i==1 && j!=1 && j!=Y) begin
  //     PE_MAC 
  //     #(
  //       .RSA_DW (RSA_DW )
  //     )
  //     u_PE_MAC(
  //       .clk  (clk  ),
  //       .sys_rst  (sys_rst  ),
  //       .cal_en   (n_cal_en[j-1]   ),  //第一行的cal_en cal_done来自所在列上一列 j-1
  //       .cal_done   (n_cal_done[j-1]   ),
  //       .westin   (westin[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]   ),
  //       .southin  (southin[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]  ),
  //       .din_val  (dout_val[(i-1)*Y+j+1]  ),
  //       .din  (dout[RSA_DW*((i-1)*Y+j+1) : RSA_DW*((i-1)*Y+j)+1]  ),
  //       .n_cal_en   (n_cal_en[(i-1)*Y+j]   ),
  //       .n_cal_done (n_cal_done[(i-1)*Y+j] ),
  //       .eastout  (westin[RSA_DW*((i-1)*Y+j+1) : RSA_DW*((i-1)*Y+j)+1]  ),
  //       .northout   (southin[RSA_DW*(i*Y+j) : RSA_DW*(i*Y+j-1)+1]   ),
  //       .dout_val   (dout_val[(i-1)*Y+j]   ),  
  //       .dout   (dout[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]   )
  //     );
  //     end
  //     //第一行的最后一个，没有din din_val eastout
  //     else if(i==1 && j==Y) begin
  //     PE_MAC 
  //     #(
  //       .RSA_DW  (RSA_DW )
  //     )
  //     u_PE_MAC(
  //       .clk  (clk  ),
  //       .sys_rst  (sys_rst  ),
  //       .cal_en   (n_cal_en[j-1]   ),  //第一列的cal_en cal_done来自该列上一列 j-1
  //       .cal_done   (n_cal_done[j-1]   ),
  //       .westin   (westin[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]   ),
  //       .southin  (southin[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]  ),
  //       .din_val  (   ),
  //       .din  (  ),
  //       .n_cal_en   (n_cal_en[(i-1)*Y+j]   ),
  //       .n_cal_done (n_cal_done[(i-1)*Y+j] ),
  //       .eastout  (  ),
  //       .northout   (southin[RSA_DW*(i*Y+j) : RSA_DW*(i*Y+j-1)+1]   ),
  //       .dout_val   (dout_val[(i-1)*Y+j]   ),  
  //       .dout   (dout[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]   )
  //     );
  //     end
  //     //中间部分
  //     else if(i>1 && i<X && j<Y) begin
  //     PE_MAC 
  //     #(
  //       .RSA_DW (RSA_DW )
  //     )
  //     u_PE_MAC(
  //       .clk  (clk  ),
  //       .sys_rst  (sys_rst  ),
  //       .cal_en   (n_cal_en[(i-2)*Y+j]   ),           //cal_en cal_done来自下一行
  //       .cal_done   (n_cal_done[(i-2)*Y+j]   ),
  //       .westin   (westin[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]   ),   //westin，southin 按PE模块位置设置
  //       .southin  (southin[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]  ),
  //       .din_val  (dout_val[(i-1)*Y+j+1]  ),          //din来自右边 j+1
  //       .din  (dout[RSA_DW*((i-1)*Y+j+1) : RSA_DW*((i-1)*Y+j)+1]  ),
  //       .n_cal_en   (n_cal_en[(i-1)*Y+j]   ),           //n_cal_en 按PE模块位置设置
  //       .n_cal_done (n_cal_done[(i-1)*Y+j] ),
  //       .eastout  (westin[RSA_DW*((i-1)*Y+j+1) : RSA_DW*((i-1)*Y+j)+1]  ),  //eastout传到右边 j+1
  //       .northout   (southin[RSA_DW*(i*Y+j) : RSA_DW*(i*Y+j-1)+1]   ),  //northout传到下边 i+1
  //       .dout_val   (dout_val[(i-1)*Y+j]   ),           //dout  按PE模块位置设置
  //       .dout   (dout[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]   )
  //     );
  //     end
  //     //最后一行，没有northout, n_cal_en, n_cal_done
  //     else if(i==X && j!=Y) begin
  //     PE_MAC 
  //     #(
  //       .RSA_DW (RSA_DW )
  //     )
  //     u_PE_MAC(
  //       .clk  (clk  ),
  //       .sys_rst  (sys_rst  ),
  //       .cal_en   (n_cal_en[(i-2)*Y+j]   ),           
  //       .cal_done   (n_cal_done[(i-2)*Y+j]   ),
  //       .westin   (westin[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]   ),  
  //       .southin  (southin[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]  ),
  //       .din_val  (dout_val[(i-1)*Y+j+1]  ),  
  //       .din  (dout[RSA_DW*((i-1)*Y+j+1) : RSA_DW*((i-1)*Y+j)+1]  ),
  //       .n_cal_en   (  ),   
  //       .n_cal_done (  ),
  //       .eastout  (westin[RSA_DW*((i-1)*Y+j+1) : RSA_DW*((i-1)*Y+j)+1]  ),  
  //       .northout   (  ),   
  //       .dout_val   (dout_val[(i-1)*Y+j]   ),  
  //       .dout   (dout[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]   )
  //     );
  //     end
  //     //最右一列，没有eastout，没有din
  //     else if(i!=1 && i!=X && j==Y) begin
  //     PE_MAC 
  //     #(
  //       .RSA_DW (RSA_DW )
  //     )
  //     u_PE_MAC(
  //       .clk  (clk  ),
  //       .sys_rst  (sys_rst  ),
  //       .cal_en   (n_cal_en[(i-2)*Y+j]   ),  
  //       .cal_done   (n_cal_done[(i-2)*Y+j]   ),
  //       .westin   (westin[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]   ),  
  //       .southin  (southin[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]  ),
  //       .din_val  (  ),  
  //       .din  (  ),
  //       .n_cal_en   (n_cal_en[(i-1)*Y+j]   ),   
  //       .n_cal_done (n_cal_done[(i-1)*Y+j] ),
  //       .eastout  (  ),  
  //       .northout   (southin[RSA_DW*(i*Y+j) : RSA_DW*(i*Y+j-1)+1]   ),   
  //       .dout_val   (dout_val[(i-1)*Y+j]   ),  
  //       .dout   (dout[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]   )
  //     );
  //     end
  //     //右上角，没有eastout, northout, din, n_cal_en, n_cal_done
  //     else if(i==X && j==Y) begin
  //     PE_MAC 
  //     #(
  //       .RSA_DW (RSA_DW )
  //     )
  //     u_PE_MAC(
  //       .clk  (clk  ),
  //       .sys_rst  (sys_rst  ),
  //       .cal_en   (n_cal_en[(i-2)*Y+j]   ),  
  //       .cal_done   (n_cal_done[(i-2)*Y+j]   ),
  //       .westin   (westin[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]   ),  
  //       .southin  (southin[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]  ),
  //       .din_val  (  ),  
  //       .din  (   ),
  //       .n_cal_en   ( ),   
  //       .n_cal_done ( ),
  //       .eastout  ( ),  
  //       .northout   ( ),  
  //       .dout_val   (dout_val[(i-1)*Y+j]   ),  
  //       .dout   (dout[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]   )
  //     );
  //     end
  //   end
  //   end
  // endgenerate



wire   signed [X*RSA_DW-1 : 0]  A_data;
wire   signed [Y*RSA_DW-1 : 0]  B_data;
wire   signed [X*RSA_DW-1 : 0]  M_data;
wire   signed [X*RSA_DW-1 : 0]  C_data;

wire   [2*X-1 : 0]    M_adder_mode;
wire   [1:0]          PE_mode;
wire   [Y-1 : 0]      new_cal_en;
wire   [Y-1 : 0]      new_cal_done;

  PE_array 
  #(
    .X      (X  ),
    .Y      (Y  ),
    .L      (L  ),
    .RSA_DW (RSA_DW )
  )
  u_PE_array(
    .clk          (clk    ),
    .sys_rst      (sys_rst  ),
    .PE_mode      (PE_mode  ),
    .A_data       (A_data   ),
    .B_data       (B_data   ),
    .M_data       (M_data   ),
    .C_data       (C_data   ),
    .new_cal_en    (new_cal_en  ),
    .new_cal_done  (new_cal_done  ),
    .M_adder_mode (M_adder_mode )
  );


//A in
wire signed [X*RSA_DW-1 : 0]   A_TB_douta;
wire signed [X*RSA_DW-1 : 0]   A_CB_douta;
wire [A_IN_SEL_DW*X-1 : 0]        A_in_sel;
wire [X-1 : 0]          A_in_en;   


//B in
wire signed [Y*RSA_DW-1 : 0]   B_TB_doutb; 
wire signed [Y*RSA_DW-1 : 0]   B_CB_douta;
wire [B_IN_SEL_DW*Y-1 : 0]        B_in_sel;     //B_in有三个来源
wire [Y-1 : 0]          B_in_en;   

//M in
wire signed [X*RSA_DW-1 : 0]   M_TB_douta; 
wire signed [X*RSA_DW-1 : 0]   M_CB_douta;
wire [M_IN_SEL_DW*X-1 : 0]        M_in_sel;  
wire [X-1 : 0]          M_in_en;  

//C out
wire signed [X*RSA_DW-1 : 0]   C_TB_dinb; 
wire signed [X*RSA_DW-1 : 0]   C_CB_dinb;
wire signed [X*RSA_DW-1 : 0]   C_B_cache_din;
wire signed [X*RSA_DW-1 : 0]   C_PLB_din;
wire [C_OUT_SEL_DW*X-1 : 0]        C_out_sel; 
wire [X-1 : 0]          C_out_en; 

wire signed [L*RSA_DW-1 : 0]   TB_dina_CB_douta;
wire signed [L*RSA_DW-1 : 0]   TB_dina_non_linear;

//B_cache -> ABCM
wire signed [X*RSA_DW-1 : 0]    B_cache_dout_A;
wire signed [Y*RSA_DW-1 : 0]    B_cache_dout_B;
wire signed [X*RSA_DW-1 : 0]    B_cache_dout_M;

generate 
  genvar i_X;
    for(i_X=0; i_X<=X-1; i_X=i_X+1) begin: DATA_X
      // regMUX_sel2 
      // #(
      //   .RSA_DW (RSA_DW )
      // )
      // A_regMUX_sel2(
      // 	.clk     (clk     ),
      //   .sys_rst (sys_rst ),
      //   .en      (A_in_en[i_X]      ),
      //   .sel     (A_in_sel[2*i_X+2 : 2*i_X]     ),
      //   .din_00  (A_TB_douta[RSA_DW*i_X+RSA_DW-1 : RSA_DW*i_X]  ),
      //   .din_01  (B_cache_dout_A[RSA_DW*i_X+RSA_DW-1 : RSA_DW*i_X] ),
      //   .din_10  (A_CB_douta[RSA_DW*i_X+RSA_DW-1 : RSA_DW*i_X]  ),
      //   .din_11  (0  ),
      //   .dout    (A_data[RSA_DW*i_X+RSA_DW-1 : RSA_DW*i_X]    )
      // );

      // regMUX_sel2 
      // #(
      //   .RSA_DW (RSA_DW )
      // )
      // M_regMUX_sel2(
      // 	.clk     (clk     ),
      //   .sys_rst (sys_rst ),
      //   .en      (M_in_en[i_X]      ),
      //   .sel     (M_in_sel[2*i_X+2 : 2*i_X]     ),
      //   .din_00  (M_TB_douta[RSA_DW*i_X+RSA_DW-1 : RSA_DW*i_X]  ),
      //   .din_01  (B_cache_dout_M[RSA_DW*i_X+RSA_DW-1 : RSA_DW*i_X] ),
      //   .din_10  (M_CB_douta[RSA_DW*i_X+RSA_DW-1 : RSA_DW*i_X]  ),
      //   .din_11  (0  ),
      //   .dout    (M_data[RSA_DW*i_X+RSA_DW-1 : RSA_DW*i_X]    )
      // );

      // regdeMUX_sel2 
      // #(
      //   .RSA_DW (RSA_DW )
      // )
      // C_regdeMUX_sel2(
      // 	.clk     (clk     ),
      //   .sys_rst (sys_rst ),
      //   .en      (C_out_en[i_X]      ),
      //   .sel     (C_out_sel[2*i_X+2 : 2*i_X]     ),
      //   .din     (C_data[RSA_DW*i_X+RSA_DW-1 : RSA_DW*i_X]     ),
      //   .dout_00 (C_TB_dinb[RSA_DW*i_X+RSA_DW-1 : RSA_DW*i_X] ),
      //   .dout_01 (C_B_cache_din[RSA_DW*i_X+RSA_DW-1 : RSA_DW*i_X] ),
      //   .dout_10 (C_CB_dinb[RSA_DW*i_X+RSA_DW-1 : RSA_DW*i_X] ),
      //   .dout_11 (C_PLB_din[RSA_DW*i_X+RSA_DW-1 : RSA_DW*i_X] )
      // );
      
      regMUX_sel2 
      #(
        .RSA_DW (RSA_DW )
      )
      A_regMUX_sel2(
      	.clk     (clk     ),
        .sys_rst (sys_rst ),
        .en      (A_in_en[i_X]      ),
        .sel     (A_in_sel[2*i_X +: 2]     ),
        .din_00  (A_TB_douta[RSA_DW*i_X +: RSA_DW]  ),
        .din_01  (B_cache_dout_A[RSA_DW*i_X +: RSA_DW] ),
        .din_10  (A_CB_douta[RSA_DW*i_X +: RSA_DW]  ),
        .din_11  (0  ),
        .dout    (A_data[RSA_DW*i_X +: RSA_DW]    )
      );

      regMUX_sel2 
      #(
        .RSA_DW (RSA_DW )
      )
      M_regMUX_sel2(
      	.clk     (clk     ),
        .sys_rst (sys_rst ),
        .en      (M_in_en[i_X]      ),
        .sel     (M_in_sel[2*i_X +: 2]     ),
        .din_00  (M_TB_douta[RSA_DW*i_X +: RSA_DW]  ),
        .din_01  (B_cache_dout_M[RSA_DW*i_X +: RSA_DW] ),
        .din_10  (M_CB_douta[RSA_DW*i_X +: RSA_DW]  ),
        .din_11  (0  ),
        .dout    (M_data[RSA_DW*i_X +: RSA_DW]    )
      );

      regdeMUX_sel2 
      #(
        .RSA_DW (RSA_DW )
      )
      C_regdeMUX_sel2(
      	.clk     (clk     ),
        .sys_rst (sys_rst ),
        .en      (C_out_en[i_X]      ),
        .sel     (C_out_sel[2*i_X +: 2]     ),
        .din     (C_data[RSA_DW*i_X +: RSA_DW]     ),
        .dout_00 (C_TB_dinb[RSA_DW*i_X +: RSA_DW] ),
        .dout_01 (C_B_cache_din[RSA_DW*i_X +: RSA_DW] ),
        .dout_10 (C_CB_dinb[RSA_DW*i_X +: RSA_DW] ),
        .dout_11 (C_PLB_din[RSA_DW*i_X +: RSA_DW] )
      );
     
  end
endgenerate

//Bin 临时寄存H

wire [Y-1:0] B_cache_en;
wire [Y-1:0] B_cache_we;
wire [Y*3-1:0] B_cache_addr;

wire signed [Y*RSA_DW-1:0] B_cache_din; 
wire signed [Y*RSA_DW-1:0] B_cache_TB_doutb; //TB_doutb -> B_cache

wire signed [Y*RSA_DW-1:0] B_cache_dout; 

wire [3:0]   B_cache_in_sel;   //in_map
wire [3:0]   B_cache_out_sel;  //out_map

/*有out_map多buffer一级，无需手动延迟*/
// reg  signed [Y*RSA_DW-1:0] B_cache_dout_d;    //B_cache需加一级缓冲(比TB CB少一个map)
// always @(posedge clk) begin
//   if(sys_rst) begin
//     B_cache_dout_d <= 0;
//   end
//   else 
//     B_cache_dout_d <= B_cache_dout;
// end

generate
  genvar i_Y;
  for(i_Y=0; i_Y<=Y-1; i_Y=i_Y+1) begin: DATA_Y
    // t_ram 
    // #(
    //   .DW (RSA_DW ),
    //   .AW (3 )
    // )
    // B_cache_ram(
    // 	.clk     (clk     ),
    //   .sys_rst (sys_rst ),
    //   .en      (B_cache_en[i_Y]      ),
    //   .we      (B_cache_we[i_Y]      ),
    //   .addr    (B_cache_addr[3*i_Y+3 : 3*i_Y]    ),
    //   .din     (B_cache_din[RSA_DW*i_Y +RSA_DW-1 : RSA_DW*i_Y ]     ),
    //   .dout    (B_cache_dout[RSA_DW*i_Y +RSA_DW-1 : RSA_DW*i_Y ]    )
    // );
    
    // regMUX_sel2 
    // #(
    //   .RSA_DW (RSA_DW )
    // )
    // B_regMUX_sel2(
    //   .clk     (clk   ),
    //   .sys_rst (sys_rst ),
    //   .en      (B_in_en[i_Y]  ),
    //   .sel     (B_in_sel[2*i_Y+2 : 2*i_Y]   ),
    //   .din_00  (B_TB_doutb[RSA_DW*i_Y +RSA_DW-1 : RSA_DW*i_Y ]  ),
    //   .din_01  (B_cache_dout_B[RSA_DW*i_Y +RSA_DW-1 : RSA_DW*i_Y ]  ),
    //   .din_10  (B_CB_douta[RSA_DW*i_Y +RSA_DW-1 : RSA_DW*i_Y ]  ),
    //   .din_11  (0   ),
    //   .dout    (B_data[RSA_DW*i_Y +RSA_DW-1 : RSA_DW*i_Y ]  )
    // );

    t_ram 
    #(
      .DW (RSA_DW ),
      .AW (3 )
    )
    B_cache_ram(
    	.clk     (clk     ),
      .sys_rst (sys_rst ),
      .en      (B_cache_en[i_Y]      ),
      .we      (B_cache_we[i_Y]      ),
      .addr    (B_cache_addr[3*i_Y +: 3]    ),
      .din     (B_cache_din[RSA_DW*i_Y +: RSA_DW]     ),
      .dout    (B_cache_dout[RSA_DW*i_Y +: RSA_DW]    )
    );
    
    regMUX_sel2 
    #(
      .RSA_DW (RSA_DW )
    )
    B_regMUX_sel2(
      .clk     (clk   ),
      .sys_rst (sys_rst ),
      .en      (B_in_en[i_Y]  ),
      .sel     (B_in_sel[2*i_Y +: 2]   ),
      .din_00  (B_TB_doutb[RSA_DW*i_Y +: RSA_DW]  ),
      .din_01  (B_cache_dout_B[RSA_DW*i_Y +: RSA_DW]  ),
      .din_10  (B_CB_douta[RSA_DW*i_Y +: RSA_DW]  ),
      .din_11  (0   ),
      .dout    (B_data[RSA_DW*i_Y +: RSA_DW]  )
    );
  end
endgenerate

/*
  ********************** cache map ports **********************
*/
wire        init_inv;
wire        done_inv;

B_cache_din_map 
#(
  .X          (X          ),
  .Y          (Y          ),
  .L          (L          ),
  .RSA_DW     (RSA_DW     ),
  .SEQ_CNT_DW (SEQ_CNT_DW )
)
u_B_cache_din_map(
  .clk            (clk            ),
  .sys_rst        (sys_rst        ),
  .B_cache_in_sel (B_cache_in_sel ),
  .seq_cnt_out    (seq_cnt_out    ),
  .B_cache_TB_doutb (B_cache_TB_doutb),
  .C_B_cache_din  (C_B_cache_din  ),
  .Fxi_13         (Fxi_13         ),
  .Fxi_23         (Fxi_23         ),
  .Gxi_13         (Gxi_13         ),
  .Gxi_23         (Gxi_23         ),
  .Gz_11          (Gz_11          ),
  .Gz_12          (Gz_12          ),
  .Gz_21          (Gz_21          ),
  .Gz_22          (Gz_22          ),
  .Hz_11          (Hz_11          ),
  .Hz_12          (Hz_12          ),
  .Hz_21          (Hz_21          ),
  .Hz_22          (Hz_22          ),
  .Hxi_11         (Hxi_11         ),
  .Hxi_12         (Hxi_12         ),
  .Hxi_21         (Hxi_21         ),
  .Hxi_22         (Hxi_22         ),
  .vt_1           (vt_1           ),
  .vt_2           (vt_2           ),

  .init_inv      (init_inv      ),
  .done_inv      (done_inv      ),
  .B_cache_din    (B_cache_din    )
);

B_cache_dout_map 
#(
  .X          (X          ),
  .Y          (Y          ),
  .L          (L          ),
  .RSA_DW     (RSA_DW     ),
  .SEQ_CNT_DW (SEQ_CNT_DW )
)
u_B_cache_dout_map(
  .clk             (clk             ),
  .sys_rst         (sys_rst         ),
  .B_cache_out_sel (B_cache_out_sel ),
  .B_cache_dout    (B_cache_dout    ),
  .B_cache_dout_A  (B_cache_dout_A  ),
  .B_cache_dout_B  (B_cache_dout_B  ),
  .B_cache_dout_M  (B_cache_dout_M  )
);

/*
  ********************** PS-PL BRAM ports **********************
*/

wire  [1:0]             assoc_status;
wire  [ROW_LEN-1 : 0]   assoc_l_k;

PLB_din_map 
#(
  .X          (X          ),
  .Y          (Y          ),
  .L          (L          ),
  .RSA_DW     (RSA_DW     ),
  .SEQ_CNT_DW (SEQ_CNT_DW ),
  .ROW_LEN    (ROW_LEN    )
)
u_PLB_din_map(
  .clk         (clk         ),
  .sys_rst     (sys_rst     ),
  .l_k           (l_k           ),
  .seq_cnt_out   (seq_cnt_out   ),
  .prd_cur_out   (prd_cur_out   ),
  .new_cur_out   (new_cur_out   ),
  .upd_cur_out   (upd_cur_out   ),
  .assoc_cur_out (assoc_cur_out ),

  .xk            (xk            ),
  .yk            (yk            ),
  .xita          (xita          ),
  .lkx           (lkx           ),
  .lky           (lky           ),

  .x_hat       (x_hat       ),
  .y_hat       (y_hat       ),
  .xita_hat    (xita_hat    ),
  .lkx_hat     (lkx_hat         ),
  .lky_hat     (lky_hat         ),

  .C_PLB_din   (C_PLB_din   ),
  .PLB_dout    (PLB_dout    ),
  .PLB_en      (PLB_en      ),
  .PLB_we      (PLB_we      ),
  .PLB_addr    (PLB_addr    ),
  .PLB_din     (PLB_din     ),
  .assoc_status(assoc_status),
  .assoc_l_k   (assoc_l_k)
);


/*
  ********************** BRAM map ports **********************
*/
//TEMP BRAM
wire [TB_DINA_SEL_DW-1 : 0]    TB_dina_sel;
wire [TB_DINB_SEL_DW-1 : 0]    TB_dinb_sel;
wire [TB_DOUTA_SEL_DW-1 : 0]   TB_douta_sel;
wire [TB_DOUTB_SEL_DW-1 : 0]   TB_doutb_sel;

wire [L-1 : 0]    TB_ena;
wire [L-1 : 0]    TB_enb;

wire [L-1 : 0]    TB_wea;
wire [L-1 : 0]    TB_web;

wire signed [L*RSA_DW-1 : 0] TB_dina;
wire [L*TB_AW-1 : 0] TB_addra;
wire signed [L*RSA_DW-1 : 0] TB_dinb;
wire [L*TB_AW-1 : 0] TB_addrb;

wire signed [L*RSA_DW-1 : 0] TB_douta;
wire signed [L*RSA_DW-1 : 0] TB_doutb;

//COV BRAM
// wire [CB_DINA_SEL_DW-1 : 0]    CB_dina_sel;
wire [CB_DINB_SEL_DW-1 : 0]    CB_dinb_sel;
wire [CB_DOUTA_SEL_DW-1 : 0]   CB_douta_sel;

wire [L-1 : 0]    CB_ena;
wire [L-1 : 0]    CB_enb;

wire [L-1 : 0]    CB_wea;
wire [L-1 : 0]    CB_web;

wire signed [L*RSA_DW-1 : 0] CB_dina;
wire [L*CB_AW-1 : 0] CB_addra;
wire signed [L*RSA_DW-1 : 0] CB_dinb;
wire [L*CB_AW-1 : 0] CB_addrb;

wire signed [L*RSA_DW-1 : 0] CB_douta;
wire signed [L*RSA_DW-1 : 0] CB_doutb;

//l_k
// `ifndef L_k_IN
//   reg [ROW_LEN-1 : 0] l_k = 3'b100;
// `endif


//TEMP_BANK data MUX and deMUX
  TB_dina_map 
  #(
    .X              (X              ),
    .Y              (Y              ),
    .L              (L              ),
    .RSA_DW         (RSA_DW         ),
    .SEQ_CNT_DW     (SEQ_CNT_DW     ),
    .TB_DINA_SEL_DW (TB_DINA_SEL_DW )
  )
  u_TB_dina_map(
  	.clk                (clk                ),
    .sys_rst            (sys_rst            ),
    .TB_dina_sel        (TB_dina_sel        ),
    .l_k_0              (l_k_0              ),
    .seq_cnt_out        (seq_cnt_out        ),

    .TB_dina_CB_douta   (TB_dina_CB_douta   ),

    // .Fxi_13             (Fxi_13           ),
    // .Fxi_23             (Fxi_23           ),
    // .Gxi_13           (Gxi_13           ),
    // .Gxi_23           (Gxi_23           ),
    // .Gz_11            (Gz_11            ),
    // .Gz_12            (Gz_12            ),
    // .Gz_21            (Gz_21            ),
    // .Gz_22            (Gz_22            ),
    // .Hz_11            (Hz_11            ),
    // .Hz_12            (Hz_12            ),
    // .Hz_21            (Hz_21            ),
    // .Hz_22            (Hz_22            ),
    // .Hxi_11           (Hxi_11           ),
    // .Hxi_12           (Hxi_12           ),
    // .Hxi_21           (Hxi_21           ),
    // .Hxi_22           (Hxi_22           ),
    .vt_1             (vt_1             ),
    .vt_2             (vt_2             ),

    .TB_dina            (TB_dina            )
  );
  
  
  TB_dinb_map 
  #(
    .X      (X      ),
    .Y      (Y      ),
    .L      (L      ),
    .RSA_DW (RSA_DW ),
    .TB_DINB_SEL_DW(TB_DINB_SEL_DW)
  )
  u_TB_dinb_map(
  	.clk         (clk         ),
    .sys_rst     (sys_rst     ),
    .TB_dinb_sel (TB_dinb_sel ),
    .l_k_0       (l_k_0       ),
    .C_TB_dinb   (C_TB_dinb   ),
    .TB_dinb     (TB_dinb     )
  );

  TB_douta_map 
  #(
    .X      (X      ),
    .Y      (Y      ),
    .L      (L      ),
    .RSA_DW (RSA_DW ),
    .TB_DOUTA_SEL_DW (TB_DOUTA_SEL_DW)
  )
  u_TB_douta_map(
  	.clk          (clk          ),
    .sys_rst      (sys_rst      ),
    .TB_douta_sel (TB_douta_sel ),
    .l_k_0       (l_k_0       ),
    .TB_douta     (TB_douta     ),
    .A_TB_douta   (A_TB_douta   ),
    .M_TB_douta   (M_TB_douta   )
  );
  
  TB_doutb_map 
  #(
    .X         (X         ),
    .Y         (Y         ),
    .L         (L         ),
    .RSA_DW    (RSA_DW    ),
    .SEQ_CNT_DW (SEQ_CNT_DW),
    .TB_DOUTB_SEL_DW (TB_DOUTB_SEL_DW)
  )
  u_TB_doutb_map(
  	.clk             (clk             ),
    .sys_rst         (sys_rst         ),
    .TB_doutb_sel    (TB_doutb_sel    ),
    .l_k_0       (l_k_0       ),
    .seq_cnt_out (seq_cnt_out),
    .TB_doutb        (TB_doutb        ),
    .B_TB_doutb      (B_TB_doutb      ),
    .B_cache_TB_doutb (B_cache_TB_doutb )
  );

//COV BANK data MUX and deMUX
  CB_dinb_map 
  #(
    .X       (X       ),
    .Y       (Y       ),
    .L       (L       ),
    .RSA_DW  (RSA_DW  ),
    .CB_DINB_SEL_DW(CB_DINB_SEL_DW)
  )
  u_CB_dinb_map(
  	.clk          (clk          ),
    .sys_rst      (sys_rst      ),
    .CB_dinb_sel  (CB_dinb_sel  ),
    .l_k_0        (l_k_0        ),
    .seq_cnt_out  (seq_cnt_out  ),

    // .x_hat       (x_hat       ),
    // .y_hat       (y_hat       ),
    // .xita_hat    (xita_hat    ),
    // .lkx_hat     (lkx_hat         ),
    // .lky_hat     (lky_hat         ),

    .C_CB_dinb    (C_CB_dinb    ),
    .CB_dinb      (CB_dinb      )
  );
  
  CB_douta_map 
  #(
    .X       (X       ),
    .Y       (Y       ),
    .L       (L       ),
    .RSA_DW  (RSA_DW  ),
    .SEQ_CNT_DW (SEQ_CNT_DW ),
    .CB_DOUTA_SEL_DW (CB_DOUTA_SEL_DW)
  )
  u_CB_douta_map(
  	.clk          (clk          ),
    .sys_rst      (sys_rst      ),
    .CB_douta_sel (CB_douta_sel ),
    .l_k_0       (l_k_0       ),
    .seq_cnt_out (seq_cnt_out),
    .CB_douta     (CB_douta     ),

    .A_CB_douta   (A_CB_douta   ),
    .B_CB_douta   (B_CB_douta   ),
    .M_CB_douta   (M_CB_douta   ),

    .TB_dina_CB_douta (TB_dina_CB_douta )
    // .xk               (xk               ),
    // .yk               (yk               ),
    // .xita             (xita             ),
    // .lkx              (lkx              ),
    // .lky              (lky              )
  );

//instantiate of TEMP BANK
  TB_0 u_TB_0 (
  .clka(clk),  // input wire clka
  .ena(TB_ena[0]),  // input wire ena
  .wea(TB_wea[0]),  // input wire [0 : 0] wea
  .addra(TB_addra[0 +: TB_AW]),  // input wire [11 : 0] addra
  .dina(TB_dina[0 +: RSA_DW]),  // input wire [15 : 0] dina
  .douta(TB_douta[0 +: RSA_DW]),  // output wire [15 : 0] douta
  .clkb(clk),  // input wire clkb
  .enb(TB_enb[0]),  // input wire enb
  .web(TB_web[0]),  // input wire [0 : 0] web
  .addrb(TB_addrb[0 +: TB_AW]),  // input wire [11 : 0] addrb
  .dinb(TB_dinb[0 +: RSA_DW]),  // input wire [15 : 0] dinb
  .doutb(TB_doutb[0 +: RSA_DW])  // output wire [15 : 0] doutb
  );
   
  TB_1 u_TB_1 (
  .clka(clk),  // input wire clka
  .ena(TB_ena[1]),  // input wire ena
  .wea(TB_wea[1]),  // input wire [0 : 0] wea
  .addra(TB_addra[TB_AW +: TB_AW]),  // input wire [11 : 0] addra
  .dina(TB_dina[RSA_DW +: RSA_DW]),  // input wire [15 : 0] dina
  .douta(TB_douta[RSA_DW +: RSA_DW]),  // output wire [15 : 0] douta
  .clkb(clk),  // input wire clkb
  .enb(TB_enb[1]),  // input wire enb
  .web(TB_web[1]),  // input wire [0 : 0] web
  .addrb(TB_addrb[TB_AW +: TB_AW]),  // input wire [11 : 0] addrb
  .dinb(TB_dinb[RSA_DW +: RSA_DW]),  // input wire [15 : 0] dinb
  .doutb(TB_doutb[RSA_DW +: RSA_DW])  // output wire [15 : 0] doutb
  );

  TB_2 u_TB_2 (
  .clka(clk),  // input wire clka
  .ena(TB_ena[2]),  // input wire ena
  .wea(TB_wea[2]),  // input wire [0 : 0] wea
  .addra(TB_addra[2*TB_AW +: TB_AW]),  // input wire [11 : 0] addra
  .dina(TB_dina[2*RSA_DW +: RSA_DW]),  // input wire [15 : 0] dina
  .douta(TB_douta[2*RSA_DW +: RSA_DW]),  // output wire [15 : 0] douta
  .clkb(clk),  // input wire clkb
  .enb(TB_enb[2]),  // input wire enb
  .web(TB_web[2]),  // input wire [0 : 0] web
  .addrb(TB_addrb[2*TB_AW +: TB_AW]),  // input wire [11 : 0] addrb
  .dinb(TB_dinb[2*RSA_DW +: RSA_DW]),  // input wire [15 : 0] dinb
  .doutb(TB_doutb[2*RSA_DW +: RSA_DW])  // output wire [15 : 0] doutb
  );

  TB_3 u_TB_3 (
  .clka(clk),  // input wire clka
  .ena(TB_ena[3]),  // input wire ena
  .wea(TB_wea[3]),  // input wire [0 : 0] wea
  .addra(TB_addra[3*TB_AW +: TB_AW]),  // input wire [11 : 0] addra
  .dina(TB_dina[3*RSA_DW +: RSA_DW]),  // input wire [15 : 0] dina
  .douta(TB_douta[3*RSA_DW +: RSA_DW]),  // output wire [15 : 0] douta
  .clkb(clk),  // input wire clkb
  .enb(TB_enb[3]),  // input wire enb
  .web(TB_web[3]),  // input wire [0 : 0] web
  .addrb(TB_addrb[3*TB_AW +: TB_AW]),  // input wire [11 : 0] addrb
  .dinb(TB_dinb[3*RSA_DW +: RSA_DW]),  // input wire [15 : 0] dinb
  .doutb(TB_doutb[3*RSA_DW +: RSA_DW])  // output wire [15 : 0] doutb
  );

  //instantiate of COV BANK
  CB_0 u_CB_0 (
  .clka(clk),  // input wire clka
  .ena(CB_ena[0]),  // input wire ena
  .wea(CB_wea[0]),  // input wire [0 : 0] wea
  .addra(CB_addra[0 +: CB_AW]),  // input wire [11 : 0] addra
  .dina(CB_dina[0 +: RSA_DW]),  // input wire [15 : 0] dina
  .douta(CB_douta[0 +: RSA_DW]),  // output wire [15 : 0] douta
  .clkb(clk),  // input wire clkb
  .enb(CB_enb[0]),  // input wire enb
  .web(CB_web[0]),  // input wire [0 : 0] web
  .addrb(CB_addrb[0 +: CB_AW]),  // input wire [11 : 0] addrb
  .dinb(CB_dinb[0 +: RSA_DW]),  // input wire [15 : 0] dinb
  .doutb(CB_doutb[0 +: RSA_DW])  // output wire [15 : 0] doutb
  );
   
  CB_1 u_CB_1 (
  .clka(clk),  // input wire clka
  .ena(CB_ena[1]),  // input wire ena
  .wea(CB_wea[1]),  // input wire [0 : 0] wea
  .addra(CB_addra[CB_AW +: CB_AW]),  // input wire [11 : 0] addra
  .dina(CB_dina[RSA_DW +: RSA_DW]),  // input wire [15 : 0] dina
  .douta(CB_douta[RSA_DW +: RSA_DW]),  // output wire [15 : 0] douta
  .clkb(clk),  // input wire clkb
  .enb(CB_enb[1]),  // input wire enb
  .web(CB_web[1]),  // input wire [0 : 0] web
  .addrb(CB_addrb[CB_AW +: CB_AW]),  // input wire [11 : 0] addrb
  .dinb(CB_dinb[RSA_DW +: RSA_DW]),  // input wire [15 : 0] dinb
  .doutb(CB_doutb[RSA_DW +: RSA_DW])  // output wire [15 : 0] doutb
  );

  CB_2 u_CB_2 (
  .clka(clk),  // input wire clka
  .ena(CB_ena[2]),  // input wire ena
  .wea(CB_wea[2]),  // input wire [0 : 0] wea
  .addra(CB_addra[2*CB_AW +: CB_AW]),  // input wire [11 : 0] addra
  .dina(CB_dina[2*RSA_DW +: RSA_DW]),  // input wire [15 : 0] dina
  .douta(CB_douta[2*RSA_DW +: RSA_DW]),  // output wire [15 : 0] douta
  .clkb(clk),  // input wire clkb
  .enb(CB_enb[2]),  // input wire enb
  .web(CB_web[2]),  // input wire [0 : 0] web
  .addrb(CB_addrb[2*CB_AW +: CB_AW]),  // input wire [11 : 0] addrb
  .dinb(CB_dinb[2*RSA_DW +: RSA_DW]),  // input wire [15 : 0] dinb
  .doutb(CB_doutb[2*RSA_DW +: RSA_DW])  // output wire [15 : 0] doutb
  );

  CB_3 u_CB_3 (
  .clka(clk),  // input wire clka
  .ena(CB_ena[3]),  // input wire ena
  .wea(CB_wea[3]),  // input wire [0 : 0] wea
  .addra(CB_addra[3*CB_AW +: CB_AW]),  // input wire [11 : 0] addra
  .dina(CB_dina[3*RSA_DW +: RSA_DW]),  // input wire [15 : 0] dina
  .douta(CB_douta[3*RSA_DW +: RSA_DW]),  // output wire [15 : 0] douta
  .clkb(clk),  // input wire clkb
  .enb(CB_enb[3]),  // input wire enb
  .web(CB_web[3]),  // input wire [0 : 0] web
  .addrb(CB_addrb[3*CB_AW +: CB_AW]),  // input wire [11 : 0] addrb
  .dinb(CB_dinb[3*RSA_DW +: RSA_DW]),  // input wire [15 : 0] dinb
  .doutb(CB_doutb[3*RSA_DW +: RSA_DW])  // output wire [15 : 0] doutb
  );

PE_config 
#(
  .X             (X     ),
  .Y             (Y     ),
  .L             (L     ),

  .A_IN_SEL_DW       (A_IN_SEL_DW       ),
  .B_IN_SEL_DW       (B_IN_SEL_DW       ),
  .M_IN_SEL_DW       (M_IN_SEL_DW       ),
  .C_OUT_SEL_DW      (C_OUT_SEL_DW      ),
  .TB_DINA_SEL_DW    (TB_DINA_SEL_DW    ),
  .TB_DINB_SEL_DW    (TB_DINB_SEL_DW    ),
  .TB_DOUTA_SEL_DW   (TB_DOUTA_SEL_DW   ),
  .TB_DOUTB_SEL_DW   (TB_DOUTB_SEL_DW   ),
  .CB_DINA_SEL_DW    (CB_DINA_SEL_DW    ),
  .CB_DINB_SEL_DW    (CB_DINB_SEL_DW    ),
  .CB_DOUTA_SEL_DW   (CB_DOUTA_SEL_DW   ),

  .RSA_DW        (RSA_DW  ),
  .TB_AW         (TB_AW   ),
  .CB_AW         (CB_AW   ),

  .SEQ_CNT_DW  (SEQ_CNT_DW  ),
  .ROW_LEN       (ROW_LEN   )
)
u_PE_config(
  .clk                  (clk               ),
  .sys_rst              (sys_rst           ),
  .landmark_num         (landmark_num      ),
  .l_k           (l_k           ),
  .stage_val     (stage_val     ),
  .stage_rdy     (stage_rdy     ),
  .init_predict  (init_predict  ),
  .init_newlm    (init_newlm    ),
  .init_update   (init_update   ),
  .done_predict  (done_predict  ),
  .done_newlm    (done_newlm    ),
  .done_update   (done_update   ),
  .A_in_sel      (A_in_sel      ),
  .A_in_en       (A_in_en       ),
  .B_in_sel      (B_in_sel      ),
  .B_in_en       (B_in_en       ),
  .M_in_sel      (M_in_sel      ),
  .M_in_en       (M_in_en       ),
  .C_out_sel     (C_out_sel     ),
  .C_out_en      (C_out_en      ),

  .TB_dina_sel   (TB_dina_sel   ),
  .TB_dinb_sel   (TB_dinb_sel   ),
  .TB_douta_sel  (TB_douta_sel  ),
  .TB_doutb_sel  (TB_doutb_sel  ),
  .TB_ena        (TB_ena        ),
  .TB_enb        (TB_enb        ),
  .TB_wea        (TB_wea        ),
  .TB_web        (TB_web        ),
  .TB_addra      (TB_addra      ),
  .TB_addrb      (TB_addrb      ),

  // .CB_dina_sel   (CB_dina_sel   ),
  .CB_dinb_sel   (CB_dinb_sel   ),
  .CB_douta_sel  (CB_douta_sel  ),
  .CB_ena        (CB_ena        ),
  .CB_enb        (CB_enb        ),
  .CB_wea        (CB_wea        ),
  .CB_web        (CB_web        ),
  .CB_addra      (CB_addra      ),
  .CB_addrb      (CB_addrb      ),

  .B_cache_in_sel(B_cache_in_sel),
  .B_cache_out_sel(B_cache_out_sel),
  .B_cache_en    (B_cache_en    ),
  .B_cache_we    (B_cache_we    ),
  .B_cache_addr  (B_cache_addr  ),
  .init_inv      (init_inv      ),
  .done_inv      (done_inv      ),

  .seq_cnt_out   (seq_cnt_out   ),
  .stage_cur_out (stage_cur_out ),
  .prd_cur_out   (prd_cur_out   ),
  .new_cur_out   (new_cur_out   ),
  .upd_cur_out   (upd_cur_out   ),
  .assoc_cur_out (assoc_cur_out ),

  .assoc_status(assoc_status),
  .assoc_l_k   (assoc_l_k),

  .M_adder_mode  (M_adder_mode  ),
  .PE_mode       (PE_mode       ),
  .new_cal_en    (new_cal_en    ),
  .new_cal_done  (new_cal_done  )
);

endmodule