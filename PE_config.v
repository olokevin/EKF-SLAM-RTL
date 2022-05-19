`include "macro.v"
module PE_config #(
  parameter X = 4,
  parameter Y = 4,
  parameter L = 4,

  parameter A_IN_SEL_DW = 2,
  parameter B_IN_SEL_DW = 2,
  parameter M_IN_SEL_DW = 2,
  parameter C_OUT_SEL_DW = 2,

  parameter TB_DINA_SEL_DW  = 3,
  parameter TB_DINB_SEL_DW  = 2,
  parameter TB_DOUTA_SEL_DW = 3,
  parameter TB_DOUTB_SEL_DW = 3,
  parameter CB_DINB_SEL_DW  = 2,
  parameter CB_DOUTA_SEL_DW = 4,  //注意MUX deMUX需手动修改

  parameter RSA_DW = 16,
  parameter TB_AW = 11,
  parameter CB_AW = 17,

  parameter SEQ_CNT_DW = 5,
  parameter ROW_LEN  = 10
) (
  input clk,
  input sys_rst,

//landmark numbers
`ifdef LANDMARK_NUM_IN
  input   [ROW_LEN-1 : 0]  landmark_num,  //总地标数
`endif
// `ifdef L_K_IN
  input   [ROW_LEN-1 : 0]  l_k,           //当前地标编号
// `endif
//handshake of stage change
  input   [2:0]   stage_val,
  output  reg [2:0]   stage_rdy,

//handshake of nonlinear calculation start & complete
  //nonlinear start(3 stages are conbined)
  output   reg [2:0]   nonlinear_m_rdy,
  input  [2:0]     nonlinear_s_val,
  //nonlinear cplt(3 stages are conbined)
  output   reg [2:0]   nonlinear_m_val,
  input  [2:0]     nonlinear_s_rdy,

//sel en we addr are wire connected to the regs of dshift out. actually they are reg output
  output  [A_IN_SEL_DW*X-1 : 0]       A_in_sel,
  output reg [X-1 : 0]                A_in_en,   

  output  [B_IN_SEL_DW*Y-1 : 0]       B_in_sel,   
  output reg [Y-1 : 0]                B_in_en,  

  output  [M_IN_SEL_DW*X-1 : 0]       M_in_sel,  
  output reg [X-1 : 0]                M_in_en,   

  output  [C_OUT_SEL_DW*X-1 : 0]      C_out_sel, 
  output reg [X-1 : 0]                C_out_en,

  output reg [TB_DINA_SEL_DW-1 : 0]       TB_dina_sel,
  output reg [TB_DINB_SEL_DW-1 : 0]       TB_dinb_sel,
  output reg [TB_DOUTA_SEL_DW-1 : 0]      TB_douta_sel,
  output reg [TB_DOUTB_SEL_DW-1 : 0]      TB_doutb_sel,

  output  [L-1 : 0]         TB_ena,
  output  [L-1 : 0]         TB_enb,

  output  [L-1 : 0]         TB_wea,
  output  [L-1 : 0]         TB_web,

  output  [L*TB_AW-1 : 0]      TB_addra,
  output  [L*TB_AW-1 : 0]      TB_addrb,

  output reg [CB_DINB_SEL_DW-1 : 0]      CB_dinb_sel,
  output reg [CB_DOUTA_SEL_DW-1 : 0]     CB_douta_sel,

  output [L-1 : 0]        CB_ena,
  output [L-1 : 0]        CB_enb,

  output [L-1 : 0]        CB_wea,
  output [L-1 : 0]        CB_web,

  output [L*CB_AW-1 : 0]      CB_addra,
  output [L*CB_AW-1 : 0]      CB_addrb,

  output reg [L*RSA_DW-1 : 0]     CB_dina,

  output  [Y-1:0]         B_cache_en,
  output  [Y-1:0]         B_cache_we,
  output  [Y*3-1:0]       B_cache_addr,

  output [SEQ_CNT_DW-1:0]   seq_cnt_dout_sel, 

  output [2*X-1 : 0]          M_adder_mode, 
  output reg [1:0]            PE_mode,
  output  [Y-1 : 0]           new_cal_en,
  output  [Y-1 : 0]           new_cal_done

);

//delay
  localparam RD_DELAY = 3;
  localparam WR_DELAY = 2;
  localparam AGD_DELAY = 5;

  localparam RD_SEL_D = 1'd1;
  localparam AB_IN_SEL_D = 2'd3;
  localparam CAL_EN_D = 2'd3;
  localparam PE_MODE_D = 3'd4;
  localparam M_IN_SEL_D = 3'd7;
  localparam C_OUT_SEL_D = 4'd8;
  localparam WR_SEL_D = 4'd9;

  localparam SET_2_PEin = 3'd4;    //给出addr_new到westin

  localparam RD_2_WR_D = 3'd7;
  
  localparam ADDER_2_NEW = 1'd1;   //adder输出到给addr_new

//shift 
//   localparam DIR_POS = 1'b0;
//   localparam DIR_NEG = 1'b1;
  localparam DIR_IDLE = 2'b00;
  localparam DIR_POS  = 2'b01;
  localparam DIR_NEG  = 2'b10;
  localparam DIR_NEW  = 2'b11;

  // localparam DIR_NEW_0  = 1'b0;
  // localparam DIR_NEW_1  = 1'b1;

//PE_mode
  localparam N_W = 2'b00;
  localparam S_W = 2'b10;
  localparam N_E = 2'b01;
  localparam S_E = 2'b11;

//A map mode
  localparam A_TBa = 2'b00;
  localparam A_CBa = 2'b10;
  localparam A_NONE = 2'b11;

//B map mode
  localparam B_TBb = 2'b00;
  localparam B_cache = 2'b01;
  localparam B_CBa = 2'b10;
  localparam B_NONE = 2'b11;

//M map mode
  localparam M_TBa = 2'b00;
  localparam M_CBa = 2'b10;
  localparam M_NONE = 2'b11;

//adder mode
  localparam NONE = 2'b00;
  localparam ADD = 2'b01;
  localparam C_MINUS_M = 2'b10;
  localparam M_MINUS_C = 2'b11;

//C map mode
  localparam  C_TBb = 2'b00;
  localparam  C_CBb = 2'b10;
  localparam  C_NONE = 2'b11;

//CB portA map mode

//CB portB map mode

/*
  *********************** TB mode config **********************
*/
  localparam TB_IDLE = 5'b00000;
//MODE[4:2] PARAMS
  //TBa RD
    localparam TBa_IDLE = 3'b000;
    localparam TBa_A = 3'b001;
    localparam TBa_M = 3'b010;
    localparam TBa_AM = 3'b011;
  //TBa WR
    localparam TBa_cov_lm = 3'b100;
    localparam TBa_nonlinear = 3'b101;

  //TBb RD
    localparam TBb_IDLE = 3'b000;
    localparam TBb_B = 3'b001;
    localparam TBb_B_cache = 3'b100;

  //TBb WR
    localparam TBb_C = 3'b010;
    localparam TBb_BC = 3'b011;

  //MODE[1:0] PARAMS （declared above）
  //B C下的对应
    // localparam DIR_IDLE = 2'b00;
    // localparam DIR_POS  = 2'b01;
    // localparam DIR_NEW_0  = 2'b10;
    // localparam DIR_NEW_1  = 2'b11;

  //B_cache模式下对应的TBb_mode[1:0]
      localparam B_cache_IDLE = 2'b00;
      localparam B_cache_trnsfer = 2'b01;
      localparam B_cache_transpose = 2'b10;
      localparam B_cache_inv = 2'b11;

/*
  ************************** CB mode config *********************
*/
  localparam CB_IDLE = 5'b00000;
  //CB_mode[4:3] dir
  localparam CBa_TBa = 2'b00;
  localparam CBa_A = 2'b01;
  localparam CBa_B = 2'b10;
  localparam CBa_M = 2'b11;

  localparam CBb_C = 2'b01;  

  //CB_mode[2:0] mode
  localparam CB_cov_vv = 3'b001;
  localparam CB_cov_mv = 3'b010;
  localparam CB_cov    = 3'b011;
  localparam CB_cov_lv = 3'b100;
  localparam CB_cov_lm = 3'b101;
  localparam CB_cov_ml = 3'b110;
  localparam CB_cov_ll = 3'b111;

/*
  ********************** params of FSMs *************************
*/
//stage
  localparam      IDLE       = 3'b000 ;
  localparam      STAGE_PRD  = 3'b001 ;
  localparam      STAGE_NEW  = 3'b010 ;
  localparam      STAGE_UPD  = 3'b100 ;
  // parameter      STAGE_INIT = 3'b111 ;

//stage_rdy
  localparam BUSY  = 3'b000;
  localparam READY   = 3'b111;

//SEQ_CNT_PARAM
  localparam [SEQ_CNT_DW-1 : 0] SEQ_0 = 'd0;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_1 = 'd1;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_2 = 'd2;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_3 = 'd3;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_4 = 'd4;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_5 = 'd5;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_6 = 'd6;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_7 = 'd7;
/*
  ******************* params of Prediction stage *****************
*/
  // TEMP BANK offsets of PRD
    localparam [TB_AW-1 : 0] F_xi = 'd0;
    localparam [TB_AW-1 : 0] F_xi_T = 'd3;
    localparam [TB_AW-1 : 0] t_cov = 'd6;
    localparam [TB_AW-1 : 0] F_cov = 'd9;
    localparam [TB_AW-1 : 0] M_t = 'd12;
  // PREDICTION SERIES
    localparam PRD_IDLE = 'b0000;
    localparam PRD_NONLINEAR = 'b0001;
    localparam PRD_1 = 'b0010;       //prd_cur[1]
    localparam PRD_2 = 'b0100;
    localparam PRD_3 = 'b1000;

    // localparam PRD_1_START = 0;
    // localparam PRD_2_START = 'd18;
    // localparam PRD_3_START = 'd36;

    localparam [SEQ_CNT_DW-1 : 0] PRD_1_CNT_MAX = 'd17;
    localparam [SEQ_CNT_DW-1 : 0] PRD_2_CNT_MAX = 'd17;
    localparam [SEQ_CNT_DW-1 : 0] PRD_3_CNT_MAX = 'd5;

    localparam PRD_1_M = 3'b011;
    localparam PRD_2_M = 3'b011;
    localparam PRD_3_M = 3'b100;

    localparam PRD_1_N = 3'b011;
    localparam PRD_2_N = 3'b011;
    localparam PRD_3_N = 3'b011;

    localparam PRD_1_K = 3'b011;
    localparam PRD_2_K = 3'b011;
    localparam PRD_3_K = 3'b011;


/*
  NEW: params of New landmark initialization stage
*/
  // TEMP BANK offsets of PRD
    localparam [TB_AW-1 : 0] G_xi          = 'd15;
    localparam [TB_AW-1 : 0] G_z           = 'd18;
    localparam [TB_AW-1 : 0] Q         = 'd20;
    localparam [TB_AW-1 : 0] G_z_Q         = 'd22;
    localparam [TB_AW-1 : 0] lv_G_xi           = 'd24;
  // PREDICTION SERIES
    localparam NEW_IDLE      = 'b000000;
    localparam NEW_NONLINEAR = 'b000001;
    localparam NEW_1         = 'b000010;       //prd_cur[1]
    localparam NEW_2         = 'b000100;
    localparam NEW_3         = 'b001000;
    localparam NEW_4         = 'b010000;
    localparam NEW_5         = 'b100000;

    localparam [SEQ_CNT_DW-1 : 0] NEW_1_CNT_MAX     = 'd5;
    localparam [SEQ_CNT_DW-1 : 0] NEW_2_CNT_MAX     = 'd7;
    localparam [SEQ_CNT_DW-1 : 0] NEW_3_CNT_MAX     = 'd7;
    localparam [SEQ_CNT_DW-1 : 0] NEW_4_CNT_MAX     = 'd11;
    localparam [SEQ_CNT_DW-1 : 0] NEW_5_CNT_MAX     = 'd11;

    localparam NEW_1_M       = 3'b010;
    localparam NEW_2_M       = 3'b010;
    localparam NEW_3_M       = 3'b010;
    localparam NEW_4_M       = 3'b010;
    localparam NEW_5_M       = 3'b010;
    
    localparam NEW_1_N       = 3'b011;
    localparam NEW_2_N       = 3'b011;
    localparam NEW_3_N       = 3'b011;
    localparam NEW_4_N       = 3'b010;
    localparam NEW_5_N       = 3'b010;

    localparam NEW_1_K       = 3'b011;
    localparam NEW_2_K       = 3'b100;
    localparam NEW_3_K       = 3'b010;
    localparam NEW_4_K       = 3'b010;
    localparam NEW_5_K       = 3'b010;
    localparam NEW_3_DELAY   = 4'd7;

/*
  UPD: params of Update stage
*/
  // TEMP BANK offsets of PRD
    localparam [TB_AW-1 : 0] H_xi          = 'd26;
    localparam [TB_AW-1 : 0] H_z           = 'd29;
    localparam [TB_AW-1 : 0] S_t           = 'd31;
    localparam [TB_AW-1 : 0] t_cov_HT      = 'd33;
    localparam [TB_AW-1 : 0] cov_HT        = 'd38;
    localparam [TB_AW-1 : 0] t_cov_l       = 'd40;
    localparam [TB_AW-1 : 0] K_t           = 'd40;
  // PREDICTION SERIES
    localparam UPD_IDLE      = 11'b000_0000_0000;
    localparam UPD_NONLINEAR = 11'b1;
    localparam UPD_1         = 11'b10;       
    localparam UPD_2         = 11'b100;
    localparam UPD_3         = 11'b1000;
    localparam UPD_4         = 11'b1_0000;
    localparam UPD_5         = 11'b10_0000;
    localparam UPD_6         = 11'b100_0000;
    localparam UPD_7         = 11'b1000_0000;
    localparam UPD_8         = 11'b1_0000_0000;
    localparam UPD_9         = 11'b10_0000_0000;
    localparam UPD_10        = 11'b100_0000_0000;

    localparam [SEQ_CNT_DW-1 : 0] UPD_1_CNT_MAX     = 'd4;
    localparam [SEQ_CNT_DW-1 : 0] UPD_2_CNT_MAX     = 'd2;
    localparam [SEQ_CNT_DW-1 : 0] UPD_3_CNT_MAX     = 'd2;
    localparam [SEQ_CNT_DW-1 : 0] UPD_4_CNT_MAX     = 'd3;
    localparam [SEQ_CNT_DW-1 : 0] UPD_5_CNT_MAX     = 'd3;
    localparam [SEQ_CNT_DW-1 : 0] UPD_6_CNT_MAX     = 'd8;
    localparam [SEQ_CNT_DW-1 : 0] UPD_7_CNT_MAX     = 'd13;
    localparam [SEQ_CNT_DW-1 : 0] UPD_8_CNT_MAX     = 'd8;
    localparam [SEQ_CNT_DW-1 : 0] UPD_9_CNT_MAX     = 'd3;
    localparam [SEQ_CNT_DW-1 : 0] UPD_10_CNT_MAX    = 'd7;

    localparam UPD_1_M       = 3'b000;
    localparam UPD_2_M       = 3'b011;
    localparam UPD_3_M       = 3'b100;
    localparam UPD_4_M       = 3'b100;
    localparam UPD_5_M       = 3'b100;
    localparam UPD_6_M       = 3'b000;
    localparam UPD_7_M       = 3'b010;
    localparam UPD_8_M       = 3'b000;
    localparam UPD_9_M       = 3'b100;
    localparam UPD_10_M      = 3'b100;
    
    localparam UPD_1_N       = 3'b101;
    localparam UPD_2_N       = 3'b011;
    localparam UPD_3_N       = 3'b011;
    localparam UPD_4_N       = 3'b010;
    localparam UPD_5_N       = 3'b010;
    localparam UPD_6_N       = 3'b101;
    localparam UPD_7_N       = 3'b101;
    localparam UPD_8_N       = 3'b010;
    localparam UPD_9_N       = 3'b010;
    localparam UPD_10_N      = 3'b010;

    localparam UPD_1_K       = 3'b000;
    localparam UPD_2_K       = 3'b010;
    localparam UPD_3_K       = 3'b010;
    localparam UPD_4_K       = 3'b010;
    localparam UPD_5_K       = 3'b010;
    localparam UPD_6_K       = 3'b000;
    localparam UPD_7_K       = 3'b010;
    localparam UPD_8_K       = 3'b000;
    localparam UPD_9_K       = 3'b010;
    localparam UPD_10_K      = 3'b100;

/*
  ******************DATA FLOW config*******************
*/
  reg [2:0] PE_m;
  reg [2:0] PE_n;
  reg [2:0] PE_k;

  reg [1:0] CAL_mode;

  reg [A_IN_SEL_DW-1:0] A_in_mode;
  reg [B_IN_SEL_DW-1:0] B_in_mode;
  reg [M_IN_SEL_DW-1:0] M_in_mode; 
  reg [1:0]             M_adder_mode_set;
  reg [C_OUT_SEL_DW-1:0] C_out_mode;

  reg [4:0] TBa_mode;
  reg [4:0] TBb_mode;
  reg [4:0] CBa_mode;
  reg [4:0] CBb_mode;

  reg [TB_AW-1:0] A_TB_base_addr;
  reg [TB_AW-1:0] B_TB_base_addr;
  reg [TB_AW-1:0] M_TB_base_addr;
  reg [TB_AW-1:0] C_TB_base_addr;

  reg [TB_AW-1:0] A_TB_base_addr_set;
  reg [TB_AW-1:0] B_TB_base_addr_set;
  reg [TB_AW-1:0] M_TB_base_addr_set;
  reg [TB_AW-1:0] C_TB_base_addr_set;

/*
  ****************CAL_mode config****************
*/
  //A_in_en 
  //B_in_en 
  //M_in_en 
  //C_out_en 

  wire [A_IN_SEL_DW-1:0] A_in_sel_new;
  wire [B_IN_SEL_DW-1:0] B_in_sel_new;
  wire [M_IN_SEL_DW-1:0] M_in_sel_new; 
  wire [1:0]             M_adder_mode_new;
  wire [C_OUT_SEL_DW-1:0] C_out_sel_new;

  reg [1:0] A_in_sel_dir;
  reg [1:0] B_in_sel_dir;
  reg [1:0] M_in_sel_dir;
  reg [1:0] C_out_sel_dir;

  reg [1:0] cal_en_done_dir;

/*
  **************Address Generate Config*****************
*/
  //TB def
  reg [TB_DINB_SEL_DW-1 : 0]       TB_dina_sel_new;
  reg [TB_DINB_SEL_DW-1 : 0]       TB_dinb_sel_new;
  reg [TB_DOUTA_SEL_DW-1 : 0]      TB_douta_sel_new;
  reg [TB_DOUTB_SEL_DW-1 : 0]      TB_doutb_sel_new; 
    
  reg [1:0]                          TBa_shift_dir;
  reg [1:0]                          TBb_shift_dir;

  reg                           TB_ena_new;
  reg                           TB_wea_new;
  reg [TB_AW-1 : 0]             TB_addra_new;

  reg                           TB_enb_new;
  reg                           TB_web_new;
  reg [TB_AW-1 : 0]             TB_addrb_new;
  
  //B_cache def
  reg                           B_cache_en_new;
  reg                           B_cache_we_new;
  reg [2 : 0]                   B_cache_addr_new;

  //CB def
    //port A
    reg [CB_DINB_SEL_DW-1 : 0]    CB_dinb_sel_new;
    reg [1:0]                     CBa_shift_dir; 

    reg                           CB_ena_new;
    reg                           CB_wea_new;
    reg [CB_AW-1 : 0]             CB_addra_new;
    
    reg [CB_AW-1 : 0]            CB_addra_base;

    //port B
    reg [CB_DOUTA_SEL_DW-1 : 0]   CB_douta_sel_new;
    reg [1:0]                     CBb_shift_dir;

    reg                           CB_enb_new;
    reg                           CB_web_new;
    reg [CB_AW-1 : 0]             CB_addrb_new;

    reg [CB_AW-1 : 0]             CB_addrb_base;

/*
    l_k 
*/
    reg [ROW_LEN:0]     l_k_row;
    reg [ROW_LEN-1:0]   l_k_group;
    reg [ROW_LEN-1:0]   l_k_t_cov_l;
    reg [CB_AW-1 : 0]  l_k_base_addr_RD; 
    reg [CB_AW-1 : 0]  l_k_base_addr_WR; 
    wire l_k_0;
    assign l_k_0 = l_k[0];

/*
  ******* variables of FSM of STAGE(IDLE PRD NEW UPD) *************
*/

  reg [2:0]      stage_cur ;   
  reg          stage_change_err;  

/*
  **************** variables of Prediction(PRD) *********************
*/
  reg [3:0]   prd_cur;
  reg [5:0]   new_cur;
  reg [10:0]   upd_cur;
  reg [SEQ_CNT_DW-1:0]   seq_cnt;      //时序计数器
  reg [SEQ_CNT_DW-1:0]   seq_cnt_max;  //计数器上限
  reg [ROW_LEN-1:0]   v_group_cnt;    //组计数器（4行，2个地标为1组）
  reg [ROW_LEN-1 : 0] v_group_cnt_max;    //组数目
  reg [ROW_LEN-1:0]   h_group_cnt;    //横向列计数器（UPD_7更新cov）
  reg [ROW_LEN-1 : 0] h_group_cnt_max;    //列组数目

  //******************* seq_cnt延迟 *************************
  // output [SEQ_CNT_DW-1:0]   seq_cnt_dout_sel;      
    dynamic_shreg 
    #(
      .DW    (SEQ_CNT_DW    ),
      .AW    (2    )
    )
    seq_cnt_dout_sel_dynamic_shreg(
      .clk  (clk  ),
      .ce   (1'b1   ),
      .addr (2'b10 ),
      .din  (seq_cnt  ),
      .dout (seq_cnt_dout_sel )
    );

  //******************* M读取状态延迟*************************
    wire [SEQ_CNT_DW-1 : 0] seq_cnt_M;
    reg  [2:0]              M_RD_d_addr;
    always @(posedge clk) begin
      if(sys_rst) begin
        M_RD_d_addr <= 0;
      end
      else begin
        M_RD_d_addr <= PE_n + 1'b1;
      end 
    end
    
    dynamic_shreg 
    #(
      .DW    (SEQ_CNT_DW    ),
      .AW    (3    )
    )
    u_dynamic_shreg(
    	.clk  (clk  ),
      .ce   (1'b1   ),
      .addr (M_RD_d_addr ),
      .din  (seq_cnt  ),
      .dout (seq_cnt_M )
    );
  //******************* 写入状态延迟 *************************
    wire [SEQ_CNT_DW-1 : 0] seq_cnt_WR;
    wire [ROW_LEN-1 : 0] v_group_cnt_WR;
    wire [4:0]           TBb_mode_WR;
    wire [4:0]           CBb_mode_WR;
    wire [2:0]           PE_n_WR;
    
    reg [3 : 0]          WR_d_addr;       //具体取多少级延迟
    always @(posedge clk) begin
      if(sys_rst) begin
        WR_d_addr <= RD_2_WR_D;
      end
      else begin
        WR_d_addr <= RD_2_WR_D + PE_n;
      end 
    end
    
    dynamic_shreg 
    #(
      .DW    (3    ),
      .AW    (4    )
    )
    PE_n_dynamic_shreg(
      .clk  (clk  ),
      .ce   (1'b1   ),
      .addr (WR_d_addr ),
      .din  (PE_n  ),
      .dout (PE_n_WR )
    );

    dynamic_shreg 
    #(
      .DW  (SEQ_CNT_DW  ),
      .AW  (4  )
    )
    seq_cnt_shreg(
      .clk  (clk  ),
      .ce   (1'b1  ),
      .addr (WR_d_addr ),
      .din  (seq_cnt  ),
      .dout (seq_cnt_WR )
    );

    dynamic_shreg 
    #(
      .DW  (ROW_LEN  ),
      .AW  (4  )
    )
    group_cnt_shreg(
      .clk  (clk  ),
      .ce   (1'b1  ),
      .addr (WR_d_addr ),
      .din  (v_group_cnt  ),
      .dout (v_group_cnt_WR )
    );

    dynamic_shreg 
    #(
      .DW  (5  ),
      .AW  (4  )
    )
    TBb_mode_shreg(
      .clk  (clk  ),
      .ce   (1'b1  ),
      .addr (WR_d_addr ),
      .din  (TBb_mode  ),
      .dout (TBb_mode_WR )
    );

    dynamic_shreg 
    #(
      .DW  (5  ),
      .AW  (4  )
    )
    CBb_mode_shreg(
      .clk  (clk  ),
      .ce   (1'b1  ),
      .addr (WR_d_addr ),
      .din  (CBb_mode  ),
      .dout (CBb_mode_WR )
    );

/*
  ****************** FSM of STAGE(IDLE PRD NEW UPD) *******************
*/
  //(1)&(2) state switch
  always @(posedge clk) begin
    if(sys_rst) begin
      stage_cur <= IDLE;
    end
    else begin
      case(stage_cur)
        IDLE: begin
                case(stage_val & stage_rdy)
                  IDLE:       stage_cur <= IDLE;
                  STAGE_PRD:  stage_cur <= STAGE_PRD;
                  STAGE_NEW:  stage_cur <= STAGE_NEW;
                  STAGE_UPD:  stage_cur <= STAGE_UPD;
                  default: begin
                    stage_cur <= IDLE;
                    stage_change_err <= 1'b1;
                  end  
                endcase
              end
        //STAGE_PRD  STAGE_NEW  STAGE_UPD
        STAGE_PRD:begin
                    if(prd_cur == PRD_3 && seq_cnt == seq_cnt_max && v_group_cnt == v_group_cnt_max)
                      stage_cur <= IDLE;
                    else
                      stage_cur <= STAGE_PRD;
                  end
        STAGE_NEW:begin
                    if(new_cur == NEW_5 && seq_cnt == seq_cnt_max && v_group_cnt == v_group_cnt_max)
                      stage_cur <= IDLE;
                    else
                      stage_cur <= STAGE_NEW;
                  end
        STAGE_UPD:begin
                    if(upd_cur == UPD_10 && seq_cnt == seq_cnt_max && v_group_cnt == v_group_cnt_max && h_group_cnt == h_group_cnt_max)
                      stage_cur <= IDLE;
                    else
                      stage_cur <= STAGE_UPD;
                  end
        default: stage_cur <= IDLE;
      endcase
    end
  end

  //(3) output: stage handshake
  always @(posedge clk) begin
    if(sys_rst)
      stage_rdy <= READY;
    else if(stage_cur != IDLE) begin
      stage_rdy <= BUSY;
    end
    else
      stage_rdy <= READY;
  end

  /*
    (4) output: nonlinear_val, nonlinear_rdy
  */
  always @(posedge clk) begin
    if(sys_rst)
      nonlinear_m_rdy <= 0;
    else if(prd_cur == PRD_IDLE || new_cur == NEW_IDLE || upd_cur == UPD_IDLE) begin
      nonlinear_m_rdy <= 1'b1;
    end
    else
      nonlinear_m_rdy <= 0;  
  end 

  always @(posedge clk) begin
    if(sys_rst)
      nonlinear_m_val <= 0;
    else if(prd_cur == PRD_NONLINEAR || new_cur == NEW_NONLINEAR || upd_cur == UPD_NONLINEAR) begin
      nonlinear_m_val <= 1'b1;
    end
    else
      nonlinear_m_val <= 0;  
  end 

  //(5)output: calculate the landmark number
`ifndef LANDMARK_NUM_IN
  reg [ROW_LEN-1 : 0]  landmark_num;
  always @(posedge clk) begin
    if(sys_rst)
      landmark_num <= 0;
    else begin
      if(stage_cur == STAGE_NEW && new_cur == NEW_5 && seq_cnt == seq_cnt_max && v_group_cnt == v_group_cnt_max)
        landmark_num <= landmark_num + 1'b1;
      else 
        landmark_num <= landmark_num;
    end
  end
`endif

// `ifndef L_K_IN
  // reg [ROW_LEN-1 : 0]  l_k = 'd3;
// `endif
  /*
    ************************** calculate l_k group ******************8
  */
    always @(posedge clk) begin
      if(sys_rst) begin
        l_k_row <= 0;
      end
      else 
        l_k_row <= (l_k + 1'b1) << 1;
    end

    always @(posedge clk) begin
      if(sys_rst) begin
        l_k_group <= 0;
      end
      else begin
        case (stage_cur)
          STAGE_NEW: l_k_group <= (l_k + 1'b1) >> 1;
          STAGE_UPD: l_k_group <= (l_k + 1'b1) >> 1;
          default: l_k_group <= 0;
        endcase
      end
    end

    always @(posedge clk) begin
      if(sys_rst) begin
        l_k_t_cov_l <= 0;
      end
      else begin
        if(l_k == 1'b1)
          l_k_t_cov_l <= 1'b1;      //保证H_T能读完
        else
          l_k_t_cov_l <= l_k >> 1;      
      end
    end
/*
  (using) FSM of PRD stage, with seq_cnt back to 0 when prd_cur changes
*/
/*
  ***************** (0) calculate seq_cnt ***********************
*/
  //seq_cnt_max LUT
  always @(*) begin
    case(stage_cur)
      STAGE_PRD: begin
        case(prd_cur)
          PRD_1: seq_cnt_max = PRD_1_CNT_MAX;
          PRD_2: seq_cnt_max = PRD_2_CNT_MAX;
          PRD_3: seq_cnt_max = PRD_3_CNT_MAX;
          default: seq_cnt_max = 0;
        endcase
      end
      STAGE_NEW: begin
        case(new_cur)
          NEW_1: seq_cnt_max = NEW_1_CNT_MAX;
          NEW_2: seq_cnt_max = NEW_2_CNT_MAX;
          NEW_3: seq_cnt_max = NEW_3_CNT_MAX;
          NEW_4: seq_cnt_max = NEW_4_CNT_MAX;
          NEW_5: seq_cnt_max = NEW_5_CNT_MAX;
          default: seq_cnt_max = 0;
        endcase
      end
      STAGE_UPD: begin
        case(upd_cur)
          UPD_1: seq_cnt_max = UPD_1_CNT_MAX;
          UPD_2: seq_cnt_max = UPD_2_CNT_MAX;
          UPD_3: seq_cnt_max = UPD_3_CNT_MAX;
          UPD_4: seq_cnt_max = UPD_4_CNT_MAX;
          UPD_5: seq_cnt_max = UPD_5_CNT_MAX;
          UPD_6: seq_cnt_max = UPD_6_CNT_MAX;
          UPD_7: seq_cnt_max = UPD_7_CNT_MAX;
          UPD_8: seq_cnt_max = UPD_8_CNT_MAX;
          UPD_9: seq_cnt_max = UPD_9_CNT_MAX;
          UPD_10: seq_cnt_max = UPD_10_CNT_MAX;
          default: seq_cnt_max = 0;
        endcase
      end
      default: seq_cnt_max = 0;
    endcase
  end

  always @(posedge clk) begin
    if(sys_rst) begin
      seq_cnt <= 0;
    end
    else begin
      if(seq_cnt >= seq_cnt_max)
        seq_cnt <= 0;
      else
        seq_cnt <= seq_cnt + 1'b1;
    end
      
  end
/*
  ******************** calculate v_group_cnt ********************
*/
  //*********************** v_group_cnt_max ***************
  always @(posedge clk) begin
    if(sys_rst)
      v_group_cnt_max <= 0;
    else begin
      case(stage_rdy & stage_val)
        STAGE_PRD: v_group_cnt_max <= (landmark_num+1) >> 1;
        STAGE_NEW: v_group_cnt_max <= (landmark_num+1) >> 1;
        STAGE_UPD: v_group_cnt_max <= (landmark_num+1) >> 1;
        default: v_group_cnt_max <= v_group_cnt_max;
      endcase  
    end
  end

  //*********************** v_group_cnt ***************
  always @(posedge clk) begin
    if(sys_rst) begin
      v_group_cnt <= 0;
    end
    else begin
      case(stage_cur)
        STAGE_PRD: 
          case(prd_cur)
            PRD_2: begin
              if(seq_cnt == seq_cnt_max)
                v_group_cnt <= 1'b1;
            end
            PRD_3: begin
              if(seq_cnt == seq_cnt_max) begin
                if(v_group_cnt == v_group_cnt_max) //这已经是最后一组
                  v_group_cnt <= 0;
                else
                  v_group_cnt <= v_group_cnt + 1'b1;
              end
              else begin
                v_group_cnt <= v_group_cnt;
              end
            end
            default: begin
              v_group_cnt <= 0;
            end
          endcase
        STAGE_NEW: 
          case(new_cur)
            NEW_1: begin
              if(seq_cnt == seq_cnt_max)
                v_group_cnt <= 1'b1;
            end
            NEW_2: begin
                    if(seq_cnt == seq_cnt_max) begin
                      if(v_group_cnt == v_group_cnt_max) //这已经是最后一组
                        v_group_cnt <= 0;
                      else
                        v_group_cnt <= v_group_cnt + 1'b1;
                    end
                    else begin
                      v_group_cnt <= v_group_cnt;
                    end
                  end
            default: begin
              v_group_cnt <= 0;
            end
          endcase
        STAGE_UPD: begin
          case(upd_cur)
            UPD_1: begin
                    if(seq_cnt == seq_cnt_max) begin
                      if(v_group_cnt == l_k_t_cov_l) //这已经是最后一组
                        v_group_cnt <= 0;
                      else
                        v_group_cnt <= v_group_cnt + 1'b1;
                    end
                    else begin
                      v_group_cnt <= v_group_cnt;
                    end
                  end
            UPD_3: begin
                    v_group_cnt <= v_group_cnt;   
                  end
            UPD_4: begin
                    if(seq_cnt == seq_cnt_max) begin
                      if(v_group_cnt == v_group_cnt_max) //这已经是最后一组
                        v_group_cnt <= 0;
                      else
                        v_group_cnt <= v_group_cnt + 1'b1;
                    end
                    else begin
                      v_group_cnt <= v_group_cnt;
                    end
                  end
            UPD_5: begin
                    if(seq_cnt == seq_cnt_max) begin
                      if(v_group_cnt == v_group_cnt_max) //这已经是最后一组
                        v_group_cnt <= 0;
                      else
                        v_group_cnt <= v_group_cnt + 1'b1;
                    end
                    else begin
                      v_group_cnt <= v_group_cnt;
                    end
                  end
            UPD_9: begin
                    if(seq_cnt == seq_cnt_max) begin
                      if(v_group_cnt == v_group_cnt_max) //这已经是最后一组
                        v_group_cnt <= 0;
                      else
                        v_group_cnt <= v_group_cnt + 1'b1;
                    end
                    else begin
                      v_group_cnt <= v_group_cnt;
                    end
                  end
            UPD_10: begin
                    if(seq_cnt == seq_cnt_max) begin
                      if(h_group_cnt == h_group_cnt_max) begin
                        if(v_group_cnt == v_group_cnt_max)
                          v_group_cnt <= 0;
                        else
                          v_group_cnt <= v_group_cnt + 1'b1;
                      end
                      else
                        v_group_cnt <= v_group_cnt;
                    end
                    else begin
                      v_group_cnt <= v_group_cnt;
                    end
                  end
            default: begin
              v_group_cnt <= 0;
            end
          endcase
        end
        default: v_group_cnt <= 0;
      endcase
    end   
  end

/*
  ******************** calculate h_group_cnt ********************
*/
  //*********************** h_group_cnt_max ***************
  always @(posedge clk) begin
    if(sys_rst) begin
      h_group_cnt_max <= 0;
    end
    else begin
      case(stage_cur)
        STAGE_UPD: begin
          case(upd_cur)
            UPD_10: begin
              if(seq_cnt == seq_cnt_max) begin
                if(h_group_cnt == h_group_cnt_max) 
                  h_group_cnt_max <= h_group_cnt_max + 1'b1;
                else
                  h_group_cnt_max <= h_group_cnt_max;
              end
              else begin
                h_group_cnt_max <= h_group_cnt_max;
              end
            end
            default: h_group_cnt_max <= 0;
          endcase
        end
        default: h_group_cnt_max <= 0;
      endcase
    end
  end

  //*********************** h_group_cnt ***************
  always @(posedge clk) begin
    if(sys_rst) begin
      h_group_cnt <= 0;
    end
    else begin
      case(stage_cur)
        STAGE_UPD: begin
          case(upd_cur)
            UPD_10: begin
              if(seq_cnt == seq_cnt_max) begin
                if(h_group_cnt == h_group_cnt_max) 
                  h_group_cnt <= 0;
                else
                  h_group_cnt <= h_group_cnt + 1'b1;
              end
              else begin
                h_group_cnt <= h_group_cnt;
              end
            end
            default: h_group_cnt <= 0;
          endcase
        end
        default: h_group_cnt <= 0;
      endcase
    end
  end

/*
  ****************** 2nd FSM sequential stage transfer ***************
*/
  
  /*
    ******************** PRD state transfer **************************
  */
    always @(posedge clk) begin
      if(stage_val & stage_rdy == STAGE_PRD) begin
        prd_cur <= PRD_IDLE;
      end
      else  begin
        case(prd_cur)
          PRD_IDLE: begin
            if(nonlinear_m_rdy & nonlinear_s_val == STAGE_PRD) begin
              prd_cur <= PRD_NONLINEAR;
            end
            else
              prd_cur <= PRD_IDLE;
          end
          PRD_NONLINEAR: begin
            if(nonlinear_m_val & nonlinear_s_rdy == STAGE_PRD) begin
              prd_cur <= PRD_1;
            end
            else
              prd_cur <= PRD_NONLINEAR;
          end
          PRD_1: begin
            if(seq_cnt == seq_cnt_max) begin
              prd_cur <= PRD_2;
            end
            else begin
              prd_cur <= PRD_1;
            end
          end
          PRD_2: begin
            if(seq_cnt == seq_cnt_max) begin
              prd_cur <= PRD_3;
            end
            else begin
              prd_cur <= PRD_2;
            end
          end
          PRD_3: begin
            if(seq_cnt == seq_cnt_max && v_group_cnt == v_group_cnt_max) begin
              prd_cur <= PRD_IDLE;
            end
            else begin
              prd_cur <= PRD_3;
            end
          end
          default: begin
            prd_cur <= PRD_IDLE;
          end
        endcase
      end
    end
  
  /*
    ************************ NEW state transfer **********************
  */ 
    always @(posedge clk) begin
      if(stage_val & stage_rdy == STAGE_NEW) begin
        new_cur <= NEW_IDLE;
      end
      else  begin
        case(new_cur)
          NEW_IDLE: begin
            if(nonlinear_m_rdy & nonlinear_s_val == STAGE_NEW) begin
              new_cur <= NEW_NONLINEAR;
            end
            else
              new_cur <= NEW_IDLE;
          end
          NEW_NONLINEAR: begin
            if(nonlinear_m_val & nonlinear_s_rdy == STAGE_NEW) begin
              new_cur <= NEW_1;
            end
            else
              new_cur <= NEW_NONLINEAR;
          end
          NEW_1: begin
            if(seq_cnt == seq_cnt_max) begin
              new_cur <= NEW_2;
            end
            else begin
              new_cur <= NEW_1;
            end
          end
          NEW_2: begin
            if(seq_cnt == seq_cnt_max && v_group_cnt == v_group_cnt_max) begin
              new_cur <= NEW_3;
            end
            else begin
              new_cur <= NEW_2;
            end
          end
          NEW_3: begin
            if(seq_cnt == seq_cnt_max) begin
              new_cur <= NEW_4;
            end
            else begin
              new_cur <= NEW_3;
            end
          end
          NEW_4: begin
            if(seq_cnt == seq_cnt_max) begin
              new_cur <= NEW_5;
            end
            else begin
              new_cur <= NEW_4;
            end
          end
          NEW_5: begin
            if(seq_cnt == seq_cnt_max) begin
              new_cur <= NEW_IDLE;
            end
            else begin
              new_cur <= NEW_5;
            end
          end
          default: begin
            new_cur <= NEW_IDLE;
          end
        endcase
      end
    end

  /*
    ************************ UPD state transfer **********************
  */
    always @(posedge clk) begin
      if(stage_val & stage_rdy == STAGE_UPD) begin
        upd_cur <= UPD_IDLE;
      end
      else  begin
        case(upd_cur)
          UPD_IDLE: begin
            if(nonlinear_m_rdy & nonlinear_s_val == STAGE_UPD) begin
              upd_cur <= UPD_NONLINEAR;
            end
            else
              upd_cur <= UPD_IDLE;
          end
          UPD_NONLINEAR: begin
            if(nonlinear_m_val & nonlinear_s_rdy == STAGE_UPD) begin
              upd_cur <= UPD_1;
            end
            else
              upd_cur <= UPD_NONLINEAR;
          end
          UPD_1: begin
            if(seq_cnt == seq_cnt_max && v_group_cnt == l_k_t_cov_l) begin
              upd_cur <= UPD_2;
            end
            else begin
              upd_cur <= UPD_1;
            end
          end
          UPD_2: begin
            if(seq_cnt == seq_cnt_max) begin
              upd_cur <= UPD_4;
            end
            else begin
              upd_cur <= UPD_2;
            end
          end
          UPD_3: begin
            if(seq_cnt == seq_cnt_max) begin
              if(v_group_cnt <= l_k_t_cov_l)
                upd_cur <= UPD_4;
              else
                upd_cur <= UPD_5;
            end
            else begin
              upd_cur <= UPD_3;
            end
          end
          UPD_4: begin
            if(seq_cnt == seq_cnt_max) begin
              if(v_group_cnt == v_group_cnt_max)
                upd_cur <= UPD_6;
              else
                upd_cur <= UPD_3;
            end
            else begin
              upd_cur <= UPD_4;
            end
          end
          UPD_5: begin
            if(seq_cnt == seq_cnt_max) begin
              if(v_group_cnt == v_group_cnt_max)
                upd_cur <= UPD_6;
              else
                upd_cur <= UPD_3;
            end
            else begin
              upd_cur <= UPD_5;
            end
          end
          UPD_6: begin
            if(seq_cnt == seq_cnt_max) begin
              upd_cur <= UPD_7;
            end
            else begin
              upd_cur <= UPD_6;
            end
          end
          UPD_7: begin
            if(seq_cnt == seq_cnt_max) begin
              upd_cur <= UPD_8;
            end
            else begin
              upd_cur <= UPD_7;
            end
          end
          UPD_8: begin
            if(seq_cnt == seq_cnt_max) begin
              upd_cur <= UPD_9;
            end
            else begin
              upd_cur <= UPD_8;
            end
          end
          UPD_9: begin
            if(seq_cnt == seq_cnt_max && v_group_cnt == v_group_cnt_max) begin
              upd_cur <= UPD_10;
            end
            else begin
              upd_cur <= UPD_9;
            end
          end
          UPD_10: begin
            if(seq_cnt == seq_cnt_max && v_group_cnt == v_group_cnt_max && h_group_cnt == h_group_cnt_max) begin
              upd_cur <= UPD_IDLE;
            end
            else begin
              upd_cur <= UPD_10;
            end
          end
          default: begin
            upd_cur <= UPD_IDLE;
          end
        endcase
      end
    end

/*
  **************(disabled) sequential RSA work-mode Config ************************
*/
  // always @(posedge clk) begin
  //   if(sys_rst) begin
  //     PE_m <= 0;
  //     PE_n <= 0;
  //     PE_k <= 0;

  //     CAL_mode <= N_W;

  //     A_in_mode <= A_TBa;   
  //     B_in_mode <= B_TBb;
  //     M_in_mode <= M_TBa;
  //     C_out_mode <= C_CBb;
  //     M_adder_mode_set <= NONE;

  //     TBa_mode <= TB_IDLE;
  //     TBb_mode <= TB_IDLE;
  //     CBa_mode <= CB_IDLE;
  //     CBb_mode <= CB_IDLE;

  //     A_TB_base_addr <= 0;
  //     B_TB_base_addr <= 0;
  //     M_TB_base_addr <= 0;
  //     C_TB_base_addr <= 0;
  //   end
  //   else begin
  //     case(stage_cur)
  //       STAGE_PRD: begin
  //         case (prd_cur)
  //           PRD_1: begin
  //             PE_m <= PRD_1_M;
  //             PE_n <= PRD_1_N;
  //             PE_k <= PRD_1_K;

  //             CAL_mode <= N_W;

  //             A_in_mode <= A_TBa;   
  //             B_in_mode <= B_CBa;
  //             M_in_mode <= M_NONE;
  //             C_out_mode <= C_TBb;
  //             M_adder_mode_set <= NONE;

  //             TBa_mode <= {TBa_A,DIR_POS};
  //             TBb_mode <= {TBb_C,DIR_POS};
  //             CBa_mode <= {CBa_B,CB_cov_vv};
  //             CBb_mode <= CB_IDLE;

  //             A_TB_base_addr <= F_xi;
  //             B_TB_base_addr <= 0;
  //             M_TB_base_addr <= 0;
  //             C_TB_base_addr <= F_cov;
  //           end
  //           PRD_2: begin
  //             PE_m <= PRD_2_M;
  //             PE_n <= PRD_2_N;
  //             PE_k <= PRD_2_K;

  //             CAL_mode <= N_W;

  //             A_in_mode <= A_TBa;   
  //             B_in_mode <= B_TBb;
  //             M_in_mode <= M_TBa;
  //             C_out_mode <= C_CBb;
  //             M_adder_mode_set <= ADD;

  //             TBa_mode <= {TBa_AM,DIR_POS};
  //             TBb_mode <= {TBb_B,DIR_POS};
  //             CBa_mode <= CB_IDLE;
  //             CBb_mode <= {CBb_C,CB_cov_vv};

  //             A_TB_base_addr <= F_cov;
  //             B_TB_base_addr <= F_xi;
  //             M_TB_base_addr <= M_t;
  //             C_TB_base_addr <= 0;
  //           end
  //           PRD_3: begin
  //             PE_m <= PRD_3_M;
  //             PE_n <= PRD_3_N;
  //             PE_k <= PRD_3_K;

  //             CAL_mode <= N_W;

  //             A_in_mode <= A_CBa;   
  //             B_in_mode <= B_TBb;
  //             M_in_mode <= M_NONE;
  //             C_out_mode <= C_CBb;
  //             M_adder_mode_set <= NONE;

  //             TBa_mode <= {TBa_IDLE,DIR_IDLE};
  //             TBb_mode <= {TBb_B,DIR_POS};
  //             CBa_mode <= {CBa_A,CB_cov_mv};
  //             CBb_mode <= {CBb_C,CB_cov_mv};

  //             A_TB_base_addr <= 0;
  //             B_TB_base_addr <= F_xi;
  //             M_TB_base_addr <= 0;
  //             C_TB_base_addr <= 0;
  //           end
  //           default: begin
  //             PE_m <= 0;
  //             PE_n <= 0;
  //             PE_k <= 0;

  //             CAL_mode <= N_W;

  //             A_in_mode <= A_TBa;   
  //             B_in_mode <= B_TBb;
  //             M_in_mode <= M_TBa;
  //             C_out_mode <= C_CBb;
  //             M_adder_mode_set <= NONE;

  //             TBa_mode <= TB_IDLE;
  //             TBb_mode <= TB_IDLE;
  //             CBa_mode <= CB_IDLE;
  //             CBb_mode <= CB_IDLE;

  //             A_TB_base_addr <= 0;
  //             B_TB_base_addr <= 0;
  //             M_TB_base_addr <= 0;
  //             C_TB_base_addr <= 0;
  //           end
  //         endcase
  //       end
  //       STAGE_NEW: begin
  //         case(new_cur)
  //           NEW_1: begin
  //           /*
  //             G_xi * t_cov = cov_lm
  //             X=2 Y=2 N=3
  //             Ain: TB-A
  //             bin: CB-A
  //             Cout: CB-B
  //           */
  //             PE_m <= NEW_1_M;
  //             PE_n <= NEW_1_N;
  //             PE_k <= NEW_1_K;

  //             CAL_mode <= N_W;

  //             A_in_mode <= A_TBa;   
  //             B_in_mode <= B_CBa;
  //             M_in_mode <= M_NONE;
  //             C_out_mode <= C_CBb;
  //             M_adder_mode_set <= NONE;

  //             TBa_mode <= {TBa_A,DIR_POS};
  //             TBb_mode <= TB_IDLE;
  //             CBa_mode <= {CBa_B,CB_cov_vv};
  //             CBb_mode <= {CBb_C,CB_cov_lv};

  //             A_TB_base_addr <= G_xi;
  //             B_TB_base_addr <= 0;
  //             M_TB_base_addr <= 0;
  //             C_TB_base_addr <= 0;
              
  //           end
  //           NEW_2: begin
  //           /*
  //             G_xi * cov_mv = cov_lv
  //             X=2 Y=4 N=3
  //             Ain: TB-A
  //             Bin: CB-A
  //             Min: 0
  //             Cout: CB-B
  //           */
  //             PE_m <= NEW_2_M;
  //             PE_n <= NEW_2_N;
  //             PE_k <= NEW_2_K;

  //             CAL_mode <= N_W;

  //             A_in_mode <= A_TBa;   
  //             B_in_mode <= B_CBa;
  //             M_in_mode <= M_TBa;
  //             C_out_mode <= C_CBb;
  //             M_adder_mode_set <= NONE;

  //             TBa_mode <= {TBa_A,DIR_POS};
  //             TBb_mode <= TB_IDLE;
  //             CBa_mode <= {CBa_B,CB_cov_mv};
  //             CBb_mode <= {CBb_C,CB_cov_lm};

  //             A_TB_base_addr <= G_xi;
  //             B_TB_base_addr <= 0;
  //             M_TB_base_addr <= 0;
  //             C_TB_base_addr <= 0;
  //           end
  //           NEW_3: begin
  //           /*
  //             cov_lv * G_xi_T = lv_G_xi
  //             X=2 Y=2 N=3
  //             Ain: CB-A
  //             Bin: TB-B
  //             Min: NONE  
  //             Cout: TB-B
  //           */
  //             PE_m <= NEW_3_M;
  //             PE_n <= NEW_3_N;
  //             PE_k <= NEW_3_K;

  //             CAL_mode <= N_W;

  //             A_in_mode <= A_CBa;   
  //             B_in_mode <= B_TBb;
  //             M_in_mode <= M_NONE;
  //             C_out_mode <= C_TBb;
  //             M_adder_mode_set <= NONE;

  //             TBa_mode <= TB_IDLE;
  //             TBb_mode <= {TBb_BC,DIR_POS};
  //             CBa_mode <= {CBa_A,CB_cov_lv};
  //             CBb_mode <= CB_IDLE;

  //             A_TB_base_addr <= 0;
  //             B_TB_base_addr <= G_xi;
  //             M_TB_base_addr <= 0;
  //             C_TB_base_addr <= lv_G_xi;
  //           end
  //           NEW_4: begin
  //           /*
  //             G_z * Q = G_z_Q
  //             X=2 Y=2 N=2
  //             Ain: TB-A
  //             Bin: TB-B
  //             Min: NONE  
  //             Cout: TB-B
  //           */
  //             PE_m <= NEW_4_M;
  //             PE_n <= NEW_4_N;
  //             PE_k <= NEW_4_K;

  //             CAL_mode <= N_W;

  //             A_in_mode <= A_TBa;   
  //             B_in_mode <= B_TBb;
  //             M_in_mode <= M_NONE;
  //             C_out_mode <= C_TBb;
  //             M_adder_mode_set <= NONE;

  //             TBa_mode <= {TBa_A,DIR_POS};
  //             TBb_mode <= {TBb_BC,DIR_POS};
  //             CBa_mode <= CB_IDLE; 
  //             CBb_mode <= CB_IDLE;

  //             A_TB_base_addr <= G_z;
  //             B_TB_base_addr <= Q;
  //             M_TB_base_addr <= 0;
  //             C_TB_base_addr <= G_z_Q;
  //           end
  //           NEW_5: begin
  //           /*
  //             G_z_Q * G_z_T + lv_G_xi = cov_ll
  //             X=2 Y=2 N=2
  //             Ain: TB-A
  //             Bin: TB-B
  //             Min: TB-A  
  //             Cout: CB-B
  //           */
  //             PE_m <= NEW_5_M;
  //             PE_n <= NEW_5_M;
  //             PE_k <= NEW_5_M;

  //             CAL_mode <= N_W;

  //             A_in_mode <= A_TBa;   
  //             B_in_mode <= B_TBb;
  //             M_in_mode <= M_TBa;
  //             C_out_mode <= C_CBb;
  //             M_adder_mode_set <= ADD;

  //             TBa_mode <= {TBa_AM,DIR_POS};
  //             TBb_mode <= {TBb_B,DIR_POS};
  //             CBa_mode <= CB_IDLE;
  //             CBb_mode <= {CBb_C,CB_cov_ll};

  //             A_TB_base_addr <= 0;
  //             B_TB_base_addr <= 0;
  //             M_TB_base_addr <= 0;
  //             C_TB_base_addr <= 0;
  //           end
  //           default: begin
  //             PE_m <= 0;
  //             PE_n <= 0;
  //             PE_k <= 0;

  //             CAL_mode <= N_W;

  //             A_in_mode <= A_TBa;   
  //             B_in_mode <= B_TBb;
  //             M_in_mode <= M_TBa;
  //             C_out_mode <= C_CBb;
  //             M_adder_mode_set <= NONE;

  //             TBa_mode <= TB_IDLE;
  //             TBb_mode <= TB_IDLE;
  //             CBa_mode <= CB_IDLE;
  //             CBb_mode <= CB_IDLE;

  //             A_TB_base_addr <= 0;
  //             B_TB_base_addr <= 0;
  //             M_TB_base_addr <= 0;
  //             C_TB_base_addr <= 0;
  //           end
  //         endcase
  //       end
  //       STAGE_UPD: begin
  //         case(upd_cur)
  //           UPD_1: begin
  //           /*
  //             transfer H
  //             X=0 Y=2 N=5
  //             Ain: 0
  //             bin: CB-B
  //             Cout: 0
  //           */
  //             PE_m <= UPD_1_M;
  //             PE_n <= UPD_1_N;
  //             PE_k <= UPD_1_K;

  //             CAL_mode <= N_W;

  //             A_in_mode <= A_CBa;   
  //             B_in_mode <= B_TBb;
  //             M_in_mode <= M_NONE;
  //             C_out_mode <= C_CBb;
  //             M_adder_mode_set <= NONE;

  //             TBa_mode <= TB_IDLE;
  //             TBb_mode <= {TBb_B,DIR_POS};
  //             CBa_mode <= TB_IDLE;
  //             CBb_mode <= CB_IDLE;

  //             A_TB_base_addr <= 0;
  //             B_TB_base_addr <= H_xi;
  //             M_TB_base_addr <= 0;
  //             C_TB_base_addr <= 0;
  //           end
  //           UPD_2: begin
  //           /*
  //             cov_mv * H_T = cov_HT
  //             X=4 Y=2 N=3
  //             Ain: CB-A
  //             Bin: B-cache
  //             Min: 0
  //             Cout: TB-B
  //           */
              
  //             PE_m <= UPD_2_M;
  //             PE_n <= UPD_2_N;
  //             PE_k <= UPD_2_K;

  //             CAL_mode <= N_W;

  //             A_in_mode <= A_CBa;   
  //             B_in_mode <= B_cache;
  //             M_in_mode <= M_NONE;
  //             C_out_mode <= C_TBb;
  //             M_adder_mode_set <= NONE;

  //             TBa_mode <= TB_IDLE;
  //             TBb_mode <= {TBb_C,DIR_POS};
  //             CBa_mode <= {CBa_A,CB_cov_mv};
  //             CBb_mode <= CB_IDLE;

  //             A_TB_base_addr <= 0;
  //             B_TB_base_addr <= 0;
  //             M_TB_base_addr <= 0;
  //             C_TB_base_addr <= cov_HT;
  //           end
  //           UPD_3: begin
  //           /*
  //             t_cov_l * H_T = cov_HT
  //             X=4 Y=2 N=2
  //             Ain: TB-A
  //             Bin: B-cache
  //             Min: 0
  //             Cout: 0
  //           */
  //             PE_m <= UPD_3_M;
  //             PE_n <= UPD_3_N;
  //             PE_k <= UPD_3_K;

  //             CAL_mode <= N_W;

  //             A_in_mode <= A_TBa;   
  //             B_in_mode <= B_cache;
  //             M_in_mode <= M_NONE;
  //             C_out_mode <= C_TBb;
  //             M_adder_mode_set <= NONE;

  //             TBa_mode <= {TBa_A,DIR_POS};
  //             TBb_mode <= TB_IDLE;
  //             CBa_mode <= CB_IDLE;
  //             CBb_mode <= CB_IDLE;

  //             A_TB_base_addr <= t_cov_l;
  //             B_TB_base_addr <= 0;
  //             M_TB_base_addr <= 0;
  //             C_TB_base_addr <= 0;
  //           end
  //           UPD_4: begin
  //           /*
  //             cov_l * H_T = cov_HT
  //             X=4 Y=2 N=2
  //             Ain: CB-A
  //             Bin: B-cache
  //             Min: 0
  //             Cout: 0
  //           */
  //             PE_m <= UPD_4_M;
  //             PE_n <= UPD_4_N;
  //             PE_k <= UPD_4_K;

  //             CAL_mode <= N_W;

  //             A_in_mode <= A_CBa;   
  //             B_in_mode <= B_cache;
  //             M_in_mode <= M_NONE;
  //             C_out_mode <= C_TBb;
  //             M_adder_mode_set <= NONE;

  //             TBa_mode <= TB_IDLE;
  //             TBb_mode <= TB_IDLE;
  //             CBa_mode <= {CBa_A,CB_cov_ml}; 
  //             CBb_mode <= CB_IDLE;

  //             A_TB_base_addr <= 0;
  //             B_TB_base_addr <= 0;
  //             M_TB_base_addr <= 0;
  //             C_TB_base_addr <= 0;
  //           end
  //           UPD_5: begin
  //           /*
  //             H_T * cov_HT + Q = S
  //             X=2 Y=2 N=2
  //             Ain: TB-A
  //             Bin: B_cache
  //             Min: TB-A  
  //             Cout: TB-B
  //           */
  //             PE_m <= 0;
  //             PE_n <= 0;
  //             PE_k <= 0;

  //             CAL_mode <= N_W;

  //             A_in_mode <= A_TBa;   
  //             B_in_mode <= B_cache;
  //             M_in_mode <= M_TBa;
  //             C_out_mode <= C_TBb;
  //             M_adder_mode_set <= ADD;

  //             TBa_mode <= {TBa_AM,DIR_POS};
  //             TBb_mode <= TB_dinb_sel_new;
  //             CBa_mode <= CB_IDLE;
  //             CBb_mode <= CB_IDLE;

  //             A_TB_base_addr <= H_xi;
  //             B_TB_base_addr <= 0;
  //             M_TB_base_addr <= Q;
  //             C_TB_base_addr <= S_t;
  //           end
  //           UPD_6: begin
  //           /*
  //             cov_HT * S = K_t
  //             X=4 Y=2 N=2
  //             Ain: TB-A
  //             Bin: TB-B
  //             Min: 0
  //             Cout: TB-B
  //           */
  //             PE_m <= UPD_6_M;
  //             PE_n <= UPD_6_N;
  //             PE_k <= UPD_6_K;

  //             CAL_mode <= N_W;

  //             A_in_mode <= A_TBa;   
  //             B_in_mode <= B_TBb;
  //             M_in_mode <= M_NONE;
  //             C_out_mode <= C_TBb;
  //             M_adder_mode_set <= NONE;

  //             TBa_mode <= {TBa_A,DIR_POS};
  //             TBb_mode <= {TBb_BC,DIR_POS};
  //             CBa_mode <= CB_IDLE;
  //             CBb_mode <= CB_IDLE;

  //             A_TB_base_addr <= cov_HT;
  //             B_TB_base_addr <= S_t;
  //             M_TB_base_addr <= 0;
  //             C_TB_base_addr <= K_t;
  //           end
  //           UPD_7: begin
  //           /*
  //             K_t * cov_HT = cov
  //             X=4 Y=4 N=2
  //             Ain: TB-A
  //             Bin: TB-B
  //             Min: CB-A
  //             Cout: CB-B
  //           */
  //             PE_m <= UPD_7_M;
  //             PE_n <= UPD_7_N;
  //             PE_k <= UPD_7_K;

  //             CAL_mode <= N_W;

  //             A_in_mode <= A_TBa;   
  //             B_in_mode <= B_TBb;
  //             M_in_mode <= M_CBa;
  //             C_out_mode <= C_TBb;
  //             M_adder_mode_set <= M_MINUS_C;

  //             TBa_mode <= {TBa_A,DIR_POS};
  //             TBb_mode <= {TBb_B,DIR_POS};
  //             CBa_mode <= {CBa_M,CB_cov};
  //             CBb_mode <= {CBb_C,CB_cov};

  //             A_TB_base_addr <= K_t;
  //             B_TB_base_addr <= cov_HT;
  //             M_TB_base_addr <= 0;
  //             C_TB_base_addr <= 0;
  //           end
  //           default: begin
  //             PE_m <= 0;
  //             PE_n <= 0;
  //             PE_k <= 0;

  //             CAL_mode <= N_W;

  //             A_in_mode <= A_TBa;   
  //             B_in_mode <= B_TBb;
  //             M_in_mode <= M_TBa;
  //             C_out_mode <= C_CBb;
  //             M_adder_mode_set <= NONE;

  //             TBa_mode <= TB_IDLE;
  //             TBb_mode <= TB_IDLE;
  //             CBa_mode <= CB_IDLE;
  //             CBb_mode <= CB_IDLE;

  //             A_TB_base_addr <= 0;
  //             B_TB_base_addr <= 0;
  //             M_TB_base_addr <= 0;
  //             C_TB_base_addr <= 0;
  //           end
  //         endcase
  //       end
  //     endcase
  //   end  
  // end

/*
  ************* (using) combinational RSA work-mode Config *************
*/
  always @(*) begin
    if(sys_rst) begin
      PE_m = 0;
      PE_n = 0;
      PE_k = 0;

      CAL_mode = N_W;

      A_in_mode = A_TBa;   
      B_in_mode = B_TBb;
      M_in_mode = M_TBa;
      C_out_mode = C_CBb;
      M_adder_mode_set = NONE;

      TBa_mode = TB_IDLE;
      TBb_mode = TB_IDLE;
      CBa_mode = CB_IDLE;
      CBb_mode = CB_IDLE;

      A_TB_base_addr_set = 0;
      B_TB_base_addr_set = 0;
      M_TB_base_addr_set = 0;
      C_TB_base_addr_set = 0;
    end
    else begin
      case(stage_cur)
        STAGE_PRD: begin
                    case (prd_cur)
                      PRD_1: begin
                              PE_m = PRD_1_M;
                              PE_n = PRD_1_N;
                              PE_k = PRD_1_K;

                              CAL_mode = N_W;

                              A_in_mode = A_TBa;   
                              B_in_mode = B_CBa;
                              M_in_mode = M_NONE;
                              C_out_mode = C_TBb;
                              M_adder_mode_set = NONE;

                              TBa_mode = {TBa_A,DIR_POS};
                              TBb_mode = {TBb_C,DIR_POS};
                              CBa_mode = {CBa_B,CB_cov_vv};
                              CBb_mode = CB_IDLE;

                              A_TB_base_addr_set = F_xi;
                              B_TB_base_addr_set = 0;
                              M_TB_base_addr_set = 0;
                              C_TB_base_addr_set = F_cov;
                            end
                      PRD_2: begin
                              PE_m = PRD_2_M;
                              PE_n = PRD_2_N;
                              PE_k = PRD_2_K;

                              CAL_mode = N_W;

                              A_in_mode = A_TBa;   
                              B_in_mode = B_TBb;
                              M_in_mode = M_TBa;
                              C_out_mode = C_CBb;
                              M_adder_mode_set = ADD;

                              TBa_mode = {TBa_AM,DIR_POS};
                              TBb_mode = {TBb_B,DIR_POS};
                              CBa_mode = CB_IDLE;
                              CBb_mode = {CBb_C,CB_cov_vv};

                              A_TB_base_addr_set = F_cov;
                              B_TB_base_addr_set = F_xi;
                              M_TB_base_addr_set = M_t;
                              C_TB_base_addr_set = 0;
                            end
                      PRD_3: begin
                              PE_m = PRD_3_M;
                              PE_n = PRD_3_N;
                              PE_k = PRD_3_K;

                              CAL_mode = N_W;

                              A_in_mode = A_CBa;   
                              B_in_mode = B_TBb;
                              M_in_mode = M_NONE;
                              C_out_mode = C_CBb;
                              M_adder_mode_set = NONE;

                              TBa_mode = {TBa_IDLE,DIR_IDLE};
                              TBb_mode = {TBb_B,DIR_POS};
                              CBa_mode = {CBa_A,CB_cov_mv};
                              CBb_mode = {CBb_C,CB_cov_mv};

                              A_TB_base_addr_set = 0;
                              B_TB_base_addr_set = F_xi;
                              M_TB_base_addr_set = 0;
                              C_TB_base_addr_set = 0;
                            end
                      default: begin
                                PE_m = 0;
                                PE_n = 0;
                                PE_k = 0;

                                CAL_mode = N_W;

                                A_in_mode = A_TBa;   
                                B_in_mode = B_TBb;
                                M_in_mode = M_TBa;
                                C_out_mode = C_CBb;
                                M_adder_mode_set = NONE;

                                TBa_mode = TB_IDLE;
                                TBb_mode = TB_IDLE;
                                CBa_mode = CB_IDLE;
                                CBb_mode = CB_IDLE;

                                A_TB_base_addr_set = 0;
                                B_TB_base_addr_set = 0;
                                M_TB_base_addr_set = 0;
                                C_TB_base_addr_set = 0;
                              end
                    endcase
                  end
        STAGE_NEW: begin
                    case(new_cur)
                      NEW_1: begin
                            /*
                              G_xi * t_cov = cov_lm
                              X=2 Y=2 N=3
                              Ain: TB-A
                              bin: CB-A
                              Cout: CB-B
                            */
                              PE_m = NEW_1_M;
                              PE_n = NEW_1_N;
                              PE_k = NEW_1_K;

                              CAL_mode = N_W;

                              A_in_mode = A_TBa;   
                              B_in_mode = B_CBa;
                              M_in_mode = M_NONE;
                              C_out_mode = C_CBb;
                              M_adder_mode_set = NONE;

                              TBa_mode = {TBa_A,DIR_POS};
                              TBb_mode = TB_IDLE;
                              CBa_mode = {CBa_B,CB_cov_vv};
                              CBb_mode = {CBb_C,CB_cov_lv};

                              A_TB_base_addr_set = G_xi;
                              B_TB_base_addr_set = 0;
                              M_TB_base_addr_set = 0;
                              C_TB_base_addr_set = 0;
                              
                            end
                      NEW_2: begin
                            /*
                              G_xi * cov_mv = cov_lv
                              X=2 Y=4 N=3
                              Ain: TB-A
                              Bin: CB-A
                              Min: 0
                              Cout: CB-B
                            */
                              PE_m = NEW_2_M;
                              PE_n = NEW_2_N;
                              PE_k = NEW_2_K;

                              CAL_mode = N_W;

                              A_in_mode = A_TBa;   
                              B_in_mode = B_CBa;
                              M_in_mode = M_TBa;
                              C_out_mode = C_CBb;
                              M_adder_mode_set = NONE;

                              TBa_mode = {TBa_A,DIR_POS};
                              TBb_mode = TB_IDLE;
                              CBa_mode = {CBa_B,CB_cov_mv};
                              CBb_mode = {CBb_C,CB_cov_lm};

                              A_TB_base_addr_set = G_xi;
                              B_TB_base_addr_set = 0;
                              M_TB_base_addr_set = 0;
                              C_TB_base_addr_set = 0;
                            end
                      NEW_3: begin
                              /*
                                cov_lv * G_xi_T = lv_G_xi
                                X=2 Y=2 N=3
                                Ain: CB-A
                                Bin: TB-B
                                Min: NONE  
                                Cout: TB-B
                              */
                                PE_m = NEW_3_M;
                                PE_n = NEW_3_N;
                                PE_k = NEW_3_K;

                                CAL_mode = N_W;

                                A_in_mode = A_CBa;   
                                B_in_mode = B_TBb;
                                M_in_mode = M_NONE;
                                C_out_mode = C_TBb;
                                M_adder_mode_set = NONE;

                                TBa_mode = TB_IDLE;
                                TBb_mode = {TBb_BC,DIR_POS};
                                CBa_mode = {CBa_A,CB_cov_lv};
                                CBb_mode = CB_IDLE;

                                A_TB_base_addr_set = 0;
                                B_TB_base_addr_set = G_xi;
                                M_TB_base_addr_set = 0;
                                C_TB_base_addr_set = lv_G_xi;
                              end
                      NEW_4: begin
                            /*
                              G_z * Q = G_z_Q
                              X=2 Y=2 N=2
                              Ain: TB-A
                              Bin: TB-B
                              Min: NONE  
                              Cout: TB-B
                            */
                              PE_m = NEW_4_M;
                              PE_n = NEW_4_N;
                              PE_k = NEW_4_K;

                              CAL_mode = N_W;

                              A_in_mode = A_TBa;   
                              B_in_mode = B_TBb;
                              M_in_mode = M_NONE;
                              C_out_mode = C_TBb;
                              M_adder_mode_set = NONE;

                              TBa_mode = {TBa_A,DIR_POS};
                              TBb_mode = {TBb_BC,DIR_POS};
                              CBa_mode = CB_IDLE; 
                              CBb_mode = CB_IDLE;

                              A_TB_base_addr_set = G_z;
                              B_TB_base_addr_set = Q;
                              M_TB_base_addr_set = 0;
                              C_TB_base_addr_set = G_z_Q;
                            end
                      NEW_5: begin
                            /*
                              G_z_Q * G_z_T + lv_G_xi = cov_ll
                              X=2 Y=2 N=2
                              Ain: TB-A
                              Bin: TB-B
                              Min: TB-A  
                              Cout: CB-B
                            */
                              PE_m = NEW_5_M;
                              PE_n = NEW_5_M;
                              PE_k = NEW_5_M;

                              CAL_mode = N_W;

                              A_in_mode = A_TBa;   
                              B_in_mode = B_TBb;
                              M_in_mode = M_TBa;
                              C_out_mode = C_CBb;
                              M_adder_mode_set = ADD;

                              TBa_mode = {TBa_AM,DIR_POS};
                              TBb_mode = {TBb_B,DIR_POS};
                              CBa_mode = CB_IDLE;
                              CBb_mode = {CBb_C,CB_cov_ll};

                              A_TB_base_addr_set = 0;
                              B_TB_base_addr_set = 0;
                              M_TB_base_addr_set = 0;
                              C_TB_base_addr_set = 0;
                            end
                      default: begin
                              PE_m = 0;
                              PE_n = 0;
                              PE_k = 0;

                              CAL_mode = N_W;

                              A_in_mode = A_TBa;   
                              B_in_mode = B_TBb;
                              M_in_mode = M_TBa;
                              C_out_mode = C_CBb;
                              M_adder_mode_set = NONE;

                              TBa_mode = TB_IDLE;
                              TBb_mode = TB_IDLE;
                              CBa_mode = CB_IDLE;
                              CBb_mode = CB_IDLE;

                              A_TB_base_addr_set = 0;
                              B_TB_base_addr_set = 0;
                              M_TB_base_addr_set = 0;
                              C_TB_base_addr_set = 0;
                            end
                    endcase
                  end
        STAGE_UPD: begin
                    case(upd_cur)
                      UPD_1: begin
                            /*
                              transfer
                              H:    TB-B -> B_cache
                              cov_l:CB-A -> TB-A
                              X=0 Y=2 N=5
                              Ain: 0
                              bin: TB-B
                              Cout: 0
                            */
                              PE_m = UPD_1_M;
                              PE_n = UPD_1_N;
                              PE_k = UPD_1_K;

                              CAL_mode = N_W;

                              A_in_mode = A_CBa;   
                              B_in_mode = B_TBb;
                              M_in_mode = M_NONE;
                              C_out_mode = C_CBb;
                              M_adder_mode_set = NONE;

                              TBa_mode = {TBa_cov_lm,DIR_POS};
                              TBb_mode = {TBb_B_cache,B_cache_trnsfer};
                              CBa_mode = {CBa_TBa, CB_cov_lm};
                              CBb_mode = CB_IDLE;

                              A_TB_base_addr_set = t_cov_l;
                              B_TB_base_addr_set = H_xi;
                              M_TB_base_addr_set = 0;
                              C_TB_base_addr_set = 0;
                            end
                      UPD_2: begin
                            /*
                              cov_vv * H_T = cov_HT
                              X=3 Y=2 N=3
                              Ain: CB-A
                              Bin: B-cache
                              Min: 0
                              Cout: TB-B
                            */
                              
                              PE_m = UPD_2_M;
                              PE_n = UPD_2_N;
                              PE_k = UPD_2_K;

                              CAL_mode = N_W;

                              A_in_mode = A_CBa;   
                              B_in_mode = B_cache;
                              M_in_mode = M_NONE;
                              C_out_mode = C_TBb;
                              M_adder_mode_set = NONE;

                              TBa_mode = TB_IDLE;
                              TBb_mode = {TBb_C,DIR_POS};
                              CBa_mode = {CBa_A,CB_cov_vv};
                              CBb_mode = CB_IDLE;

                              A_TB_base_addr_set = t_cov_l;
                              B_TB_base_addr_set = 0;
                              M_TB_base_addr_set = 0;
                              C_TB_base_addr_set = cov_HT;
                            end
                      UPD_3: begin
                            /*
                              cov_mv * H_T = cov_HT
                              X=4 Y=2 N=3
                              Ain: CB-A
                              Bin: B-cache
                              Min: 0
                              Cout: TB-B
                            */
                              
                              PE_m = UPD_3_M;
                              PE_n = UPD_3_N;
                              PE_k = UPD_3_K;

                              CAL_mode = N_W;

                              A_in_mode = A_CBa;   
                              B_in_mode = B_cache;
                              M_in_mode = M_NONE;
                              C_out_mode = C_TBb;
                              M_adder_mode_set = NONE;

                              TBa_mode = TB_IDLE;
                              TBb_mode = {TBb_C,DIR_POS};
                              CBa_mode = {CBa_A,CB_cov_mv};
                              CBb_mode = CB_IDLE;

                              A_TB_base_addr_set = t_cov_l;
                              B_TB_base_addr_set = 0;
                              M_TB_base_addr_set = 0;
                              C_TB_base_addr_set = cov_HT;
                            end
                      UPD_4: begin
                            /*
                              t_cov_l * H_T = cov_HT
                              X=4 Y=2 N=2
                              Ain: TB-A
                              Bin: B-cache
                              Min: 0
                              Cout: 0
                            */
                              PE_m = UPD_4_M;
                              PE_n = UPD_4_N;
                              PE_k = UPD_4_K;

                              CAL_mode = N_W;

                              A_in_mode = A_TBa;   
                              B_in_mode = B_cache;
                              M_in_mode = M_NONE;
                              C_out_mode = C_TBb;
                              M_adder_mode_set = NONE;

                              TBa_mode = {TBa_A,DIR_POS};
                              TBb_mode = TB_IDLE;
                              CBa_mode = {CBa_A,CB_cov_ll}; //保证en
                              CBb_mode = CB_IDLE;

                              A_TB_base_addr_set = t_cov_l;
                              B_TB_base_addr_set = 0;
                              M_TB_base_addr_set = 0;
                              C_TB_base_addr_set = 0;
                            end
                      UPD_5: begin
                            /*
                              cov_ml * H_T = cov_HT
                              X=4 Y=2 N=2
                              Ain: CB-A
                              Bin: B-cache
                              Min: 0
                              Cout: 0
                            */
                              PE_m = UPD_5_M;
                              PE_n = UPD_5_N;
                              PE_k = UPD_5_K;

                              CAL_mode = N_W;

                              A_in_mode = A_CBa;   
                              B_in_mode = B_cache;
                              M_in_mode = M_NONE;
                              C_out_mode = C_TBb;
                              M_adder_mode_set = NONE;

                              TBa_mode = TB_IDLE;
                              TBb_mode = TB_IDLE;
                              CBa_mode = {CBa_A,CB_cov_ml}; 
                              CBb_mode = CB_IDLE;

                              A_TB_base_addr_set = t_cov_l;
                              B_TB_base_addr_set = 0;
                              M_TB_base_addr_set = 0;
                              C_TB_base_addr_set = 0;
                            end
                      UPD_6: begin
                            /*
                              cov_HT transpose
                              Ain: 
                              Bin: B-cache
                              Min: 0
                              Cout: 0
                            */
                              PE_m = UPD_6_M;
                              PE_n = UPD_6_N;
                              PE_k = UPD_6_K;

                              CAL_mode = N_W;

                              A_in_mode = A_NONE;   
                              B_in_mode = B_NONE;
                              M_in_mode = M_NONE;
                              C_out_mode = C_NONE;
                              M_adder_mode_set = NONE;

                              TBa_mode = TB_IDLE;
                              TBb_mode = {TBb_B_cache,B_cache_transpose};
                              CBa_mode = CB_IDLE;
                              CBb_mode = CB_IDLE;

                              A_TB_base_addr_set = 0;
                              B_TB_base_addr_set = cov_HT;
                              M_TB_base_addr_set = 0;
                              C_TB_base_addr_set = 0;
                            end
                      UPD_7: begin
                            /*
                              H_T * cov_HT + Q = S
                              X=2 Y=2 N=5
                              Ain: TB-A
                              Bin: B_cache
                              Min: TB-A  
                              Cout: TB-B
                            */
                              PE_m = UPD_7_M;
                              PE_n = UPD_7_N;
                              PE_k = UPD_7_K;

                              CAL_mode = N_W;

                              A_in_mode = A_TBa;   
                              B_in_mode = B_cache;
                              M_in_mode = M_TBa;
                              C_out_mode = C_TBb;
                              M_adder_mode_set = ADD;

                              TBa_mode = {TBa_AM,DIR_POS};
                              TBb_mode = {TBb_C, DIR_POS};
                              CBa_mode = CB_IDLE;
                              CBb_mode = CB_IDLE;

                              A_TB_base_addr_set = H_xi;
                              B_TB_base_addr_set = 0;
                              M_TB_base_addr_set = Q;
                              C_TB_base_addr_set = S_t;
                            end
                      UPD_8: begin
                            /*
                              S_t inverse
                              Ain: 0
                              Bin: B-cache
                              Min: 0
                              Cout: 0
                            */
                              PE_m = UPD_8_M;
                              PE_n = UPD_8_N;
                              PE_k = UPD_8_K;

                              CAL_mode = N_W;

                              A_in_mode = A_NONE;   
                              B_in_mode = B_NONE;
                              M_in_mode = M_NONE;
                              C_out_mode = C_NONE;
                              M_adder_mode_set = NONE;

                              TBa_mode = TB_IDLE;
                              TBb_mode = {TBb_B_cache,B_cache_inv};
                              CBa_mode = CB_IDLE;
                              CBb_mode = CB_IDLE;

                              A_TB_base_addr_set = 0;
                              B_TB_base_addr_set = S_t;
                              M_TB_base_addr_set = 0;
                              C_TB_base_addr_set = 0;
                            end
                      UPD_9: begin
                            /*
                              cov_HT * S = K_t
                              X=4 Y=2 N=2
                              Ain: TB-A
                              Bin: B_cache
                              Min: 0
                              Cout: TB-B
                            */
                              PE_m = UPD_9_M;
                              PE_n = UPD_9_N;
                              PE_k = UPD_9_K;

                              CAL_mode = N_W;

                              A_in_mode = A_TBa;   
                              B_in_mode = B_cache;
                              M_in_mode = M_NONE;
                              C_out_mode = C_TBb;
                              M_adder_mode_set = NONE;

                              TBa_mode = {TBa_A,DIR_POS};
                              TBb_mode = {TBb_C,DIR_POS};
                              CBa_mode = CB_IDLE;
                              CBb_mode = CB_IDLE;

                              A_TB_base_addr_set = cov_HT;
                              B_TB_base_addr_set = 0;
                              M_TB_base_addr_set = 0;
                              C_TB_base_addr_set = K_t;
                            end
                      UPD_10: begin
                            /*
                              K_t * cov_HT = cov
                              X=4 Y=4 N=2
                              Ain: TB-A
                              Bin: TB-B
                              Min: CB-A
                              Cout: CB-B
                            */
                              PE_m = UPD_10_M;
                              PE_n = UPD_10_N;
                              PE_k = UPD_10_K;

                              CAL_mode = N_W;

                              A_in_mode = A_TBa;   
                              B_in_mode = B_TBb;
                              M_in_mode = M_CBa;
                              C_out_mode = C_TBb;
                              M_adder_mode_set = M_MINUS_C;

                              TBa_mode = {TBa_A,DIR_POS};
                              TBb_mode = {TBb_B,DIR_POS};
                              CBa_mode = {CBa_M,CB_cov};
                              CBb_mode = {CBb_C,CB_cov};

                              A_TB_base_addr_set = K_t;
                              B_TB_base_addr_set = cov_HT;
                              M_TB_base_addr_set = 0;
                              C_TB_base_addr_set = 0;
                            end
                      default: begin
                                PE_m = 0;
                                PE_n = 0;
                                PE_k = 0;

                                CAL_mode = N_W;

                                A_in_mode = A_TBa;   
                                B_in_mode = B_TBb;
                                M_in_mode = M_TBa;
                                C_out_mode = C_CBb;
                                M_adder_mode_set = NONE;

                                TBa_mode = TB_IDLE;
                                TBb_mode = TB_IDLE;
                                CBa_mode = CB_IDLE;
                                CBb_mode = CB_IDLE;

                                A_TB_base_addr_set = 0;
                                B_TB_base_addr_set = 0;
                                M_TB_base_addr_set = 0;
                                C_TB_base_addr_set = 0;
                              end
                    endcase
                  end
        default: begin
                  PE_m = 0;
                  PE_n = 0;
                  PE_k = 0;

                  CAL_mode = N_W;

                  A_in_mode = A_TBa;   
                  B_in_mode = B_TBb;
                  M_in_mode = M_TBa;
                  C_out_mode = C_CBb;
                  M_adder_mode_set = NONE;

                  TBa_mode = TB_IDLE;
                  TBb_mode = TB_IDLE;
                  CBa_mode = CB_IDLE;
                  CBb_mode = CB_IDLE;

                  A_TB_base_addr_set = 0;
                  B_TB_base_addr_set = 0;
                  M_TB_base_addr_set = 0;
                  C_TB_base_addr_set = 0;
                end
      endcase
    end  
  end

/*
  ********************** PE array mode config *********************
*/

  /*
    ******************* ABMC_en config *****************************
  */
  reg [2:0] PE_m_d [CAL_EN_D : 1];
  reg [2:0] PE_n_d [CAL_EN_D : 1];
  reg [2:0] PE_k_d [CAL_EN_D : 1];
  
  integer i_PE_m_d;
  always @(posedge clk) begin
    PE_m_d[1] <= PE_m;
    for(i_PE_m_d=1; i_PE_m_d<=CAL_EN_D-1; i_PE_m_d=i_PE_m_d+1) begin
      PE_m_d[i_PE_m_d+1] <= PE_m_d[i_PE_m_d];
    end     
  end

  always @(posedge clk) begin
    if(sys_rst) begin
      A_in_en <= 4'b0000;  
      M_in_en <= 4'b0000;
      C_out_en <= 4'b0000;
    end
    else begin
      case(PE_m_d[CAL_EN_D])
        3'b001: begin
          A_in_en <= 4'b0001;  
          M_in_en <= 4'b0001;
          C_out_en <= 4'b0001;
        end
        3'b010: begin
          A_in_en <= 4'b0011;  
          M_in_en <= 4'b0011;
          C_out_en <= 4'b0011;
        end
        3'b011: begin
          A_in_en <= 4'b0111;  
          M_in_en <= 4'b0111;
          C_out_en <= 4'b0111;
        end
        3'b100: begin
          A_in_en <= 4'b1111;  
          M_in_en <= 4'b1111;
          C_out_en <= 4'b1111;
        end
        default: begin
          A_in_en <= 4'b0000;  
          M_in_en <= 4'b0000;
          C_out_en <= 4'b0000;
        end
      endcase
    end
  end

  integer i_PE_k_d;
  always @(posedge clk) begin
    PE_k_d[1] <= PE_k;
    for(i_PE_k_d=1; i_PE_k_d<=CAL_EN_D-1; i_PE_k_d=i_PE_k_d+1) begin
      PE_k_d[i_PE_k_d+1] <= PE_k_d[i_PE_k_d];
    end     
  end

  always @(posedge clk) begin
    if(sys_rst) begin
      B_in_en <= 4'b0000;
    end
    else begin
      case(PE_m_d[CAL_EN_D])
        3'b001: begin
          B_in_en <= 4'b0001;  
        end
        3'b010: begin
          B_in_en <= 4'b0011;  
        end
        3'b011: begin
          B_in_en <= 4'b0111;  
        end
        3'b100: begin
          B_in_en <= 4'b1111;  
        end
        default: begin
          B_in_en <= 4'b0000;  
        end
      endcase
    end
  end

/*
  ******************* in_sel_new config *****************************
*/
  reg [1:0] AB_in_sel_d_addr;
  reg [2:0] M_in_sel_d_addr;
  reg [3:0] C_out_sel_d_addr;

  always @(posedge clk) begin
    if(sys_rst) begin
      AB_in_sel_d_addr <= 0;
      M_in_sel_d_addr  <= 0;
      C_out_sel_d_addr <= 0;
    end
    else begin
      AB_in_sel_d_addr <= AB_IN_SEL_D;
      M_in_sel_d_addr  <= M_IN_SEL_D;
      C_out_sel_d_addr <= C_OUT_SEL_D;
    end
      
  end
  
  dynamic_shreg 
  #(
    .DW    (A_IN_SEL_DW    ),
    .AW    (2    )
  )
  A_in_sel_dynamic_shreg(
  	.clk  (clk  ),
    .ce   (1'b1   ),
    .addr (AB_in_sel_d_addr ),
    .din  (A_in_mode  ),
    .dout (A_in_sel_new )
  );

  dynamic_shreg 
  #(
    .DW    (B_IN_SEL_DW    ),
    .AW    (2    )
  )
  B_in_sel_dynamic_shreg(
  	.clk  (clk  ),
    .ce   (1'b1   ),
    .addr (AB_in_sel_d_addr ),
    .din  (B_in_mode  ),
    .dout (B_in_sel_new )
  );

  dynamic_shreg 
  #(
    .DW    (M_IN_SEL_DW    ),
    .AW    (3    )
  )
  M_in_sel_dynamic_shreg(
  	.clk  (clk  ),
    .ce   (1'b1   ),
    .addr (M_in_sel_d_addr ),
    .din  (M_in_mode  ),
    .dout (M_in_sel_new )
  );

  dynamic_shreg 
  #(
    .DW    (M_IN_SEL_DW    ),
    .AW    (4    )
  )
  M_adder_mode_dynamic_shreg(
  	.clk  (clk  ),
    .ce   (1'b1   ),
    .addr (M_IN_SEL_D ),
    .din  (M_adder_mode_set  ),
    .dout (M_adder_mode_new )
  );

  dynamic_shreg 
  #(
    .DW    (C_OUT_SEL_DW    ),
    .AW    (4    )
  )
  C_out_sel_dynamic_shreg(
  	.clk  (clk  ),
    .ce   (1'b1   ),
    .addr (C_out_sel_d_addr ),
    .din  (C_out_mode  ),
    .dout (C_out_sel_new )
  );

//****//
/*
  ******************* CAL_mode config *****************************
*/
  reg  [1 : 0] CAL_mode_d  [PE_MODE_D : 1];

  integer i_CAL_mode;
  always @(posedge clk) begin
    CAL_mode_d[1] <= CAL_mode;
    for(i_CAL_mode=1; i_CAL_mode<=PE_MODE_D-1; i_CAL_mode=i_CAL_mode+1) begin
      CAL_mode_d[i_CAL_mode+1] <= CAL_mode_d[i_CAL_mode];
    end     
  end

  always @(posedge clk) begin
    if(sys_rst) begin
      A_in_sel_dir <= DIR_POS;
      B_in_sel_dir <= DIR_POS;
      M_in_sel_dir <= DIR_POS;
      C_out_sel_dir <= DIR_POS;
    end
    else begin
      case(CAL_mode_d[AB_IN_SEL_D])
        N_W: begin
          A_in_sel_dir <= DIR_POS;
          B_in_sel_dir <= DIR_POS;
          M_in_sel_dir <= DIR_POS;
          C_out_sel_dir <= DIR_POS;
        end
        S_W: begin
          A_in_sel_dir <= DIR_NEG;
          B_in_sel_dir <= DIR_POS;
          M_in_sel_dir <= DIR_NEG;
          C_out_sel_dir <= DIR_NEG;
        end 
        N_E: begin
          A_in_sel_dir <= DIR_POS;
          B_in_sel_dir <= DIR_NEG;
          M_in_sel_dir <= DIR_POS;
          C_out_sel_dir <= DIR_POS;
        end
        S_E: begin
          A_in_sel_dir <= DIR_NEG;
          B_in_sel_dir <= DIR_NEG;
          M_in_sel_dir <= DIR_NEG;
          C_out_sel_dir <= DIR_NEG;
        end
      endcase
    end
  end

  always @(posedge clk) begin
    if(sys_rst) begin
      cal_en_done_dir <= 0;
    end
    else begin
      case(CAL_mode_d[CAL_EN_D])
        N_W: begin
          cal_en_done_dir <= DIR_POS;
        end
        S_W: begin
          cal_en_done_dir <= DIR_POS;
        end 
        N_E: begin
          cal_en_done_dir <= DIR_NEG;
        end
        S_E: begin
          cal_en_done_dir <= DIR_NEG;
        end
      endcase
    end
  end
  
  /*
    *********************** PE_mode *************************
  */

  always @(posedge clk) begin
    if(sys_rst) begin
      PE_mode <= N_W;
    end
    else begin
      PE_mode <= CAL_mode_d[PE_MODE_D];
    end
  end

  /*
    ****************** new_cal_en & new_cal_done *****************
  */
  wire [SEQ_CNT_DW-1 : 0] seq_cnt_cal_d;
  wire [2:0]           PEn_cal_d;

  reg [1:0] cal_en_d_addr;

  always @(posedge clk) begin
    if(sys_rst) begin
      cal_en_d_addr <= 0;
    end
    else begin
      cal_en_d_addr <= CAL_EN_D;
    end
  end

  dynamic_shreg 
    #(
      .DW  (SEQ_CNT_DW  ),
      .AW  (2  )
    )
    seq_cnt_cal_d_shreg(
      .clk  (clk  ),
      .ce   (1'b1  ),
      .addr (cal_en_d_addr ),
      .din  (seq_cnt  ),
      .dout (seq_cnt_cal_d )
    );

  dynamic_shreg 
  #(
    .DW    (3    ),
    .AW    (2    )
  )
  PEn_cal_d_shreg(
  	.clk  (clk  ),
    .ce   (1'b1   ),
    .addr (cal_en_d_addr ),
    .din  (PE_n  ),
    .dout (PEn_cal_d )
  );

  reg new_cal_en_new;
  reg new_cal_done_new;
  //由于实际的new_cal_en[0]为new_cal_en_new的一级延迟，所以均比实际数据流提前一个T
  always @(posedge clk) begin
    if(sys_rst) begin
      new_cal_en_new <= 0;
    end
    else begin
      if(seq_cnt_cal_d >= 1'b1 && seq_cnt_cal_d <= PEn_cal_d) begin
        new_cal_en_new <= 1'b1;
      end
      else
        new_cal_en_new <= 1'b0;
    end  
  end

  always @(posedge clk) begin
    if(sys_rst) begin
      new_cal_done_new <= 0;
    end
    else begin
      if(seq_cnt_cal_d == PEn_cal_d + 1'b1)
        new_cal_done_new <= 1'b1;
      else
        new_cal_done_new <= 1'b0;
    end
      
  end

  //new_cal_en 移位
    dshift 
    #(
      .DW  (1  ),
      .DEPTH (Y )
    )
    new_cal_en_dshift(
      .clk   (clk   ),
      .sys_rst (sys_rst ),
      .dir   (cal_en_done_dir   ),
      .l_k_0       (l_k_0       ),
      .din   (new_cal_en_new   ),
      .dout  (new_cal_en  )
    );

    dshift 
    #(
      .DW  (1  ),
      .DEPTH (Y )
    )
    new_cal_done_dshift(
      .clk   (clk   ),
      .sys_rst (sys_rst ),
      .dir   (cal_en_done_dir   ),
      .l_k_0       (l_k_0       ),
      .din   (new_cal_done_new   ),
      .dout  (new_cal_done  )
    );

/*
  ********************** address generate config *********************
*/
  /*
    *****************************TB-portA*****************************
  */
  always @(posedge clk) begin
    if(sys_rst) begin
      TB_douta_sel_new[2] <= 1'b0;  

      TB_ena_new <= 1'b0;
      TB_wea_new <= 1'b0;
      TB_addra_new <= 0;
    end
    else begin
      case(TBa_mode[4:2])
        TBa_A:begin
                TB_douta_sel_new[2] <= 1'b0;
                if(seq_cnt < PE_n) begin
                  TB_ena_new <= 1'b1;
                  TB_wea_new <= 1'b0;
                  if(v_group_cnt == 0)
                    TB_addra_new <= A_TB_base_addr_set + seq_cnt;
                  else
                    TB_addra_new <= A_TB_base_addr + seq_cnt;
                end
                else begin
                  TB_ena_new <= 1'b0;
                  TB_wea_new <= 1'b0;
                  TB_addra_new <= 0;
                end
              end
        TBa_M:begin
                TB_douta_sel_new[2] <= 1'b1;
                //M[1]
                if(seq_cnt == PE_n + 1'b1) begin 
                  TB_ena_new <= 1'b1;
                  TB_wea_new <= 1'b0;
                  TB_addra_new <= M_TB_base_addr_set;
                end
                //M[2]
                else if(seq_cnt == PE_n + 2'b11) begin
                    TB_ena_new <= 1'b1;
                    TB_wea_new <= 1'b0;
                    TB_addra_new <= M_TB_base_addr_set + 1'b1;
                end
                //M[3]
                else if(seq_cnt == PE_n + 3'b101 && PE_k == 3'b11) begin
                    TB_ena_new <= 1'b1;
                    TB_wea_new <= 1'b0;
                    TB_addra_new <= M_TB_base_addr_set + 2'b10;
                end
                // if(seq_cnt_M < PE_n) begin
                //   TB_ena_new <= 1'b1;
                //   TB_wea_new <= 1'b0;
                //   if(v_group_cnt == 0)
                //     TB_addra_new <= M_TB_base_addr_set + seq_cnt;
                //   else
                //     TB_addra_new <= M_TB_base_addr + seq_cnt;
                // end
                else begin
                    TB_ena_new <= 1'b0;
                    TB_wea_new <= 1'b0;
                    TB_addra_new <= 0;
                end
              end
        TBa_AM: begin
                  if(seq_cnt < PE_n) begin
                    TB_douta_sel_new[2] <= 1'b0;
                    TB_ena_new <= 1'b1;
                    TB_wea_new <= 1'b0;
                    if(v_group_cnt == 0)
                      TB_addra_new <= A_TB_base_addr_set + seq_cnt;
                    else
                      TB_addra_new <= A_TB_base_addr + seq_cnt;
                  end
                  //M[1]
                  else if(seq_cnt == PE_n + 1'b1) begin
                    TB_douta_sel_new[2] <= 1'b1;
                    TB_ena_new <= 1'b1;
                    TB_wea_new <= 1'b0;
                    TB_addra_new <= M_TB_base_addr_set;
                  end
                  //M[2]
                  else if(seq_cnt == PE_n + 2'b11) begin
                      TB_ena_new <= 1'b1;
                      TB_wea_new <= 1'b0;
                      TB_addra_new <= M_TB_base_addr_set + 1'b1;
                  end
                  //M[3]
                  else if(seq_cnt == PE_n + 3'b101 && PE_k == 3'b11) begin
                      TB_ena_new <= 1'b1;
                      TB_wea_new <= 1'b0;
                      TB_addra_new <= M_TB_base_addr_set + 2'b10;
                  end
                  // if(seq_cnt_M < PE_n) begin
                  //   TB_ena_new <= 1'b1;
                  //   TB_wea_new <= 1'b0;
                  //   if(v_group_cnt == 0)
                  //     TB_addra_new <= M_TB_base_addr_set + seq_cnt;
                  //   else
                  //     TB_addra_new <= M_TB_base_addr + seq_cnt;
                  // end
                  else begin
                      TB_ena_new <= 1'b0;
                      TB_wea_new <= 1'b0;
                      TB_addra_new <= 0;
                  end
                end
        TBa_cov_lm: begin
                      case(seq_cnt)
                        SEQ_3: begin
                          TB_ena_new <= 1'b1;
                          TB_wea_new <= 1'b1;
                          if(v_group_cnt == 0)
                            TB_addra_new <= A_TB_base_addr_set;
                          else
                            TB_addra_new <= A_TB_base_addr;
                        end
                        SEQ_4: begin
                          TB_ena_new <= 1'b1;
                          TB_wea_new <= 1'b1;
                          if(v_group_cnt == 0)
                            TB_addra_new <= A_TB_base_addr_set + 1'b1;
                          else
                            TB_addra_new <= A_TB_base_addr + 1'b1;
                        end
                        default:begin
                          TB_ena_new <= 1'b0;
                          TB_wea_new <= 1'b0;
                          TB_addra_new <= 0;
                        end
                      endcase
                    end  
        default:begin
                  TB_ena_new <= 1'b0;
                  TB_wea_new <= 1'b0;
                  TB_addra_new <= 0;
                end
      endcase
    end 
  end

    /*
      ******************* TB_douta_sel_new, TBa_shift_dir *****************
    */
    reg [4:0] TBa_mode_d1;
    reg [4:0] TBa_mode_d2;
    always @(posedge clk) begin
      if(sys_rst) begin
        TBa_mode_d1 <= 0;
        TBa_mode_d2 <= 0;
      end
      else 
        TBa_mode_d1 <= TBa_mode;
        TBa_mode_d2 <= TBa_mode_d1;
    end

    always @(posedge clk) begin
      if(sys_rst) begin
        TB_douta_sel_new[1:0] <= DIR_IDLE;
        TBa_shift_dir <= 0;
      end
      else begin
        case(TBa_mode_d1[1:0])
          DIR_IDLE: begin
            TB_douta_sel_new[1:0] <= DIR_IDLE;
            TBa_shift_dir <= DIR_POS;
          end
          DIR_POS: begin
            TB_douta_sel_new[1:0] <= DIR_POS;
            TBa_shift_dir <= DIR_POS;
          end
          DIR_NEG: begin
            TB_douta_sel_new[1:0] <= DIR_NEG;
            TBa_shift_dir <= DIR_NEG;
          end
          DIR_NEW: begin
            TB_douta_sel_new[1:0] <= DIR_NEW;
            TBa_shift_dir <= DIR_NEW;
          end
        endcase
      end
    end


  /*
    ********************** TB_dina_sel *****************************
  */
    always @(posedge clk) begin
      if(sys_rst) begin
        TB_dina_sel_new[2] <= 0;
      end
      else begin
        case (TBa_mode_d2[4:2])
          TBa_cov_lm:    TB_dina_sel_new[2] <= 1'b0;
          TBa_nonlinear: TB_dina_sel_new[2] <= 1'b1;
        endcase
      end
    end
    always @(posedge clk) begin
      if(sys_rst) begin
        TB_dina_sel_new[1:0] <= 0;
      end
      else 
        TB_dina_sel_new[1:0] <= TBa_mode_d2[1:0];
    end

  /*
    *****************************TB-portB*****************************
  */
  always @(posedge clk) begin
    if(sys_rst) begin
      TB_doutb_sel_new[2] <= 1'b0;  

      TB_enb_new <= 1'b0;
      TB_web_new <= 1'b0;
      TB_addrb_new <= 0;
    end
    else begin
      case(TBb_mode[4:2])
        TBb_B:begin
                TB_doutb_sel_new[2] <= 1'b0;
                if(seq_cnt < PE_n) begin
                  TB_enb_new <= 1'b1;
                  TB_web_new <= 1'b0;
                  if(v_group_cnt == 0)
                    TB_addrb_new <= B_TB_base_addr_set + seq_cnt;
                  else
                    TB_addrb_new <= B_TB_base_addr + seq_cnt;
                end
                else begin
                  TB_enb_new <= 1'b0;
                  TB_web_new <= 1'b0;
                  TB_addrb_new <= 0;
                end
              end
        TBb_C:begin
                case (seq_cnt_WR)
                  SEQ_0: begin
                    TB_enb_new <= 1'b1;
                    TB_web_new <= 1'b1;
                    if(v_group_cnt == 0)
                      TB_addrb_new <= C_TB_base_addr_set;
                    else
                      TB_addrb_new <= C_TB_base_addr;
                  end
                  SEQ_2: begin
                    TB_enb_new <= 1'b1;
                    TB_web_new <= 1'b1;
                    TB_addrb_new <= TB_addrb_new + 1'b1;
                  end
                  SEQ_4: begin
                    TB_enb_new <= 1'b1;
                    TB_web_new <= 1'b1;
                    TB_addrb_new <= TB_addrb_new + 1'b1;
                  end
                  default: begin
                    TB_enb_new <= 1'b0;
                    TB_web_new <= 1'b0;
                    TB_addrb_new <= 0;
                  end
                endcase
              end
        TBb_BC: begin
                  TB_doutb_sel_new[2] <= 1'b0;
                  if(seq_cnt < PE_n) begin
                    TB_enb_new <= 1'b1;
                    TB_web_new <= 1'b0;
                    if(v_group_cnt == 0)
                      TB_addrb_new <= B_TB_base_addr_set + seq_cnt;
                    else
                      TB_addrb_new <= B_TB_base_addr + seq_cnt;
                  end
                  else begin
                    case (seq_cnt_WR)
                      SEQ_0: begin
                        TB_enb_new <= 1'b1;
                        TB_web_new <= 1'b1;
                        if(v_group_cnt == 0)
                          TB_addrb_new <= C_TB_base_addr_set;
                        else
                          TB_addrb_new <= C_TB_base_addr;
                      end
                      SEQ_2: begin
                        TB_enb_new <= 1'b1;
                        TB_web_new <= 1'b1;
                        TB_addrb_new <= TB_addrb_new + 1'b1;
                      end
                      SEQ_4: begin
                        TB_enb_new <= 1'b1;
                        TB_web_new <= 1'b1;
                        TB_addrb_new <= TB_addrb_new + 1'b1;
                      end
                      default: begin
                        TB_enb_new <= 1'b0;
                        TB_web_new <= 1'b0;
                        TB_addrb_new <= 0;
                      end
                    endcase
                  end
                end
        TBb_B_cache: begin
                      TB_doutb_sel_new[2] <= 1'b1;
                      if(v_group_cnt == 0 && seq_cnt < PE_n) begin
                        TB_enb_new <= 1'b1;
                        TB_web_new <= 1'b0;
                        TB_addrb_new <= B_TB_base_addr_set + seq_cnt;
                      end
                      else begin
                            TB_enb_new <= 1'b0;
                            TB_web_new <= 1'b0;
                            TB_addrb_new <= 0;
                          end
                    end
        default: begin
          TB_enb_new <= 1'b0;
          TB_web_new <= 1'b0;
          TB_addrb_new <= 0;
        end
      endcase
    end 
  end
    /*
      ******************* TB_doutb_sel_new, TBb_shift_dir *****************
    */
      reg [4:0] TBb_mode_d;
      always @(posedge clk) begin
        if(sys_rst) begin
          TBb_mode_d <= 0;
        end
        else 
          TBb_mode_d <= TBb_mode;
      end

      always @(posedge clk) begin
        if(sys_rst) begin
          TB_doutb_sel_new[1:0] = DIR_IDLE;
          TBb_shift_dir <= 0;
        end
        else begin
          case(TBb_mode_d[1:0])
            DIR_IDLE: begin
              TB_doutb_sel_new[1:0] = DIR_IDLE;
              TBb_shift_dir <= DIR_POS;
            end
            DIR_POS: begin
              TB_doutb_sel_new[1:0] = DIR_POS;
              TBb_shift_dir <= DIR_POS;
            end
          DIR_NEG: begin
              TB_doutb_sel_new[1:0] = DIR_NEG;
              TBb_shift_dir <= DIR_NEG;
            end
            DIR_NEW: begin
              TB_doutb_sel_new[1:0] = DIR_NEW;
              TBb_shift_dir <= DIR_NEW;
            end
          endcase
        end
      end

      always @(posedge clk) begin
        if(sys_rst) begin
          TB_dinb_sel_new <= 0;
        end
        else 
          TB_dinb_sel_new <= DIR_POS;
      end

  /*
    ***************************** B_cache *****************************
  */
  always @(posedge clk) begin
    if(sys_rst) begin
      B_cache_en_new <= 0;
      B_cache_we_new <= 0;
      B_cache_addr_new <= 0;
    end
    else begin
      case(stage_cur)
        STAGE_UPD: begin
          case(upd_cur)
            UPD_1:begin
                    case (seq_cnt)
                      SEQ_0:begin
                            if(v_group_cnt == 1'b1) begin
                              B_cache_en_new <= 1'b1;
                              B_cache_we_new <= 1'b1;
                              B_cache_addr_new <= 3'b011;
                            end
                            else begin
                              B_cache_en_new <= 0;
                              B_cache_we_new <= 0;
                              B_cache_addr_new <= 0;
                            end
                          end 
                      SEQ_1:begin
                            if(v_group_cnt == 1'b1) begin
                              B_cache_en_new <= 1'b1;
                              B_cache_we_new <= 1'b1;
                              B_cache_addr_new <= 3'b100;
                            end
                            else begin
                              B_cache_en_new <= 0;
                              B_cache_we_new <= 0;
                              B_cache_addr_new <= 0;
                            end
                          end 
                      SEQ_2:begin
                            if(v_group_cnt == 1'b0) begin
                              B_cache_en_new <= 1'b1;
                              B_cache_we_new <= 1'b1;
                              B_cache_addr_new <= 0;
                            end
                            else begin
                              B_cache_en_new <= 0;
                              B_cache_we_new <= 0;
                              B_cache_addr_new <= 0;
                            end
                          end 
                      SEQ_3:begin
                            if(v_group_cnt == 1'b0) begin
                              B_cache_en_new <= 1'b1;
                              B_cache_we_new <= 1'b1;
                              B_cache_addr_new <= 3'b001;
                            end
                            else begin
                              B_cache_en_new <= 0;
                              B_cache_we_new <= 0;
                              B_cache_addr_new <= 0;
                            end
                          end 
                      SEQ_4:begin
                            if(v_group_cnt == 1'b0) begin
                              B_cache_en_new <= 1'b1;
                              B_cache_we_new <= 1'b1;
                              B_cache_addr_new <= 3'b010;
                            end
                            else begin
                              B_cache_en_new <= 0;
                              B_cache_we_new <= 0;
                              B_cache_addr_new <= 0;
                            end
                          end
                      default:begin
                            B_cache_en_new <= 0;
                            B_cache_we_new <= 0;
                            B_cache_addr_new <= 0;
                          end
                    endcase
                  end
            UPD_2:begin
                    B_cache_en_new <= 1'b1;
                    B_cache_we_new <= 0;
                    B_cache_addr_new <= seq_cnt;
                  end
            UPD_3:begin
                    B_cache_en_new <= 1'b1;
                    B_cache_we_new <= 0;
                    B_cache_addr_new <= seq_cnt;
                  end
            UPD_4:begin
                    case(seq_cnt)
                      SEQ_0:begin
                          B_cache_en_new <= 1'b1;
                          B_cache_we_new <= 0;
                          B_cache_addr_new <= 3'b011;
                        end
                      SEQ_1:begin
                          B_cache_en_new <= 1'b1;
                          B_cache_we_new <= 0;
                          B_cache_addr_new <= 3'b100;
                        end
                      default:begin
                          B_cache_en_new <= 0;
                          B_cache_we_new <= 0;
                          B_cache_addr_new <= 0;
                        end
                    endcase
                  end
            UPD_5:begin
                    case(seq_cnt)
                      SEQ_0:begin
                          B_cache_en_new <= 1'b1;
                          B_cache_we_new <= 0;
                          B_cache_addr_new <= 3'b011;
                        end
                      SEQ_1:begin
                          B_cache_en_new <= 1'b1;
                          B_cache_we_new <= 0;
                          B_cache_addr_new <= 3'b100;
                        end
                      default:begin
                          B_cache_en_new <= 0;
                          B_cache_we_new <= 0;
                          B_cache_addr_new <= 0;
                        end
                    endcase
                  end
            UPD_6:begin
                    case(seq_cnt)
                      SEQ_2:begin
                          B_cache_en_new <= 1'b1;
                          B_cache_we_new <= 1'b1;
                          B_cache_addr_new <= 3'b000;
                        end
                      SEQ_3:begin
                          B_cache_en_new <= 1'b1;
                          B_cache_we_new <= 1'b1;
                          B_cache_addr_new <= 3'b001;
                        end
                      SEQ_4:begin
                          B_cache_en_new <= 1'b1;
                          B_cache_we_new <= 1'b1;
                          B_cache_addr_new <= 3'b010;
                        end
                      SEQ_6:begin
                          B_cache_en_new <= 1'b1;
                          B_cache_we_new <= 1'b1;
                          B_cache_addr_new <= 3'b011;
                        end
                      SEQ_7:begin
                          B_cache_en_new <= 1'b1;
                          B_cache_we_new <= 1'b1;
                          B_cache_addr_new <= 3'b100;
                        end
                      default:begin
                          B_cache_en_new <= 0;
                          B_cache_we_new <= 0;
                          B_cache_addr_new <= 0;
                        end
                    endcase
                  end
            UPD_7:begin
                    if(seq_cnt < 'd5) begin
                      B_cache_en_new <= 1'b1;
                      B_cache_we_new <= 0;
                      B_cache_addr_new <= seq_cnt;
                    end
                    else begin
                      B_cache_en_new <= 0;
                      B_cache_we_new <= 0;
                      B_cache_addr_new <= 0;
                    end
                  end
            UPD_8:begin
                    case(seq_cnt)
                      SEQ_6:begin
                        B_cache_en_new <= 1'b1;
                        B_cache_we_new <= 1'b1;
                        B_cache_addr_new <= 0;
                      end
                      SEQ_7:begin
                        B_cache_en_new <= 1'b1;
                        B_cache_we_new <= 1'b1;
                        B_cache_addr_new <= 1;
                      end
                      default:begin
                        B_cache_en_new <= 0;
                        B_cache_we_new <= 0;
                        B_cache_addr_new <= 0;
                      end
                    endcase
                  end
            UPD_9:begin
                    if(seq_cnt < 'd2) begin
                      B_cache_en_new <= 1'b1;
                      B_cache_we_new <= 0;
                      B_cache_addr_new <= seq_cnt;
                    end
                    else begin
                      B_cache_en_new <= 0;
                      B_cache_we_new <= 0;
                      B_cache_addr_new <= 0;
                    end
                  end
            default:begin
                      B_cache_en_new <= 0;
                      B_cache_we_new <= 0;
                      B_cache_addr_new <= 0;
                    end
          endcase
        end 
        default: begin
          B_cache_en_new <= 0;
          B_cache_we_new <= 0;
          B_cache_addr_new <= 0;
        end
      endcase
    end
      
  end


/*
  *****************************CB-portA READ*****************************
*/
  always @(posedge clk) begin
    if(sys_rst) begin
      CBa_shift_dir <= 0;
      CB_douta_sel_new <= 0;  

      CB_ena_new <= 1'b0;
      CB_wea_new <= 1'b0;
      CB_addra_new <= 0;
    end
    else begin
      case (CBa_mode[2:0])
        CB_cov_vv: begin
                    CB_wea_new <= 1'b0;
                    case(seq_cnt)
                      SEQ_0: begin
                        CBa_shift_dir <= DIR_POS;
                        CB_ena_new <= 1'b1;
                        CB_addra_new <= 0;
                      end     
                      SEQ_1: begin
                        CB_douta_sel_new <= {CBa_mode[4:3], DIR_POS};
                        CB_ena_new <= 1'b1;
                        CB_addra_new <= 2'b01;
                      end
                      SEQ_2: begin
                        CB_ena_new <= 1'b1;
                        CB_addra_new <= 2'b10;
                      end
                      default: begin
                        CB_ena_new <= 1'b0;
                        CB_addra_new <= 0;
                      end
                    endcase 
                  end
        CB_cov_mv: begin
                    CB_wea_new <= 1'b0;
                    case(seq_cnt)  
                      SEQ_0: begin
                        CBa_shift_dir <= DIR_POS;
                        CB_ena_new <= 1'b1;
                        CB_addra_new <= CB_addra_base;
                      end     
                      SEQ_1: begin
                        CB_douta_sel_new <= {CBa_mode[4:3], DIR_POS};
                        CB_ena_new <= 1'b1;
                        CB_addra_new <= CB_addra_base + 2'b01;
                      end
                      SEQ_2: begin
                        CB_ena_new <= 1'b1;
                        CB_addra_new <= CB_addra_base + 2'b10;
                      end
                      default: begin
                        CB_ena_new <= 1'b0;
                        CB_addra_new <= 0;
                      end
                    endcase 
                  end
        CB_cov_lv: begin
                    CB_wea_new <= 1'b0;
                    case(seq_cnt)
                      SEQ_0: begin
                        CBa_shift_dir <= DIR_NEW; //0-POS 1-NEG
                        CB_ena_new <= 1'b1;
                        CB_addra_new <= l_k_base_addr_RD;
                      end     
                      SEQ_1: begin
                        CB_douta_sel_new[3:2] <= CBa_mode[4:3]; 
                        CB_douta_sel_new[1:0] <= DIR_NEW;
                        CB_ena_new <= 1'b1;
                        CB_addra_new <= l_k_base_addr_RD + 2'b01;
                      end
                      SEQ_2: begin
                        CB_ena_new <= 1'b1;
                        CB_addra_new <= l_k_base_addr_RD + 2'b10;
                      end
                      default: begin
                        CB_ena_new <= 1'b0;
                        CB_addra_new <= 0;
                      end
                    endcase 
                  end
        CB_cov:   begin
                    CB_wea_new <= 1'b0;
                    if(v_group_cnt == 0) begin
                      case(seq_cnt)
                        SEQ_3: begin
                          CB_ena_new <= 1'b1;
                          CB_addra_new <= 0;
                        end
                        SEQ_5: begin
                          CB_ena_new <= 1'b1;
                          CB_addra_new <= 1'b1;
                        end
                        SEQ_7: begin
                          CB_ena_new <= 1'b1;
                          CB_addra_new <= 2'b10;
                        end
                        default: begin
                          CB_ena_new <= 1'b0;
                          CB_addra_new <= CB_addra_new;
                        end
                      endcase
                    end
                    else begin
                      case(seq_cnt_M[0])
                      1'b1: begin
                        CB_ena_new <= 1'b1;
                        CB_addra_new <= CB_addra_new + 1'b1;
                      end
                      1'b0: begin
                        CB_ena_new <= 1'b0;
                        CB_addra_new <= CB_addra_new;
                      end
                    endcase
                    end
                  end
        CB_cov_lm: begin
                    CB_wea_new <= 1'b0;
                    case(seq_cnt)
                      SEQ_0: begin
                        CBa_shift_dir <= DIR_NEW; //0-POS 1-NEG
                        CB_ena_new <= 1'b1;
                        CB_addra_new <= l_k_base_addr_RD;
                      end     
                      SEQ_1: begin
                        CB_douta_sel_new[3:2] <= CBa_mode[4:3]; 
                        CB_douta_sel_new[1:0] <= DIR_NEW;
                        CB_ena_new <= 1'b1;
                        CB_addra_new <= l_k_base_addr_RD + 2'b01;
                      end
                      SEQ_2: begin
                        CB_ena_new <= 1'b1;
                        CB_addra_new <= l_k_base_addr_RD + 2'b10;
                      end
                      SEQ_3: begin
                        CB_ena_new <= 1'b1;
                        CB_addra_new <= l_k_base_addr_RD + 2'b11;
                      end
                      default: begin
                        CB_ena_new <= 1'b0;
                        CB_addra_new <= 0;
                      end
                    endcase 
                  end
          CB_cov_ml: begin
                    CB_wea_new <= 1'b0;
                    case(seq_cnt) 
                      SEQ_0: begin 
                        CBa_shift_dir <= DIR_NEW; //0-POS 1-NEG
                        CB_ena_new <= 1'b1;
                        CB_addra_new <= CB_addra_base + l_k_row;
                      end     
                      SEQ_1: begin
                        CB_douta_sel_new[3:2] <= CBa_mode[4:3]; 
                        CB_douta_sel_new[1:0] <= DIR_NEW;
                        CB_ena_new <= 1'b1;
                        CB_addra_new <= CB_addra_new + 1'b1;
                      end
                      default: begin
                        CB_ena_new <= 1'b0;
                        CB_addra_new <= 0;
                      end
                    endcase 
                  end
        default: begin
          CBa_shift_dir <= 0;
          CB_douta_sel_new <= 0;  

          CB_ena_new <= 1'b0;
          CB_wea_new <= 1'b0;
          CB_addra_new <= 0;
        end
      endcase
    end
  end

//CB portB
  /*
    *****************************CB-portB write*****************************
  */
  always @(posedge clk) begin
    if(sys_rst) begin
      CBb_shift_dir   <= 0;
      CB_dinb_sel_new <= 0;

      CB_enb_new <= 1'b0;
      CB_web_new <= 1'b0;
      CB_addrb_new <= 0;
    end
    else begin
      case (CBb_mode_WR[2:0])
        CB_cov_vv : begin
                      CB_web_new <= 1'b1;
                      CB_dinb_sel_new <= DIR_POS;
                      CBb_shift_dir <= DIR_POS;
                      case(seq_cnt_WR)
                        SEQ_0: begin
                          CB_enb_new <= 1'b1;
                          CB_addrb_new <= 2'b00;
                        end  
                        SEQ_1: begin
                          CB_enb_new <= 1'b0;
                          CB_addrb_new <= 0;
                        end
                        SEQ_2: begin
                          CB_enb_new <= 1'b1;
                          CB_addrb_new <= 2'b01;
                        end
                        SEQ_3: begin
                          CB_enb_new <= 1'b0;
                          CB_addrb_new <= 0;
                        end
                        SEQ_4: begin
                          CB_enb_new <= 1'b1;
                          CB_addrb_new <= 2'b10;
                        end
                        default: begin
                          CB_enb_new <= 1'b0;
                          CB_addrb_new <= 0;
                        end
                      endcase
                    end
        CB_cov_mv : begin
                      CB_web_new <= 1'b1;
                      CB_dinb_sel_new <= DIR_POS;
                      CBb_shift_dir <= DIR_POS;
                      case(seq_cnt_WR)
                        SEQ_0: begin
                          CBb_shift_dir <= DIR_POS;

                          CB_enb_new <= 1'b1;
                          CB_addrb_new <= CB_addrb_base;
                        end  
                        SEQ_2: begin
                          CB_enb_new <= 1'b1;
                          CB_addrb_new <= CB_addrb_base + 2'b01;
                        end
                        SEQ_4: begin
                          CB_enb_new <= 1'b1;
                          CB_addrb_new <= CB_addrb_base + 2'b10;
                        end
                        default: begin
                          CB_enb_new <= 1'b0;
                          CB_addrb_new <= 0;
                        end
                      endcase
                    end
        CB_cov    : begin
                      CB_web_new <= 1'b1;
                      CB_dinb_sel_new <= DIR_POS;
                      CBb_shift_dir <= DIR_POS;
                      case(seq_cnt_WR[0])
                        1'b0: begin
                          CB_enb_new <= 1'b0;
                          CB_addrb_new <= 0;
                        end
                        1'b1: begin
                          CB_enb_new <= 1'b1;
                          CB_addrb_new <= CB_addrb_new + 1'b1;
                        end
                      endcase     
                    end
        CB_cov_lv : begin
                      CB_web_new <= 1'b1;
                      CB_dinb_sel_new <= DIR_NEW;
                      CBb_shift_dir <= DIR_NEW;
                      case(seq_cnt_WR)
                        SEQ_0: begin
                          CB_enb_new <= 1'b1;
                          CB_addrb_new <= l_k_base_addr_WR;
                        end  
                        SEQ_2: begin
                          CB_enb_new <= 1'b1;
                          CB_addrb_new <= l_k_base_addr_WR + 2'b01;
                        end
                        SEQ_4: begin
                          CB_enb_new <= 1'b1;
                          CB_addrb_new <= l_k_base_addr_WR + 2'b10;
                        end
                        default: begin
                          CB_enb_new <= 1'b0;
                          CB_addrb_new <= 0;
                        end
                      endcase
                    end
        CB_cov_lm : begin
                      CB_web_new <= 1'b1;
                      CB_dinb_sel_new <= DIR_NEW;
                      CBb_shift_dir <= DIR_NEW;
                      case(seq_cnt_WR)
                        SEQ_0: begin
                          CB_enb_new <= 1'b1;
                          CB_addrb_new <= l_k_base_addr_WR;
                        end  
                        SEQ_2: begin
                          CB_enb_new <= 1'b1;
                          CB_addrb_new <= l_k_base_addr_WR + 1'b1;
                        end
                        SEQ_4: begin
                          CB_enb_new <= 1'b1;
                          CB_addrb_new <= l_k_base_addr_WR + 2'b10;
                        end
                        SEQ_6: begin
                          CB_enb_new <= 1'b1;
                          CB_addrb_new <= l_k_base_addr_WR + 2'b11;
                        end
                        default: begin
                          CB_enb_new <= 1'b0;
                          CB_addrb_new <= 0;
                        end
                      endcase
                    end
        CB_cov_ll : begin
                      CB_web_new <= 1'b1;
                      CB_dinb_sel_new <= DIR_NEW;
                      CBb_shift_dir <= DIR_NEW;
                      case(seq_cnt_WR)
                        SEQ_0: begin
                          CB_enb_new <= 1'b1;
                          CB_addrb_new <= l_k_base_addr_WR + l_k_row;
                        end  
                        SEQ_2: begin
                          CB_enb_new <= 1'b1;
                          CB_addrb_new <= CB_addrb_new + 1'b1;
                        end
                        default: begin
                          CB_enb_new <= 1'b0;
                          CB_addrb_new <= 0;
                        end
                      endcase
                    end
        default   : begin
                      CBb_shift_dir   <= 0;
                      CB_dinb_sel_new <= 0;

                      CB_enb_new <= 1'b0;
                      CB_web_new <= 1'b0;
                      CB_addrb_new <= 0;

                    end
      endcase
    end
  end

/*
  ************************shift inst***************************
*/

  /*
    ************************ABCM shift***************************
  */
  //shift of PE_sel
    dshift 
    #(
      .DW  (A_IN_SEL_DW ),
      .DEPTH (X )
    )
    A_in_sel_dshift(
      .clk  (clk  ),
      .dir  (A_in_sel_dir   ),
      .l_k_0       (l_k_0       ),
      .sys_rst ( sys_rst),
      .din  (A_in_sel_new  ),
      .dout (A_in_sel )
    );

    dshift 
    #(
      .DW  (B_IN_SEL_DW ),
      .DEPTH (X )
    )
    B_in_sel_dshift(
      .clk  (clk  ),
      .dir   (B_in_sel_dir   ),
      .l_k_0       (l_k_0       ),
      .sys_rst ( sys_rst),
      .din  (B_in_sel_new  ),
      .dout (B_in_sel )
    );

    dshift 
    #(
      .DW  (M_IN_SEL_DW ),
      .DEPTH (X )
    )
    M_in_sel_dshift(
      .clk  (clk  ),
      .dir  (M_in_sel_dir   ),
      .l_k_0       (l_k_0       ),
      .sys_rst ( sys_rst),
      .din  (M_in_sel_new  ),
      .dout (M_in_sel )
    );

    dshift 
    #(
      .DW  (2 ),
      .DEPTH (X )
    )
    M_adder_mode_dshift(
      .clk  (clk  ),
      .dir  (M_in_sel_dir   ),
      .l_k_0       (l_k_0       ),
      .sys_rst ( sys_rst),
      .din  (M_adder_mode_new  ),
      .dout (M_adder_mode )
    );

    dshift 
    #(
      .DW  (C_OUT_SEL_DW ),
      .DEPTH (X )
    )
   C_out_sel_dshift(
      .clk  (clk  ),
      .dir   (C_out_sel_dir   ),
      .l_k_0       (l_k_0       ),
      .sys_rst ( sys_rst),
      .din  (C_out_sel_new  ),
      .dout (C_out_sel )
    );

/*
  **********************shift of TB_portA***********************
*/
    dshift 
    #(
      .DW  (1 ),
      .DEPTH (L )
    )
    TB_ena_dshift(
      .clk  (clk  ),
      .dir  (TBa_shift_dir   ),
      .l_k_0       (l_k_0       ),
      .sys_rst ( sys_rst),
      .din  (TB_ena_new  ),
      .dout (TB_ena )
    );

    dshift 
    #(
      .DW  (1 ),
      .DEPTH (L )
    )
    TB_wea_dshift(
      .clk  (clk  ),
      .dir   (TBa_shift_dir   ),
      .l_k_0       (l_k_0       ),
      .sys_rst ( sys_rst),
      .din  (TB_wea_new  ),
      .dout (TB_wea )
    );

    dshift 
    #(
      .DW  (TB_AW  ),
      .DEPTH (L )
    )
    TB_addra_dshift(
      .clk  (clk  ),
      .dir   (TBa_shift_dir   ),
      .l_k_0       (l_k_0       ),
      .sys_rst ( sys_rst),
      .din  (TB_addra_new  ),
      .dout (TB_addra )
    );

/*
    **********************shift of TB_portB**************************
*/
    dshift 
    #(
      .DW  (1 ),
      .DEPTH (L )
    )
    TB_enb_dshift(
      .clk  (clk  ),
      .dir  (TBb_shift_dir   ),
      .l_k_0       (l_k_0       ),
      .sys_rst ( sys_rst),
      .din  (TB_enb_new  ),
      .dout (TB_enb )
    );

    dshift 
    #(
      .DW  (1 ),
      .DEPTH (L )
    )
    TB_web_dshift(
      .clk  (clk  ),
      .dir   (TBb_shift_dir   ),
      .l_k_0       (l_k_0       ),
      .sys_rst ( sys_rst),
      .din  (TB_web_new  ),
      .dout (TB_web )
    );

    dshift 
    #(
      .DW  (TB_AW  ),
      .DEPTH (L )
    )
    TB_addrb_dshift(
      .clk  (clk  ),
      .sys_rst ( sys_rst),
      .dir  (TBb_shift_dir   ),
      .l_k_0       (l_k_0       ),
      .din  (TB_addrb_new  ),
      .dout (TB_addrb )
    );

/*
    **********************shift of B_cache**************************
*/
    dshift 
    #(
      .DW  (1 ),
      .DEPTH (L )
    )
    B_cache_en_dshift(
      .clk  (clk  ),
      .dir  (DIR_POS   ),
      .l_k_0       (l_k_0       ),
      .sys_rst ( sys_rst),
      .din  (B_cache_en_new  ),
      .dout (B_cache_en )
    );

    dshift 
    #(
      .DW  (1 ),
      .DEPTH (L )
    )
    B_cache_we_dshift(
      .clk  (clk  ),
      .dir   (DIR_POS   ),
      .l_k_0       (l_k_0       ),
      .sys_rst ( sys_rst),
      .din  (B_cache_we_new  ),
      .dout (B_cache_we )
    );

    dshift 
    #(
      .DW  (3  ),
      .DEPTH (L )
    )
    B_cache_addr_dshift(
      .clk  (clk  ),
      .sys_rst ( sys_rst),
      .dir  (DIR_POS   ),
      .l_k_0       (l_k_0       ),
      .din  (B_cache_addr_new  ),
      .dout (B_cache_addr )
    );

/*
  *********************shift of CB-portA****************
*/
    dshift 
    #(
      .DW  (1 ),
      .DEPTH (L )
    )
    CB_ena_dshift(
      .clk  (clk  ),
      .sys_rst ( sys_rst),
      .dir          (CBa_shift_dir          ),
      .l_k_0       (l_k_0       ),
      .din  (CB_ena_new  ),
      .dout (CB_ena )
    );

    dshift 
    #(
      .DW  (1 ),
      .DEPTH (L )
    )
    CB_wea_dshift(
      .clk  (clk  ),
      .sys_rst ( sys_rst),
      .dir          (CBa_shift_dir          ),
      .l_k_0       (l_k_0       ),
      .din  (CB_wea_new  ),
      .dout (CB_wea )
    );

    dshift 
    #(
      .DW        (CB_AW        ),
      .DEPTH     (L     )
    )
    CB_addra_dshift(
    	.clk     (clk     ),
      .sys_rst (sys_rst ),
      .dir  (CBa_shift_dir  ),
      .l_k_0       (l_k_0       ),
      .din     (CB_addra_new     ),
      .dout    (CB_addra    )
    );
    
/*
  *********************shift of CB-portB****************
*/
    dshift 
    #(
      .DW  (1 ),
      .DEPTH (L )
    )
    CB_enb_dshift(
      .clk  (clk  ),
      .sys_rst ( sys_rst),
      .dir          (CBb_shift_dir          ),
      .l_k_0       (l_k_0       ),
      .din  (CB_enb_new  ),
      .dout (CB_enb )
    );

    dshift 
    #(
      .DW  (1 ),
      .DEPTH (L )
    )
    CB_web_dshift(
      .clk  (clk  ),
      .sys_rst ( sys_rst),
      .dir          (CBb_shift_dir          ),
      .l_k_0       (l_k_0       ),
      .din  (CB_web_new  ),
      .dout (CB_web )
    );

    dshift 
    #(
      .DW        (CB_AW        ),
      .DEPTH     (L     )
    )
    CB_addrb_dshift(
    	.clk     (clk     ),
      .sys_rst (sys_rst ),
      .dir  (CBb_shift_dir  ),
      .l_k_0       (l_k_0       ),
      .din     (CB_addrb_new     ),
      .dout    (CB_addrb    )
    );


/*
  **************************** TB_base_addr ***********************
*/
  always @(posedge clk) begin
    if(sys_rst) begin
      A_TB_base_addr <= 0;
    end
    else begin
      case(stage_cur)
        STAGE_PRD: A_TB_base_addr <= A_TB_base_addr_set;
        STAGE_NEW: A_TB_base_addr <= A_TB_base_addr_set;
        STAGE_UPD: begin
          case(upd_cur)
            UPD_1: begin
              if(seq_cnt == 1'b1 && v_group_cnt == 0) begin
                A_TB_base_addr <= A_TB_base_addr_set;
              end
              else if(seq_cnt == seq_cnt_max && v_group_cnt < v_group_cnt_max) begin
                A_TB_base_addr <= A_TB_base_addr + 3'b100;
              end
              else
                A_TB_base_addr <= A_TB_base_addr;
            end
            UPD_3: begin
              if(seq_cnt == 1'b1 && v_group_cnt == 0) begin
                A_TB_base_addr <= A_TB_base_addr_set;
              end
              else if(seq_cnt == seq_cnt_max && v_group_cnt < v_group_cnt_max) begin
                A_TB_base_addr <= A_TB_base_addr + 3'b100;
              end
              else
                A_TB_base_addr <= A_TB_base_addr;
            end
            UPD_4: begin
              A_TB_base_addr <= A_TB_base_addr;
            end
            UPD_5: begin
              A_TB_base_addr <= A_TB_base_addr;
            end
            UPD_9: begin
              if(seq_cnt == 1'b1 && v_group_cnt == 0) begin
                A_TB_base_addr <= A_TB_base_addr_set;
              end
              else if(seq_cnt == seq_cnt_max && v_group_cnt < v_group_cnt_max) begin
                A_TB_base_addr <= A_TB_base_addr + 3'b100;
              end
              else
                A_TB_base_addr <= A_TB_base_addr;
            end
            UPD_10: begin
              if(seq_cnt == 1'b1 && h_group_cnt == 0 && v_group_cnt == 0) begin
                A_TB_base_addr <= A_TB_base_addr_set;
              end
              else if(seq_cnt == seq_cnt_max && h_group_cnt == h_group_cnt_max && v_group_cnt < v_group_cnt_max) begin
                A_TB_base_addr <= A_TB_base_addr + 3'b100;
              end
              else
                A_TB_base_addr <= A_TB_base_addr;
            end
            default: A_TB_base_addr <= A_TB_base_addr_set;
          endcase
        end
        default: A_TB_base_addr <= A_TB_base_addr_set;
      endcase
    end
  end

  always @(posedge clk) begin
    if(sys_rst) begin
      B_TB_base_addr <= 0;
    end
    else begin
      case(stage_cur)
        STAGE_PRD: B_TB_base_addr <= B_TB_base_addr_set;
        STAGE_NEW: B_TB_base_addr <= B_TB_base_addr_set;
        STAGE_UPD: begin
          case(upd_cur)
            UPD_10: begin
              if(seq_cnt == 1'b1 && h_group_cnt == 0 && v_group_cnt == 0) begin
                B_TB_base_addr <= B_TB_base_addr_set;
              end
              else if(seq_cnt == seq_cnt_max && h_group_cnt < h_group_cnt_max)  begin
                B_TB_base_addr <= B_TB_base_addr + 3'b100;
              end
              else if(seq_cnt == seq_cnt_max && h_group_cnt == h_group_cnt_max) begin
                B_TB_base_addr <= B_TB_base_addr_set;
              end
              else
                B_TB_base_addr <= B_TB_base_addr;
            end
            default: B_TB_base_addr <= B_TB_base_addr_set;
          endcase
        end
        default: B_TB_base_addr <= B_TB_base_addr_set;
      endcase
    end
  end

  always @(posedge clk) begin
    if(sys_rst) begin
      C_TB_base_addr <= 0;
    end
    else begin
      case(stage_cur)
        STAGE_PRD: C_TB_base_addr <= C_TB_base_addr_set;
        STAGE_NEW: C_TB_base_addr <= C_TB_base_addr_set;
        STAGE_UPD: begin
          case(upd_cur)
            UPD_3: begin
              if(seq_cnt_WR == 1 && v_group_cnt_WR == 0) begin
                C_TB_base_addr <= C_TB_base_addr_set;
              end
              else if(seq_cnt_WR == seq_cnt_max && v_group_cnt_WR < v_group_cnt_max) begin
                C_TB_base_addr <= C_TB_base_addr + 3'b100;
              end
              else
                C_TB_base_addr <= C_TB_base_addr;
            end
            UPD_4:begin
              C_TB_base_addr <= C_TB_base_addr;
            end
            UPD_5:begin
              C_TB_base_addr <= C_TB_base_addr;
            end
            UPD_9: begin
              if(seq_cnt_WR == 1 && v_group_cnt_WR == 0) begin
                C_TB_base_addr <= C_TB_base_addr_set;
              end
              else if(seq_cnt_WR == seq_cnt_max && v_group_cnt_WR < v_group_cnt_max) begin
                C_TB_base_addr <= C_TB_base_addr + 3'b100;
              end
              else
                C_TB_base_addr <= C_TB_base_addr;
            end
            default: C_TB_base_addr <= C_TB_base_addr_set;
          endcase
        end
        default: C_TB_base_addr <= C_TB_base_addr_set;
      endcase
    end
  end

/*
  ********************** CB base addr gen *****************************
*/

  reg                           CBa_vm_AGD_en;
  reg                           CBb_vm_AGD_en;
  reg                           l_k_AGD_en;

  wire [CB_AW-1 : 0]            CB_addra_base_raw;
  wire [CB_AW-1 : 0]            CB_addrb_base_raw;
  wire [CB_AW-1 : 0]            l_k_base_addr_raw;

  //*********************** CBa_vm_AGD *************************

  //CBa_vm_AGD_en有效时，CB_base_AGD就会不断更新CB_addra_base_raw
  always @(posedge clk) begin
    if(sys_rst) begin
      CBa_vm_AGD_en <= 0;
    end
    else begin
      case(CBa_mode[2:0])
        CB_cov_vv: CBa_vm_AGD_en <= 1'b1;
        CB_cov_mv: CBa_vm_AGD_en <= 1'b1;
        CB_cov_ml: CBa_vm_AGD_en <= 1'b1;
        CB_cov_ll: CBa_vm_AGD_en <= 1'b1;
        default:   CBa_vm_AGD_en <= 1'b0;
      endcase
    end
  end
  CB_base_AGD 
    #(
      .CB_AW   (CB_AW   ),
      .ROW_LEN (ROW_LEN ),
      .AGD_MODE(0)
    )
    CB_addra_base_AGD(
    	.clk          (clk          ),
      .sys_rst      (sys_rst      ),
      .en           (CBa_vm_AGD_en           ),
      .group_cnt    (v_group_cnt    ),
      .CB_base_addr (CB_addra_base_raw )
    );
  
  always @(posedge clk) begin
    if(sys_rst) begin
      CB_addra_base <= 0;
    end
    else begin
      case(CBa_mode[2:0])
        CB_cov_vv: begin
          if(seq_cnt == seq_cnt_max)
            CB_addra_base <= CB_addra_base_raw;
          else
            CB_addra_base <= 1'b1;
        end
        CB_cov_mv:begin
                    if(seq_cnt == seq_cnt_max)
                      CB_addra_base <= CB_addra_base_raw;
                    else
                      CB_addra_base <= CB_addra_base;
                  end
        CB_cov_ml:begin
                    CB_addra_base <= CB_addra_base;
                  end
        CB_cov_ll:begin
                    if(seq_cnt == seq_cnt_max)
                      CB_addra_base <= CB_addra_base_raw;
                    else
                      CB_addra_base <= CB_addra_base;
                  end
        default:   CB_addra_base <= 0;
      endcase
    end
  end

  //*********************** CBb_vm_AGD *************************
  always @(posedge clk) begin
    if(sys_rst) begin
      CBb_vm_AGD_en <= 0;
    end
    else begin
      case(CBb_mode_WR[2:0])
        CB_cov_vv: CBb_vm_AGD_en <= 1'b1;
        CB_cov_mv: CBb_vm_AGD_en <= 1'b1;
        default:   CBb_vm_AGD_en <= 1'b0;
      endcase
    end
  end
  CB_base_AGD 
    #(
      .CB_AW   (CB_AW   ),
      .ROW_LEN (ROW_LEN ),
      .AGD_MODE(0)
    )
    CB_addrb_base_AGD(
    	.clk          (clk          ),
      .sys_rst      (sys_rst      ),
      .en           (CBb_vm_AGD_en           ),
      .group_cnt    (v_group_cnt_WR    ),
      .CB_base_addr (CB_addrb_base_raw )
    );

  always @(posedge clk) begin
    if(sys_rst) begin
      CB_addrb_base <= 0;
    end
    else begin
      case(CBb_mode_WR[2:0])
        CB_cov_vv: begin
          if(seq_cnt_WR == seq_cnt_max)
            CB_addrb_base <= CB_addrb_base_raw;
          else
            CB_addrb_base <= 1'b1;
        end
        CB_cov_mv: begin
          if(seq_cnt_WR == seq_cnt_max)
            CB_addrb_base <= CB_addrb_base_raw;
          else
            CB_addrb_base <= CB_addrb_base;
        end
        CB_cov_ml: begin
          CB_addra_base <= CB_addra_base;
        end
        default:   CB_addrb_base <= 0;
      endcase
    end
  end

  //*********************** l_k_base_addr_AGD *************************
    always @(posedge clk) begin
      if(sys_rst) begin
        l_k_AGD_en <= 0;
      end
      else begin
        case(stage_cur)
          STAGE_NEW: l_k_AGD_en <= 1'b1;
          STAGE_UPD: l_k_AGD_en <= 1'b1;
          default:   l_k_AGD_en <= 1'b0;
        endcase
      end
    end

    CB_base_AGD 
    #(
      .CB_AW   (CB_AW   ),
      .ROW_LEN (ROW_LEN ),
      .AGD_MODE(1)
    )
    l_k_base_AGD(
    	.clk          (clk          ),
      .sys_rst      (sys_rst      ),
      .en           (l_k_AGD_en         ),
      .group_cnt    (l_k_group          ),
      .CB_base_addr (l_k_base_addr_raw)
    );

  /*
    ********************** l_k_base_addr_RD **********************
  */
    always @(posedge clk) begin
      if(sys_rst) begin
        l_k_base_addr_RD <= 0;
      end
      else begin
        case(CBa_mode[2:0])
          CB_cov_lv: begin
            if(seq_cnt == seq_cnt_max)
              l_k_base_addr_RD <= l_k_base_addr_RD + 3'b100;  //准备好 cov_lm的起始地址
            else
              l_k_base_addr_RD <= l_k_base_addr_raw;
          end
          CB_cov_lm: begin
            if(seq_cnt == seq_cnt_max)
              l_k_base_addr_RD <= l_k_base_addr_RD + 3'b100;
            else
              l_k_base_addr_RD <= l_k_base_addr_RD;
          end
          default:   l_k_base_addr_RD <= l_k_base_addr_raw;
        endcase
      end
    end
  /*
    ********************** l_k_base_addr_WR **********************
  */
    always @(posedge clk) begin
      if(sys_rst) begin
        l_k_base_addr_WR <= 0;
      end
      else begin
        case(CBb_mode_WR[2:0])
          CB_cov_lv: begin
            if(seq_cnt_WR == seq_cnt_max)
              l_k_base_addr_WR <= l_k_base_addr_WR + 3'b100;  //准备好 cov_lm的起始地址
            else
              l_k_base_addr_WR <= l_k_base_addr_raw;
          end
          CB_cov_lm: begin
            if(seq_cnt_WR == seq_cnt_max)
              l_k_base_addr_WR <= l_k_base_addr_WR + 3'b100;
            else
              l_k_base_addr_WR <= l_k_base_addr_WR;
          end
          default:   l_k_base_addr_WR <= l_k_base_addr_raw;
        endcase
      end
    end

  /*
    ******************* sel_new -> sel ********************
  */
  always @(posedge clk) begin
    TB_dina_sel <= TB_dina_sel_new;
    TB_dinb_sel <= TB_dinb_sel_new;
    TB_douta_sel <= TB_douta_sel_new;
    TB_doutb_sel <= TB_doutb_sel_new;
    CB_dinb_sel <= CB_dinb_sel_new;
    CB_douta_sel <= CB_douta_sel_new;
  end

  always @(posedge clk) begin
    if(sys_rst) begin
      CB_dina <= 0;
    end
    else 
      CB_dina <= 0;
  end

endmodule