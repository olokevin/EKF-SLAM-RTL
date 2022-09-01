module PE_config #(
  parameter X = 4,
  parameter Y = 4,
  parameter L = 4,

  parameter A_IN_SEL_DW = 2,
  parameter B_IN_SEL_DW = 2,
  parameter M_IN_SEL_DW = 2,
  parameter C_OUT_SEL_DW = 2,

  parameter TB_DINA_SEL_DW  = 5,
  parameter TB_DINB_SEL_DW  = 2,
  parameter TB_DOUTA_SEL_DW = 3,
  parameter TB_DOUTB_SEL_DW = 5,
  parameter CB_DINA_SEL_DW  = 2,
  parameter CB_DINB_SEL_DW  = 5,
  parameter CB_DOUTA_SEL_DW = 5,  //注意MUX deMUX需手动修改

  parameter RSA_DW = 32,
  parameter TB_AW = 11,
  parameter CB_AW = 17,

  parameter SEQ_CNT_DW = 5,
  parameter ROW_LEN  = 10
) (
  input clk,
  input sys_rst,

//landmark numbers
  // input   [ROW_LEN-1 : 0]  landmark_num,  //总地标数
  // input   [ROW_LEN-1 : 0]  l_k,           //当前地标编号
  output reg   [ROW_LEN-1 : 0]  landmark_num,  //总地标数
  output reg   [ROW_LEN-1 : 0]  l_k,           //当前地标编号
//handshake of stage change
  input   [2:0]   stage_val,
  output  reg     stage_rdy,

/*
  (OLD) handshake of nonlinear calculation start & complete
  //nonlinear start(3 stages are conbined)
    output   reg [2:0]   nonlinear_m_rdy,
    input  [2:0]     nonlinear_s_val,
  //nonlinear cplt(3 stages are conbined)
    output   reg [2:0]   nonlinear_m_val,
    input  [2:0]     nonlinear_s_rdy,
*/

// NonLinear init
  output reg init_predict, init_newlm, init_update,

// NonLinear done
  input done_predict, done_newlm, done_update,
  

//sel en we addr are wire connected to the regs of dshift out. actually they are reg output
  output  [A_IN_SEL_DW*X-1 : 0]       A_in_sel,
  output reg [X-1 : 0]                A_in_en,   

  output  [B_IN_SEL_DW*Y-1 : 0]       B_in_sel,   
  output reg [Y-1 : 0]                B_in_en,  

  output  [M_IN_SEL_DW*X-1 : 0]       M_in_sel,  
  output reg [X-1 : 0]                M_in_en,   

  output  [C_OUT_SEL_DW*X-1 : 0]      C_out_sel, 
  output reg [X-1 : 0]                C_out_en,

//TEMP BRAM
  output [TB_DINA_SEL_DW-1 : 0]       TB_dina_sel,
  output [TB_DINB_SEL_DW-1 : 0]       TB_dinb_sel,
  output reg [TB_DOUTA_SEL_DW-1 : 0]      TB_douta_sel,
  output reg [TB_DOUTB_SEL_DW-1 : 0]      TB_doutb_sel,

  output  [L-1 : 0]         TB_ena,
  output  [L-1 : 0]         TB_enb,

  output  [L-1 : 0]         TB_wea,
  output  [L-1 : 0]         TB_web,

  output  [L*TB_AW-1 : 0]      TB_addra,
  output  [L*TB_AW-1 : 0]      TB_addrb,

//COV BRAM
  // output [CB_DINA_SEL_DW-1 : 0]      CB_dina_sel,
  output [CB_DINB_SEL_DW-1 : 0]      CB_dinb_sel,
  output reg [CB_DOUTA_SEL_DW-1 : 0]     CB_douta_sel,

  output [L-1 : 0]        CB_ena,
  output [L-1 : 0]        CB_enb,

  output [L-1 : 0]        CB_wea,
  output [L-1 : 0]        CB_web,

  output [L*CB_AW-1 : 0]      CB_addra,
  output [L*CB_AW-1 : 0]      CB_addrb,

//B cache
  output  reg [3:0]                     B_cache_in_sel,
  output  reg [3:0]                     B_cache_out_sel,
  output  [Y-1:0]         B_cache_en,
  output  [Y-1:0]         B_cache_we,
  output  [Y*3-1:0]       B_cache_addr,

  output  reg  init_inv,
  input        done_inv,

//states
  (*mark_debug = "true" *)output [SEQ_CNT_DW-1:0]   seq_cnt_out, 
  (*mark_debug = "true" *)output [2:0]              stage_cur_out,
  (*mark_debug = "true" *)output [3:0]              prd_cur_out,
  (*mark_debug = "true" *)output [5:0]              new_cur_out,
  (*mark_debug = "true" *)output [5:0]              upd_cur_out,
  (*mark_debug = "true" *)output [5:0]              assoc_cur_out,

  input  [1:0]              assoc_status,
  input  [ROW_LEN-1 : 0]    assoc_l_k,

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
  // localparam M_IN_SEL_D = 3'd7;
  localparam M_IN_SEL_D  = 3'd6;    //Min_sel也与n有关
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
  localparam A_cache = 2'b01;
  localparam A_CBa = 2'b10;
  localparam A_NONE = 2'b11;

//B map mode
  localparam B_TBb = 2'b00;
  localparam B_cache = 2'b01;
  localparam B_CBa = 2'b10;
  localparam B_NONE = 2'b11;

//M map mode
  localparam M_TBa = 2'b00;
  localparam M_cache = 2'b01;
  localparam M_CBa = 2'b10;
  localparam M_NONE = 2'b11;

//adder mode
  localparam NONE = 2'b00;
  localparam ADD = 2'b01;
  localparam C_MINUS_M = 2'b10;
  localparam M_MINUS_C = 2'b11;

//C map mode
  localparam  C_TBb = 2'b00;
  localparam  C_cache = 2'b01;
  localparam  C_CBb = 2'b10;
  localparam  C_PLB = 2'b11;
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
    localparam TBa_CBa     = 3'b100;
    localparam TBa_TBb     = 3'b101;
    // localparam TBa_NL_PRD  = 3'b101;
    // localparam TBa_NL_NEW  = 3'b110;
    localparam TBa_NL_UPD  = 3'b111;

  //TBb RD
    localparam TBb_IDLE = 3'b000;
    localparam TBb_B = 3'b001;
    // localparam TBb_B_cache = 3'b100;
    // localparam TBb_B_cache_IDLE = 3'b100;
    // localparam TBb_B_cache_trnsfer = 3'b101;
    localparam TBb_H_lv_H_transpose = 3'b101;
    localparam TBb_cov_HT_transpose = 3'b110;
    localparam TBb_B_cache_inv = 3'b111;

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


/*
  ************************** CB mode config *********************
*/
  localparam CB_IDLE = 6'b000000;
  //CB_mode[6:4] dir

  //CB port-A map
    localparam CBa_IDLE = 3'b000;
    localparam CBa_A = 3'b001;
    localparam CBa_B = 3'b010;
    localparam CBa_M = 3'b011;
    localparam CBa_TBa = 3'b100;
    localparam CBa_NL  = 3'b111;

  //CB port-B map 
    //CB_mode[6] == 0, RSA WR
    localparam CBb_IDLE = 3'b000;
    localparam CBb_C    = 3'b001;  
    //CB_mode[6] == 1, NL WR
    localparam CBb_xyxita  = 3'b101 ;
    localparam CBb_lxly    = 3'b110 ;

  //CB_mode[3:0] mode
    localparam CB_cov_IDLE = 4'b0000;
    localparam CB_cov_vv = 4'b0001;
    localparam CB_cov_mv = 4'b0010;
    localparam CB_cov    = 4'b0011;
    localparam CB_cov_lv = 4'b0100;
    localparam CB_cov_lm = 4'b0101;
    localparam CB_cov_ml = 4'b0110;
    localparam CB_cov_ll = 4'b0111;    
    localparam CB_NL_xyxita = 4'b1001;
    localparam CB_NL_lxly   = 4'b1010;

/*
  ************************** B_cache mode config *********************
*/
  
    localparam Bca_IDLE  = 4'b0000;
  //RD 首位为0
    localparam Bca_RD_A  = 4'b0001;
    localparam Bca_RD_B  = 4'b0010;
    // localparam Bca_RD_BM = 4'b0100;

  //WR 首位为1
    // localparam Bca_WR_cov_HT  = 4'b1000;
    // localparam Bca_WR_H_lv_H  = 4'b1001;
    localparam Bca_WR_inv     = 4'b1010;
    localparam Bca_WR_chi     = 4'b1011;
    
    localparam Bca_WR_NL_PRD  = 4'b1100;
    localparam Bca_WR_NL_ASSOC= 4'b1101;
    localparam Bca_WR_NL_NEW  = 4'b1110;
    localparam Bca_WR_NL_UPD  = 4'b1111; 

/*
  ********************** params of FSMs *************************
*/
//stage
  localparam      STAGE_IDLE = 3'b000 ;
  localparam      STAGE_PRD  = 3'b001 ;
  localparam      STAGE_NEW  = 3'b010 ;
  localparam      STAGE_UPD  = 3'b011 ;
  localparam      STAGE_ASSOC  = 3'b100 ;
  // parameter      STAGE_INIT = 3'b111 ;

//stage_rdy
  // localparam BUSY  = 3'b000;
  // localparam READY   = 3'b111;

//ASSOC STATUS
  localparam ASSOC_WAIT = 2'b00;
  localparam ASSOC_NEW  = 2'b01;
  localparam ASSOC_UPD  = 2'b10;
  localparam ASSOC_FAIL = 2'b11;

//SEQ_CNT_PARAM
  localparam [SEQ_CNT_DW-1 : 0] SEQ_0 = 5'd0;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_1 = 5'd1;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_2 = 5'd2;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_3 = 5'd3;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_4 = 5'd4;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_5 = 5'd5;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_6 = 5'd6;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_7 = 5'd7;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_8 = 5'd8;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_9 = 5'd9;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_10 = 5'd10;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_11 = 5'd11;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_12 = 5'd12;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_13 = 5'd13;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_14 = 5'd14;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_15 = 5'd15;


/*
  ******************* params of B_cache addr *****************
*/
    localparam Fxi_cache = 3'b000;

    localparam Gxi_cache = 3'b000;
    localparam Gz_cache  = 3'b011;

    localparam Hxi_cache = 3'b000;
    localparam Hz_cache  = 3'b011;

  //ASSOC
    localparam I_cache = 3'b101;
    localparam H_vl_H_cache_0  = 3'b000;
    localparam H_vl_H_cache_1  = 3'b001;
    
  //UPD
    localparam v_t_cache = 3'b101;
    localparam cov_HT_cache = 3'b000;
    localparam S_cache_0 = 3'b000;
    localparam S_cache_1 = 3'b001;
    localparam vt_S_inv_cache_0 = 3'b010;
    localparam vt_S_inv_cache_1 = 3'b011;


/*
  ******************* params of Prediction stage *****************
*/
  // TEMP BANK offsets of PRD
    // localparam [TB_AW-1 : 0] F_xi = 'd0;
    // localparam [TB_AW-1 : 0] F_xi_T = 'd3;
    // localparam [TB_AW-1 : 0] t_cov = 'd6;
    localparam [TB_AW-1 : 0] F_cov = 'd5;
    localparam [TB_AW-1 : 0] M_t = 'd0;
  // PREDICTION SERIES
    localparam PRD_IDLE    = 4'b0000;
    localparam PRD_NL_SEND = 4'b1001;
    localparam PRD_NL_WAIT = 4'b1010;
    localparam PRD_NL_RCV  = 4'b1011;
    localparam PRD_1       = 4'b0001;       //prd_cur[1]
    localparam PRD_2       = 4'b0010;
    localparam PRD_3       = 4'b0011;
    localparam PRD_3_HALT  = 4'b0100;

    // localparam PRD_1_START = 0;
    // localparam PRD_2_START = 'd18;
    // localparam PRD_3_START = 'd36;

    localparam [SEQ_CNT_DW-1 : 0] PRD_NL_SEND_CNT_MAX = 'd11;
    localparam [SEQ_CNT_DW-1 : 0] PRD_NL_RCV_CNT_MAX  = 'd6;
    localparam [SEQ_CNT_DW-1 : 0] PRD_1_CNT_MAX = 'd15;
    localparam [SEQ_CNT_DW-1 : 0] PRD_2_CNT_MAX = 'd10;
    localparam [SEQ_CNT_DW-1 : 0] PRD_3_CNT_MAX = 'd5;
    localparam [SEQ_CNT_DW-1 : 0] PRD_3_HALT_CNT_MAX = 'd7;

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
    // localparam [TB_AW-1 : 0] G_xi          = 'd15;
    // localparam [TB_AW-1 : 0] G_z           = 'd18;
    localparam [TB_AW-1 : 0] Q         = 'd3;
    localparam [TB_AW-1 : 0] G_z_Q         = 'd8;
    localparam [TB_AW-1 : 0] lv_G_xi           = 'd10;
  // NEW SERIES
    localparam NEW_IDLE      = 6'b000000;
    localparam NEW_NL_SEND   = 6'b100001;
    localparam NEW_NL_WAIT   = 6'b100010;
    localparam NEW_NL_RCV    = 6'b100011;
    localparam NEW_1         = 6'b000001;       //prd_cur[1]
    localparam NEW_2         = 6'b000010;
    localparam NEW_3         = 6'b000011;
    localparam NEW_4         = 6'b000100;
    localparam NEW_5         = 6'b000101;

    localparam [SEQ_CNT_DW-1 : 0] NEW_NL_SEND_CNT_MAX = 'd11;
    localparam [SEQ_CNT_DW-1 : 0] NEW_NL_RCV_CNT_MAX  = 'd6;
    localparam [SEQ_CNT_DW-1 : 0] NEW_1_CNT_MAX     = 'd15;
    localparam [SEQ_CNT_DW-1 : 0] NEW_2_CNT_MAX     = 'd7;
    localparam [SEQ_CNT_DW-1 : 0] NEW_3_CNT_MAX     = 'd14;
    localparam [SEQ_CNT_DW-1 : 0] NEW_4_CNT_MAX     = 'd12;
    localparam [SEQ_CNT_DW-1 : 0] NEW_5_CNT_MAX     = 'd12;

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
    // localparam [TB_AW-1 : 0] H_xi          = 'd26;
    // localparam [TB_AW-1 : 0] H_z           = 'd29;
    // localparam [TB_AW-1 : 0] S_t           = 'd31;
    // localparam [TB_AW-1 : 0] t_cov_HT      = 'd33;
    // localparam [TB_AW-1 : 0] cov_HT        = 'd38;
    localparam [TB_AW-1 : 0] t_cov_HT      = 'd5;     //transposed cov_HT
    localparam [TB_AW-1 : 0] cov_HT        = 'd14;
    localparam [TB_AW-1 : 0] v_t           = 'd12;
    localparam [TB_AW-1 : 0] t_cov_l       = 'd16;
    localparam [TB_AW-1 : 0] K_t           = 'd16;
  // UPDATE SERIES
    localparam UPD_IDLE      = 6'b00_0000;
    localparam UPD_NL_SEND   = 6'b10_0001;
    localparam UPD_NL_WAIT   = 6'b10_0010;
    localparam UPD_NL_RCV    = 6'b10_0011;
    localparam UPD_1         = 6'b1;       
    localparam UPD_2         = 6'b10;
    localparam UPD_3         = 6'b11;
    localparam UPD_4         = 6'b100;
    localparam UPD_5         = 6'b101;
    localparam UPD_HALT_56   = 6'b110;
    localparam UPD_6         = 6'b111;
    localparam UPD_7         = 6'b1000;
    localparam UPD_INV       = 6'b1001;
    localparam UPD_8         = 6'b1010;
    localparam UPD_9         = 6'b1011;
    localparam UPD_STATE     = 6'b1100;
    localparam UPD_10        = 6'b1101;
    
    // localparam UPD_HALT_78   = 6'b1110;
    

    localparam [SEQ_CNT_DW-1 : 0] UPD_NL_SEND_CNT_MAX = 'd11;
    localparam [SEQ_CNT_DW-1 : 0] UPD_NL_RCV_CNT_MAX  = 'd10;
    localparam [SEQ_CNT_DW-1 : 0] UPD_1_CNT_MAX     = 'd4;
    localparam [SEQ_CNT_DW-1 : 0] UPD_2_CNT_MAX     = 'd2;
    localparam [SEQ_CNT_DW-1 : 0] UPD_3_CNT_MAX     = 'd2;
    localparam [SEQ_CNT_DW-1 : 0] UPD_4_CNT_MAX     = 'd3;
    localparam [SEQ_CNT_DW-1 : 0] UPD_5_CNT_MAX     = 'd3;
    localparam [SEQ_CNT_DW-1 : 0] UPD_HALT_56_CNT_MAX  = 'd11;
    localparam [SEQ_CNT_DW-1 : 0] UPD_6_CNT_MAX     = 'd11;
    localparam [SEQ_CNT_DW-1 : 0] UPD_7_CNT_MAX     = 'd10; //HALT： 8
    localparam [SEQ_CNT_DW-1 : 0] UPD_8_CNT_MAX     = 'd4;
    localparam [SEQ_CNT_DW-1 : 0] UPD_9_CNT_MAX     = 'd3;
    localparam [SEQ_CNT_DW-1 : 0] UPD_10_CNT_MAX    = 'd7;
    // localparam [SEQ_CNT_DW-1 : 0] UPD_HALT_78_CNT_MAX  = 'd11;
    localparam [SEQ_CNT_DW-1 : 0] UPD_STATE_CNT_MAX  = 'd7;


    localparam UPD_1_M       = 3'b000;
    localparam UPD_2_M       = 3'b011;
    localparam UPD_3_M       = 3'b100;
    localparam UPD_4_M       = 3'b100;
    localparam UPD_5_M       = 3'b100;
    localparam UPD_6_M       = 3'b100;    //保持en
    localparam UPD_7_M       = 3'b010;
    localparam UPD_8_M       = 3'b000;
    localparam UPD_9_M       = 3'b100;
    localparam UPD_10_M      = 3'b100;
    
    localparam UPD_1_N       = 3'b000;
    localparam UPD_2_N       = 3'b011;
    localparam UPD_3_N       = 3'b011;    //在UPD_2 UPD_3读出，保持延迟时序
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
  ******************* params of Data Assoc stage *****************
*/
  // TEMP BANK offsets of ASSOC
    localparam [TB_AW-1 : 0] H_vv = 'd5;
    localparam [TB_AW-1 : 0] H_lv = 'd8;
    localparam [TB_AW-1 : 0] H_vl = 'd8;
    localparam [TB_AW-1 : 0] H_ll = 'd10;
    localparam [TB_AW-1 : 0] H_vv_H = 'd5;
    localparam [TB_AW-1 : 0] H_lv_H = 'd8;
    localparam [TB_AW-1 : 0] H_vl_H = 'd8;    // OK to cover
    localparam [TB_AW-1 : 0] H_ll_H = 'd10;
  // ASSOC SERIES
    localparam ASSOC_IDLE      = 6'b000000;
    localparam ASSOC_NL_SEND   = 6'b100001;
    localparam ASSOC_NL_WAIT   = 6'b100010;
    localparam ASSOC_NL_RCV    = 6'b100011;
    localparam ASSOC_1         = 6'b000001;       
    localparam ASSOC_2         = 6'b000010;
    localparam ASSOC_3         = 6'b000011;
    localparam ASSOC_4         = 6'b000100;
    localparam ASSOC_5         = 6'b000101;
    localparam ASSOC_TRANS     = 6'b000110;
    localparam ASSOC_6         = 6'b000111;
    localparam ASSOC_7         = 6'b001000;
    localparam ASSOC_INV       = 6'b001001;
    localparam ASSOC_8         = 6'b001010;
    localparam ASSOC_9         = 6'b001011;
    localparam ASSOC_10        = 6'b001100;

    localparam [SEQ_CNT_DW-1 : 0] ASSOC_NL_SEND_CNT_MAX = 'd11;
    localparam [SEQ_CNT_DW-1 : 0] ASSOC_NL_RCV_CNT_MAX  = 'd10;
    localparam [SEQ_CNT_DW-1 : 0] ASSOC_1_CNT_MAX     = 'd6;
    localparam [SEQ_CNT_DW-1 : 0] ASSOC_2_CNT_MAX     = 'd4;
    localparam [SEQ_CNT_DW-1 : 0] ASSOC_3_CNT_MAX     = 'd10;
    localparam [SEQ_CNT_DW-1 : 0] ASSOC_4_CNT_MAX     = 'd10;
    localparam [SEQ_CNT_DW-1 : 0] ASSOC_5_CNT_MAX     = 'd10;
    localparam [SEQ_CNT_DW-1 : 0] ASSOC_TRANS_CNT_MAX = 'd15;
    localparam [SEQ_CNT_DW-1 : 0] ASSOC_6_CNT_MAX     = 'd10;
    localparam [SEQ_CNT_DW-1 : 0] ASSOC_7_CNT_MAX     = 'd7;
    localparam [SEQ_CNT_DW-1 : 0] ASSOC_8_CNT_MAX     = 'd4;
    localparam [SEQ_CNT_DW-1 : 0] ASSOC_9_CNT_MAX     = 'd12;
    localparam [SEQ_CNT_DW-1 : 0] ASSOC_10_CNT_MAX    = 'd12;


    localparam ASSOC_1_M       = 3'b010;
    localparam ASSOC_2_M       = 3'b010;
    localparam ASSOC_3_M       = 3'b010;
    localparam ASSOC_4_M       = 3'b010;
    localparam ASSOC_5_M       = 3'b010;
    localparam ASSOC_6_M       = 3'b010;    //保持en
    localparam ASSOC_7_M       = 3'b010;
    localparam ASSOC_8_M       = 3'b010;    //保持en
    localparam ASSOC_9_M       = 3'b001;
    localparam ASSOC_10_M      = 3'b001;
    
    localparam ASSOC_1_N       = 3'b011;
    localparam ASSOC_2_N       = 3'b011;
    localparam ASSOC_3_N       = 3'b010;    //在ASSOC_2 ASSOC_3读出，保持延迟时序
    localparam ASSOC_4_N       = 3'b010;
    localparam ASSOC_5_N       = 3'b011;
    localparam ASSOC_6_N       = 3'b010;
    localparam ASSOC_7_N       = 3'b010;
    localparam ASSOC_8_N       = 3'b010;
    localparam ASSOC_9_N       = 3'b010;
    localparam ASSOC_10_N      = 3'b010;

    localparam ASSOC_1_K       = 3'b011;
    localparam ASSOC_2_K       = 3'b010;
    localparam ASSOC_3_K       = 3'b010;
    localparam ASSOC_4_K       = 3'b010;
    localparam ASSOC_5_K       = 3'b010;
    localparam ASSOC_6_K       = 3'b010;
    localparam ASSOC_7_K       = 3'b010;
    localparam ASSOC_8_K       = 3'b000;
    localparam ASSOC_9_K       = 3'b010;
    localparam ASSOC_10_K      = 3'b001;

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
  reg [6:0] CBa_mode;
  reg [6:0] CBb_mode;
  reg [3:0] B_cache_mode;

  reg [TB_AW-1:0] A_TB_base_addr;
  reg [TB_AW-1:0] B_TB_base_addr;
  reg [TB_AW-1:0] M_TB_base_addr;
  reg [TB_AW-1:0] C_TB_base_addr;

  reg [TB_AW-1:0] A_TB_base_addr_set;
  reg [TB_AW-1:0] B_TB_base_addr_set;
  reg [TB_AW-1:0] M_TB_base_addr_set;
  reg [TB_AW-1:0] C_TB_base_addr_set;

  reg [2:0] B_cache_base_addr_set;

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
  reg [TB_DINA_SEL_DW-1 : 0]       TB_dina_sel_new;
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
    reg [CB_DINA_SEL_DW-1 : 0]    CB_dina_sel_new;
    reg [CB_DOUTA_SEL_DW-1 : 0]   CB_douta_sel_new;
    
    reg [1:0]                     CBa_shift_dir; 

    reg                           CB_ena_new;
    reg                           CB_wea_new;
    reg [CB_AW-1 : 0]             CB_addra_new;
    
    wire [CB_AW-1 : 0]           CB_addra_base_raw;
    reg [CB_AW-1 : 0]            CB_addra_base;

    //port B
    reg [CB_DINB_SEL_DW-1 : 0]    CB_dinb_sel_new;
    reg [1:0]                     CBb_shift_dir;

    reg                           CB_enb_new;
    reg                           CB_web_new;
    reg [CB_AW-1 : 0]             CB_addrb_new;

    wire [CB_AW-1 : 0]            CB_addrb_base_raw;
    reg [CB_AW-1 : 0]             CB_addrb_base;

/*
    l_k 
*/
    reg [ROW_LEN:0]     l_k_row;
    reg [ROW_LEN-1:0]   l_k_group;
    reg [ROW_LEN-1:0]   l_k_t_cov_l;
  
    wire [CB_AW-1 : 0]            l_k_base_addr_raw;
    reg [CB_AW-1 : 0]  l_k_base_addr_RD; 
    reg [CB_AW-1 : 0]  l_k_base_addr_WR; 
    wire l_k_0;
    assign l_k_0 = l_k[0];

/*
  ******* variables of FSM of STAGE(STAGE_IDLE PRD NEW UPD) *************
*/

  reg [2:0]      stage_next ;   
  (*mark_debug = "true" *)reg [2:0]      stage_cur ;   
  reg          stage_change_err;  

  assign stage_cur_out = stage_cur;   //输出当前阶段

/*
  **************** variables of Prediction(PRD) *********************
*/
  reg [3:0]   prd_next;
  reg [5:0]   new_next;
  reg [5:0]   upd_next;
  reg [5:0]   assoc_next;

  reg [3:0]   prd_cur;
  reg [5:0]   new_cur;
  reg [5:0]   upd_cur;
  reg [5:0]   assoc_cur;
  reg [SEQ_CNT_DW-1:0]   seq_cnt;      //时序计数器
  reg [SEQ_CNT_DW-1:0]   seq_cnt_max;  //计数器上限
  (*mark_debug = "true" *)reg [ROW_LEN-1:0]   v_group_cnt;    //组计数器（4行，2个地标为1组）
  reg [ROW_LEN-1 : 0] v_group_cnt_max;    //组数目
  (*mark_debug = "true" *)reg [ROW_LEN-1:0]   h_group_cnt;    //横向列计数器（UPD_7更新cov）
  reg [ROW_LEN-1 : 0] h_group_cnt_max;    //列组数目

  assign seq_cnt_out = seq_cnt;       //时序计数器输出
  assign prd_cur_out = prd_cur;
  assign new_cur_out = new_cur;
  assign upd_cur_out = upd_cur;
  assign assoc_cur_out = assoc_cur;

  

/*
  ****************** FSM of STAGE(STAGE_IDLE PRD NEW UPD) *******************
*/
  //(1)&(2) state switch

  always @(posedge clk) begin
    if(sys_rst) begin
      stage_cur <= STAGE_IDLE;
    end
    else 
      stage_cur <= stage_next;
  end

  always @(*) begin
    if(sys_rst) begin
      stage_next = STAGE_IDLE;
    end
    else begin
      stage_next = stage_cur;
      case(stage_cur)
        STAGE_IDLE: begin
                case(stage_val)
                  STAGE_IDLE: stage_next = STAGE_IDLE;
                  STAGE_PRD:  stage_next = STAGE_PRD;
                  STAGE_NEW:  stage_next = STAGE_NEW;
                  STAGE_UPD:  stage_next = STAGE_UPD;
                  STAGE_ASSOC:  stage_next = STAGE_ASSOC;
                  default: begin
                    stage_next = STAGE_IDLE;
                    stage_change_err <= 1'b1;
                  end  
                endcase
              end
        //STAGE_PRD  STAGE_NEW  STAGE_UPD
        STAGE_PRD:begin
                    // if(prd_cur == PRD_3 && seq_cnt == seq_cnt_max && v_group_cnt == v_group_cnt_max)
                    if(prd_cur == PRD_3_HALT && seq_cnt == seq_cnt_max)
                      stage_next = STAGE_IDLE;
                    else
                      stage_next = STAGE_PRD;
                  end
        STAGE_NEW:begin
                    if(new_cur == NEW_5 && seq_cnt == seq_cnt_max)
                      stage_next = STAGE_IDLE;
                    else
                      stage_next = STAGE_NEW;
                  end
        STAGE_UPD:begin
                    if(upd_cur == UPD_10 && seq_cnt == seq_cnt_max && v_group_cnt == v_group_cnt_max && h_group_cnt == h_group_cnt_max)
                      stage_next = STAGE_IDLE;
                    else
                      stage_next = STAGE_UPD;
                  end
        STAGE_ASSOC:begin
                    //Finished ALL data associtaion
                    if(assoc_cur == ASSOC_10 && seq_cnt == seq_cnt_max && l_k == landmark_num) begin
                      case (assoc_status)
                        ASSOC_NEW: stage_next = STAGE_NEW;
                        ASSOC_UPD: stage_next = STAGE_UPD;
                        ASSOC_FAIL: stage_next = STAGE_IDLE;
                        default: stage_next = STAGE_ASSOC;
                      endcase
                    end
                    else
                      stage_next = STAGE_ASSOC;
                  end
        default: stage_next = STAGE_IDLE;
      endcase
    end
  end

//(3) output: stage handshake
  // always @(posedge clk) begin
  //   if(sys_rst)
  //     stage_rdy <= READY;
  //   else if(stage_cur != STAGE_IDLE) begin
  //     stage_rdy <= BUSY;
  //   end
  //   else
  //     stage_rdy <= READY; 
  // end

  always @(posedge clk) begin
    if(sys_rst)
      stage_rdy <= 1'b0;
    else if(stage_rdy == 1'b0) begin
      if(stage_next == STAGE_IDLE) begin
        case(stage_cur)
          STAGE_PRD, STAGE_NEW, STAGE_UPD: begin
            stage_rdy <= 1'b1;
          end
          default: begin
            stage_rdy <= 1'b0;
          end
        endcase
      end
      else
        stage_rdy <= 1'b0;
    end
    else begin //stage_rdy == 1'b1
      if(stage_cur == STAGE_IDLE && stage_next != STAGE_IDLE) begin
        stage_rdy <= 1'b0;
      end
      else
        stage_rdy <= 1'b1;
    end
  end

//(4)output: calculate the landmark_num
  always @(posedge clk) begin
    if(sys_rst)
      landmark_num <= 0;
    else begin
      //FOR SIMULATIOM
        // landmark_num <= 10'b111;
      //FOR ITERATION
        // if(stage_cur == STAGE_NEW && new_cur == NEW_5 && seq_cnt == seq_cnt_max)
        if(stage_cur == STAGE_NEW && stage_next == STAGE_IDLE)
          landmark_num <= landmark_num + 1'b1;
        else 
          landmark_num <= landmark_num;
    end
  end

//(5)designate l_k
  always @(posedge clk) begin
    if(sys_rst)
      l_k <= 0;
    else begin
      case (stage_cur)
        STAGE_IDLE: begin
                case(stage_val)
                  STAGE_IDLE:       l_k <= 0;
                  STAGE_PRD:  l_k <= 0;
                  STAGE_NEW:  l_k <= landmark_num + 1'b1;
                  STAGE_UPD:  l_k <= 10'd2;   //Simulation
                  STAGE_ASSOC:  l_k <= 10'd1; //From landmark no.1
                  default: l_k <= 0; 
                endcase
              end
        STAGE_PRD, STAGE_NEW, STAGE_UPD: begin
          l_k <= l_k;
        end
        STAGE_ASSOC: begin
            if(assoc_cur == ASSOC_10 && seq_cnt == seq_cnt_max) begin
              if(l_k == landmark_num) begin
                case(assoc_status)
                  ASSOC_NEW: l_k <= landmark_num + 1'b1;
                  ASSOC_UPD: l_k <= assoc_l_k;
                  ASSOC_FAIL: l_k <= 0;
                  default: l_k <= 0;
                endcase
              end 
              else begin
                l_k <= l_k + 1'b1;
              end
            end
        end
        default: begin
          l_k <= 0;
        end
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
      if(sys_rst) begin
        prd_cur <= PRD_IDLE;
      end
      else 
        prd_cur <= prd_next;
    end

    always @(*) begin
      if(sys_rst) begin
        prd_next = PRD_IDLE;
      end
      else  begin
        prd_next = prd_cur;
        case(prd_cur)
          PRD_IDLE: begin
            if((stage_val) == STAGE_PRD) begin
              prd_next = PRD_NL_SEND;
            end
            else
              prd_next = PRD_IDLE;
          end
          PRD_NL_SEND: begin
            if(seq_cnt == seq_cnt_max) begin
              prd_next = PRD_NL_WAIT;
            end
            else
              prd_next = PRD_NL_SEND;
          end
          PRD_NL_WAIT: begin
            if(done_predict == 1'b1) begin
              prd_next = PRD_NL_RCV;
            end
            else
              prd_next = PRD_NL_WAIT;
          end
          PRD_NL_RCV: begin
            if(seq_cnt == seq_cnt_max) begin
              prd_next = PRD_1;
            end
            else
              prd_next = PRD_NL_RCV;
          end
          PRD_1: begin
            if(seq_cnt == seq_cnt_max) begin
              prd_next = PRD_2;
            end
            else begin
              prd_next = PRD_1;
            end
          end
          PRD_2: begin
            if(seq_cnt == seq_cnt_max) begin
              if(landmark_num == 0)
                prd_next = PRD_3_HALT;
              else
                prd_next = PRD_3;
            end
            else begin
              prd_next = PRD_2;
            end
          end
          PRD_3: begin
            if(seq_cnt == seq_cnt_max && v_group_cnt == v_group_cnt_max) begin
              prd_next = PRD_3_HALT;
            end
            else begin
              prd_next = PRD_3;
            end
          end
          PRD_3_HALT: begin
            if(seq_cnt == seq_cnt_max) begin
              prd_next = PRD_IDLE;
            end
            else begin
              prd_next = PRD_3_HALT;
            end
          end
          default: begin
            prd_next = PRD_IDLE;
          end
        endcase
      end
    end

    //output: init_predict, rcv_OK_predict
      always @(posedge clk) begin
        if(sys_rst) begin
          init_predict <= 0;
        end
        else if(prd_next == PRD_NL_WAIT && prd_cur == PRD_NL_SEND)
          init_predict <= 1'b1;
        else
          init_predict <= 0;
      end
  /*
    ************************ NEW state transfer **********************
  */ 
    always @(posedge clk) begin
      if(sys_rst) begin
        new_cur <= NEW_IDLE;
      end
      else 
        new_cur <= new_next;
    end
    
    always @(*) begin
      if(sys_rst) begin
        new_next = NEW_IDLE;
      end
      else  begin
        new_next = new_cur;
        case(new_cur)
          NEW_IDLE: begin
            if(((stage_val) == STAGE_NEW)
            || (assoc_status == ASSOC_NEW && assoc_cur == ASSOC_10 && seq_cnt == seq_cnt_max && l_k == landmark_num)) begin
              new_next = NEW_NL_SEND;
            end
            else
              new_next = NEW_IDLE;
          end
          NEW_NL_SEND: begin
            if(seq_cnt == seq_cnt_max) begin
              new_next = NEW_NL_WAIT;
            end
            else
              new_next = NEW_NL_SEND;
          end
          NEW_NL_WAIT: begin
            if(done_newlm == 1'b1) begin
              new_next = NEW_NL_RCV;
            end
            else
              new_next = NEW_NL_WAIT;
          end
          NEW_NL_RCV: begin
            if(seq_cnt == seq_cnt_max) begin
              new_next = NEW_1;
            end
            else
              new_next = NEW_NL_RCV;
          end
          NEW_1: begin
            if(seq_cnt == seq_cnt_max) begin
              if(landmark_num == 0)
                new_next = NEW_3;
              else
                new_next = NEW_2;
            end
            else begin
              new_next = NEW_1;
            end
          end
          NEW_2: begin
            if(seq_cnt == seq_cnt_max && v_group_cnt == v_group_cnt_max) begin
              new_next = NEW_3;
            end
            else begin
              new_next = NEW_2;
            end
          end
          NEW_3: begin
            if(seq_cnt == seq_cnt_max) begin
              new_next = NEW_4;
            end
            else begin
              new_next = NEW_3;
            end
          end
          NEW_4: begin
            if(seq_cnt == seq_cnt_max) begin
              new_next = NEW_5;
            end
            else begin
              new_next = NEW_4;
            end
          end
          NEW_5: begin
            if(seq_cnt == seq_cnt_max) begin
              new_next = NEW_IDLE;
            end
            else begin
              new_next = NEW_5;
            end
          end
          default: begin
            new_next = NEW_IDLE;
          end
        endcase
      end
    end

    //output: init_predict, rcv_OK_predict
      always @(posedge clk) begin
        if(sys_rst) begin
          init_newlm <= 0;
        end
        else if(new_next == NEW_NL_WAIT && new_cur == NEW_NL_SEND)
          init_newlm <= 1'b1;
        else
          init_newlm <= 0;
      end

  /*
    ************************ UPD state transfer **********************
  */
    always @(posedge clk) begin
      if(sys_rst) begin
        upd_cur <= UPD_IDLE;
      end
      else 
        upd_cur <= upd_next;
    end

    always @(*) begin
      if(sys_rst) begin
        upd_next = UPD_IDLE;
      end
      else  begin
        upd_next = upd_cur;
        case(upd_cur)
          UPD_IDLE: begin
            if(((stage_val) == STAGE_UPD)
            || (assoc_cur == ASSOC_10 && seq_cnt == seq_cnt_max && l_k == landmark_num && assoc_status == ASSOC_UPD)) begin
              upd_next = UPD_NL_SEND;
            end
            else
              upd_next = UPD_IDLE;
          end
          UPD_NL_SEND: begin
            if(seq_cnt == seq_cnt_max) begin
              upd_next = UPD_NL_WAIT;
            end
            else
              upd_next = UPD_NL_SEND;
          end
          UPD_NL_WAIT: begin
            if(done_update == 1'b1) begin
              upd_next = UPD_NL_RCV;
            end
            else
              upd_next = UPD_NL_WAIT;
          end
          UPD_NL_RCV: begin
            if(seq_cnt == seq_cnt_max) begin
              upd_next = UPD_1;
            end
            else
              upd_next = UPD_NL_RCV;
          end
          UPD_1: begin
            if(seq_cnt == seq_cnt_max && v_group_cnt == l_k_t_cov_l) begin
              upd_next = UPD_2;
            end
            else begin
              upd_next = UPD_1;
            end
          end
          UPD_2: begin
            if(seq_cnt == seq_cnt_max) begin
              upd_next = UPD_4;
            end
            else begin
              upd_next = UPD_2;
            end
          end
          UPD_3: begin
            if(seq_cnt == seq_cnt_max) begin
              if(v_group_cnt <= l_k_t_cov_l)
                upd_next = UPD_4;
              else
                upd_next = UPD_5;
            end
            else begin
              upd_next = UPD_3;
            end
          end
          UPD_4: begin
            if(seq_cnt == seq_cnt_max) begin
              if(v_group_cnt == v_group_cnt_max)
                upd_next = UPD_6;
              else
                upd_next = UPD_3;
            end
            else begin
              upd_next = UPD_4;
            end
          end
          UPD_5: begin
            if(seq_cnt == seq_cnt_max) begin
              if(v_group_cnt == v_group_cnt_max) begin
                if(l_k_group == v_group_cnt_max)
                  upd_next = UPD_HALT_56;   //只有最后一组可能产生冲突
                else
                  upd_next = UPD_6;
              end
              else
                upd_next = UPD_3;
            end
            else begin
              upd_next = UPD_5;
            end
          end
          UPD_HALT_56: begin
            if(seq_cnt == seq_cnt_max) begin
              upd_next = UPD_6;
            end
            else begin
              upd_next = UPD_HALT_56;
            end
          end
          UPD_6: begin
            if(seq_cnt == seq_cnt_max) begin
              upd_next = UPD_7;
            end
            else begin
              upd_next = UPD_6;
            end
          end
          UPD_7: begin
            if(seq_cnt == seq_cnt_max) begin
              upd_next = UPD_INV;    
              // upd_next = UPD_HALT_78;  //220722 加入halt //220726 取消
            end
            else begin
              upd_next = UPD_7;
            end
          end
          UPD_INV: begin
            if(done_inv == 1'b1) begin
              upd_next = UPD_8;
            end
            else begin
              upd_next = UPD_INV;
            end
          end
          UPD_8: begin
            if(seq_cnt == seq_cnt_max) begin
              upd_next = UPD_9;
            end
            else begin
              upd_next = UPD_8;
            end
          end
          UPD_9: begin
            if(seq_cnt == seq_cnt_max && v_group_cnt == v_group_cnt_max) begin
              // upd_next = UPD_10;  //220722 加入halt
              upd_next = UPD_STATE;
            end
            else begin
              upd_next = UPD_9;
            end
          end
          UPD_STATE: begin
            if(seq_cnt == seq_cnt_max && v_group_cnt == v_group_cnt_max) begin
              upd_next = UPD_10;
            end
            else begin
              upd_next = UPD_STATE;
            end
          end
          UPD_10: begin
            if(seq_cnt == seq_cnt_max && v_group_cnt == v_group_cnt_max && h_group_cnt == h_group_cnt_max) begin
              upd_next = UPD_IDLE;
            end
            else begin
              upd_next = UPD_10;
            end
          end
          default: begin
            upd_next = UPD_IDLE;
          end
        endcase
      end
    end

    //output: init_update
      always @(posedge clk) begin
        if(sys_rst) begin
          init_update <= 0;
        end
        else if((upd_next == UPD_NL_WAIT && upd_cur == UPD_NL_SEND)          //update
                ||(assoc_next == ASSOC_NL_WAIT && assoc_cur == ASSOC_NL_SEND)) //assoc
          init_update <= 1'b1;
        else
          init_update <= 0;
      end

/*
  ************************ ASSOC state transfer **********************
*/
    always @(posedge clk) begin
      if(sys_rst) begin
        assoc_cur <= ASSOC_IDLE;
      end
      else 
        assoc_cur <= assoc_next;
    end
    
    always @(*) begin
      if(sys_rst) begin
        assoc_next = ASSOC_IDLE;
      end
      else  begin
        assoc_next = assoc_cur;
        case(assoc_cur)
          ASSOC_IDLE: begin
            if((stage_val) == STAGE_ASSOC) begin
              assoc_next = ASSOC_NL_SEND;
            end
            else
              assoc_next = ASSOC_IDLE;
          end
          ASSOC_NL_SEND: begin
            if(seq_cnt == seq_cnt_max) begin       //复用update非线性
              assoc_next = ASSOC_NL_WAIT;
            end
            else
              assoc_next = ASSOC_NL_SEND;
          end
          ASSOC_NL_WAIT: begin
            if(done_update == 1'b1) begin       //复用update非线性
              assoc_next = ASSOC_NL_RCV;
            end
            else
              assoc_next = ASSOC_NL_WAIT;
          end
          ASSOC_NL_RCV: begin
            if(seq_cnt == seq_cnt_max) begin
              assoc_next = ASSOC_1;
            end
            else
              assoc_next = ASSOC_NL_RCV;
          end
          ASSOC_1: begin
            if(seq_cnt == seq_cnt_max) begin
              assoc_next = ASSOC_2;
            end
            else begin
              assoc_next = ASSOC_1;
            end
          end
          ASSOC_2: begin
            if(seq_cnt == seq_cnt_max) begin
              assoc_next = ASSOC_3;
            end
            else begin
              assoc_next = ASSOC_2;
            end
          end
          ASSOC_3: begin
            if(seq_cnt == seq_cnt_max) begin
                assoc_next = ASSOC_4;
            end
            else begin
              assoc_next = ASSOC_3;
            end
          end
          ASSOC_4: begin
            if(seq_cnt == seq_cnt_max) 
                assoc_next = ASSOC_5;
            else
              assoc_next = ASSOC_4;
          end
          ASSOC_5: begin
            if(seq_cnt == seq_cnt_max) begin
                assoc_next = ASSOC_TRANS;
            end
            else begin
              assoc_next = ASSOC_5;
            end
          end
          ASSOC_TRANS: begin
            if(seq_cnt == seq_cnt_max) begin
                assoc_next = ASSOC_6;
            end
            else begin
              assoc_next = ASSOC_TRANS;
            end
          end
          ASSOC_6: begin
            if(seq_cnt == seq_cnt_max) begin
              assoc_next = ASSOC_7;
            end
            else begin
              assoc_next = ASSOC_6;
            end
          end
          ASSOC_7: begin
            if(seq_cnt == seq_cnt_max) begin
              assoc_next = ASSOC_INV;    
            end
            else begin
              assoc_next = ASSOC_7;
            end
          end
          ASSOC_INV: begin
            if(done_inv == 1'b1) begin
              assoc_next = ASSOC_8;
            end
            else begin
              assoc_next = ASSOC_INV;
            end
          end
          ASSOC_8: begin
            if(seq_cnt == seq_cnt_max) begin
              assoc_next = ASSOC_9;
            end
            else begin
              assoc_next = ASSOC_8;
            end
          end
          ASSOC_9: begin
            if(seq_cnt == seq_cnt_max) begin
              assoc_next = ASSOC_10;
            end
            else begin
              assoc_next = ASSOC_9;
            end
          end
          ASSOC_10: begin
            if(seq_cnt == seq_cnt_max) begin
              if(l_k == landmark_num) begin
                assoc_next = ASSOC_IDLE;    //Finish data assocition
              end
              else begin
                assoc_next = ASSOC_NL_SEND;       //Start another association
              end
            end
            else begin
              assoc_next = ASSOC_10;
            end
          end
          default: begin
            assoc_next = ASSOC_IDLE;
          end
        endcase
      end
    end

  //output: init_inv
    always @(posedge clk) begin
      if(sys_rst) begin
        init_inv <= 0;
      end
      else if((upd_cur == UPD_7     && seq_cnt == seq_cnt_max)
            ||(assoc_cur == ASSOC_7 && seq_cnt == seq_cnt_max)) begin
              init_inv <= 1'b1;
            end
      else
        init_inv <= 0;
    end

  /*
    (4) (old): nonlinear_val, nonlinear_rdy
  */
    // always @(posedge clk) begin
    //   if(sys_rst)
    //     nonlinear_m_rdy <= 0;
    //   else if(prd_cur == PRD_IDLE || new_cur == NEW_IDLE || upd_cur == UPD_IDLE) begin
    //     nonlinear_m_rdy <= 1'b1;
    //   end
    //   else
    //     nonlinear_m_rdy <= 0;  
    // end 

    // always @(posedge clk) begin
    //   if(sys_rst)
    //     nonlinear_m_val <= 0;
    //   else if(prd_cur == PRD_NONLINEAR || new_cur == NEW_NONLINEAR || upd_cur == UPD_NONLINEAR) begin
    //     nonlinear_m_val <= 1'b1;
    //   end
    //   else
    //     nonlinear_m_val <= 0;  
    // end 

  // reg [ROW_LEN-1 : 0]  l_k = 'd3;
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
          STAGE_PRD: l_k_group <= (l_k + 1'b1) >> 1;
          STAGE_NEW: l_k_group <= (l_k + 1'b1) >> 1;
          STAGE_UPD: l_k_group <= (l_k + 1'b1) >> 1;
          STAGE_ASSOC: l_k_group <= (l_k + 1'b1) >> 1;
          default: l_k_group <= 0;
        endcase
      end
    end

    //Transfer from CB to TB
    always @(posedge clk) begin
      if(sys_rst) begin
        l_k_t_cov_l <= 0;
      end
      else begin
        if(l_k == 1'b1)
          l_k_t_cov_l <= 1'b0;      //保证H_T能读完
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
          PRD_NL_SEND: seq_cnt_max = PRD_NL_SEND_CNT_MAX;
          PRD_NL_RCV:  seq_cnt_max = PRD_NL_RCV_CNT_MAX;
          PRD_1: seq_cnt_max = PRD_1_CNT_MAX;
          PRD_2: seq_cnt_max = PRD_2_CNT_MAX;
          PRD_3: seq_cnt_max = PRD_3_CNT_MAX;
          PRD_3_HALT: seq_cnt_max = PRD_3_HALT_CNT_MAX;
          default: seq_cnt_max = 0;
        endcase
      end
      STAGE_NEW: begin
        case(new_cur)
          NEW_NL_SEND: seq_cnt_max = NEW_NL_SEND_CNT_MAX;
          NEW_NL_RCV:  seq_cnt_max = NEW_NL_RCV_CNT_MAX;
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
          UPD_NL_SEND: seq_cnt_max = UPD_NL_SEND_CNT_MAX;
          UPD_NL_RCV:  seq_cnt_max = UPD_NL_RCV_CNT_MAX;
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
          UPD_HALT_56: seq_cnt_max = UPD_HALT_56_CNT_MAX;
          // UPD_HALT_78: seq_cnt_max = UPD_HALT_78_CNT_MAX;
          UPD_STATE: seq_cnt_max = UPD_STATE_CNT_MAX;
          default: seq_cnt_max = 0;
        endcase
      end
      STAGE_ASSOC: begin
        case(assoc_cur)
          ASSOC_NL_SEND: seq_cnt_max = ASSOC_NL_SEND_CNT_MAX;
          ASSOC_NL_RCV:  seq_cnt_max = ASSOC_NL_RCV_CNT_MAX;
          ASSOC_1: seq_cnt_max = ASSOC_1_CNT_MAX;
          ASSOC_2: seq_cnt_max = ASSOC_2_CNT_MAX;
          ASSOC_3: seq_cnt_max = ASSOC_3_CNT_MAX;
          ASSOC_4: seq_cnt_max = ASSOC_4_CNT_MAX;
          ASSOC_5: seq_cnt_max = ASSOC_5_CNT_MAX;
          ASSOC_TRANS: seq_cnt_max = ASSOC_TRANS_CNT_MAX;
          ASSOC_6: seq_cnt_max = ASSOC_6_CNT_MAX;
          ASSOC_7: seq_cnt_max = ASSOC_7_CNT_MAX;
          ASSOC_8: seq_cnt_max = ASSOC_8_CNT_MAX;
          ASSOC_9: seq_cnt_max = ASSOC_9_CNT_MAX;
          ASSOC_10: seq_cnt_max = ASSOC_10_CNT_MAX;
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
      case(stage_cur)
        STAGE_PRD: v_group_cnt_max <= (landmark_num+1'b1) >> 1;
        STAGE_NEW: v_group_cnt_max <= (landmark_num+1'b1) >> 1;
        STAGE_UPD: v_group_cnt_max <= (landmark_num+1'b1) >> 1;
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
            UPD_9,UPD_STATE: begin
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
  ************* (using) sequential RSA work-mode Config *************
*/
  always @(posedge clk) begin
    if(sys_rst) begin
      PE_m <= 0;
      PE_n <= 0;
      PE_k <= 0;

      CAL_mode <= N_W;

      A_in_mode <= A_TBa;   
      B_in_mode <= B_TBb;
      M_in_mode <= M_TBa;
      C_out_mode <= C_CBb;
      M_adder_mode_set <= NONE;

      TBa_mode <= TB_IDLE;
      TBb_mode <= TB_IDLE;
      CBa_mode <= CB_IDLE;
      CBb_mode <= CB_IDLE;

      A_TB_base_addr_set <= 0;
      B_TB_base_addr_set <= 0;
      M_TB_base_addr_set <= 0;
      C_TB_base_addr_set <= 0;
    end
    else begin
      case(stage_cur)
        STAGE_PRD: begin
                    case (prd_next)
                    /*STATE VECTOR move to PLB*/
                      // PRD_NL_SEND:
                      //       begin
                      //         CBa_mode <= {CBa_NL,CB_NL_xyxita};    
                      //       end
                      PRD_NL_RCV:
                            begin
                              PE_n <= 3'b011;
                              B_cache_mode <= Bca_WR_NL_PRD;
                              B_cache_base_addr_set <= 0;
                              // TBa_mode <= {TBa_NL_PRD,DIR_POS};
                              // CBb_mode <= {CBb_xyxita,CB_NL_xyxita};    

                              PE_m <= 0;
                              PE_k <= 0;

                              CAL_mode <= N_W;

                              A_in_mode <= A_NONE;   
                              B_in_mode <= B_NONE;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_NONE;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= TB_IDLE;
                              TBb_mode <= TB_IDLE;
                              CBa_mode <= CB_IDLE;
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= 0;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= 0;
                            end
                      PRD_1: begin
                              PE_m <= PRD_1_M;
                              PE_n <= PRD_1_N;
                              PE_k <= PRD_1_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_cache;   
                              B_in_mode <= B_CBa;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_TBb;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= TB_IDLE;
                              TBb_mode <= {TBb_C,DIR_POS};
                              CBa_mode <= {CBa_B,CB_cov_vv};
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= 0;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= F_cov;

                              B_cache_mode <= Bca_RD_A;
                              B_cache_base_addr_set <= 0;
                            end
                      PRD_2: begin
                              PE_m <= PRD_2_M;
                              PE_n <= PRD_2_N;
                              PE_k <= PRD_2_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_TBa;   
                              B_in_mode <= B_cache;
                              M_in_mode <= M_TBa;
                              C_out_mode <= C_CBb;
                              M_adder_mode_set <= ADD;

                              TBa_mode <= {TBa_AM,DIR_POS};
                              TBb_mode <= TB_IDLE;
                              CBa_mode <= CB_IDLE;
                              CBb_mode <= {CBb_C,CB_cov_vv};

                              A_TB_base_addr_set <= F_cov;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= M_t;
                              C_TB_base_addr_set <= 0;

                              B_cache_mode <= Bca_RD_B;
                              B_cache_base_addr_set <= 0;
                            end
                      PRD_3: begin
                              PE_m <= PRD_3_M;
                              PE_n <= PRD_3_N;
                              PE_k <= PRD_3_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_CBa;   
                              B_in_mode <= B_cache;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_CBb;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= TB_IDLE;
                              TBb_mode <= TB_IDLE;
                              CBa_mode <= {CBa_A,CB_cov_mv};
                              CBb_mode <= {CBb_C,CB_cov_mv};

                              A_TB_base_addr_set <= 0;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= 0;

                              B_cache_mode <= Bca_RD_B;
                              B_cache_base_addr_set <= 0;
                            end
                      PRD_3_HALT: begin
                              PE_m <= PRD_3_M;
                              PE_n <= PRD_3_N;
                              PE_k <= PRD_3_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_NONE;   
                              B_in_mode <= B_NONE;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_CBb;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= TB_IDLE;
                              TBb_mode <= TB_IDLE;
                              CBa_mode <= CB_IDLE;
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= 0;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= 0;

                              B_cache_mode <= Bca_IDLE;
                              B_cache_base_addr_set <= 0;
                            end
                      default: begin
                                PE_m <= 0;
                                PE_n <= 0;
                                PE_k <= 0;

                                CAL_mode <= N_W;

                                A_in_mode <= A_NONE;   
                                B_in_mode <= B_NONE;
                                M_in_mode <= M_NONE;
                                C_out_mode <= C_CBb;
                                M_adder_mode_set <= NONE;

                                TBa_mode <= TB_IDLE;
                                TBb_mode <= TB_IDLE;
                                CBa_mode <= CB_IDLE;
                                CBb_mode <= CB_IDLE;

                                A_TB_base_addr_set <= 0;
                                B_TB_base_addr_set <= 0;
                                M_TB_base_addr_set <= 0;
                                C_TB_base_addr_set <= 0;

                              B_cache_mode <= Bca_IDLE;
                              B_cache_base_addr_set <= 0;
                              end
                    endcase
                  end
        STAGE_NEW: begin
                    case(new_next)
                    /*STATE VECTOR move to PLB*/
                      // NEW_NL_SEND:
                      //       begin
                      //         CBa_mode <= {CBa_NL,CB_NL_xyxita};    
                      //       end
                      NEW_NL_RCV:
                            begin
                              // TBa_mode <= {TBa_NL_NEW,DIR_POS};
                              // CBb_mode <= {CBb_lxly,CB_NL_lxly};
                              PE_n <= 3'b101;
                              B_cache_mode <= Bca_WR_NL_NEW;
                              B_cache_base_addr_set <= 0;    

                              PE_m <= 0;
                              PE_k <= 0;

                              CAL_mode <= N_W;

                              A_in_mode <= A_NONE;   
                              B_in_mode <= B_NONE;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_NONE;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= TB_IDLE;
                              TBb_mode <= TB_IDLE;
                              CBa_mode <= CB_IDLE;
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= 0;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= 0;
                            end
                      NEW_1: begin
                            /*
                              G_xi * t_cov <= cov_lm
                              X=2 Y=2 N=3
                              Ain: TB-A
                              bin: CB-A
                              Cout: CB-B
                            */
                              PE_m <= NEW_1_M;
                              PE_n <= NEW_1_N;
                              PE_k <= NEW_1_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_cache;   
                              B_in_mode <= B_CBa;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_CBb;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= TB_IDLE;
                              TBb_mode <= TB_IDLE;
                              CBa_mode <= {CBa_B,CB_cov_vv};
                              CBb_mode <= {CBb_C,CB_cov_lv};

                              A_TB_base_addr_set <= 0;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= 0;
                              
                              B_cache_mode <= Bca_RD_A;
                              B_cache_base_addr_set <= 0;  
                            end
                      NEW_2: begin
                            /*
                              G_xi * cov_mv <= cov_lv
                              X=2 Y=4 N=3
                              Ain: TB-A
                              Bin: CB-A
                              Min: 0
                              Cout: CB-B
                            */
                              PE_m <= NEW_2_M;
                              PE_n <= NEW_2_N;
                              PE_k <= NEW_2_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_cache;   
                              B_in_mode <= B_CBa;
                              M_in_mode <= M_TBa;
                              C_out_mode <= C_CBb;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= TB_IDLE;
                              TBb_mode <= TB_IDLE;
                              CBa_mode <= {CBa_B,CB_cov_mv};
                              CBb_mode <= {CBb_C,CB_cov_lm};

                              A_TB_base_addr_set <= 0;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= 0;

                              B_cache_mode <= Bca_RD_A;
                              B_cache_base_addr_set <= 0; 
                            end
                      NEW_3: begin
                              /*
                                cov_lv * G_xi_T <= lv_G_xi
                                X=2 Y=2 N=3
                                Ain: CB-A
                                Bin: TB-B
                                Min: NONE  
                                Cout: TB-B
                              */
                                PE_m <= NEW_3_M;
                                PE_n <= NEW_3_N;
                                PE_k <= NEW_3_K;

                                CAL_mode <= N_W;

                                A_in_mode <= A_CBa;   
                                B_in_mode <= B_cache;
                                M_in_mode <= M_NONE;
                                C_out_mode <= C_CBb;
                                M_adder_mode_set <= NONE;

                                TBa_mode <= TB_IDLE;
                                TBb_mode <= TB_IDLE;
                                CBa_mode <= {CBa_A,CB_cov_lv};
                                CBb_mode <= {CBb_C,CB_cov_ll};

                                A_TB_base_addr_set <= 0;
                                B_TB_base_addr_set <= 0;
                                M_TB_base_addr_set <= 0;
                                C_TB_base_addr_set <= 0;

                                B_cache_mode <= Bca_RD_B;
                                B_cache_base_addr_set <= 0; 
                              end
                      NEW_4: begin
                            /*
                              G_z * Q <= G_z_Q
                              X=2 Y=2 N=2
                              Ain: TB-A
                              Bin: TB-B
                              Min: NONE  
                              Cout: TB-B
                            */
                              PE_m <= NEW_4_M;
                              PE_n <= NEW_4_N;
                              PE_k <= NEW_4_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_cache;   
                              B_in_mode <= B_TBb;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_TBb;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= {TBa_A,DIR_POS};
                              TBb_mode <= {TBb_BC,DIR_POS};
                              CBa_mode <= CB_IDLE; 
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= 0;
                              B_TB_base_addr_set <= Q;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= G_z_Q;

                              B_cache_mode <= Bca_RD_A;
                              B_cache_base_addr_set <= 3'b011; 
                            end
                      NEW_5: begin
                            /*
                              G_z_Q * G_z_T + lv_G_xi <= cov_ll
                              X=2 Y=2 N=2
                              Ain: TB-A
                              Bin: TB-B
                              Min: TB-A  
                              Cout: CB-B
                            */
                              PE_m <= NEW_5_M;
                              PE_n <= NEW_5_N;
                              PE_k <= NEW_5_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_TBa;   
                              B_in_mode <= B_cache;
                              M_in_mode <= M_CBa;
                              C_out_mode <= C_CBb;
                              M_adder_mode_set <= ADD;

                              TBa_mode <= {TBa_AM,DIR_POS};
                              TBb_mode <= {TBb_IDLE,DIR_POS};
                              CBa_mode <= {CBa_M,CB_cov_ll};
                              CBb_mode <= {CBb_C,CB_cov_ll};

                              A_TB_base_addr_set <= G_z_Q;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= lv_G_xi;
                              C_TB_base_addr_set <= 0;

                              B_cache_mode <= Bca_RD_B;
                              B_cache_base_addr_set <= 3'b011; 
                            end
                      default: begin
                              PE_m <= 0;
                              PE_n <= 0;
                              PE_k <= 0;

                              CAL_mode <= N_W;

                              A_in_mode <= A_NONE;   
                              B_in_mode <= B_NONE;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_CBb;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= TB_IDLE;
                              TBb_mode <= TB_IDLE;
                              CBa_mode <= CB_IDLE;
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= 0;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= 0;

                              B_cache_mode <= Bca_IDLE;
                              B_cache_base_addr_set <= 0;
                            end
                    endcase
                  end
        STAGE_UPD: begin
                    case(upd_next)
                    /*STATE VECTOR move to PLB*/
                      // UPD_NL_SEND:
                      //       begin
                      //         CBa_mode <= {CBa_NL,CB_NL_xyxita};    
                      //       end
                      UPD_NL_RCV:
                            begin
                              TBa_mode <= {TBa_NL_UPD,DIR_POS}; //Write Vt
                              PE_n <= 3'b111;
                              B_cache_mode <= Bca_WR_NL_UPD;   //UPD中vt写入Bcache
                              B_cache_base_addr_set <= 0; 

                              PE_m <= 0;
                              PE_k <= 0;

                              CAL_mode <= N_W;

                              A_in_mode <= A_NONE;   
                              B_in_mode <= B_NONE;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_NONE;
                              M_adder_mode_set <= NONE;

                              TBb_mode <= TB_IDLE;
                              CBa_mode <= CB_IDLE;
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= 0;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= 0;
                            end
                      UPD_1: begin
                            /*
                              transfer
                              cov_l:CB-A -> TB-A
                              X=0 Y=2 N=5
                              Ain: 0
                              bin: TB-B
                              Cout: 0
                            */
                              PE_m <= UPD_1_M;
                              PE_n <= UPD_1_N;
                              PE_k <= UPD_1_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_NONE;   
                              B_in_mode <= B_NONE;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_NONE;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= {TBa_CBa,DIR_POS};     //TB_dina直接接收即可
                              TBb_mode <= TB_IDLE;
                              CBa_mode <= {CBa_TBa, CB_cov_lm};  //在CB_douta_map处理数据
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= t_cov_l;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= 0;

                              B_cache_mode <= Bca_IDLE;
                              B_cache_base_addr_set <= 0;
                            end
                      UPD_2: begin
                            /*
                              cov_vv * H_T <= cov_HT
                              X=3 Y=2 N=3
                              Ain: CB-A
                              Bin: B-cache
                              Min: 0
                              Cout: TB-B
                            */
                              
                              PE_m <= UPD_2_M;
                              PE_n <= UPD_2_N;
                              PE_k <= UPD_2_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_CBa;   
                              B_in_mode <= B_cache;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_TBb;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= TB_IDLE;
                              TBb_mode <= {TBb_C,DIR_POS};
                              CBa_mode <= {CBa_A,CB_cov_vv};
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= t_cov_l;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= cov_HT;

                              B_cache_mode <= Bca_RD_B;
                              B_cache_base_addr_set <= 0;
                            end
                      UPD_3: begin
                            /*
                              cov_mv * H_T <= cov_HT
                              X=4 Y=2 N=3
                              Ain: CB-A
                              Bin: B-cache
                              Min: 0
                              Cout: TB-B
                            */
                              
                              PE_m <= UPD_3_M;
                              PE_n <= UPD_3_N;
                              PE_k <= UPD_3_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_CBa;   
                              B_in_mode <= B_cache;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_TBb;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= {TBa_IDLE,DIR_POS};
                              TBb_mode <= {TBb_C,DIR_POS};
                              CBa_mode <= {CBa_A,CB_cov_mv};
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= t_cov_l;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= cov_HT;

                              B_cache_mode <= Bca_RD_B;
                              B_cache_base_addr_set <= 0;
                            end
                      UPD_4: begin
                            /*
                              t_cov_l * H_T <= cov_HT
                              X=4 Y=2 N=2
                              Ain: TB-A
                              Bin: B-cache
                              Min: 0
                              Cout: 0
                            */
                              PE_m <= UPD_4_M;
                              PE_n <= UPD_4_N;
                              PE_k <= UPD_4_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_TBa;   
                              B_in_mode <= B_cache;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_TBb;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= {TBa_A,DIR_POS};
                              TBb_mode <= {TBb_IDLE,DIR_POS};
                              CBa_mode <= {CBa_A,CB_cov_IDLE}; //保证dir不改变
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= t_cov_l;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= cov_HT;  //保持一致

                              B_cache_mode <= Bca_RD_B;
                              B_cache_base_addr_set <= 3'b011;
                            end
                      UPD_5: begin
                            /*
                              cov_ml * H_T <= cov_HT
                              X=4 Y=2 N=2
                              Ain: CB-A
                              Bin: B-cache
                              Min: 0
                              Cout: 0
                            */
                              PE_m <= UPD_5_M;
                              PE_n <= UPD_5_N;
                              PE_k <= UPD_5_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_CBa;   
                              B_in_mode <= B_cache;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_TBb;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= TB_IDLE;
                              TBb_mode <= {TBb_IDLE,DIR_POS}; //for TB_addrb_shift_dir
                              CBa_mode <= {CBa_A,CB_cov_ml}; 
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= t_cov_l;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= cov_HT;

                              B_cache_mode <= Bca_RD_B;
                              B_cache_base_addr_set <= 3'b011;
                            end
                      UPD_HALT_56: begin
                              PE_m <= UPD_5_M;
                              PE_n <= UPD_5_N;
                              PE_k <= UPD_5_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_CBa;   
                              B_in_mode <= B_cache;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_TBb;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= TB_IDLE;
                              TBb_mode <= {TBb_IDLE,DIR_POS}; //for TB_addrb_shift_dir
                              CBa_mode <= CB_IDLE; 
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= 0;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= 0;

                              B_cache_mode <= Bca_IDLE;
                              B_cache_base_addr_set <= 0;
                      end
                      UPD_6: begin
                            /*
                              cov_HT transpose
                              TBb -> TBa
                            */
                              PE_m <= UPD_6_M;
                              PE_n <= UPD_6_N;
                              PE_k <= UPD_6_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_NONE;   
                              B_in_mode <= B_NONE;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_NONE;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= {TBa_TBb, DIR_POS};
                              TBb_mode <= {TBb_cov_HT_transpose,DIR_POS}; //不依赖于N
                              CBa_mode <= CB_IDLE;
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= 0;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= 0;

                              B_cache_mode <= Bca_IDLE;
                              B_cache_base_addr_set <= 0;
                            end
                      UPD_7: begin
                            /*
                              H_T * cov_HT + Q <= S
                              X=2 Y=2 N=5
                              Ain: B_cache
                              Bin: TB-B
                              Min:  
                              Cout: C_cache 
                            */
                              PE_m <= UPD_7_M;
                              PE_n <= UPD_7_N;
                              PE_k <= UPD_7_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_cache;   
                              B_in_mode <= B_TBb;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_cache;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= TB_IDLE;
                              TBb_mode <= {TBb_B, DIR_POS};
                              CBa_mode <= CB_IDLE;
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= 0;
                              B_TB_base_addr_set <= t_cov_HT;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= 0;

                              B_cache_mode <= Bca_RD_A;
                              B_cache_base_addr_set <= Hxi_cache;
                            end
                      UPD_INV: begin
                              PE_m <= 0;
                              PE_n <= 0;
                              PE_k <= 0;

                              CAL_mode <= N_W;

                              A_in_mode <= A_NONE;   
                              B_in_mode <= B_NONE;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_NONE;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= TB_IDLE;
                              TBb_mode <= TB_IDLE;
                              CBa_mode <= CB_IDLE;
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= 0;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= 0;

                              B_cache_mode <= Bca_IDLE;
                              B_cache_base_addr_set <= 0;
                             end
                      UPD_8: begin
                            /*
                              S_t inverse
                              Ain: 0
                              Bin: B-cache
                              Min: 0
                              Cout: 0
                            */
                              PE_m <= UPD_8_M;
                              PE_n <= UPD_8_N;
                              PE_k <= UPD_8_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_NONE;   
                              B_in_mode <= B_NONE;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_NONE;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= TB_IDLE;
                              TBb_mode <= TB_IDLE;
                              CBa_mode <= CB_IDLE;
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= 0;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= 0;

                              B_cache_mode <= Bca_WR_inv;
                              B_cache_base_addr_set <= 0;
                            end
                      UPD_9: begin
                            /*
                              cov_HT * S <= K_t
                              X=4 Y=2 N=2
                              Ain: TB-A
                              Bin: B_cache
                              Min: 0
                              Cout: TB-B
                            */
                              PE_m <= UPD_9_M;
                              PE_n <= UPD_9_N;
                              PE_k <= UPD_9_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_TBa;   
                              B_in_mode <= B_cache;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_TBb;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= {TBa_A,DIR_POS};
                              TBb_mode <= {TBb_C,DIR_POS};
                              CBa_mode <= CB_IDLE;
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= cov_HT;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= K_t;

                              B_cache_mode <= Bca_RD_B;
                              B_cache_base_addr_set <= S_cache_0;
                            end
                      UPD_STATE: begin
                                PE_m <= 3'b100;
                                PE_n <= 3'b010;
                                PE_k <= 3'b001;

                                CAL_mode <= N_W;

                                A_in_mode <= A_TBa;   
                                B_in_mode <= B_cache;
                                M_in_mode <= M_NONE;
                                C_out_mode <= C_PLB;
                                M_adder_mode_set <= NONE;

                                TBa_mode <= {TBa_A,DIR_POS};
                                TBb_mode <= {TBb_IDLE,DIR_POS};
                                CBa_mode <= CB_IDLE;
                                CBb_mode <= CB_IDLE;

                                A_TB_base_addr_set <= K_t;
                                B_TB_base_addr_set <= 0;
                                M_TB_base_addr_set <= 0;
                                C_TB_base_addr_set <= 0;

                                B_cache_mode <= Bca_RD_B;
                                B_cache_base_addr_set <= v_t_cache;
                              end
                      UPD_10: begin
                            /*
                              K_t * cov_HT <= cov
                              X=4 Y=4 N=2
                              Ain: TB-A
                              Bin: TB-B
                              Min: CB-A
                              Cout: CB-B
                            */
                              PE_m <= UPD_10_M;
                              PE_n <= UPD_10_N;
                              PE_k <= UPD_10_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_TBa;   
                              B_in_mode <= B_TBb;
                              M_in_mode <= M_CBa;
                              C_out_mode <= C_CBb;
                              M_adder_mode_set <= M_MINUS_C;

                              TBa_mode <= {TBa_A,DIR_POS};
                              TBb_mode <= {TBb_B,DIR_POS};
                              CBa_mode <= {CBa_M,CB_cov};
                              CBb_mode <= {CBb_C,CB_cov};

                              A_TB_base_addr_set <= K_t;
                              B_TB_base_addr_set <= cov_HT;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= 0;

                              B_cache_mode <= Bca_IDLE;
                              B_cache_base_addr_set <= 0;
                            end
                      default: begin
                                PE_m <= 0;
                                PE_n <= 0;
                                PE_k <= 0;

                                CAL_mode <= N_W;

                                A_in_mode <= A_NONE;   
                                B_in_mode <= B_NONE;
                                M_in_mode <= M_NONE;
                                C_out_mode <= C_CBb;
                                M_adder_mode_set <= NONE;

                                TBa_mode <= TB_IDLE;
                                TBb_mode <= TB_IDLE;
                                CBa_mode <= CB_IDLE;
                                CBb_mode <= CB_IDLE;

                                A_TB_base_addr_set <= 0;
                                B_TB_base_addr_set <= 0;
                                M_TB_base_addr_set <= 0;
                                C_TB_base_addr_set <= 0;

                                B_cache_mode <= Bca_IDLE;
                                B_cache_base_addr_set <= 0;
                              end
                    endcase
                  end
        STAGE_ASSOC:begin
                    case(assoc_next)
                    /*STATE VECTOR move to PLB*/
                      // ASSOC_NL_SEND:
                      //       begin
                      //         CBa_mode <= {CBa_NL,CB_NL_xyxita};    
                      //       end
                      ASSOC_NL_RCV:begin
                        
                              TBa_mode <= {TBa_NL_UPD,DIR_POS};    //ASSOC中vt写入TB
                              PE_n <= 3'b111;
                              B_cache_mode <= Bca_WR_NL_ASSOC;
                              B_cache_base_addr_set <= 0; 

                              PE_m <= 0;
                              PE_k <= 0;

                              CAL_mode <= N_W;

                              A_in_mode <= A_TBa;   
                              B_in_mode <= B_TBb;
                              M_in_mode <= M_TBa;
                              C_out_mode <= C_CBb;
                              M_adder_mode_set <= NONE;

                              TBb_mode <= TB_IDLE;
                              CBa_mode <= CB_IDLE;
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= 0;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= 0;
                            end
                      ASSOC_1: begin
                              PE_m <= ASSOC_1_M;
                              PE_n <= ASSOC_1_N;
                              PE_k <= ASSOC_1_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_cache;   
                              B_in_mode <= B_CBa;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_TBb;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= TB_IDLE;
                              TBb_mode <= {TBb_C,DIR_POS};
                              CBa_mode <= {CBa_B, CB_cov_vv};
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= 0;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= H_vv;

                              B_cache_mode <= Bca_RD_A;
                              B_cache_base_addr_set <= Hxi_cache; 
                          end
                      ASSOC_2: begin
                              PE_m <= ASSOC_2_M;
                              PE_n <= ASSOC_2_N;
                              PE_k <= ASSOC_2_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_cache;   
                              B_in_mode <= B_CBa;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_TBb;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= TB_IDLE;
                              TBb_mode <= {TBb_C,DIR_POS};
                              CBa_mode <= {CBa_B, CB_cov_lv};
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= 0;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= H_lv;

                              B_cache_mode <= Bca_RD_A;
                              B_cache_base_addr_set <= Hxi_cache; 
                          end
                      ASSOC_3: begin
                              PE_m <= ASSOC_3_M;
                              PE_n <= ASSOC_3_N;
                              PE_k <= ASSOC_3_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_cache;   
                              B_in_mode <= B_CBa;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_TBb;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= TB_IDLE;
                              TBb_mode <= {TBb_C,DIR_POS};
                              CBa_mode <= {CBa_B, CB_cov_ll};
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= 0;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= H_ll;

                              B_cache_mode <= Bca_RD_A;
                              B_cache_base_addr_set <= Hz_cache; 
                          end
                      ASSOC_4: begin
                              PE_m <= ASSOC_4_M;
                              PE_n <= ASSOC_4_N;
                              PE_k <= ASSOC_4_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_TBa;   
                              B_in_mode <= B_cache;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_TBb;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= {TBa_A,DIR_POS};
                              TBb_mode <= {TBb_C,DIR_POS};
                              CBa_mode <= CB_IDLE;
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= H_lv;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= H_lv_H;

                              B_cache_mode <= Bca_RD_B;
                              B_cache_base_addr_set <= Hz_cache; 
                          end
                       ASSOC_5: begin
                              PE_m <= ASSOC_5_M;
                              PE_n <= ASSOC_5_N;
                              PE_k <= ASSOC_5_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_TBa;   
                              B_in_mode <= B_cache;
                              M_in_mode <= M_TBa;
                              C_out_mode <= C_TBb;
                              M_adder_mode_set <= ADD;

                              TBa_mode <= {TBa_AM,DIR_POS};
                              TBb_mode <= {TBb_C,DIR_POS};
                              CBa_mode <= CB_IDLE;
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= H_vv;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= H_lv_H;
                              C_TB_base_addr_set <= H_vv_H;

                              B_cache_mode <= Bca_RD_B;
                              B_cache_base_addr_set <= Hxi_cache; 
                          end
                      ASSOC_TRANS: begin
                            /*
                              H_lv_H transpose
                              Ain: 
                              Bin: B-cache
                              Min: 0
                              Cout: 0
                            */
                              PE_m <= 0;
                              PE_n <= ASSOC_6_N;
                              PE_k <= 0;

                              CAL_mode <= N_W;

                              A_in_mode <= A_NONE;   
                              B_in_mode <= B_NONE;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_NONE;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= {TBa_TBb,DIR_POS};
                              TBb_mode <= {TBb_H_lv_H_transpose,DIR_POS}; //不依赖于N
                              CBa_mode <= CB_IDLE;
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= 0;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= 0;

                              B_cache_mode <= Bca_IDLE;
                              B_cache_base_addr_set <= 0;
                            end
                      ASSOC_6: begin
                              PE_m <= ASSOC_6_M;
                              PE_n <= ASSOC_6_N;
                              PE_k <= ASSOC_6_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_TBa;   
                              B_in_mode <= B_cache;
                              M_in_mode <= M_TBa;
                              C_out_mode <= C_TBb;
                              M_adder_mode_set <= ADD;

                              TBa_mode <= {TBa_AM,DIR_POS};
                              TBb_mode <= {TBb_C,DIR_POS};
                              CBa_mode <= CB_IDLE;
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= H_ll;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= H_vl_H;
                              C_TB_base_addr_set <= H_ll_H;

                              B_cache_mode <= Bca_RD_B;
                              B_cache_base_addr_set <= Hz_cache; 
                          end
                      ASSOC_7: begin
                              PE_m <= ASSOC_7_M;
                              PE_n <= ASSOC_7_N;
                              PE_k <= ASSOC_7_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_TBa;   
                              B_in_mode <= B_cache;
                              M_in_mode <= M_TBa;
                              C_out_mode <= C_cache;
                              M_adder_mode_set <= ADD;

                              TBa_mode <= {TBa_AM,DIR_POS};
                              TBb_mode <= TB_IDLE;
                              CBa_mode <= CB_IDLE;
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= H_ll_H;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= H_vv_H;
                              C_TB_base_addr_set <= 0;

                              B_cache_mode <= Bca_RD_B;
                              B_cache_base_addr_set <= I_cache; 
                          end
                      ASSOC_INV: begin
                              PE_m <= 0;
                              PE_n <= 0;
                              PE_k <= 0;

                              CAL_mode <= N_W;

                              A_in_mode <= A_NONE;   
                              B_in_mode <= B_NONE;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_NONE;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= TB_IDLE;
                              TBb_mode <= TB_IDLE;
                              CBa_mode <= CB_IDLE;
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= 0;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= 0;

                              B_cache_mode <= Bca_IDLE;
                              B_cache_base_addr_set <= 0;
                             end
                      ASSOC_8: begin
                            /*
                              S_t inverse
                              Ain: 0
                              Bin: B-cache
                              Min: 0
                              Cout: 0
                            */
                              PE_m <= ASSOC_8_M;
                              PE_n <= ASSOC_8_N;
                              PE_k <= ASSOC_8_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_NONE;   
                              B_in_mode <= B_NONE;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_NONE;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= TB_IDLE;
                              TBb_mode <= TB_IDLE;
                              CBa_mode <= CB_IDLE;
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= 0;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= 0;

                              B_cache_mode <= Bca_WR_inv;
                              B_cache_base_addr_set <= 0;
                            end
                      ASSOC_9: begin
                              PE_m <= ASSOC_9_M;
                              PE_n <= ASSOC_9_N;
                              PE_k <= ASSOC_9_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_TBa;   
                              B_in_mode <= B_cache;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_cache;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= {TBa_A,DIR_POS};
                              TBb_mode <= TB_IDLE;
                              CBa_mode <= CB_IDLE;
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= v_t;
                              B_TB_base_addr_set <= 0;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= 0;

                              B_cache_mode <= Bca_WR_chi;
                              B_cache_base_addr_set <= S_cache_0; 
                          end
                      ASSOC_10: begin
                              PE_m <= ASSOC_10_M;
                              PE_n <= ASSOC_10_N;
                              PE_k <= ASSOC_10_K;

                              CAL_mode <= N_W;

                              A_in_mode <= A_cache;   
                              B_in_mode <= B_TBb;
                              M_in_mode <= M_NONE;
                              C_out_mode <= C_PLB;
                              M_adder_mode_set <= NONE;

                              TBa_mode <= TB_IDLE;
                              TBb_mode <= {TBb_B,DIR_POS};
                              CBa_mode <= CB_IDLE;
                              CBb_mode <= CB_IDLE;

                              A_TB_base_addr_set <= 0;
                              B_TB_base_addr_set <= v_t;
                              M_TB_base_addr_set <= 0;
                              C_TB_base_addr_set <= 0;

                              B_cache_mode <= Bca_RD_A;
                              B_cache_base_addr_set <= vt_S_inv_cache_0; 
                          end
                      default: begin
                                PE_m <= 0;
                                PE_n <= 0;
                                PE_k <= 0;

                                CAL_mode <= N_W;

                                A_in_mode <= A_NONE;   
                                B_in_mode <= B_NONE;
                                M_in_mode <= M_NONE;
                                C_out_mode <= C_CBb;
                                M_adder_mode_set <= NONE;

                                TBa_mode <= TB_IDLE;
                                TBb_mode <= TB_IDLE;
                                CBa_mode <= CB_IDLE;
                                CBb_mode <= CB_IDLE;

                                A_TB_base_addr_set <= 0;
                                B_TB_base_addr_set <= 0;
                                M_TB_base_addr_set <= 0;
                                C_TB_base_addr_set <= 0;

                                B_cache_mode <= Bca_IDLE;
                                B_cache_base_addr_set <= 0; 
                              end
                    endcase
                 end
        default: begin
                  PE_m <= 0;
                  PE_n <= 0;
                  PE_k <= 0;

                  CAL_mode <= N_W;

                  A_in_mode <= A_NONE;   
                  B_in_mode <= B_NONE;
                  M_in_mode <= M_NONE;
                  C_out_mode <= C_CBb;
                  M_adder_mode_set <= NONE;

                  TBa_mode <= TB_IDLE;
                  TBb_mode <= TB_IDLE;
                  CBa_mode <= CB_IDLE;
                  CBb_mode <= CB_IDLE;

                  A_TB_base_addr_set <= 0;
                  B_TB_base_addr_set <= 0;
                  M_TB_base_addr_set <= 0;
                  C_TB_base_addr_set <= 0;

                  B_cache_mode <= Bca_IDLE;
                  B_cache_base_addr_set <= 0;
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
  wire [2:0] PE_m_A_in_en, PE_m_M_in_en, PE_m_C_out_en;
  wire [2:0] PE_k_B_in_en;

  reg [1:0] AB_in_en_d_addr = CAL_EN_D;
  reg [2:0] M_in_en_d_addr  = M_IN_SEL_D;
  reg [3:0] C_out_en_d_addr = C_OUT_SEL_D;

  dynamic_shreg 
  #(
    .DW    (3    ),
    .AW    (2    )
  )
  A_in_en_dynamic_shreg(
  	.clk  (clk  ),
    .ce   (1'b1   ),
    .addr (AB_in_en_d_addr ),
    .din  (PE_m  ),
    .dout (PE_m_A_in_en )
  );

  always @(posedge clk) begin
    if(sys_rst) begin
      A_in_en <= 4'b0000;  
    end
    else begin
      case(PE_m_A_in_en)
        3'b001: begin
          A_in_en <= 4'b0001;  
        end
        3'b010: begin
          A_in_en <= 4'b0011;  
        end
        3'b011: begin
          A_in_en <= 4'b0111;  
        end
        3'b100: begin
          A_in_en <= 4'b1111;  
        end
        default: begin
          A_in_en <= 4'b0000;  
        end
      endcase
    end
  end

  dynamic_shreg 
  #(
    .DW    (3    ),
    .AW    (3    )
  )
  M_in_en_dynamic_shreg(
  	.clk  (clk  ),
    .ce   (1'b1   ),
    .addr (M_in_en_d_addr ),
    .din  (PE_m  ),
    .dout (PE_m_M_in_en )
  );

  always @(posedge clk) begin
    if(sys_rst) begin
      M_in_en <= 4'b0000;  
    end
    else begin
      case(PE_m_M_in_en)
        3'b001: begin
          M_in_en <= 4'b0001;  
        end
        3'b010: begin
          M_in_en <= 4'b0011;  
        end
        3'b011: begin
          M_in_en <= 4'b0111;  
        end
        3'b100: begin
          M_in_en <= 4'b1111;  
        end
        default: begin
          M_in_en <= 4'b0000;  
        end
      endcase
    end
  end

  dynamic_shreg 
  #(
    .DW    (3    ),
    .AW    (4    )
  )
  C_out_en_dynamic_shreg(
  	.clk  (clk  ),
    .ce   (1'b1   ),
    .addr (C_out_en_d_addr ),
    .din  (PE_m  ),
    .dout (PE_m_C_out_en )
  );

  always @(posedge clk) begin
    if(sys_rst) begin
      C_out_en <= 4'b0000;  
    end
    else begin
      case(PE_m_C_out_en)
        3'b001: begin
          C_out_en <= 4'b0001;  
        end
        3'b010: begin
          C_out_en <= 4'b0011;  
        end
        3'b011: begin
          C_out_en <= 4'b0111;  
        end
        3'b100: begin
          C_out_en <= 4'b1111;  
        end
        default: begin
          C_out_en <= 4'b0000;  
        end
      endcase
    end
  end

  dynamic_shreg 
  #(
    .DW    (3    ),
    .AW    (2    )
  )
  B_in_en_dynamic_shreg(
    .clk  (clk  ),
    .ce   (1'b1   ),
    .addr (AB_in_en_d_addr ),
    .din  (PE_k  ),
    .dout (PE_k_B_in_en )
  );

  always @(posedge clk) begin
    if(sys_rst) begin
      B_in_en <= 4'b0000;
    end
    else begin
      case(PE_k_B_in_en)
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
    .AW    (3    )
  )
  M_adder_mode_dynamic_shreg(
  	.clk  (clk  ),
    .ce   (1'b1   ),
    .addr (M_in_sel_d_addr ),
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
  // wire [2:0]           stage_cur_cal;

  reg [1:0] cal_en_d_addr = CAL_EN_D;

  // seq_cnt PE_n 延迟
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

  // 确定最低位
  reg new_cal_en_new;
  reg new_cal_done_new;
  
  always @(posedge clk) begin
    if(sys_rst) begin
      new_cal_en_new <= 0;
    end
    else begin
      if(PEn_cal_d != 0 && seq_cnt_cal_d >= 0 && seq_cnt_cal_d < PEn_cal_d) begin
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
      if(PEn_cal_d != 0 && seq_cnt_cal_d == PEn_cal_d)
        new_cal_done_new <= 1'b1;
      else
        new_cal_done_new <= 1'b0;
    end
      
  end

  //new_cal_en 移位 
  wire  [Y-1 : 0]           new_cal_en_shift;
  wire  [Y-1 : 0]           new_cal_done_shift;

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
      .dout  (new_cal_en_shift  )
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
      .dout  (new_cal_done_shift  )
    );

  //与 B_in_en相与, 得到于第一行输入，纵向传递的cal向量
  assign new_cal_en = new_cal_en_shift & B_in_en;
  assign new_cal_done = new_cal_done_shift & B_in_en;
    

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
    wire [2:0]   stage_cur_WR;
    wire [3:0]   prd_cur_WR;
    wire [5:0]   new_cur_WR;
    wire [5:0]   upd_cur_WR;
    wire [5:0]   assoc_cur_WR;
    
    wire [SEQ_CNT_DW-1 : 0] seq_cnt_WR;
    wire [SEQ_CNT_DW-1 : 0] seq_cnt_max_WR;
    wire [ROW_LEN-1 : 0] v_group_cnt_WR;
    wire [ROW_LEN-1 : 0] v_group_cnt_max_WR;
    wire [4:0]           TBb_mode_WR;
    wire [6:0]           CBb_mode_WR;
    wire [2:0]           PE_n_WR;
    wire [2:0]           PE_k_WR;

    wire [TB_AW-1:0] C_TB_base_addr_set_WR;
    
    reg [2 : 0]          PE_n_d_addr = RD_2_WR_D;     //PE_n延迟级数，固定值
    reg [3 : 0]          WR_d_addr;       //读出部分取多少级延迟
    always @(posedge clk) begin
      if(sys_rst) begin
        WR_d_addr <= RD_2_WR_D;
      end
      else begin
        if((upd_cur == UPD_2) || (upd_cur == UPD_3) || (upd_cur == UPD_4) || (upd_cur == UPD_5) || (upd_cur == UPD_6))
          WR_d_addr <= RD_2_WR_D + 3'b101;
        else
          WR_d_addr <= RD_2_WR_D + PE_n_WR;
      end 
    end

    //PE_n_WR只延迟RD_2_WR_D，保证WR_d_addr采样到的还是上一次的PE_n
    dynamic_shreg 
    #(
      .DW    (3    ),
      .AW    (3    )
    )
    PE_n_dynamic_shreg(
      .clk  (clk  ),
      .ce   (1'b1   ),
      .addr (PE_n_d_addr ),
      .din  (PE_n  ),
      .dout (PE_n_WR )
    );

    dynamic_shreg 
    #(
      .DW    (3    ),
      .AW    (4    )
    )
    PE_k_dynamic_shreg(
      .clk  (clk  ),
      .ce   (1'b1   ),
      .addr (WR_d_addr ),
      .din  (PE_k  ),
      .dout (PE_k_WR )
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
      .DW  (SEQ_CNT_DW  ),
      .AW  (4  )
    )
    seq_cnt_max_shreg(
      .clk  (clk  ),
      .ce   (1'b1  ),
      .addr (WR_d_addr ),
      .din  (seq_cnt_max  ),
      .dout (seq_cnt_max_WR )
    );

    dynamic_shreg 
    #(
      .DW  (ROW_LEN  ),
      .AW  (4  )
    )
    v_group_cnt_shreg(
      .clk  (clk  ),
      .ce   (1'b1  ),
      .addr (WR_d_addr ),
      .din  (v_group_cnt  ),
      .dout (v_group_cnt_WR )
    );

    dynamic_shreg 
    #(
      .DW  (ROW_LEN  ),
      .AW  (4  )
    )
    v_group_cnt_max_shreg(
      .clk  (clk  ),
      .ce   (1'b1  ),
      .addr (WR_d_addr ),
      .din  (v_group_cnt_max  ),
      .dout (v_group_cnt_max_WR )
    );

    dynamic_shreg 
    #(
      .DW  (3  ),
      .AW  (4  )
    )
    stage_cur_shreg(
      .clk  (clk  ),
      .ce   (1'b1  ),
      .addr (WR_d_addr ),
      .din  (stage_cur  ),
      .dout (stage_cur_WR )
    );

    dynamic_shreg 
    #(
      .DW  (4  ),
      .AW  (4  )
    )
    prd_cur_shreg(
      .clk  (clk  ),
      .ce   (1'b1  ),
      .addr (WR_d_addr ),
      .din  (prd_cur  ),
      .dout (prd_cur_WR )
    );

    dynamic_shreg 
    #(
      .DW  (6  ),
      .AW  (4  )
    )
    new_cur_shreg(
      .clk  (clk  ),
      .ce   (1'b1  ),
      .addr (WR_d_addr ),
      .din  (new_cur  ),
      .dout (new_cur_WR )
    );

    dynamic_shreg 
    #(
      .DW  (6  ),
      .AW  (4  )
    )
    upd_cur_shreg(
      .clk  (clk  ),
      .ce   (1'b1  ),
      .addr (WR_d_addr ),
      .din  (upd_cur  ),
      .dout (upd_cur_WR )
    );

    dynamic_shreg 
    #(
      .DW  (6  ),
      .AW  (4  )
    )
    assoc_cur_shreg(
      .clk  (clk  ),
      .ce   (1'b1  ),
      .addr (WR_d_addr ),
      .din  (assoc_cur  ),
      .dout (assoc_cur_WR )
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
      .DW  (7  ),
      .AW  (4  )
    )
    CBb_mode_shreg(
      .clk  (clk  ),
      .ce   (1'b1  ),
      .addr (WR_d_addr ),
      .din  (CBb_mode  ),
      .dout (CBb_mode_WR )
    );

    dynamic_shreg 
    #(
      .DW  (TB_AW  ),
      .AW  (4  )
    )
    C_TB_base_addr_set_shreg(
      .clk  (clk  ),
      .ce   (1'b1  ),
      .addr (WR_d_addr ),
      .din  (C_TB_base_addr_set  ),
      .dout (C_TB_base_addr_set_WR )
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
                    // TB_douta_sel_new[2] <= 1'b1;
                    TB_ena_new <= 1'b1;
                    TB_wea_new <= 1'b0;
                    TB_addra_new <= M_TB_base_addr_set;
                  end
                  else if(seq_cnt == PE_n + 2'b10) begin
                    TB_douta_sel_new[2] <= 1'b1;
                    TB_ena_new <= 1'b0;
                    TB_wea_new <= 1'b0;
                    TB_addra_new <= 0;
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
        TBa_CBa: begin
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
        TBa_TBb: begin
          case(TBb_mode[4:2])
            TBb_H_lv_H_transpose: begin
                    case(seq_cnt)
                      SEQ_12:begin
                          TB_ena_new <= 1'b1;
                          TB_wea_new <= 1'b1;
                          TB_addra_new <= H_vl_H;
                        end
                      SEQ_13:begin
                          TB_ena_new <= 1'b1;
                          TB_wea_new <= 1'b1;
                          TB_addra_new <= TB_addra_new + 1'b1;
                        end
                      default:begin
                          TB_ena_new <= 0;
                          TB_wea_new <= 0;
                          TB_addra_new <= 0;
                        end
                    endcase
                  end
            TBb_cov_HT_transpose: begin
                    case(seq_cnt)
                      SEQ_4:begin
                          TB_ena_new <= 1'b1;
                          TB_wea_new <= 1'b1;
                          TB_addra_new <= t_cov_HT;
                        end
                      SEQ_5:begin
                          TB_ena_new <= 1'b1;
                          TB_wea_new <= 1'b1;
                          TB_addra_new <= TB_addra_new + 1'b1;
                        end
                      SEQ_6:begin
                          TB_ena_new <= 1'b1;
                          TB_wea_new <= 1'b1;
                          TB_addra_new <= TB_addra_new + 1'b1;
                        end
                      SEQ_7:begin
                          TB_ena_new <= 1'b0;
                          TB_wea_new <= 1'b0;
                          TB_addra_new <= TB_addra_new;
                        end
                      SEQ_8:begin
                          TB_ena_new <= 1'b1;
                          TB_wea_new <= 1'b1;
                          TB_addra_new <= TB_addra_new + 1'b1;
                        end
                      SEQ_9:begin
                          TB_ena_new <= 1'b1;
                          TB_wea_new <= 1'b1;
                          TB_addra_new <= TB_addra_new + 1'b1;
                        end
                      default:begin
                          TB_ena_new <= 0;
                          TB_wea_new <= 0;
                          TB_addra_new <= 0;
                        end
                    endcase
                  end
            default: begin
              TB_ena_new <= 0;
              TB_wea_new <= 0;
              TB_addra_new <= 0;
            end
          endcase
        end
        TBa_NL_UPD: begin       //只写vt
                  case(seq_cnt)
                    SEQ_0: begin
                      TB_ena_new <= 1'b1;
                      TB_wea_new <= 1'b1;
                      TB_addra_new <= v_t;
                    end
                    SEQ_1: begin
                      TB_ena_new <= 1'b1;
                      TB_wea_new <= 1'b1;
                      TB_addra_new <= v_t + 1'b1;
                    end
                    default:begin
                      TB_ena_new <= 1'b0;
                      TB_wea_new <= 1'b0;
                      TB_addra_new <= 0;
                    end
                  endcase
                end
        // TBa_NL_PRD: begin
        //           case(seq_cnt)
        //             SEQ_0: begin
        //               TB_ena_new <= 1'b1;
        //               TB_wea_new <= 1'b1;
        //               TB_addra_new <= 2'b10;
        //             end
        //             SEQ_1: begin
        //               TB_ena_new <= 1'b1;
        //               TB_wea_new <= 1'b1;
        //               TB_addra_new <= 2'b11;
        //             end
        //             SEQ_2: begin
        //               TB_ena_new <= 1'b1;
        //               TB_wea_new <= 1'b1;
        //               TB_addra_new <= 3'b100;
        //             end
        //             default:begin
        //               TB_ena_new <= 1'b0;
        //               TB_wea_new <= 1'b0;
        //               TB_addra_new <= 0;
        //             end
        //           endcase
        //         end
        // TBa_NL_NEW: begin
        //           case(seq_cnt)
        //             SEQ_0: begin
        //               TB_ena_new <= 1'b1;
        //               TB_wea_new <= 1'b1;
        //               TB_addra_new <= G_xi + 2'b10;
        //             end
        //             SEQ_1: begin
        //               TB_ena_new <= 1'b1;
        //               TB_wea_new <= 1'b1;
        //               TB_addra_new <= G_z;
        //             end
        //             SEQ_2: begin
        //               TB_ena_new <= 1'b1;
        //               TB_wea_new <= 1'b1;
        //               TB_addra_new <= G_z + 1'b1;
        //             end
        //             default:begin
        //               TB_ena_new <= 1'b0;
        //               TB_wea_new <= 1'b0;
        //               TB_addra_new <= 0;
        //             end
        //           endcase
        //         end
        // TBa_NL_UPD: begin
        //           case(seq_cnt)
        //             SEQ_0: begin
        //               TB_ena_new <= 1'b1;
        //               TB_wea_new <= 1'b1;
        //               TB_addra_new <= H_xi;
        //             end
        //             SEQ_1: begin
        //               TB_ena_new <= 1'b1;
        //               TB_wea_new <= 1'b1;
        //               TB_addra_new <= H_xi + 1'b1;
        //             end
        //             SEQ_2: begin
        //               TB_ena_new <= 1'b1;
        //               TB_wea_new <= 1'b1;
        //               TB_addra_new <= H_z;
        //             end
        //             SEQ_3: begin
        //               TB_ena_new <= 1'b1;
        //               TB_wea_new <= 1'b1;
        //               TB_addra_new <= H_z + 1'b1;
        //             end
        //             SEQ_4: begin
        //               TB_ena_new <= 1'b1;
        //               TB_wea_new <= 1'b1;
        //               TB_addra_new <= v_t;
        //             end
        //             SEQ_5: begin
        //               TB_ena_new <= 1'b1;
        //               TB_wea_new <= 1'b1;
        //               TB_addra_new <= v_t + 1'b1;
        //             end
        //             default:begin
        //               TB_ena_new <= 1'b0;
        //               TB_wea_new <= 1'b0;
        //               TB_addra_new <= 0;
        //             end
        //           endcase
        //         end
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
    reg [4:0] TBa_mode_d3;
    always @(posedge clk) begin
      if(sys_rst) begin
        TBa_mode_d1 <= 0;
        TBa_mode_d2 <= 0;
        TBa_mode_d3 <= 0;
      end
      else 
        TBa_mode_d1 <= TBa_mode;
        TBa_mode_d2 <= TBa_mode_d1;
        TBa_mode_d3 <= TBa_mode_d2;
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
        if(TBa_mode_d3[4:2] == TBa_CBa) begin
          TB_dina_sel_new[TB_DINA_SEL_DW-1 : 2] <= TBa_CBa;
          TB_dina_sel_new[1:0] <= TBa_mode_d3[1:0];   //CB -> TB 延迟时序
        end
        else begin
          case (TBa_mode[4:2])
            TBa_CBa: begin
              TB_dina_sel_new[TB_DINA_SEL_DW-1 : 2] <= TBa_CBa;
              TB_dina_sel_new[1:0] <= TBa_mode[1:0]; 
            end 
            TBa_TBb: begin
              TB_dina_sel_new[TB_DINA_SEL_DW-1 : 2] <= TBa_TBb;
              TB_dina_sel_new[1:0] <= TBa_mode[1:0]; 
            end 
            // TBa_NL_PRD: begin
            //   TB_dina_sel_new[TB_DINA_SEL_DW-1 : 2] <= TBa_NL_PRD;
            //   TB_dina_sel_new[1:0] <= TBa_mode[1:0];
            // end
            // TBa_NL_NEW: begin
            //   TB_dina_sel_new[TB_DINA_SEL_DW-1 : 2] <= TBa_NL_NEW;
            //   TB_dina_sel_new[1:0] <= TBa_mode[1:0];
            // end
            TBa_NL_UPD: begin
              TB_dina_sel_new[TB_DINA_SEL_DW-1 : 2] <= TBa_NL_UPD;
              TB_dina_sel_new[1:0] <= TBa_mode[1:0];
            end
            default: begin
              TB_dina_sel_new <= TB_IDLE;
            end
          endcase
        end
      end
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
      //延迟时序，判断是否处于写状态
      case(TBb_mode_WR[4:2])
        TBb_C: begin
                case(seq_cnt_WR)
                  SEQ_0: begin
                    TB_enb_new <= 1'b1;
                    TB_web_new <= 1'b1;
                    if(v_group_cnt_WR == 0)
                      TB_addrb_new <= C_TB_base_addr_set_WR;
                    else
                      TB_addrb_new <= C_TB_base_addr;
                  end
                  SEQ_2: begin
                    TB_enb_new <= 1'b1;
                    TB_web_new <= 1'b1;
                    TB_addrb_new <= TB_addrb_new + 1'b1;
                  end
                  SEQ_4: begin
                    if(PE_k_WR == 3'b011) begin
                      TB_enb_new <= 1'b1;
                      TB_web_new <= 1'b1;
                      TB_addrb_new <= TB_addrb_new + 1'b1;
                    end
                    else begin
                      TB_enb_new <= 1'b0;
                      TB_web_new <= 1'b0;
                      TB_addrb_new <= TB_addrb_new;
                    end
                  end
                  default: begin
                    TB_enb_new <= 1'b0;
                    TB_web_new <= 1'b0;
                    TB_addrb_new <= TB_addrb_new;
                  end
                endcase
              end
        TBb_BC: begin
                case (seq_cnt_WR)
                  SEQ_0: begin
                    TB_enb_new <= 1'b1;
                    TB_web_new <= 1'b1;
                    if(v_group_cnt_WR == 0)
                      TB_addrb_new <= C_TB_base_addr_set_WR;
                    else
                      TB_addrb_new <= C_TB_base_addr;
                  end
                  SEQ_2: begin
                    TB_enb_new <= 1'b1;
                    TB_web_new <= 1'b1;
                    TB_addrb_new <= TB_addrb_new + 1'b1;
                  end
                  SEQ_4: begin
                    if(PE_k_WR == 3'b011) begin
                      TB_enb_new <= 1'b1;
                      TB_web_new <= 1'b1;
                      TB_addrb_new <= TB_addrb_new + 1'b1;
                    end
                    else begin
                      TB_enb_new <= 1'b0;
                      TB_web_new <= 1'b0;
                      TB_addrb_new <= TB_addrb_new;
                    end
                  end
                  default: begin
                    TB_enb_new <= 1'b0;
                    TB_web_new <= 1'b0;
                    TB_addrb_new <= TB_addrb_new;
                  end
                endcase
              end  
        //非写时序，判断是否为读时序
        default: begin
          case(TBb_mode[4:2])
              TBb_B:begin
                      TB_doutb_sel_new[TB_DOUTB_SEL_DW-1 : 2] <= TBb_B;
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
                        TB_addrb_new <= TB_addrb_new;
                      end
                    end
              TBb_BC: begin
                        TB_doutb_sel_new[TB_DOUTB_SEL_DW-1 : 2] <= TBb_B;
                        if(seq_cnt < PE_n) begin
                          TB_enb_new <= 1'b1;
                          TB_web_new <= 1'b0;
                          if(v_group_cnt == 0)
                            TB_addrb_new <= B_TB_base_addr_set + seq_cnt;
                          else
                            TB_addrb_new <= B_TB_base_addr + seq_cnt;
                        end
                      end
              // TBb_B_cache_trnsfer: begin
              //               TB_doutb_sel_new[TB_DOUTB_SEL_DW-1 : 2] <= TBb_B_cache_trnsfer;
              //               if(v_group_cnt == 0 && seq_cnt < PE_n) begin
              //                 TB_enb_new <= 1'b1;
              //                 TB_web_new <= 1'b0;
              //                 TB_addrb_new <= B_TB_base_addr_set + seq_cnt;
              //               end
              //               else begin
              //                     TB_enb_new <= 1'b0;
              //                     TB_web_new <= 1'b0;
              //                     TB_addrb_new <= TB_addrb_new;
              //                   end
              //             end
              TBb_H_lv_H_transpose: begin
                            TB_doutb_sel_new[TB_DOUTB_SEL_DW-1 : 2] <= TBb_H_lv_H_transpose;
                            case (seq_cnt)
                              SEQ_9: begin
                                TB_enb_new <= 1'b1;
                                TB_web_new <= 1'b0;
                                TB_addrb_new <= H_lv_H;
                              end 
                              SEQ_10: begin
                                TB_enb_new <= 1'b1;
                                TB_web_new <= 1'b0;
                                TB_addrb_new <= H_lv_H + 1'b1;
                              end
                              default: begin
                                TB_enb_new <= 1'b0;
                                TB_web_new <= 1'b0;
                                TB_addrb_new <= 0;
                              end
                            endcase 
                          end
              TBb_cov_HT_transpose: begin
                            TB_doutb_sel_new[TB_DOUTB_SEL_DW-1 : 2] <= TBb_cov_HT_transpose;
                            case (seq_cnt)
                              SEQ_1: begin
                                TB_enb_new <= 1'b1;
                                TB_web_new <= 1'b0;
                                TB_addrb_new <= cov_HT;
                              end 
                              SEQ_2: begin
                                TB_enb_new <= 1'b1;
                                TB_web_new <= 1'b0;
                                TB_addrb_new <= TB_addrb_new + 1'b1;
                              end
                              SEQ_3: begin
                                TB_enb_new <= 1'b1;
                                TB_web_new <= 1'b0;
                                TB_addrb_new <= (l_k_group << 2) + cov_HT;
                              end
                              SEQ_4: begin
                                TB_enb_new <= 1'b1;
                                TB_web_new <= 1'b0;
                                TB_addrb_new <= TB_addrb_new + 1'b1;
                              end
                              default: begin
                                TB_enb_new <= 1'b0;
                                TB_web_new <= 1'b0;
                                TB_addrb_new <= TB_addrb_new;
                              end
                            endcase 
                          end
              // TBb_B_cache_inv: begin
              //               TB_doutb_sel_new[TB_DOUTB_SEL_DW-1 : 2] <= TBb_B_cache_inv;
              //               case (seq_cnt)
              //                 SEQ_0: begin
              //                   TB_enb_new <= 1'b1;
              //                   TB_web_new <= 1'b0;
              //                   TB_addrb_new <= B_TB_base_addr_set;
              //                 end 
              //                 SEQ_1: begin
              //                   TB_enb_new <= 1'b1;
              //                   TB_web_new <= 1'b0;
              //                   TB_addrb_new <= B_TB_base_addr_set + 1'b1;
              //                 end
              //                 default: begin
              //                   TB_enb_new <= 1'b0;
              //                   TB_web_new <= 1'b0;
              //                   TB_addrb_new <= TB_addrb_new;
              //                 end
              //               endcase
              //             end
              default: begin
                TB_enb_new <= 1'b0;
                TB_web_new <= 1'b0;
                TB_addrb_new <= 0;
              end
          endcase
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

    //TBb_shift_dir 需考虑写入和读取两种状态
      always @(posedge clk) begin
        if(sys_rst) begin
          TBb_shift_dir <= DIR_IDLE;
        end
         else begin
          case(TBb_mode_WR[4:2])
            TBb_C: begin
              TBb_shift_dir <= TBb_mode_WR[1:0];
            end
            TBb_BC: begin
              TBb_shift_dir <= TBb_mode_WR[1:0];
            end
            default: begin    //非写时序
              TBb_shift_dir <= TBb_mode[1:0];
            end
          endcase
        end 
      end

    //TB_doutb_sel 只与读取有关
      always @(posedge clk) begin
        if(sys_rst) begin
          TB_doutb_sel_new[1:0] <= DIR_IDLE;
        end
        else begin
          TB_doutb_sel_new[1:0] <= TBb_mode_d[1:0];
        end
      end

    //TB_dinb_sel 只与读取有关
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
      case (B_cache_mode)
        Bca_RD_A,Bca_RD_B: begin
                    B_cache_we_new <= 0;
                    B_cache_out_sel <= B_cache_mode;
                    if(seq_cnt < PE_n) begin
                      B_cache_en_new <= 1'b1;
                      B_cache_addr_new <= B_cache_base_addr_set + seq_cnt;
                    end
                    else begin
                      B_cache_en_new <= 0;
                      B_cache_addr_new <= 0;
                    end
                  end
        Bca_WR_NL_PRD,Bca_WR_NL_NEW,Bca_WR_NL_UPD,Bca_WR_NL_ASSOC: begin
                    B_cache_in_sel <= B_cache_mode;
                    if(seq_cnt < PE_n) begin
                      B_cache_we_new <= 1'b1;
                      B_cache_en_new <= 1'b1;
                      B_cache_addr_new <= B_cache_base_addr_set + seq_cnt;
                    end
                    else begin
                      B_cache_we_new <= 1'b0;
                      B_cache_en_new <= 0;
                      B_cache_addr_new <= 0;
                    end
                  end
        // Bca_WR_H_lv_H: begin
        //             B_cache_in_sel <= B_cache_mode;
        //             case(seq_cnt)
        //               SEQ_12:begin
        //                   B_cache_en_new <= 1'b1;
        //                   B_cache_we_new <= 1'b1;
        //                   B_cache_addr_new <= H_vl_H_cache_0;
        //                 end
        //               SEQ_13:begin
        //                   B_cache_en_new <= 1'b1;
        //                   B_cache_we_new <= 1'b1;
        //                   B_cache_addr_new <= H_vl_H_cache_1;
        //                 end
        //               default:begin
        //                   B_cache_en_new <= 0;
        //                   B_cache_we_new <= 0;
        //                   B_cache_addr_new <= 0;
        //                 end
        //             endcase
        //           end
        // Bca_WR_cov_HT: begin
        //             B_cache_in_sel <= B_cache_mode;
        //             case(seq_cnt)
        //               SEQ_4:begin
        //                   B_cache_en_new <= 1'b1;
        //                   B_cache_we_new <= 1'b1;
        //                   B_cache_addr_new <= 3'b000;
        //                 end
        //               SEQ_5:begin
        //                   B_cache_en_new <= 1'b1;
        //                   B_cache_we_new <= 1'b1;
        //                   B_cache_addr_new <= 3'b001;
        //                 end
        //               SEQ_6:begin
        //                   B_cache_en_new <= 1'b1;
        //                   B_cache_we_new <= 1'b1;
        //                   B_cache_addr_new <= 3'b010;
        //                 end
        //               SEQ_8:begin
        //                   B_cache_en_new <= 1'b1;
        //                   B_cache_we_new <= 1'b1;
        //                   B_cache_addr_new <= 3'b011;
        //                 end
        //               SEQ_9:begin
        //                   B_cache_en_new <= 1'b1;
        //                   B_cache_we_new <= 1'b1;
        //                   B_cache_addr_new <= 3'b100;
        //                 end
        //               default:begin
        //                   B_cache_en_new <= 0;
        //                   B_cache_we_new <= 0;
        //                   B_cache_addr_new <= 0;
        //                 end
        //             endcase
        //           end
        Bca_WR_inv: begin
                    B_cache_in_sel <= B_cache_mode;
                    case(seq_cnt)
                      SEQ_0:begin
                          B_cache_en_new <= 1'b1;
                          B_cache_we_new <= 1'b1;
                          B_cache_addr_new <= S_cache_0;
                        end
                      SEQ_1:begin
                          B_cache_en_new <= 1'b1;
                          B_cache_we_new <= 1'b1;
                          B_cache_addr_new <= S_cache_1;
                        end
                      default:begin
                          B_cache_en_new <= 0;
                          B_cache_we_new <= 0;
                          B_cache_addr_new <= 0;
                        end
                    endcase
                  end
        Bca_WR_chi:begin
                    B_cache_out_sel <= Bca_RD_B;
                    B_cache_in_sel  <= Bca_WR_chi;
                    case(seq_cnt)
                      SEQ_0:begin
                          B_cache_en_new <= 1'b1;
                          B_cache_we_new <= 1'b0;
                          B_cache_addr_new <= S_cache_0;
                        end
                      SEQ_1:begin
                          B_cache_en_new <= 1'b1;
                          B_cache_we_new <= 1'b0;
                          B_cache_addr_new <= S_cache_1;
                        end
                      SEQ_9:begin
                          B_cache_en_new <= 1'b1;
                          B_cache_we_new <= 1'b1;
                          B_cache_addr_new <= vt_S_inv_cache_0;
                        end
                      SEQ_11:begin
                          B_cache_en_new <= 1'b1;
                          B_cache_we_new <= 1'b1;
                          B_cache_addr_new <= vt_S_inv_cache_1;
                        end
                      default:begin
                          B_cache_en_new <= 1'b0;
                          B_cache_we_new <= 1'b0;
                          B_cache_addr_new <= 0;
                        end
                    endcase
                  end
        default: begin
                    B_cache_in_sel <= Bca_IDLE;
                    B_cache_out_sel <= Bca_IDLE;
                    B_cache_we_new <= 0;
                    B_cache_en_new <= 0;
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
      case (CBa_mode[3:0])
        CB_cov_IDLE: begin
                      CBa_shift_dir <= CBa_shift_dir;
                      CB_douta_sel_new <= CB_douta_sel_new;

                      CB_ena_new <= 1'b0;
                      CB_wea_new <= 1'b0;
                      CB_addra_new <= 0;
                    end
        CB_NL_xyxita: begin
                    CB_wea_new <= 1'b0;
                    case(seq_cnt)
                      SEQ_4: begin
                        CBa_shift_dir <= DIR_POS;
                        CB_ena_new <= 1'b1;
                        CB_addra_new <= 2'b11;
                      end     
                      SEQ_5: begin
                        CB_douta_sel_new <= {CBa_NL, DIR_POS};
                        CB_ena_new <= 1'b1;
                        CB_addra_new <= l_k_base_addr_raw + 2'b11;
                      end
                      default: begin
                        CB_ena_new <= 1'b0;
                        CB_addra_new <= 0;
                      end
                    endcase 
                  end
        CB_cov_vv: begin
                    CB_wea_new <= 1'b0;
                    case(seq_cnt)
                      SEQ_0: begin
                        CBa_shift_dir <= DIR_POS;
                        CB_ena_new <= 1'b1;
                        CB_addra_new <= 0;
                      end     
                      SEQ_1: begin
                        CB_douta_sel_new <= {CBa_mode[6:4], DIR_POS};
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
                        CB_douta_sel_new <= {CBa_mode[6:4], DIR_POS};
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
        CB_cov:   begin
                    CB_wea_new <= 1'b0;
                    CBa_shift_dir <= DIR_POS;
                    CB_douta_sel_new <= {CBa_mode[6:4],DIR_POS}; 
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
                      1'b0: begin
                        CB_ena_new <= 1'b1;
                        CB_addra_new <= CB_addra_new + 1'b1;
                      end
                      1'b1: begin
                        CB_ena_new <= 1'b0;
                        CB_addra_new <= CB_addra_new;
                      end
                    endcase
                    end
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
                        CB_douta_sel_new[CB_DOUTA_SEL_DW-1:2] <= CBa_mode[6:4]; 
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
        CB_cov_lm: begin
                    CB_wea_new <= 1'b0;
                    case(seq_cnt)
                      SEQ_0: begin
                        CBa_shift_dir <= DIR_NEW; //0-POS 1-NEG
                        CB_ena_new <= 1'b1;
                        if(v_group_cnt == 0)
                          // CB_addra_new <= l_k_base_addr_RD + 3'b100;
                          CB_addra_new <= l_k_base_addr_RD;
                        else
                          CB_addra_new <= CB_addra_new + 1'b1;
                      end     
                      SEQ_1: begin
                        CB_douta_sel_new[CB_DOUTA_SEL_DW-1:2] <= CBa_mode[6:4]; 
                        CB_douta_sel_new[1:0] <= DIR_NEW;
                        CB_ena_new <= 1'b1;
                        CB_addra_new <= CB_addra_new + 1'b1;
                      end
                      SEQ_2: begin
                        CB_ena_new <= 1'b1;
                        CB_addra_new <= CB_addra_new + 1'b1;
                      end
                      SEQ_3: begin
                        CB_ena_new <= 1'b1;
                        CB_addra_new <= CB_addra_new + 1'b1;
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
                        CBa_shift_dir <= DIR_POS; //0-POS 1-NEG
                        CB_ena_new <= 1'b1;
                        CB_addra_new <= CB_addra_base + l_k_row;
                      end     
                      SEQ_1: begin
                        CB_douta_sel_new[CB_DOUTA_SEL_DW-1:2] <= CBa_mode[6:4]; 
                        CB_douta_sel_new[1:0] <= DIR_POS;
                        CB_ena_new <= 1'b1;
                        CB_addra_new <= CB_addra_new + 1'b1;
                      end
                      default: begin
                        CB_ena_new <= 1'b0;
                        CB_addra_new <= 0;
                      end
                    endcase 
                  end
          CB_cov_ll: begin
                    CB_wea_new <= 1'b0;
                    if(CBa_mode[6:4] == CBa_M) begin
                      CBa_shift_dir <= DIR_NEW; 
                      CB_douta_sel_new[CB_DOUTA_SEL_DW-1:2] <= CBa_mode[6:4]; 
                      CB_douta_sel_new[1:0] <= DIR_NEW;
                      if(seq_cnt == PE_n + 1'b1) begin
                        CB_ena_new <= 1'b1;
                        CB_addra_new <= l_k_base_addr_RD + l_k_row;
                      end
                      else if(seq_cnt == PE_n + 2'b11) begin
                        CB_ena_new <= 1'b1;
                        CB_addra_new <= CB_addra_new + 1'b1;
                      end
                    end
                    else begin
                      case(seq_cnt) 
                        SEQ_0: begin 
                          CBa_shift_dir <= DIR_NEW; 
                          CB_ena_new <= 1'b1;
                          CB_addra_new <= l_k_base_addr_RD + l_k_row;
                        end     
                        SEQ_1: begin
                          CB_douta_sel_new[CB_DOUTA_SEL_DW-1:2] <= CBa_mode[6:4]; 
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
                  end
        default: begin
          CBa_shift_dir <= CBa_shift_dir;
          CB_douta_sel_new <= CB_douta_sel_new;  

          CB_ena_new <= 1'b0;
          CB_wea_new <= 1'b0;
          CB_addra_new <= 0;
        end
      endcase
    end
  end

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
      case (CBb_mode[6])  //为0：RSA中的写入，用延迟的mode；为1：NL的写入，直接用mode
        1'b1: begin
              case(CBb_mode[3:0])
                CB_NL_xyxita: begin
                            CBb_shift_dir <= DIR_POS;
                            CB_dinb_sel_new[CB_DINB_SEL_DW-1 : 2] <= CBb_xyxita;
                            CB_dinb_sel_new[1:0] <= DIR_POS;
                            if(seq_cnt == SEQ_0) begin
                              CB_web_new <= 1'b1;
                              CB_enb_new <= 1'b1;
                              CB_addrb_new <= 2'b11;
                            end
                            else begin
                              CB_web_new <= 1'b0;
                              CB_enb_new <= 1'b0;
                              CB_addrb_new <= 0;
                            end
                          end
                CB_NL_lxly: begin
                              CBb_shift_dir <= DIR_NEW;
                              CB_dinb_sel_new[CB_DINB_SEL_DW-1 : 2] <= CBb_lxly;
                              CB_dinb_sel_new[1:0] <= DIR_NEW;
                              if(seq_cnt == SEQ_0) begin
                                CB_web_new <= 1'b1;
                                CB_enb_new <= 1'b1;
                                CB_addrb_new <= l_k_base_addr_raw + 2'b11;
                              end
                              else begin
                                CB_web_new <= 1'b0;
                                CB_enb_new <= 1'b0;
                                CB_addrb_new <= 0;
                              end
                            end
                default:  begin
                            CBb_shift_dir   <= 0;
                            CB_dinb_sel_new <= 0;
                            CB_web_new <= 1'b0;
                            CB_enb_new <= 1'b0;
                            CB_addrb_new <= 0;
                          end
              endcase
            end 
        1'b0: begin
            case (CBb_mode_WR[3:0])
              // CB_cov_IDLE: begin
              //               CBb_shift_dir   <= 0;
              //               CB_dinb_sel_new <= 0;

              //               CB_enb_new <= 1'b0;
              //               CB_web_new <= 1'b0;
              //               CB_addrb_new <= 0;
              //             end
              CB_cov_vv : begin
                            CB_web_new <= 1'b1;
                            CB_dinb_sel_new[CB_DINB_SEL_DW-1 : 2] <= CBb_C;
                            CB_dinb_sel_new[1:0] <= DIR_POS;
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
                            CB_dinb_sel_new[CB_DINB_SEL_DW-1 : 2] <= CBb_C;
                            CB_dinb_sel_new[1:0] <= DIR_POS;
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
                            CB_dinb_sel_new[CB_DINB_SEL_DW-1 : 2] <= CBb_C;
                            CB_dinb_sel_new[1:0] <= DIR_POS;
                            CBb_shift_dir <= DIR_POS;
                            if(v_group_cnt_WR == 0 && seq_cnt_WR == 0) begin
                              CB_enb_new <= 1'b1;
                              CB_addrb_new <= 0;
                            end
                            else begin
                              case(seq_cnt_WR[0])
                              1'b0: begin
                                CB_enb_new <= 1'b1;
                                CB_addrb_new <= CB_addrb_new + 1'b1;
                              end
                              1'b1: begin
                                CB_enb_new <= 1'b0;
                                CB_addrb_new <= CB_addrb_new;
                              end
                            endcase
                            end    
                          end
              CB_cov_lv : begin
                            CB_web_new <= 1'b1;
                            CB_dinb_sel_new[CB_DINB_SEL_DW-1 : 2] <= CBb_C;
                            CB_dinb_sel_new[1:0] <= DIR_NEW;
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
                            CB_dinb_sel_new[CB_DINB_SEL_DW-1 : 2] <= CBb_C;
                            CB_dinb_sel_new[1:0] <= DIR_NEW;
                            CBb_shift_dir <= DIR_NEW;
                            case(seq_cnt_WR)
                              SEQ_0: begin
                                CB_enb_new <= 1'b1;
                                CB_addrb_new <= l_k_base_addr_WR + 3'b100;
                              end  
                              SEQ_2: begin
                                CB_enb_new <= 1'b1;
                                CB_addrb_new <= CB_addrb_new + 1'b1;
                              end
                              SEQ_4: begin
                                CB_enb_new <= 1'b1;
                                CB_addrb_new <= CB_addrb_new + 1'b1;
                              end
                              SEQ_6: begin
                                CB_enb_new <= 1'b1;
                                CB_addrb_new <= CB_addrb_new + 1'b1;
                              end
                              default: begin
                                CB_enb_new <= 1'b0;
                                CB_addrb_new <= CB_addrb_new;
                              end
                            endcase
                          end
              CB_cov_ll : begin
                            CB_web_new <= 1'b1;
                            CB_dinb_sel_new[CB_DINB_SEL_DW-1 : 2] <= CBb_C;
                            CB_dinb_sel_new[1:0] <= DIR_NEW;
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
                                CB_addrb_new <= CB_addrb_new;
                              end
                            endcase
                          end
              default   : begin
                            CBb_shift_dir   <= CBb_shift_dir;
                            CB_dinb_sel_new <= CB_dinb_sel_new;

                            CB_enb_new <= 1'b0;
                            CB_web_new <= 1'b0;
                            CB_addrb_new <= 0;

                          end
            endcase
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
            UPD_9, UPD_STATE: begin
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
      case(stage_cur_WR)
        STAGE_PRD: C_TB_base_addr <= C_TB_base_addr_set;
        STAGE_NEW: C_TB_base_addr <= C_TB_base_addr_set;
        STAGE_UPD: begin
          case(upd_cur_WR)
            UPD_2: begin
              if(seq_cnt_WR == seq_cnt_max_WR)
                C_TB_base_addr <= C_TB_base_addr + 3'b100;
              else
                C_TB_base_addr <= C_TB_base_addr;
            end
            UPD_3: begin
              if(seq_cnt_WR == seq_cnt_max_WR && v_group_cnt_WR < v_group_cnt_max_WR) begin
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
              else if(seq_cnt_WR == seq_cnt_max_WR && v_group_cnt_WR < v_group_cnt_max_WR) begin
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

  //*********************** CBa_vm_AGD *************************

  //CBa_vm_AGD_en有效时，CB_base_AGD就会不断更新CB_addra_base_raw
  always @(posedge clk) begin
    if(sys_rst) begin
      CBa_vm_AGD_en <= 0;
    end
    else begin
      CBa_vm_AGD_en <= 1'b1;
      // case(CBa_mode[3:0])
      //   CB_cov_vv: CBa_vm_AGD_en <= 1'b1;
      //   CB_cov_mv: CBa_vm_AGD_en <= 1'b1;
      //   CB_cov_ml: CBa_vm_AGD_en <= 1'b1;
      //   CB_cov_ll: CBa_vm_AGD_en <= 1'b1;
      //   default:   CBa_vm_AGD_en <= 1'b0;
      // endcase
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
      .en           (CBa_vm_AGD_en),
      .group_cnt    (v_group_cnt  ),
      .CB_base_addr (CB_addra_base_raw )
    );
  
  always @(posedge clk) begin
    if(sys_rst) begin
      CB_addra_base <= 0;
    end
    else begin
      if(seq_cnt == seq_cnt_max)
        CB_addra_base <= CB_addra_base_raw;
      else
        CB_addra_base <= CB_addra_base;
      // case(CBa_mode[3:0])
      //   CB_cov_vv: begin
      //     if(seq_cnt == seq_cnt_max)
      //       CB_addra_base <= CB_addra_base_raw;
      //     else
      //       CB_addra_base <= 1'b1;
      //   end
      //   CB_cov_mv:begin
      //               if(seq_cnt == seq_cnt_max)
      //                 CB_addra_base <= CB_addra_base_raw;
      //               else
      //                 CB_addra_base <= CB_addra_base;
      //             end
      //   // CB_cov_ml:begin
      //   //             CB_addra_base <= CB_addra_base;
      //   //           end
      //   CB_cov_ll:begin
      //               if(seq_cnt == seq_cnt_max)
      //                 CB_addra_base <= CB_addra_base_raw;
      //               else
      //                 CB_addra_base <= CB_addra_base;
      //             end
      //   default:   CB_addra_base <= CB_addra_base;    //CB_addra_base 会进行采样,不用归0
      // endcase
    end
  end

  //*********************** CBb_vm_AGD *************************
  always @(posedge clk) begin
    if(sys_rst) begin
      CBb_vm_AGD_en <= 0;
    end
    else begin
      case(CBb_mode_WR[3:0])
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
      case(CBb_mode_WR[3:0])
        CB_cov_vv: begin
          if(seq_cnt_WR == seq_cnt_max_WR)
            CB_addrb_base <= CB_addrb_base_raw;
          else
            CB_addrb_base <= 1'b1;
        end
        CB_cov_mv: begin
          if(seq_cnt_WR == seq_cnt_max_WR)
            CB_addrb_base <= CB_addrb_base_raw;
          else
            CB_addrb_base <= CB_addrb_base;
        end
        CB_cov_ml: begin
          CB_addrb_base <= CB_addrb_base;
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
          STAGE_PRD: l_k_AGD_en <= 1'b1;
          STAGE_NEW: l_k_AGD_en <= 1'b1;
          STAGE_UPD: l_k_AGD_en <= 1'b1;
          STAGE_ASSOC: l_k_AGD_en <= 1'b1;
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
        // case(CBa_mode[3:0])
        //   CB_cov_lv: begin
        //     if(seq_cnt == seq_cnt_max)
        //       l_k_base_addr_RD <= l_k_base_addr_RD + 3'b100;  //准备好 cov_lm的起始地址
        //     else
        //       l_k_base_addr_RD <= l_k_base_addr_raw;
        //   end
        //   CB_cov_lm: begin
        //     if(seq_cnt == seq_cnt_max)
        //       l_k_base_addr_RD <= l_k_base_addr_RD + 3'b100;
        //     else
        //       l_k_base_addr_RD <= l_k_base_addr_RD;
        //   end
        //   default:   l_k_base_addr_RD <= l_k_base_addr_raw;
        // endcase
        l_k_base_addr_RD <= l_k_base_addr_raw;
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
        case(CBb_mode_WR[3:0])
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
  //dout, 需多延迟1T
    always @(posedge clk) begin
      TB_douta_sel <= TB_douta_sel_new;
      TB_doutb_sel <= TB_doutb_sel_new;
      CB_douta_sel <= CB_douta_sel_new;
    end
  //din 不延迟
    assign  TB_dina_sel  = TB_dina_sel_new;
    assign  TB_dinb_sel  = TB_dinb_sel_new;
    assign  CB_dinb_sel  = CB_dinb_sel_new;

endmodule