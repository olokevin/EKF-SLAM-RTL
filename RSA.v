// `define USE_DIFF_CLK
//`define  BRAM_OUT
module RSA 
#(
  parameter X = 4,
  parameter Y = 4,
  parameter L = 4,

  parameter A_IN_SEL_DW = 2,
  parameter B_IN_SEL_DW = 2,
  parameter M_IN_SEL_DW = 2,
  parameter C_OUT_SEL_DW = 2,

  parameter TB_DINB_SEL_DW  = 2,
  parameter TB_DOUTA_SEL_DW = 3,
  parameter TB_DOUTB_SEL_DW = 3,
  parameter CB_DINB_SEL_DW  = 2,
  parameter CB_DOUTA_SEL_DW = 4,  //注意MUX deMUX需手动修改

  parameter RSA_DW = 16,
  parameter TB_AW = 11,
  parameter CB_AW = 17,
  parameter MAX_LANDMARK = 500,
  parameter ROW_LEN = 10
) 
(
// `ifdef USE_DIFF_CLK
//   input   sys_clk_p,
//   input   sys_clk_n,
// `else 
//   input   clk,
// `endif
  input   clk,

  input   sys_rst,

//landmark numbers
  input   [ROW_LEN-1 : 0]  landmark_num,
  input   [ROW_LEN-1 : 0]  l_k,

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

// //TEMP BANK ports
//   output  [L-1 : 0]    TB_ena,
//   output  [L-1 : 0]    TB_wea,
//   output  [L*TB_AW-1 : 0]    TB_addra,
//   output  [L*RSA_DW-1 : 0]   TB_dina,
//   input  [L*RSA_DW-1 : 0]   TB_douta,

//   output  [L-1 : 0]    TB_enb,
//   output  [L-1 : 0]    TB_web,
//   output  [L*TB_AW-1 : 0]    TB_addrb,
//   output  [L*RSA_DW-1 : 0]   TB_dinb,
//   input  [L*RSA_DW-1 : 0]   TB_doutb,

// //COV BANK ports
//   output  [L-1 : 0]    CB_ena,
//   output  [L-1 : 0]    CB_wea,
//   output  [L*CB_AW-1 : 0]    CB_addra,
//   output  [L*RSA_DW-1 : 0]   CB_dina,
//   input  [L*RSA_DW-1 : 0]   CB_douta,

//   output  [L-1 : 0]    CB_enb,
//   output  [L-1 : 0]    CB_web,
//   output  [L*CB_AW-1 : 0]    CB_addrb,
//   output  [L*RSA_DW-1 : 0]   CB_dinb,
//   input  [L*RSA_DW-1 : 0]   CB_doutb
);


/*
  差分时钟信号转单端
*/
// `ifdef USE_DIFF_CLK
//   wire clk;

//   IBUFDS #( 
//   .DIFF_TERM("FALSE"), // Differential Termination 
//   .IBUF_LOW_PWR("FALSE"), // Low power="TRUE", Highest performance="FALSE" 
//   .IOSTANDARD("DEFAULT") // Specify the input I/O standard 
//   ) 
//   IBUFDS_inst ( 
//   .O(clk), // Buffer output 
//   .I(sys_clk_p), // Diff_p buffer input (connect directly to top-level port) 
//   .IB(sys_clk_n) // Diff_n buffer input (connect directly to top-level port) 
//   );
// `endif

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
wire [Y*RSA_DW-1 : 0]   B_CONS_TB_doutb;
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


generate 
  genvar i_X;
    for(i_X=0; i_X<=X-1; i_X=i_X+1) begin: DATA_X
      // regMUX_sel1 
      // #(
      //   .RSA_DW (RSA_DW )
      // )
      // A_regMUX_sel1(
      //   .clk     (clk   ),
      //   .sys_rst (sys_rst ),
      //   .en      (A_in_en[i_X]  ),
      //   .sel     (A_in_sel[i_X]   ),
      //   .din_0   (A_TB_douta[RSA_DW*i_X +: RSA_DW]  ),
      //   .din_1   (A_CB_douta[RSA_DW*i_X +: RSA_DW]  ),
      //   .dout    (A_data[RSA_DW*i_X +: RSA_DW]  )
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
        .din_01  (0  ),
        .din_10  (A_CB_douta[RSA_DW*i_X +: RSA_DW]  ),
        .din_11  (0  ),
        .dout    (A_data[RSA_DW*i_X +: RSA_DW]    )
      );
      

      // regMUX_sel1 
      // #(
      //   .RSA_DW (RSA_DW )
      // )
      // M_regMUX_sel1(
      //   .clk     (clk   ),
      //   .sys_rst (sys_rst ),
      //   .en      (M_in_en[i_X]  ),
      //   .sel     (M_in_sel[i_X]   ),
      //   .din_0   (M_TB_douta[RSA_DW*i_X +: RSA_DW]  ),
      //   .din_1   (M_CB_douta[RSA_DW*i_X +: RSA_DW]  ),
      //   .dout    (M_data[RSA_DW*i_X +: RSA_DW]  )
      // );

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
      

      // regdeMUX_sel1 
      // #(
      //   .RSA_DW (RSA_DW )
      // )
      // C_regdeMUX_sel1(
      //   .clk     (clk     ),
      //   .sys_rst (sys_rst ),
      //   .en      (C_out_en[i_X]      ),
      //   .sel     (C_out_sel[i_X]     ),
      //   .din     (C_data[RSA_DW*i_X +: RSA_DW]     ),
      //   .dout_0  (C_TB_dinb[RSA_DW*i_X +: RSA_DW]  ),
      //   .dout_1  (C_CB_dinb[RSA_DW*i_X +: RSA_DW]  )
      // );

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

wire [Y-1:0] B_CONS_en;
wire [Y-1:0] B_CONS_we;
wire [Y*3-1:0] B_CONS_addr;
wire [Y*RSA_DW-1:0] B_CONS_dout; 

generate
  genvar i_Y;
  for(i_Y=0; i_Y<=Y-1; i_Y=i_Y+1) begin: DATA_Y
    t_ram 
    #(
      .DW (RSA_DW ),
      .AW (3 )
    )
    B_CONS_ram(
    	.clk     (clk     ),
      .sys_rst (sys_rst ),
      .en      (B_CONS_en[i_Y]      ),
      .we      (B_CONS_we[i_Y]      ),
      .addr    (B_CONS_addr[3*i_Y +: 3]    ),
      .din     (B_CONS_TB_doutb[RSA_DW*i_Y +: RSA_DW]     ),
      .dout    (B_CONS_dout[RSA_DW*i_Y +: RSA_DW]    )
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
      .din_01  (B_CONS_dout[RSA_DW*i_Y +: RSA_DW]  ),
      .din_10  (B_CB_douta[RSA_DW*i_Y +: RSA_DW]  ),
      .din_11  (0   ),
      .dout    (B_data[RSA_DW*i_Y +: RSA_DW]  )
    );
  end
endgenerate

//TEMP BRAM
wire [TB_DINB_SEL_DW-1 : 0]    TB_dinb_sel;
wire [TB_DOUTA_SEL_DW-1 : 0]    TB_douta_sel;
//定义提前
wire [TB_DOUTB_SEL_DW*L-1 : 0]  TB_doutb_sel;

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
wire [CB_DOUTA_SEL_DW-1 : 0]    CB_douta_sel;

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

wire [1:0] landmark_num_10;

//TEMP_BANK data MUX and deMUX
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
    .TB_douta     (TB_douta     ),
    .A_TB_douta   (A_TB_douta   ),
    .M_TB_douta   (M_TB_douta   )
  );
  
  TB_doutb_map 
  #(
    .X         (X         ),
    .Y         (Y         ),
    .L         (L         ),
    .RSA_DW    (RSA_DW    )
  )
  u_TB_doutb_map(
  	.clk             (clk             ),
    .sys_rst         (sys_rst         ),
    .TB_doutb_sel    (TB_doutb_sel    ),
    .TB_doutb        (TB_doutb        ),
    .B_TB_doutb      (B_TB_doutb      ),
    .B_CONS_TB_doutb (B_CONS_TB_doutb )
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
    .C_CB_dinb    (C_CB_dinb    ),
    .CB_dinb      (CB_dinb      )
  );
  
  CB_douta_map 
  #(
    .X       (X       ),
    .Y       (Y       ),
    .L       (L       ),
    .RSA_DW  (RSA_DW  ),
    .ROW_LEN (ROW_LEN )
  )
  u_CB_douta_map(
  	.clk          (clk          ),
    .sys_rst      (sys_rst      ),
    .CB_douta_sel (CB_douta_sel ),
    .CB_douta     (CB_douta     ),
    .A_CB_douta   (A_CB_douta   ),
    .B_CB_douta   (B_CB_douta   ),
    .M_CB_douta   (M_CB_douta   )
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
  .RSA_DW        (RSA_DW  ),
  .TB_AW         (TB_AW   ),
  .CB_AW         (CB_AW   ),
  .MAX_LANDMARK  (MAX_LANDMARK  ),
  .ROW_LEN       (ROW_LEN   )
)
u_PE_config(
  .clk                  (clk               ),
  .sys_rst              (sys_rst           ),
  .landmark_num         (landmark_num      ),
  .l_k                  (l_k               ),
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
  .TB_dinb_sel          (TB_dinb_sel       ),
  .TB_douta_sel         (TB_douta_sel      ),
  .TB_doutb_sel         (TB_doutb_sel      ),
  .TB_ena               (TB_ena            ),
  .TB_enb               (TB_enb            ),
  .TB_wea               (TB_wea            ),
  .TB_web               (TB_web            ),
  .TB_dina              (TB_dina           ),
  .TB_addra             (TB_addra          ),
  .TB_addrb             (TB_addrb          ),
  .CB_dinb_sel          (CB_dinb_sel       ),
  .CB_douta_sel         (CB_douta_sel      ),
  .CB_ena               (CB_ena            ),
  .CB_enb               (CB_enb            ),
  .CB_wea               (CB_wea            ),
  .CB_web               (CB_web            ),
  .CB_dina              (CB_dina           ),
  .CB_addra             (CB_addra          ),
  .CB_addrb             (CB_addrb          ),
  .B_CONS_en            (B_CONS_en),
  .B_CONS_we            (B_CONS_we),
  .B_CONS_addr          (B_CONS_addr),
  .B_CONS_dout          (B_CONS_dout),
  .M_adder_mode         (M_adder_mode      ),
  .PE_mode              (PE_mode           ),
  .new_cal_en           (new_cal_en        ),
  .new_cal_done         (new_cal_done      )
);

endmodule