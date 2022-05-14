`include "macro.v"
module RSA 
#(
  parameter X = 4,
  parameter Y = 4,
  parameter L = 4,

  parameter A_IN_SEL_DW = 2,
  parameter B_IN_SEL_DW = 2,
  parameter M_IN_SEL_DW = 2,
  parameter C_OUT_SEL_DW = 2,

  parameter RSA_DW = 32,
  parameter TB_AW = 11,
  parameter CB_AW = 17,
  parameter SEQ_CNT_DW = 5,
  parameter ROW_LEN = 10
) 
(
`ifdef USE_DIFF_CLK
  input   sys_clk_p,
  input   sys_clk_n,
`else 
  input   clk,
`endif
  // input   clk,

  input   sys_rst,

`ifdef BRAM_OUT
  //************************ TEMP BANK *************************
      output [TB_AW-1:0]  TB0_addra,
      output              TB0_clka,
      output  [RSA_DW-1:0] TB0_dina,
      input [RSA_DW-1:0] TB0_douta,
      output              TB0_ena,
      output              TB0_wea,

      output [TB_AW-1:0]  TB0_addrb,
      output              TB0_clkb,
      output  [RSA_DW-1:0] TB0_dinb,
      input [RSA_DW-1:0] TB0_doutb,
      output              TB0_enb,
      output              TB0_web,

      output [TB_AW-1:0]  TB1_addra,
      output              TB1_clka,
      output  [RSA_DW-1:0] TB1_dina,
      input [RSA_DW-1:0] TB1_douta,
      output              TB1_ena,
      output              TB1_wea,

      output [TB_AW-1:0]  TB1_addrb,
      output              TB1_clkb,
      output  [RSA_DW-1:0] TB1_dinb,
      input [RSA_DW-1:0] TB1_doutb,
      output              TB1_enb,
      output              TB1_web,

      output [TB_AW-1:0]  TB2_addra,
      output              TB2_clka,
      output  [RSA_DW-1:0] TB2_dina,
      input [RSA_DW-1:0] TB2_douta,
      output              TB2_ena,
      output              TB2_wea,

      output [TB_AW-1:0]  TB2_addrb,
      output              TB2_clkb,
      output  [RSA_DW-1:0] TB2_dinb,
      input [RSA_DW-1:0] TB2_doutb,
      output              TB2_enb,
      output              TB2_web,

      output [TB_AW-1:0]  TB3_addra,
      output              TB3_clka,
      output  [RSA_DW-1:0] TB3_dina,
      input [RSA_DW-1:0] TB3_douta,
      output              TB3_ena,
      output              TB3_wea,

      output [TB_AW-1:0]  TB3_addrb,
      output              TB3_clkb,
      output  [RSA_DW-1:0] TB3_dinb,
      input [RSA_DW-1:0] TB3_doutb,
      output              TB3_enb,
      output              TB3_web,

  //************************** COV BANK *************************
      output [CB_AW-1:0]  CB0_addra,
      output              CB0_clka,
      output  [RSA_DW-1:0] CB0_dina,
      input [RSA_DW-1:0] CB0_douta,
      output              CB0_ena,
      output              CB0_wea,

      output [CB_AW-1:0]  CB0_addrb,
      output              CB0_clkb,
      output  [RSA_DW-1:0] CB0_dinb,
      input [RSA_DW-1:0] CB0_doutb,
      output              CB0_enb,
      output              CB0_web,

      output [CB_AW-1:0]  CB1_addra,
      output              CB1_clka,
      output  [RSA_DW-1:0] CB1_dina,
      input [RSA_DW-1:0] CB1_douta,
      output              CB1_ena,
      output              CB1_wea,

      output [CB_AW-1:0]  CB1_addrb,
      output              CB1_clkb,
      output  [RSA_DW-1:0] CB1_dinb,
      input [RSA_DW-1:0] CB1_doutb,
      output              CB1_enb,
      output              CB1_web,

      output [CB_AW-1:0]  CB2_addra,
      output              CB2_clka,
      output  [RSA_DW-1:0] CB2_dina,
      input [RSA_DW-1:0] CB2_douta,
      output              CB2_ena,
      output              CB2_wea,

      output [CB_AW-1:0]  CB2_addrb,
      output              CB2_clkb,
      output  [RSA_DW-1:0] CB2_dinb,
      input [RSA_DW-1:0] CB2_doutb,
      output              CB2_enb,
      output              CB2_web,

      output [CB_AW-1:0]  CB3_addra,
      output              CB3_clka,
      output  [RSA_DW-1:0] CB3_dina,
      input [RSA_DW-1:0] CB3_douta,
      output              CB3_ena,
      output              CB3_wea,

      output [CB_AW-1:0]  CB3_addrb,
      output              CB3_clkb,
      output  [RSA_DW-1:0] CB3_dinb,
      input [RSA_DW-1:0] CB3_doutb,
      output              CB3_enb,
      output              CB3_web,
    
    // TEMP BANK ports
      // output  [L-1 : 0]    TB_ena,
      // output  [L-1 : 0]    TB_wea,
      // output  [L*TB_AW-1 : 0]    TB_addra,
      // output  [L*RSA_DW-1 : 0]   TB_dina,
      // input  [L*RSA_DW-1 : 0]   TB_douta,

      // output  [L-1 : 0]    TB_enb,
      // output  [L-1 : 0]    TB_web,
      // output  [L*TB_AW-1 : 0]    TB_addrb,
      // output  [L*RSA_DW-1 : 0]   TB_dinb,
      // input  [L*RSA_DW-1 : 0]   TB_doutb,


    //COV BANK ports
      // output  [L-1 : 0]    CB_ena,
      // output  [L-1 : 0]    CB_wea,
      // output  [L*CB_AW-1 : 0]    CB_addra,
      // output  [L*RSA_DW-1 : 0]   CB_dina,
      // input  [L*RSA_DW-1 : 0]   CB_douta,

      // output  [L-1 : 0]    CB_enb,
      // output  [L-1 : 0]    CB_web,
      // output  [L*CB_AW-1 : 0]    CB_addrb,
      // output  [L*RSA_DW-1 : 0]   CB_dinb,
      // input  [L*RSA_DW-1 : 0]   CB_doutb,
`endif

//landmark numbers
  `ifdef LANDMARK_NUM_IN
    input   [ROW_LEN-1 : 0]  landmark_num,
  `endif
  // `ifdef L_k_IN
    input   [ROW_LEN-1 : 0]  l_k,
  // `endif

  //handshake of stage change
  input   [2:0]   stage_val,
  output  [2:0]   stage_rdy,

//handshake of nonlinear calculation start & complete
  //nonlinear start(3 stages are conbined)
  output   [2:0]   nonlinear_m_rdy,
  input  [2:0]   nonlinear_s_val,
  //nonlinear cplt(3 stages are conbined)
  output   [2:0]   nonlinear_m_val,
  input  [2:0]   nonlinear_s_rdy
);

  parameter TB_DINA_SEL_DW  = 3;
  parameter TB_DINB_SEL_DW  = 2;
  parameter TB_DOUTA_SEL_DW = 3;
  parameter TB_DOUTB_SEL_DW = 3;
  parameter CB_DINB_SEL_DW  = 2;
  parameter CB_DOUTA_SEL_DW = 4;  //注意MUX deMUX需手动修改

/*
  差分时钟信号转单端
*/
`ifdef USE_DIFF_CLK
  wire clk;

  IBUFDS #( 
  .DIFF_TERM("FALSE"), // Differential Termination 
  .IBUF_LOW_PWR("FALSE"), // Low power="TRUE", Highest performance="FALSE" 
  .IOSTANDARD("DEFAULT") // Specify the input I/O standard 
  ) 
  IBUFDS_inst ( 
  .O(clk), // Buffer output 
  .I(sys_clk_p), // Diff_p buffer input (connect directly to top-level port) 
  .IB(sys_clk_n) // Diff_n buffer input (connect directly to top-level port) 
  );
`endif

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



wire   [X*RSA_DW-1 : 0]  A_data;
wire   [Y*RSA_DW-1 : 0]  B_data;
wire   [X*RSA_DW-1 : 0]  M_data;
wire   [X*RSA_DW-1 : 0]  C_data;

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
wire [X*RSA_DW-1 : 0]   A_TB_douta;
wire [X*RSA_DW-1 : 0]   A_CB_douta;
wire [A_IN_SEL_DW*X-1 : 0]        A_in_sel;
wire [X-1 : 0]          A_in_en;   


//B in
wire [Y*RSA_DW-1 : 0]   B_TB_doutb; 
wire [Y*RSA_DW-1 : 0]   B_cache_TB_doutb;
wire [Y*RSA_DW-1 : 0]   B_CB_douta;
wire [B_IN_SEL_DW*Y-1 : 0]        B_in_sel;     //B_in有三个来源
wire [Y-1 : 0]          B_in_en;   

//M in
wire [X*RSA_DW-1 : 0]   M_TB_douta; 
wire [X*RSA_DW-1 : 0]   M_CB_douta;
wire [M_IN_SEL_DW*X-1 : 0]        M_in_sel;  
wire [X-1 : 0]          M_in_en;  

//C out
wire [X*RSA_DW-1 : 0]   C_TB_dinb; 
wire [X*RSA_DW-1 : 0]   C_CB_dinb;
wire [C_OUT_SEL_DW*X-1 : 0]        C_out_sel; 
wire [X-1 : 0]          C_out_en; 

wire [L*RSA_DW-1 : 0]   TB_dina_CB_douta;
wire [L*RSA_DW-1 : 0]   TB_dina_non_linear;

generate 
  genvar i_X;
    for(i_X=0; i_X<=X-1; i_X=i_X+1) begin: DATA_X
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
        .din_01  (0  ),
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
        .din_01  (0  ),
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
        .dout_01 ( ),
        .dout_10 (C_CB_dinb[RSA_DW*i_X +: RSA_DW] ),
        .dout_11 ( )
      );
      

  end
endgenerate

//Bin 临时寄存H

wire [Y-1:0] B_cache_en;
wire [Y-1:0] B_cache_we;
wire [Y*3-1:0] B_cache_addr;
wire [Y*RSA_DW-1:0] B_cache_dout; 

generate
  genvar i_Y;
  for(i_Y=0; i_Y<=Y-1; i_Y=i_Y+1) begin: DATA_Y
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
      .din     (B_cache_TB_doutb[RSA_DW*i_Y +: RSA_DW]     ),
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
      .din_01  (B_cache_dout[RSA_DW*i_Y +: RSA_DW]  ),
      .din_10  (B_CB_douta[RSA_DW*i_Y +: RSA_DW]  ),
      .din_11  (0   ),
      .dout    (B_data[RSA_DW*i_Y +: RSA_DW]  )
    );
  end
endgenerate

//TEMP BRAM
wire [TB_DINA_SEL_DW-1 : 0]    TB_dina_sel;
wire [TB_DINB_SEL_DW-1 : 0]    TB_dinb_sel;
wire [TB_DOUTA_SEL_DW-1 : 0]   TB_douta_sel;
wire [TB_DOUTB_SEL_DW-1 : 0]   TB_doutb_sel;

wire [L-1 : 0]    TB_ena;
wire [L-1 : 0]    TB_enb;

wire [L-1 : 0]    TB_wea;
wire [L-1 : 0]    TB_web;

wire [L*RSA_DW-1 : 0] TB_dina;
wire [L*TB_AW-1 : 0] TB_addra;
wire [L*RSA_DW-1 : 0] TB_dinb;
wire [L*TB_AW-1 : 0] TB_addrb;

wire [L*RSA_DW-1 : 0] TB_douta;
wire [L*RSA_DW-1 : 0] TB_doutb;

//COV BRAM
wire [CB_DINB_SEL_DW-1 : 0]    CB_dinb_sel;
wire [CB_DOUTA_SEL_DW-1 : 0]   CB_douta_sel;

wire [L-1 : 0]    CB_ena;
wire [L-1 : 0]    CB_enb;

wire [L-1 : 0]    CB_wea;
wire [L-1 : 0]    CB_web;

wire [L*RSA_DW-1 : 0] CB_dina;
wire [L*CB_AW-1 : 0] CB_addra;
wire [L*RSA_DW-1 : 0] CB_dinb;
wire [L*CB_AW-1 : 0] CB_addrb;

wire [L*RSA_DW-1 : 0] CB_douta;
wire [L*RSA_DW-1 : 0] CB_doutb;

//l_k
// `ifndef L_k_IN
//   reg [ROW_LEN-1 : 0] l_k = 3'b100;
// `endif
wire l_k_0;
assign l_k_0 = l_k[0];

wire [SEQ_CNT_DW-1 : 0] seq_cnt_dout_sel;

//TEMP_BANK data MUX and deMUX
  TB_dina_map 
  #(
    .X              (X              ),
    .Y              (Y              ),
    .L              (L              ),
    .RSA_DW         (RSA_DW         )
  )
  u_TB_dina_map(
  	.clk                (clk                ),
    .sys_rst            (sys_rst            ),
    .TB_dina_sel        (TB_dina_sel        ),
    .l_k_0              (l_k_0              ),
    .TB_dina_CB_douta   (TB_dina_CB_douta   ),
    .TB_dina_non_linear (TB_dina_non_linear ),
    .TB_dina            (TB_dina            )
  );
  
  
  TB_dinb_map 
  #(
    .X      (X      ),
    .Y      (Y      ),
    .L      (L      ),
    .RSA_DW (RSA_DW )
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
    .RSA_DW (RSA_DW )
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
    .SEQ_CNT_DW (SEQ_CNT_DW)
  )
  u_TB_doutb_map(
  	.clk             (clk             ),
    .sys_rst         (sys_rst         ),
    .TB_doutb_sel    (TB_doutb_sel    ),
    .l_k_0       (l_k_0       ),
    .seq_cnt_dout_sel (seq_cnt_dout_sel),
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
    .ROW_LEN (ROW_LEN )
  )
  u_CB_dinb_map(
  	.clk          (clk          ),
    .sys_rst      (sys_rst      ),
    .CB_dinb_sel  (CB_dinb_sel  ),
    .l_k_0       (l_k_0       ),
    .C_CB_dinb    (C_CB_dinb    ),
    .CB_dinb      (CB_dinb      )
  );
  
  CB_douta_map 
  #(
    .X       (X       ),
    .Y       (Y       ),
    .L       (L       ),
    .RSA_DW  (RSA_DW  ),
    .SEQ_CNT_DW (SEQ_CNT_DW )
  )
  u_CB_douta_map(
  	.clk          (clk          ),
    .sys_rst      (sys_rst      ),
    .CB_douta_sel (CB_douta_sel ),
    .l_k_0       (l_k_0       ),
    .seq_cnt_dout_sel (seq_cnt_dout_sel),
    .CB_douta     (CB_douta     ),
    .TB_dina_CB_douta (TB_dina_CB_douta),
    .A_CB_douta   (A_CB_douta   ),
    .B_CB_douta   (B_CB_douta   ),
    .M_CB_douta   (M_CB_douta   )
  );

`ifdef BRAM_OUT
  //************************** TEMP BANK *************************
    //************** TB0 ***************
      assign TB0_addra = TB_addra[0 +: TB_AW];
      assign TB0_clka  = clk;
      assign TB0_dina  = TB_dina[0 +: RSA_DW];
      assign TB_douta[0 +: RSA_DW] = TB0_douta;
      assign TB0_ena   = TB_ena[0];
      assign TB0_wea   = TB_wea[0];
      assign TB0_addrb = TB_addrb[0 +: TB_AW];
      assign TB0_clkb  = clk;
      assign TB0_dinb  = TB_dinb[0 +: RSA_DW];
      assign TB_doutb[0 +: RSA_DW] = TB0_doutb;
      assign TB0_enb   = TB_enb[0];
      assign TB0_web   = TB_web[0];
    //************** TB1 ***************
      assign TB1_addra = TB_addra[1*TB_AW +: TB_AW];
      assign TB1_clka  = clk;
      assign TB1_dina  = TB_dina[1*RSA_DW +: RSA_DW];
      assign TB_douta[1*RSA_DW +: RSA_DW] = TB1_douta;
      assign TB1_ena   = TB_ena[1];
      assign TB1_wea   = TB_wea[1];
      assign TB1_addrb = TB_addrb[1*TB_AW +: TB_AW];
      assign TB1_clkb  = clk;
      assign TB1_dinb  = TB_dinb[1*RSA_DW +: RSA_DW];
      assign TB_doutb[1*RSA_DW +: RSA_DW] = TB1_doutb;
      assign TB1_enb   = TB_enb[1];
      assign TB1_web   = TB_web[1];
    //************** TB2 ***************
      assign TB2_addra = TB_addra[2*TB_AW +: TB_AW];
      assign TB2_clka  = clk;
      assign TB2_dina  = TB_dina[2*RSA_DW +: RSA_DW];
      assign TB_douta[2*RSA_DW +: RSA_DW] = TB2_douta;
      assign TB2_ena   = TB_ena[2];
      assign TB2_wea   = TB_wea[2];
      assign TB2_addrb = TB_addrb[2*TB_AW +: TB_AW];
      assign TB2_clkb  = clk;
      assign TB2_dinb  = TB_dinb[2*RSA_DW +: RSA_DW];
      assign TB_doutb[2*RSA_DW +: RSA_DW] = TB2_doutb;
      assign TB2_enb   = TB_enb[2];
      assign TB2_web   = TB_web[2];
    //************** TB3 ***************
      assign TB3_addra = TB_addra[3*TB_AW +: TB_AW];
      assign TB3_clka  = clk;
      assign TB3_dina  = TB_dina[3*RSA_DW +: RSA_DW];
      assign TB_douta[3*RSA_DW +: RSA_DW] = TB3_douta;
      assign TB3_ena   = TB_ena[3];
      assign TB3_wea   = TB_wea[3];
      assign TB3_addrb = TB_addrb[3*TB_AW +: TB_AW];
      assign TB3_clkb  = clk;
      assign TB3_dinb  = TB_dinb[3*RSA_DW +: RSA_DW];
      assign TB_doutb[3*RSA_DW +: RSA_DW] = TB3_doutb;
      assign TB3_enb   = TB_enb[3];
      assign TB3_web   = TB_web[3];

  //************************** COV BANK *************************
    //************** CB0 ***************
      assign CB0_addra = CB_addra[0 +: CB_AW];
      assign CB0_clka  = clk;
      assign CB0_dina  = CB_dina[0 +: RSA_DW];
      assign CB_douta[0 +: RSA_DW] = CB0_douta;
      assign CB0_ena   = CB_ena[0];
      assign CB0_wea   = CB_wea[0];
      assign CB0_addrb = CB_addrb[0 +: CB_AW];
      assign CB0_clkb  = clk;
      assign CB0_dinb  = CB_dinb[0 +: RSA_DW];
      assign CB_doutb[0 +: RSA_DW] = CB0_doutb;
      assign CB0_enb   = CB_enb[0];
      assign CB0_web   = CB_web[0];
    //************** CB1 ***************
      assign CB1_addra = CB_addra[1*CB_AW +: CB_AW];
      assign CB1_clka  = clk;
      assign CB1_dina  = CB_dina[1*RSA_DW +: RSA_DW];
      assign CB_douta[1*RSA_DW +: RSA_DW] = CB1_douta;
      assign CB1_ena   = CB_ena[1];
      assign CB1_wea   = CB_wea[1];
      assign CB1_addrb = CB_addrb[1*CB_AW +: CB_AW];
      assign CB1_clkb  = clk;
      assign CB1_dinb  = CB_dinb[1*RSA_DW +: RSA_DW];
      assign CB_doutb[1*RSA_DW +: RSA_DW] = CB1_doutb;
      assign CB1_enb   = CB_enb[1];
      assign CB1_web   = CB_web[1];
    //************** CB2 ***************
      assign CB2_addra = CB_addra[2*CB_AW +: CB_AW];
      assign CB2_clka  = clk;
      assign CB2_dina  = CB_dina[2*RSA_DW +: RSA_DW];
      assign CB_douta[2*RSA_DW +: RSA_DW] = CB2_douta;
      assign CB2_ena   = CB_ena[2];
      assign CB2_wea   = CB_wea[2];
      assign CB2_addrb = CB_addrb[2*CB_AW +: CB_AW];
      assign CB2_clkb  = clk;
      assign CB2_dinb  = CB_dinb[2*RSA_DW +: RSA_DW];
      assign CB_doutb[2*RSA_DW +: RSA_DW] = CB2_doutb;
      assign CB2_enb   = CB_enb[2];
      assign CB2_web   = CB_web[2];
    //************** CB3 ***************
      assign CB3_addra = CB_addra[3*CB_AW +: CB_AW];
      assign CB3_clka  = clk;
      assign CB3_dina  = CB_dina[3*RSA_DW +: RSA_DW];
      assign CB_douta[3*RSA_DW +: RSA_DW] = CB3_douta;
      assign CB3_ena   = CB_ena[3];
      assign CB3_wea   = CB_wea[3];
      assign CB3_addrb = CB_addrb[3*CB_AW +: CB_AW];
      assign CB3_clkb  = clk;
      assign CB3_dinb  = CB_dinb[3*RSA_DW +: RSA_DW];
      assign CB_doutb[3*RSA_DW +: RSA_DW] = CB3_doutb;
      assign CB3_enb   = CB_enb[3];
      assign CB3_web   = CB_web[3];
`else
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
`endif

PE_config 
#(
  .X             (X     ),
  .Y             (Y     ),
  .L             (L     ),
  .RSA_DW        (RSA_DW  ),
  .TB_AW         (TB_AW   ),
  .CB_AW         (CB_AW   ),
  .SEQ_CNT_DW  (SEQ_CNT_DW  ),
  .ROW_LEN       (ROW_LEN   )
)
u_PE_config(
  .clk                  (clk               ),
  .sys_rst              (sys_rst           ),
  `ifdef LANDMARK_NUM_IN
  .landmark_num         (landmark_num      ),
  `endif
  // `ifdef L_K_IN
  .l_k                  (l_k               ),
  // `endif
  .stage_val            (stage_val         ),
  .stage_rdy            (stage_rdy         ),
  .nonlinear_m_rdy      (nonlinear_m_rdy   ),
  .nonlinear_s_val      (nonlinear_s_val   ),
  .nonlinear_m_val      (nonlinear_m_val   ),
  .nonlinear_s_rdy      (nonlinear_s_rdy   ),
  .A_in_sel             (A_in_sel          ),
  .A_in_en              (A_in_en           ),
  .B_in_sel             (B_in_sel          ),
  .B_in_en              (B_in_en           ),
  .M_in_sel             (M_in_sel          ),
  .M_in_en              (M_in_en           ),
  .C_out_sel            (C_out_sel         ),
  .C_out_en             (C_out_en          ),
  .TB_dina_sel          (TB_dina_sel       ),
  .TB_dinb_sel          (TB_dinb_sel       ),
  .TB_douta_sel         (TB_douta_sel      ),
  .TB_doutb_sel         (TB_doutb_sel      ),
  .TB_ena               (TB_ena            ),
  .TB_enb               (TB_enb            ),
  .TB_wea               (TB_wea            ),
  .TB_web               (TB_web            ),
  .TB_addra             (TB_addra          ),
  .TB_addrb             (TB_addrb          ),
  .CB_dinb_sel          (CB_dinb_sel       ),
  .CB_douta_sel         (CB_douta_sel      ),
  .CB_ena               (CB_ena            ),
  .CB_enb               (CB_enb            ),
  .CB_wea               (CB_wea            ),
  .CB_web               (CB_web            ),
  .CB_addra             (CB_addra          ),
  .CB_addrb             (CB_addrb          ),
  .CB_dina              (CB_dina           ),
  .B_cache_en            (B_cache_en),
  .B_cache_we            (B_cache_we),
  .B_cache_addr          (B_cache_addr),
  .seq_cnt_dout_sel      (seq_cnt_dout_sel),
  .M_adder_mode         (M_adder_mode      ),
  .PE_mode              (PE_mode           ),
  .new_cal_en           (new_cal_en        ),
  .new_cal_done         (new_cal_done      )
);

endmodule