module PE_config #(
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
  parameter ROW_LEN  = 10
) (
  input clk,
  input sys_rst,

//landmark numbers
  // input   [ROW_LEN-1 : 0]  landmark_num,
  // input   [ROW_LEN-1 : 0]  cov_row_num,
  // input   [ROW_LEN-1 : 0]  group_num,
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
  output reg [X-1 : 0]      A_in_en,   

  output  [B_IN_SEL_DW*Y-1 : 0]       B_in_sel,   
  output reg [Y-1 : 0]      B_in_en,  

  output  [M_IN_SEL_DW*X-1 : 0]       M_in_sel,  
  output reg [X-1 : 0]      M_in_en,   

  output  [C_OUT_SEL_DW*X-1 : 0]       C_out_sel, 
  output reg [X-1 : 0]      C_out_en,

  output  [TB_DINB_SEL_DW*L-1 : 0]       TB_dinb_sel,
  output  [TB_DOUTA_SEL_DW*L-1 : 0]       TB_douta_sel,
  output  [TB_DOUTB_SEL_DW*L-1 : 0]       TB_doutb_sel,

  output  [L-1 : 0]         TB_ena,
  output  [L-1 : 0]         TB_enb,

  output  [L-1 : 0]         TB_wea,
  output  [L-1 : 0]         TB_web,

  output reg [L*RSA_DW-1 : 0]  TB_dina,
  output  [L*TB_AW-1 : 0]      TB_addra,
  output  [L*TB_AW-1 : 0]      TB_addrb,

  output [CB_DINB_SEL_DW*L-1 : 0]      CB_dinb_sel,
  output [CB_DOUTA_SEL_DW*L-1 : 0]      CB_douta_sel,

  output [L-1 : 0]        CB_ena,
  output [L-1 : 0]        CB_enb,

  output [L-1 : 0]        CB_wea,
  output [L-1 : 0]        CB_web,

  output reg [L*RSA_DW-1 : 0] CB_dina,
  output [L*CB_AW-1 : 0]      CB_addra,
  output [L*CB_AW-1 : 0]      CB_addrb,

  output [2*X-1 : 0]          M_adder_mode, 
  output reg [1:0]            PE_mode,
  output  [Y-1 : 0]           new_cal_en,
  output  [Y-1 : 0]           new_cal_done

);
//delay
  localparam RD_DELAY = 3;
  localparam WR_DELAY = 2;
  localparam AGD_DELAY = 5;

  localparam RD_SEL_D = 'd1;
  localparam AB_IN_SEL_D = 'd3;
  localparam CAL_EN_D = 'd3;
  localparam PE_MODE_D = 'd4;
  localparam M_IN_SEL_D = 'd7;
  localparam C_OUT_SEL_D = 'd8;
  localparam WR_SEL_D = 'd9;

  localparam SET_2_PEin = 'd4;    //给出addr_new到westin

  localparam RD_2_WR = 'd10;
  
  localparam ADDER_2_NEW = 'd1;   //adder输出到给addr_new

//shift 
  localparam LEFT_SHIFT = 1'b0;
  localparam RIGHT_SHIFT = 1'b1;

//PE_mode
  localparam N_W = 2'b00;
  localparam S_W = 2'b10;
  localparam N_E = 2'b01;
  localparam S_E = 2'b11;

//A map mode
  localparam A_TBa = 2'b00;
  localparam A_CBa = 2'b10;

//B map mode
  localparam B_TBb = 2'b00;
  localparam B_CONS = 2'b01;
  localparam B_CBa = 2'b10;

//M map mode
  localparam M_TBa = 2'b00;
  localparam M_CBa = 2'b10;

//adder mode
  localparam NONE = 2'b00;
  localparam ADD = 2'b01;
  localparam C_MINUS_M = 2'b10;
  localparam M_MINUS_C = 2'b11;

//C map mode
  localparam  C_TBb = 2'b00;
  localparam  C_CBb = 2'b10;

//CB portA map mode
  localparam CB_IDLE = 2'b00;
  localparam CB_A = 2'b01;
  localparam CB_B = 2'b10;
  localparam CB_M = 2'b11;

//CB portB map mode

/*
    TB CB mode config!
*/
  //MODE[4:2] PARAMS
  localparam TBa_IDLE = 3'b000;
  localparam TBa_A = 3'b001;
  localparam TBa_M = 3'b001;
  localparam TBa_AM = 3'b011;

  localparam TBb_IDLE = 3'b000;
  localparam TBb_B = 3'b001;
  localparam TBb_C = 3'b001;
  localparam TBb_BC = 3'b011;
  localparam TBb_CONS_C = 3'b100;

  // localparam CBa_IDLE = 3'b000;
  // localparam CBa_A = 3'b001;
  // localparam CBa_B = 3'b010;
  // localparam CBa_M = 3'b100;

//from CB_DOUTA_MAP.v
  localparam CBa_IDLE = 2'b00;
  localparam CBa_A = 2'b01;
  localparam CBa_B = 2'b10;
  localparam CBa_M = 2'b11;

  localparam CBb_IDLE = 3'b000;
  localparam CBb_C = 3'b001;

  //MODE[1:0] PARAMS
  localparam DIR_IDLE = 2'b00;
  localparam DIR_POS  = 2'b01;
  localparam DIR_NEG  = 2'b10;
  localparam DIR_NEW  = 2'b11;

//stage
  localparam      IDLE     = 3'b000 ;
  localparam      STAGE_PRD  = 3'b001 ;
  localparam      STAGE_NEW  = 3'b010 ;
  localparam      STAGE_UPD  = 3'b100 ;
  // parameter      STAGE_INIT = 3'b111 ;

//stage_rdy
  localparam BUSY  = 3'b000;
  localparam READY   = 3'b111;

/*
  params of Prediction stage
*/
  // TEMP BANK offsets of PRD
    localparam F_xi = 'd0;
    localparam F_xi_T = 'd3;
    localparam t_cov = 'd6;
    localparam F_cov = 'd9;
    localparam M_t = 'd12;
  // PREDICTION SERIES
    localparam PRD_IDLE = 'b0000;
    localparam PRD_NONLINEAR = 'b0001;
    localparam PRD_1 = 'b0010;       //prd_cur[1]
    localparam PRD_2 = 'b0100;
    localparam PRD_3 = 'b1000;

    // localparam PRD_1_START = 0;
    // localparam PRD_2_START = 'd18;
    // localparam PRD_3_START = 'd36;

    localparam PRD_1_END = 'd17;
    localparam PRD_2_END = 'd17;
    localparam PRD_3_END = 'd5;

    localparam PRD_1_N = 3'b011;
    localparam PRD_2_N = 3'b011;
    localparam PRD_3_N = 3'b011;
    localparam PRD_3_DELAY = 4'd7;

/*
  NEW: params of New landmark initialization stage
*/
  // TEMP BANK offsets of PRD
    localparam G_xi          = 'd15;
    localparam G_z           = 'd18;
    localparam Q         = 'd20;
    localparam G_z_Q         = 'd22;
    localparam lv_G_xi           = 'd24;
  // PREDICTION SERIES
    localparam NEW_IDLE      = 'b000000;
    localparam NEW_NONLINEAR = 'b000001;
    localparam NEW_1         = 'b000010;       //prd_cur[1]
    localparam NEW_2         = 'b000100;
    localparam NEW_3         = 'b001000;
    localparam NEW_4         = 'b010000;
    localparam NEW_5         = 'b100000;

    localparam NEW_1_END     = 'd17;
    localparam NEW_2_END     = 'd17;
    localparam NEW_3_END     = 'd5;
    localparam NEW_4_END     = 'd5;
    localparam NEW_5_END     = 'd5;

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
  // // TEMP BANK offsets of PRD
  //   localparam G_xi          = 'd15;
  //   localparam G_z           = 'd18;
  //   localparam Q         = 'd20;
  //   localparam G_z_Q         = 'd22;
  //   localparam lv_G_xi           = 'd24;
  // // PREDICTION SERIES
  //   localparam NEW_IDLE      = 'b0000;
  //   localparam NEW_NONLINEAR = 'b0001;
  //   localparam NEW_1         = 'b0010;       //prd_cur[1]
  //   localparam NEW_2         = 'b0100;
  //   localparam NEW_3         = 'b1000;

  //   localparam NEW_1_END     = 'd17;
  //   localparam NEW_2_END     = 'd17;
  //   localparam NEW_3_END     = 'd5;

  //   localparam NEW_1_N       = 'd3;
  //   localparam NEW_2_N       = 'd3;
  //   localparam NEW_3_N       = 'd3;
  //   localparam NEW_3_DELAY   = 4'd7;

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

/*
  ****************CAL_mode config****************
*/
  //A_in_en 
  //B_in_en 
  //M_in_en 
  //C_out_en 

  reg [A_IN_SEL_DW-1:0] A_in_sel_new;
  reg [B_IN_SEL_DW-1:0] B_in_sel_new;
  reg [M_IN_SEL_DW-1:0] M_in_sel_new; 
  reg [1:0]             M_adder_mode_new;
  reg [C_OUT_SEL_DW-1:0] C_out_sel_new;

  reg A_in_sel_dir;
  reg B_in_sel_dir;
  reg M_in_sel_dir;
  reg C_out_sel_dir;

  reg cal_en_done_dir;

/*
  **************Address Generate Config*****************
*/
  //TB def
    reg                           TBa_shift_dir;
    reg                           TBb_shift_dir;
    reg [TB_DOUTA_SEL_DW-1:0]     TB_douta_sel_new;
    reg [TB_DINB_SEL_DW-1:0]      TB_dinb_sel_new;
    reg [TB_DOUTB_SEL_DW-1:0]     TB_doutb_sel_new;

    reg                           TB_ena_new;
    reg                           TB_wea_new;
    reg [TB_AW-1 : 0]             TB_addra_new;

    reg                           TB_enb_new;
    reg                           TB_web_new;
    reg [TB_AW-1 : 0]             TB_addrb_new;

  //CB def
    //port A
    reg [1:0]                     CBa_shift_dir; 
    reg [CB_DOUTA_SEL_DW-1:0]     CB_douta_sel_new;

    reg                           CB_ena_new;
    reg                           CB_wea_new;
    reg [CB_AW-1 : 0]             CB_addra_new;
    
    reg                           CBa_vm_AGD_en;
    reg                           CBa_vm_AGD_rst;
    wire [CB_AW-1 : 0]            CB_addra_base;

    //port B
    reg [1:0]                     CBb_shift_dir;
    reg [CB_DINB_SEL_DW-1:0]      CB_dinb_sel_new;

    reg                           CB_enb_new;
    reg                           CB_web_new;
    reg [CB_AW-1 : 0]             CB_addrb_new;

    reg                           CBb_vm_AGD_en;
    reg                           CBb_vm_AGD_rst;
    wire [CB_AW-1 : 0]            CB_addrb_base;

/*
  variables of FSM of STAGE(IDLE PRD NEW UPD)
*/

  reg [2:0]      stage_cur ;   
  reg          stage_change_err;  

/*
  variables of Prediction(PRD)
*/
  reg [3:0]   prd_cur;
  reg [5:0]   new_cur;
  reg [7:0]   upd_cur;
  reg [ROW_LEN-1:0]   seq_cnt;      //时序计数器
  reg [ROW_LEN-1:0]   group_cnt;    //组计数器（4行，2个地标为1组）
  reg [ROW_LEN-1 : 0] group_num;    //组数目
  reg [ROW_LEN-1 : 0]  landmark_num;

  //AGD control
  wire [1:0] landmark_num_10;
  assign landmark_num_10 = landmark_num[1:0];
  wire group_cnt_0;
  assign group_cnt_0 = group_cnt[0];

/*
  FSM of STAGE(IDLE PRD NEW UPD)
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
        default: begin
          if(group_cnt == group_num)
            stage_cur <= IDLE;
          else
            stage_cur <= stage_cur;
        end
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

  //(3)output: calculate the landmark number
  always @(posedge clk) begin
    if(sys_rst)
      landmark_num <= 0;
    else begin
      case(stage_rdy & stage_val)
        STAGE_NEW: landmark_num <= landmark_num + 1'b1;
        default: landmark_num <= landmark_num;
      endcase 
    end
  end
  
  //(3) output: group_num
  always @(posedge clk) begin
    if(sys_rst)
      group_num <= 0;
    else begin
      case(stage_rdy & stage_val)
        STAGE_PRD: group_num <= (landmark_num+1) >> 1;
        STAGE_NEW: group_num <= (landmark_num+1) >> 1;
        STAGE_UPD: group_num <= (landmark_num+1) >> 1;
        default: group_num <= group_num;
      endcase  
    end
  end
  
/*
  (old) FSM of PRD stage, with non-stopping seq_cnt
*/
  // //(1)&(2)sequential: state transfer & state switch
  // always @(posedge clk) begin
  //   if(stage_val & stage_rdy == STAGE_PRD) begin
  //     prd_cur <= PRD_IDLE;
  //   end
  //   else  begin
  //     case(prd_cur)
  //       PRD_IDLE: begin
  //         if(nonlinear_m_rdy & nonlinear_s_val == STAGE_PRD) begin
  //           prd_cur <= PRD_NONLINEAR;
  //         end
  //         else
  //           prd_cur <= PRD_IDLE;
  //       end
  //       PRD_NONLINEAR: begin
  //         if(nonlinear_m_val & nonlinear_s_rdy == STAGE_PRD) begin
  //           prd_cur <= PRD_1;
  //         end
  //         else
  //           prd_cur <= PRD_NONLINEAR;
  //       end
  //       PRD_1: begin
  //         if(seq_cnt ==  - 1) begin
  //           prd_cur <= PRD_2;
  //         end
  //         else
  //           prd_cur <= PRD_1;
  //       end
  //       PRD_2: begin
  //         if(seq_cnt == PRD_3_START - 1) begin
  //           prd_cur <= PRD_3;
  //         end
  //         else
  //           prd_cur <= PRD_2;
  //       end
  //       PRD_3: begin
  //         if(seq_cnt == PRD_3_END) begin
  //           prd_cur <= PRD_IDLE;
  //         end
  //         else
  //           prd_cur <= PRD_3;
  //       end
  //       default: begin
  //         prd_cur <= PRD_IDLE;
  //       end
  //     endcase
  //   end
  // end

  // //Prediciton cnt
  // always @(posedge clk) begin
  //   if(sys_rst) begin
  
  //   end
  //   else if(stage_val & stage_rdy != IDLE)
  
  //   else begin
  //     case(stage_cur)  
  //       STAGE_PRD: begin
  //         case(prd_cur)
  //           PRD
  //           PRD_NONL
  //           default: seq_cnt <= seq_cnt + 1'b1;
  //         endcase
  //       end
  //       STAGE_NEW: begin
          
  //       end
  //       STAGE_UPD: begin
          
  //       end
  //       de
  //     endcase
  //   end
  // end

/*
  (using) FSM of PRD stage, with seq_cnt back to 0 when prd_cur changes
*/
//(1)&(2)sequential: state transfer & state switch
  /*
    PRD state transfer
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
            if(seq_cnt == PRD_1_END) begin
              prd_cur <= PRD_2;
            end
            else begin
              prd_cur <= PRD_1;
            end
          end
          PRD_2: begin
            if(seq_cnt == PRD_2_END) begin
              prd_cur <= PRD_3;
            end
            else begin
              prd_cur <= PRD_2;
            end
          end
          PRD_3: begin
            if(group_cnt == group_num) begin
              prd_cur <= PRD_IDLE;
            end
            else if(seq_cnt == PRD_3_END) begin
              prd_cur <= PRD_3;
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
    NEW state transfer
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
            if(seq_cnt == NEW_1_END) begin
              new_cur <= NEW_2;
            end
            else begin
              new_cur <= NEW_1;
            end
          end
          NEW_2: begin
            if(seq_cnt == NEW_2_END) begin
              new_cur <= NEW_3;
            end
            else begin
              new_cur <= NEW_2;
            end
          end
          NEW_3: begin
            if(group_cnt == group_num) begin
              new_cur <= NEW_IDLE;
            end
            else if(seq_cnt == NEW_3_END) begin
              new_cur <= NEW_3;
            end
            else begin
              new_cur <= NEW_3;
            end
          end
          default: begin
            new_cur <= NEW_IDLE;
          end
        endcase
      end
    end
/*
  calculate seq_cnt
*/
  always @(posedge clk) begin
    if(stage_val & stage_rdy == STAGE_PRD) begin
      seq_cnt <= 0;
    end
    else  begin
      case(stage_cur)
        STAGE_PRD: begin
          case(prd_cur)
            PRD_IDLE: begin
              seq_cnt <= 0;
            end
            PRD_NONLINEAR: begin
              seq_cnt <= 0;
            end
            PRD_1: begin
              if(seq_cnt == PRD_1_END) begin
                seq_cnt <= 0;
              end
              else begin
                seq_cnt <= seq_cnt + 1'b1;
              end    
            end
            PRD_2: begin
              if(seq_cnt == PRD_2_END) begin
                seq_cnt <= 0;
              end
              else begin
                seq_cnt <= seq_cnt + 1'b1;
              end
            end
            PRD_3: begin
              if(group_cnt == group_num) begin
                seq_cnt <= 0;
              end
              else if(seq_cnt == PRD_3_END) begin
                seq_cnt <= 0;
              end
              else begin
                seq_cnt <= seq_cnt + 1'b1;
              end
            end
            default: begin
              seq_cnt <= 0;
            end
          endcase
          end
        
        STAGE_NEW: begin
          case(new_cur)
            NEW_IDLE: begin
              seq_cnt <= 0;
            end
            NEW_NONLINEAR: begin
              seq_cnt <= 0;
            end
            NEW_1: begin
              if(seq_cnt == NEW_1_END) begin
                seq_cnt <= 0;
              end
              else begin
                seq_cnt <= seq_cnt + 1'b1;
              end    
            end
            NEW_2: begin
              if(seq_cnt == NEW_2_END) begin
                seq_cnt <= 0;
              end
              else begin
                seq_cnt <= seq_cnt + 1'b1;
              end
            end
            NEW_3: begin
              if(group_cnt == group_num) begin
                seq_cnt <= 0;
              end
              else if(seq_cnt == NEW_3_END) begin
                seq_cnt <= 0;
              end
              else begin
                seq_cnt <= seq_cnt + 1'b1;
              end
            end
            default: begin
              seq_cnt <= 0;
            end
          endcase
        end

        STAGE_UPD: begin
          
        end

        default: seq_cnt <= 0;
      endcase
    end
  end

/*
  (3) calculate group_cnt
*/
  always @(posedge clk) begin
    if(sys_rst) begin
      group_cnt <= 0;
    end
    else begin
      case(prd_cur)
        PRD_3: begin
          if(group_cnt == group_num) begin
            group_cnt <= 0;
          end
          else if(seq_cnt == PRD_3_END) begin
            group_cnt <= group_cnt + 1'b1;
          end
          else begin
            group_cnt <= group_cnt;
          end
        end
        default: begin
          group_cnt <= 0;
        end
      endcase
    end   
  end

/*
  (3) output: nonlinear_val, addr, en, we, val,
*/
  always @(posedge clk) begin
    if(sys_rst)
      nonlinear_m_rdy <= 0;
    else if(prd_cur == PRD_IDLE) begin
      nonlinear_m_rdy <= 1'b1;
    end
    else
      nonlinear_m_rdy <= 0;  
  end 

  always @(posedge clk) begin
    if(sys_rst)
      nonlinear_m_val <= 0;
    else if(prd_cur == PRD_NONLINEAR) begin
      nonlinear_m_val <= 1'b1;
    end
    else
      nonlinear_m_val <= 0;  
  end 


//(4) output: 配置A B M C输入模式
  // always @(posedge clk) begin
  //   if(sys_rst) begin
  //     A_in_en <= 4'b0000;  
  //     B_in_en <= 4'b0000;
  //     M_in_en <= 4'b0000;
  //     C_out_en <= 4'b0000;
      
  //     A_in_sel_new <= 2'b00;   
  //     B_in_sel_new <= 2'b00;
  //     M_in_sel_new <= 2'b00;
  //     // C_out_sel_new <= 2'b00;

  //     // C_map_mode   <= TB_DIR_POS;
  //     PE_mode <= N_W;
  //     M_adder_mode_new <= 2'b00;

  //     A_shift_dir <= LEFT_SHIFT;
  //     B_shift_dir <= LEFT_SHIFT;
  //     M_shift_dir <= LEFT_SHIFT;
  //     C_shift_dir <= LEFT_SHIFT;
  //   end
  //   else begin
  //     case(stage_cur)
  //       IDLE: begin
  //         A_in_en <= 4'b0000;  
  //         B_in_en <= 4'b0000;
  //         M_in_en <= 4'b0000;
  //         C_out_en <= 4'b0000;
          
  //         A_in_sel_new <= 2'b00;  
  //         B_in_sel_new <= 2'b00;
  //         M_in_sel_new <= 2'b00;
  //         // C_out_sel_new <= 2'b00;
          
  //         // C_map_mode   <= TB_DIR_POS;
  //         PE_mode <= N_W;
  //         M_adder_mode_new <= 2'b00;
  //       end
  //       STAGE_PRD: begin
  //         case(prd_cur)
  //           PRD_1: begin
  //           /*
  //             F_xi * t_cov = F_cov
  //             X=3 Y=3 N=3
  //             Ain: TB-A
  //             bin: TB-B
  //             Cout: TB-A
  //           */
  //             A_in_en <= 4'b0111;  
  //             B_in_en <= 4'b0111;
  //             M_in_en <= 4'b0000;
  //             C_out_en <= 4'b0111;
              
  //             A_in_sel_new <= 2'b00;   
  //             B_in_sel_new <= 2'b00;
  //             M_in_sel_new <= 2'b00;
  //             // C_out_sel_new <= 2'b00;

  //             // C_map_mode   <= TB_DIR_POS;
  //             PE_mode <= N_W;
  //             M_adder_mode_new <= 2'b00;
            
  //           end
  //           PRD_2: begin
  //           /*
  //             F_cov * t_cov + M= cov
  //             X=3 Y=3 N=3
  //             Ain: TB-A
  //             Bin: TB-B
  //             Min: 0    //actual M input time is in PRD_3
  //             Cout: CB-B
  //           */
  //             A_in_en <= 4'b0111;  
  //             B_in_en <= 4'b0111;
  //             M_in_en <= 4'b0111;
  //             C_out_en <= 4'b0111;
              
  //             A_in_sel_new <= 2'b00;  
  //             B_in_sel_new <= 2'b00;
  //             M_in_sel_new <= 2'b00;
  //             // C_out_sel_new <= 2'b00;

  //             // C_map_mode   <= TB_DIR_POS;
  //             PE_mode <= N_W;
  //             M_adder_mode_new <= 2'b01;
  //           end
  //           PRD_3: begin
  //           /*
  //             cov_mv * F_xi_T = cov_mv
  //             X=3 Y=3 N=3
  //             Ain: CB-A
  //             Bin: TB-B
  //             Min: TB-A   //PRD_2 adder
  //             Cout: CB-B
  //           */
  //             A_in_en <= 4'b1111;  
  //             B_in_en <= 4'b0111;
  //             M_in_en <= 4'b0000;
  //             C_out_en <= 4'b1111;
              
  //             A_in_sel_new <= 2'b10; 
  //             B_in_sel_new <= 2'b00;
  //             M_in_sel_new <= 2'b00;
  //             // C_out_sel_new <= 2'b10;

  //             // C_map_mode   <= CB_DIR_POS;
  //             PE_mode <= N_W;
  //             M_adder_mode_new <= 2'b00;
  //           end
  //           default: begin
  //             A_in_en <= 4'b0000;  
  //             B_in_en <= 4'b0000;
  //             M_in_en <= 4'b0000;
  //             C_out_en <= 4'b0000;
              
  //             A_in_sel_new <= 2'b00;   
  //             B_in_sel_new <= 2'b00;
  //             M_in_sel_new <= 2'b00;
  //             // C_out_sel_new <= 2'b00;

  //             // C_map_mode   <= TB_DIR_POS;
  //             PE_mode <= N_W;
  //             M_adder_mode_new <= 2'b00;
  //           end
  //         endcase
  //       end
  //       STAGE_NEW: begin
  //         case(new_cur)
  //           NEW_1: begin
  //           /*
  //             F_xi * t_cov = F_cov
  //             X=3 Y=3 N=3
  //             Ain: TB-A
  //             bin: TB-B
  //             Cout: TB-A
  //           */
  //             A_in_en <= 4'b0011;  
  //             B_in_en <= 4'b0111;
  //             M_in_en <= 4'b0000;
  //             C_out_en <= 4'b0011;
              
  //             A_in_sel_new <= 2'b00;   
  //             B_in_sel_new <= 2'b00;
  //             M_in_sel_new <= 2'b00;
  //             // C_out_sel_new <= 2'b00;

  //             // C_map_mode   <= TB_DIR_POS;
  //             PE_mode <= N_W;
  //             M_adder_mode_new <= 2'b00;
            
  //           end
  //           NEW_2: begin
  //           /*
  //             F_cov * t_cov + M= cov
  //             X=3 Y=3 N=3
  //             Ain: TB-A
  //             Bin: TB-B
  //             Min: 0    //actual M input time is in NEW_3
  //             Cout: CB-B
  //           */
  //             A_in_en <= 4'b0011;  
  //             B_in_en <= 4'b1111;
  //             M_in_en <= 4'b0000;
  //             C_out_en <= 4'b0011;
              
  //             A_in_sel_new <= 2'b00;  

  //             case(group_num[0])
  //               1'b0: B_in_sel_new <= 2'b11;  //逆向
  //               1'b1: B_in_sel_new <= 2'b10;  //正向
  //             endcase

  //             case(group_num[0])
  //               1'b0: B_shift_dir <= RIGHT_SHIFT;  //逆向
  //               1'b1: B_shift_dir <= LEFT_SHIFT;  //正向
  //             endcase
              
  //             M_in_sel_new <= 2'b00;
  //             // C_out_sel_new <= 2'b00;

  //             // case(landmark_num[1:0])
  //             //   2'b00: C_map_mode   <= DIR_NEW_00;
  //             //   2'b01: C_map_mode   <= DIR_NEW_01;
  //             //   2'b10: C_map_mode   <= DIR_NEW_10;
  //             //   2'b11: C_map_mode   <= DIR_NEW_11;
  //             // endcase

  //             PE_mode <= N_W;
  //             M_adder_mode_new <= 2'b00;
  //           end
  //           NEW_3: begin
  //           /*
  //             cov_mv * F_xi_T = cov_mv
  //             X=3 Y=3 N=3
  //             Ain: CB-A
  //             Bin: TB-B
  //             Min: TB-A   //NEW_2 adder
  //             Cout: CB-B
  //           */
  //             A_in_en <= 4'b0011;  
  //             B_in_en <= 4'b0011;
  //             M_in_en <= 4'b0000;
  //             C_out_en <= 4'b0011;
              
  //             A_in_sel_new <= 2'b10; 
  //             B_in_sel_new <= 2'b00;
  //             M_in_sel_new <= 2'b00;
  //             // C_out_sel_new <= 2'b10;

  //             // C_map_mode   <= CB_DIR_POS;
  //             PE_mode <= N_W;
  //             M_adder_mode_new <= 2'b00;
  //           end
  //           default: begin
  //             A_in_en <= 4'b0000;  
  //             B_in_en <= 4'b0000;
  //             M_in_en <= 4'b0000;
  //             C_out_en <= 4'b0000;
              
  //             A_in_sel_new <= 2'b00;   
  //             B_in_sel_new <= 2'b00;
  //             M_in_sel_new <= 2'b00;
  //             // C_out_sel_new <= 2'b00;

  //             // C_map_mode   <= TB_DIR_POS;
  //             PE_mode <= N_W;
  //             M_adder_mode_new <= 2'b00;
  //           end
  //         endcase
  //       end
  //       STAGE_UPD: begin
          
  //       end
        
  //     endcase
  //   end  
  // end

/*
  ************************* RSA work-mode Config **************************
*/
  /*
    DATA FLOW Config
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

      TBa_mode <= {TBa_A,DIR_IDLE};
      TBb_mode <= {TBb_B,DIR_IDLE};
      // CBa_mode <= {CBa_IDLE,DIR_IDLE};
      // CBb_mode <= {CBb_C,DIR_POS};

      A_TB_base_addr <= 0;
      B_TB_base_addr <= 0;
      M_TB_base_addr <= 0;
      C_TB_base_addr <= 0;
    end
    else begin
      case(stage_cur)
        STAGE_NEW: begin
          case(new_cur)
            NEW_1: begin
            /*
              G_xi * t_cov = cov_lm
              X=2 Y=2 N=3
              Ain: TB-A
              bin: TB-B
              Cout: CB-B
            */
              PE_m <= NEW_1_M;
              PE_n <= NEW_1_N;
              PE_k <= NEW_1_K;

              CAL_mode <= N_W;

              A_in_mode <= A_TBa;   
              B_in_mode <= B_TBb;
              M_in_mode <= M_TBa;
              C_out_mode <= C_CBb;
              M_adder_mode_set <= NONE;

              TBa_mode <= {TBa_A,DIR_POS};
              TBb_mode <= {TBb_B,DIR_POS};
              // CBa_mode <= {CBa_IDLE,DIR_IDLE};
              // CBb_mode <= {CBb_C,DIR_POS};

              A_TB_base_addr <= G_xi;
              B_TB_base_addr <= t_cov;
              M_TB_base_addr <= 0;
              C_TB_base_addr <= 0;
              
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
              PE_m <= NEW_2_M;
              PE_n <= NEW_2_N;
              PE_k <= NEW_2_K;

              CAL_mode <= N_W;

              A_in_mode <= A_TBa;   
              B_in_mode <= B_CBa;
              M_in_mode <= M_TBa;
              C_out_mode <= C_CBb;
              M_adder_mode_set <= NONE;

              TBa_mode <= {TBa_A,DIR_POS};
              TBb_mode <= {TBb_IDLE,DIR_IDLE};
              // CBa_mode <= group_cnt[0] ? {CBa_B,DIR_NEG} : {CBa_B,DIR_POS}; //0-POS 1-NEG
              // CBb_mode <= {CBb_C,DIR_NEW};

              A_TB_base_addr <= G_xi;
              B_TB_base_addr <= 0;
              M_TB_base_addr <= 0;
              C_TB_base_addr <= 0;
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
              PE_m <= NEW_1_M;
              PE_n <= NEW_1_N;
              PE_k <= NEW_1_K;

              CAL_mode <= N_W;

              A_in_mode <= A_TBa;   
              B_in_mode <= B_TBb;
              M_in_mode <= M_TBa;
              C_out_mode <= C_CBb;
              M_adder_mode_set <= NONE;

              TBa_mode <= {TBa_IDLE,DIR_IDLE};
              TBb_mode <= {TBb_BC,DIR_POS};
              // CBa_mode <= {CBa_A,DIR_NEW}; //0-POS 1-NEG
              // CBb_mode <= {CBb_IDLE,DIR_IDLE};

              A_TB_base_addr <= 0;
              B_TB_base_addr <= G_xi;
              M_TB_base_addr <= 0;
              C_TB_base_addr <= lv_G_xi;
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
              PE_m <= NEW_1_M;
              PE_n <= NEW_1_N;
              PE_k <= NEW_1_K;

              CAL_mode <= N_W;

              A_in_mode <= A_TBa;   
              B_in_mode <= B_TBb;
              M_in_mode <= M_TBa;
              C_out_mode <= C_CBb;
              M_adder_mode_set <= NONE;

              TBa_mode <= {TBa_A,DIR_POS};
              TBb_mode <= {TBb_BC,DIR_POS};
              // CBa_mode <= {CBa_IDLE,DIR_IDLE}; 
              // CBb_mode <= {CBb_IDLE,DIR_IDLE};

              A_TB_base_addr <= G_z;
              B_TB_base_addr <= Q;
              M_TB_base_addr <= 0;
              C_TB_base_addr <= G_z_Q;
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
              PE_m <= NEW_1_M;
              PE_n <= NEW_1_N;
              PE_k <= NEW_1_K;

              CAL_mode <= N_W;

              A_in_mode <= A_TBa;   
              B_in_mode <= B_TBb;
              M_in_mode <= M_TBa;
              C_out_mode <= C_CBb;
              M_adder_mode_set <= NONE;

              TBa_mode <= {TBa_AM,DIR_POS};
              TBb_mode <= {TBb_B,DIR_POS};
              // CBa_mode <= {CBa_IDLE,DIR_IDLE}; 
              // CBb_mode <= {CBb_C,DIR_NEW};

              A_TB_base_addr <= G_z_Q;
              B_TB_base_addr <= G_z;
              M_TB_base_addr <= lv_G_xi;
              C_TB_base_addr <= 0;
            end
            default: begin
              PE_m <= 0;
              PE_n <= 0;
              PE_k <= 0;

              CAL_mode <= N_W;

              A_in_mode <= A_TBa;   
              B_in_mode <= B_TBb;
              M_in_mode <= M_TBa;
              C_out_mode <= C_CBb;
              M_adder_mode_set <= NONE;

              TBa_mode <= {TBa_A,DIR_IDLE};
              TBb_mode <= {TBb_B,DIR_IDLE};
              // CBa_mode <= {CBa_IDLE,DIR_IDLE};
              // CBb_mode <= {CBb_C,DIR_POS};

              A_TB_base_addr <= 0;
              B_TB_base_addr <= 0;
              M_TB_base_addr <= 0;
              C_TB_base_addr <= 0;
            end
          endcase
        end
        STAGE_UPD: begin
          
        end
        
      endcase
    end  
  end

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
  dynamic_shreg 
  #(
    .DW    (A_IN_SEL_DW    ),
    .AW    (3    ),
    .DEPTH (AB_IN_SEL_D )
  )
  A_in_sel_dynamic_shreg(
  	.clk  (clk  ),
    .ce   (1'b1   ),
    .addr (AB_IN_SEL_D ),
    .din  (A_in_mode  ),
    .dout (A_in_sel_new )
  );

  dynamic_shreg 
  #(
    .DW    (B_IN_SEL_DW    ),
    .AW    (3    ),
    .DEPTH (AB_IN_SEL_D )
  )
  B_in_sel_dynamic_shreg(
  	.clk  (clk  ),
    .ce   (1'b1   ),
    .addr (AB_IN_SEL_D ),
    .din  (B_in_mode  ),
    .dout (B_in_sel_new )
  );

  dynamic_shreg 
  #(
    .DW    (M_IN_SEL_DW    ),
    .AW    (3    ),
    .DEPTH (M_IN_SEL_D )
  )
  M_in_sel_dynamic_shreg(
  	.clk  (clk  ),
    .ce   (1'b1   ),
    .addr (M_IN_SEL_D ),
    .din  (M_in_mode  ),
    .dout (M_in_sel_new )
  );

  dynamic_shreg 
  #(
    .DW    (M_IN_SEL_DW    ),
    .AW    (3    ),
    .DEPTH (M_IN_SEL_D )
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
    .AW    (3    ),
    .DEPTH (C_OUT_SEL_D )
  )
  C_out_sel_dynamic_shreg(
  	.clk  (clk  ),
    .ce   (1'b1   ),
    .addr (C_OUT_SEL_D ),
    .din  (C_out_mode  ),
    .dout (C_out_sel_new )
  );

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
      A_in_sel_dir <= LEFT_SHIFT;
      B_in_sel_dir <= LEFT_SHIFT;
      M_in_sel_dir <= LEFT_SHIFT;
      C_out_sel_dir <= LEFT_SHIFT;
    end
    else begin
      case(CAL_mode_d[AB_IN_SEL_D])
        N_W: begin
          A_in_sel_dir <= LEFT_SHIFT;
          B_in_sel_dir <= LEFT_SHIFT;
          M_in_sel_dir <= LEFT_SHIFT;
          C_out_sel_dir <= LEFT_SHIFT;
        end
        S_W: begin
          A_in_sel_dir <= RIGHT_SHIFT;
          B_in_sel_dir <= LEFT_SHIFT;
          M_in_sel_dir <= RIGHT_SHIFT;
          C_out_sel_dir <= RIGHT_SHIFT;
        end 
        N_E: begin
          A_in_sel_dir <= LEFT_SHIFT;
          B_in_sel_dir <= RIGHT_SHIFT;
          M_in_sel_dir <= LEFT_SHIFT;
          C_out_sel_dir <= LEFT_SHIFT;
        end
        S_E: begin
          A_in_sel_dir <= RIGHT_SHIFT;
          B_in_sel_dir <= RIGHT_SHIFT;
          M_in_sel_dir <= RIGHT_SHIFT;
          C_out_sel_dir <= RIGHT_SHIFT;
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
          cal_en_done_dir <= LEFT_SHIFT;
        end
        S_W: begin
          cal_en_done_dir <= LEFT_SHIFT;
        end 
        N_E: begin
          cal_en_done_dir <= RIGHT_SHIFT;
        end
        S_E: begin
          cal_en_done_dir <= RIGHT_SHIFT;
        end
      endcase
    end
  end

  always @(posedge clk) begin
    if(sys_rst) begin
      PE_mode <= N_W;
    end
    else begin
      PE_mode <= CAL_mode_d[PE_MODE_D];
    end
  end
/*
  ********************** address generate config *********************
*/

  /*
    *****************************TB-portA*****************************
  */
  always @(posedge clk) begin
    if(sys_rst) begin
      TB_douta_sel_new <= 3'b000;  

      TB_ena_new <= 1'b0;
      TB_wea_new <= 1'b0;
      TB_addra_new <= 0;
    end
    else begin
      case(TBa_mode[4:2])
        TBa_A: begin
          if(seq_cnt >= 1 && seq_cnt <= PE_n) begin
            TB_douta_sel_new[2] <= 1'b0;
            TB_ena_new <= 1'b1;
            TB_wea_new <= 1'b0;
            TB_addra_new <= A_TB_base_addr + seq_cnt - 1'b1;
          end
          else begin
            TB_ena_new <= 1'b0;
            TB_wea_new <= 1'b0;
            TB_addra_new <= 0;
          end
        end
        TBa_M: begin
          //M[1]
          if(seq_cnt == PE_n + 2'b10) begin
            TB_douta_sel_new[2] <= 1'b1;
            TB_ena_new <= 1'b1;
            TB_wea_new <= 1'b0;
            TB_addra_new <= M_TB_base_addr;
          end
          //M[2]
          else if(seq_cnt == PE_n + 3'b100) begin
              TB_ena_new <= 1'b1;
              TB_wea_new <= 1'b0;
              TB_addra_new <= M_TB_base_addr + 1'b1;
          end
          //M[3]
          else if(seq_cnt == PE_n + 3'b110 && PE_k == 3'b11) begin
              TB_ena_new <= 1'b1;
              TB_wea_new <= 1'b0;
              TB_addra_new <= M_TB_base_addr + 2'b10;
          end
          else begin
              TB_ena_new <= 1'b0;
              TB_wea_new <= 1'b0;
              TB_addra_new <= 0;
          end
        end
        TBa_AM: begin
          if(seq_cnt >= 1 && seq_cnt <= PE_n) begin
            TB_douta_sel_new[2] <= 1'b0;
            TB_ena_new <= 1'b1;
            TB_wea_new <= 1'b0;
            TB_addra_new <= A_TB_base_addr + seq_cnt - 1'b1;
          end
          //M[1]
          else if(seq_cnt == PE_n + 2'b10) begin
            TB_douta_sel_new[2] <= 1'b1;
            TB_ena_new <= 1'b1;
            TB_wea_new <= 1'b0;
            TB_addra_new <= M_TB_base_addr;
          end
          //M[2]
          else if(seq_cnt == PE_n + 3'b100) begin
              TB_ena_new <= 1'b1;
              TB_wea_new <= 1'b0;
              TB_addra_new <= M_TB_base_addr + 1'b1;
          end
          //M[3]
          else if(seq_cnt == PE_n + 3'b110 && PE_k == 3'b11) begin
              TB_ena_new <= 1'b1;
              TB_wea_new <= 1'b0;
              TB_addra_new <= M_TB_base_addr + 2'b10;
          end
          else begin
              TB_ena_new <= 1'b0;
              TB_wea_new <= 1'b0;
              TB_addra_new <= 0;
          end
        end
        default: begin
          TB_ena_new <= 1'b0;
          TB_wea_new <= 1'b0;
          TB_addra_new <= 0;
        end
      endcase
    end 
  end

  reg [4:0] TBa_mode_d;
  always @(posedge clk) begin
    if(sys_rst) begin
      TBa_mode_d <= 0;
    end
    else 
      TBa_mode_d <= TBa_mode;
  end

  always @(posedge clk) begin
    if(sys_rst) begin
      TB_douta_sel_new[1:0] = DIR_IDLE;
      TBa_shift_dir <= 0;
    end
    else begin
      case(TBa_mode_d[1:0])
        DIR_IDLE: begin
          TB_douta_sel_new[1:0] = DIR_IDLE;
          TBa_shift_dir <= LEFT_SHIFT;
        end
        DIR_POS: begin
          TB_douta_sel_new[1:0] = DIR_POS;
          TBa_shift_dir <= LEFT_SHIFT;
        end
        DIR_NEG: begin
          TB_douta_sel_new[1:0] = DIR_NEG;
          TBa_shift_dir <= RIGHT_SHIFT;
        end
        DIR_NEW: begin
          TB_douta_sel_new[1:0] = DIR_NEW;
          TBa_shift_dir <= LEFT_SHIFT;
        end
      endcase
    end
  end

  /*
    *****************************TB-portB*****************************
  */
  always @(posedge clk) begin
    if(sys_rst) begin
      TB_dinb_sel_new  <= 2'b00;
      TB_doutb_sel_new <= 3'b000;  

      TB_enb_new <= 1'b0;
      TB_web_new <= 1'b0;
      TB_addrb_new <= 0;
    end
    else begin
      case(TBb_mode[4:2])
        TBb_B: begin
          if(seq_cnt >= 1 && seq_cnt <= PE_n) begin
            TB_doutb_sel_new[2] <= 1'b0;
            TB_enb_new <= 1'b1;
            TB_web_new <= 1'b0;
            TB_addrb_new <= B_TB_base_addr + seq_cnt - 1'b1;
          end
          else begin
            TB_enb_new <= 1'b0;
            TB_web_new <= 1'b0;
            TB_addrb_new <= 0;
          end
        end
        TBb_C: begin
          //C[1]
          if(seq_cnt == 1'b1 + SET_2_PEin + PE_n + 2'b10 + ADDER_2_NEW) begin
            TB_enb_new <= 1'b1;
            TB_web_new <= 1'b1;
            TB_addrb_new <= C_TB_base_addr;
          end
          //C[2]
          else if(seq_cnt == 1'b1 + SET_2_PEin + PE_n + 2'b10 + ADDER_2_NEW + 2'b10) begin
              TB_enb_new <= 1'b1;
              TB_web_new <= 1'b1;
              TB_addrb_new <= C_TB_base_addr + 1'b1;
          end
          //C[3]
          else if(seq_cnt == 1'b1 + SET_2_PEin + PE_n + 2'b10 + ADDER_2_NEW + 3'b100 && PE_k == 3'b11) begin
              TB_enb_new <= 1'b1;
              TB_web_new <= 1'b1;
              TB_addrb_new <= C_TB_base_addr + 2'b10;
          end
          else begin
              TB_enb_new <= 1'b0;
              TB_web_new <= 1'b0;
              TB_addrb_new <= 0;
          end
        end
        TBb_BC: begin
          if(seq_cnt >= 1 && seq_cnt <= PE_n) begin
            TB_doutb_sel_new[2] <= 1'b0;
            TB_enb_new <= 1'b1;
            TB_web_new <= 1'b0;
            TB_addrb_new <= B_TB_base_addr + seq_cnt - 1'b1;
          end
          //C[1]
          else if(seq_cnt == 1'b1 + SET_2_PEin + PE_n + 2'b10 + ADDER_2_NEW) begin
            TB_enb_new <= 1'b1;
            TB_web_new <= 1'b1;
            TB_addrb_new <= C_TB_base_addr;
          end
          //C[2]
          else if(seq_cnt == 1'b1 + SET_2_PEin + PE_n + 2'b10 + ADDER_2_NEW + 2'b10) begin
              TB_enb_new <= 1'b1;
              TB_web_new <= 1'b1;
              TB_addrb_new <= C_TB_base_addr + 1'b1;
          end
          //C[3]
          else if(seq_cnt == 1'b1 + SET_2_PEin + PE_n + 2'b10 + ADDER_2_NEW + 3'b100 && PE_k == 3'b11) begin
              TB_enb_new <= 1'b1;
              TB_web_new <= 1'b1;
              TB_addrb_new <= C_TB_base_addr + 2'b10;
          end
          else begin
              TB_enb_new <= 1'b0;
              TB_web_new <= 1'b0;
              TB_addrb_new <= 0;
          end
        end
        TBb_CONS_C: begin
          if(seq_cnt >= 1 && seq_cnt <= PE_n) begin
            TB_doutb_sel_new[2] <= 1'b1;
            TB_enb_new <= 1'b1;
            TB_web_new <= 1'b0;
            TB_addrb_new <= B_TB_base_addr + seq_cnt - 1'b1;
          end
          //C[1]
          else if(seq_cnt == 1'b1 + SET_2_PEin + PE_n + 2'b10 + ADDER_2_NEW) begin
            TB_enb_new <= 1'b1;
            TB_web_new <= 1'b1;
            TB_addrb_new <= C_TB_base_addr;
          end
          //C[2]
          else if(seq_cnt == 1'b1 + SET_2_PEin + PE_n + 2'b10 + ADDER_2_NEW + 2'b10) begin
              TB_enb_new <= 1'b1;
              TB_web_new <= 1'b1;
              TB_addrb_new <= C_TB_base_addr + 1'b1;
          end
          //C[3]
          else if(seq_cnt == 1'b1 + SET_2_PEin + PE_n + 2'b10 + ADDER_2_NEW + 3'b100 && PE_k == 3'b11) begin
              TB_enb_new <= 1'b1;
              TB_web_new <= 1'b1;
              TB_addrb_new <= C_TB_base_addr + 2'b10;
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
          TBb_shift_dir <= LEFT_SHIFT;
        end
        DIR_POS: begin
          TB_doutb_sel_new[1:0] = DIR_POS;
          TBb_shift_dir <= LEFT_SHIFT;
        end
        DIR_NEG: begin
          TB_doutb_sel_new[1:0] = DIR_NEG;
          TBb_shift_dir <= RIGHT_SHIFT;
        end
        DIR_NEW: begin
          TB_doutb_sel_new[1:0] = DIR_NEW;
          TBb_shift_dir <= LEFT_SHIFT;
        end
      endcase
    end
  end

  /*
    *****************************CB-portA READ*****************************
  */

  // reg [4:0] CBa_mode_d;
  // always @(posedge clk) begin
  //   if(sys_rst) begin
  //     CBa_mode_d <= 0;
  //     CBa_shift_dir <= DIR_IDLE;
  //   end
  //   else begin
  //     CBa_mode_d <= CBa_mode;
  //     case (CBa_mode_d[4:2])
  //       CBa_A: CB_douta_sel_new <= 
  //       default: 
  //     endcase
  //     CBa_shift_dir <= CBa_mode_d[1:0];
  //   end 
  // end

  /*
    *****************************CB-portB*****************************
  */

//(old1, using PRD_1_START) 配置TB A B端口 输入数据及数据选择
  //   always @(posedge clk) begin
  //     if(sys_rst) begin
  //       TB_douta_sel_new <= 1'b0;  
  //       TB_dinb_sel_new <= 1'b0;
  //       TB_doutb_sel_new <= 1'b0;

  //       TB_ena_new <= 1'b0;
  //       TB_wea_new <= 1'b0;
  //       TB_addra_new <= 0;

  //       TB_enb_new <= 1'b0;
  //       TB_web_new <= 1'b0;
  //       TB_addrb_new <= 0;
  //     end
  //     else begin
  //       case(stage_cur)
  //         IDLE: begin
  //           TB_douta_sel_new <= 1'b0;  
  //           TB_dinb_sel_new <= 1'b0;
  //           TB_doutb_sel_new <= 1'b0;

  //           TB_ena_new <= 1'b0;
  //           TB_wea_new <= 1'b0;
  //           TB_addra_new <= 0;

  //           TB_enb_new <= 1'b0;
  //           TB_web_new <= 1'b0;
  //           TB_addrb_new <= 0;
  //         end
  //         STAGE_PRD: begin
  //           case(prd_cur)
  //             PRD_1: begin
  //             /*
  //               F_xi * t_cov = F_cov
  //               X=3 Y=3 N=3
  //               Ain: TB-A
  //               bin: TB-B
  //               Cout: TB-A
  //             */
  //               TB_douta_sel_new <= 1'b0;  
  //               TB_dinb_sel_new <= 1'b0;
  //               TB_doutb_sel_new <= 1'b0;
                
  //               if (seq_cnt < PRD_1_START+PRD_1_N) begin
  //                 TB_ena_new <= 1'b1;
  //                 TB_wea_new <= 1'b0;
  //                 TB_addra_new <= F_xi + seq_cnt;

  //                 TB_enb_new <= 1'b1;
  //                 TB_web_new <= 1'b0;
  //                 TB_addrb_new <= t_cov + seq_cnt;
  //               end
  //               else if(seq_cnt == SET_2_PEin+PRD_1_N+2+ADDER_2_NEW) begin
  //                 TB_ena_new <= 1'b0;
  //                 TB_wea_new <= 1'b0;
  //                 TB_addra_new <= 0;

  //                 TB_enb_new <= 1'b1;
  //                 TB_web_new <= 1'b1;
  //                 TB_addrb_new <= F_cov;
  //               end
  //               else if(seq_cnt == SET_2_PEin+PRD_1_N+2+ADDER_2_NEW + 2) begin
  //                 TB_ena_new <= 1'b0;
  //                 TB_wea_new <= 1'b0;
  //                 TB_addra_new <= 0;

  //                 TB_enb_new <= 1'b1;
  //                 TB_web_new <= 1'b1;
  //                 TB_addrb_new <= F_cov + 1'b1;
  //               end
  //               else if(seq_cnt == SET_2_PEin+PRD_1_N+2+ADDER_2_NEW + 4) begin
  //                 TB_ena_new <= 1'b0;
  //                 TB_wea_new <= 1'b0;
  //                 TB_addra_new <= 0;

  //                 TB_enb_new <= 1'b1;
  //                 TB_web_new <= 1'b1;
  //                 TB_addrb_new <= F_cov + 2'b10;
  //               end
  //               else begin
  //                 TB_ena_new <= 1'b0;
  //                 TB_wea_new <= 1'b0;
  //                 TB_addra_new <= 0;

  //                 TB_enb_new <= 1'b0;
  //                 TB_web_new <= 1'b0;
  //                 TB_addrb_new <= 0;
  //               end
  //             end
  //             PRD_2: begin
  //             /*
  //               F_cov * t_cov + M= cov
  //               X=3 Y=3 N=3
  //               Ain: TB-A
  //               Bin: TB-B
  //               Min: 0    //actual M input time is in PRD_3
  //               Cout: CB-B
  //             */
  //               TB_dinb_sel_new <= 1'b0;
  //               TB_doutb_sel_new <= 1'b0;
                
  //               if (seq_cnt < +PRD_1_N) begin
  //                 TB_ena_new <= 1'b1;
  //                 TB_wea_new <= 1'b0;
  //                 TB_addra_new <= F_cov -  + seq_cnt;
                  
  //                 TB_douta_sel_new <= 1'b0;  

  //                 TB_enb_new <= 1'b1;
  //                 TB_web_new <= 1'b0;
  //                 TB_addrb_new <= F_xi -  + seq_cnt;
  //               end
  //               else if(seq_cnt ==  + PRD_2_N + 1) begin
  //                 TB_ena_new <= 1'b1;
  //                 TB_wea_new <= 1'b0;
  //                 TB_addra_new <= M_t;
                  
  //                 TB_douta_sel_new <= 1'b1; 

  //                 TB_enb_new <= 1'b0;
  //                 TB_web_new <= 1'b0;
  //                 TB_addrb_new <= 0;
  //               end
  //               else if(seq_cnt ==  + PRD_2_N + 3) begin
  //                 TB_ena_new <= 1'b1;
  //                 TB_wea_new <= 1'b0;
  //                 TB_addra_new <= M_t + 1'b1;

  //                 TB_enb_new <= 1'b0;
  //                 TB_web_new <= 1'b0;
  //                 TB_addrb_new <= 0;
  //               end
  //               else if(seq_cnt ==  + PRD_2_N + 5) begin
  //                 TB_ena_new <= 1'b1;
  //                 TB_wea_new <= 1'b0;
  //                 TB_addra_new <= M_t + 2'b10;

  //                 TB_enb_new <= 1'b0;
  //                 TB_web_new <= 1'b0;
  //                 TB_addrb_new <= 0;
  //               end
  //               else if(seq_cnt ==  + SET_2_PEin+PRD_2_N+2+ADDER_2_NEW) begin
  //                 TB_ena_new <= 1'b0;
  //                 TB_wea_new <= 1'b0;
  //                 TB_addra_new <= 0;

  //                 TB_enb_new <= 1'b1;
  //                 TB_web_new <= 1'b1;
  //                 TB_addrb_new <= t_cov;
  //               end
  //               else if(seq_cnt ==  + SET_2_PEin+PRD_1_N+2+ADDER_2_NEW + 2) begin
  //                 TB_ena_new <= 1'b0;
  //                 TB_wea_new <= 1'b0;
  //                 TB_addra_new <= 0;

  //                 TB_enb_new <= 1'b1;
  //                 TB_web_new <= 1'b1;
  //                 TB_addrb_new <= t_cov + 1'b1;
  //               end
  //               else if(seq_cnt ==  + SET_2_PEin+PRD_1_N+2+ADDER_2_NEW + 4) begin
  //                 TB_ena_new <= 1'b0;
  //                 TB_wea_new <= 1'b0;
  //                 TB_addra_new <= 0;

  //                 TB_enb_new <= 1'b1;
  //                 TB_web_new <= 1'b1;
  //                 TB_addrb_new <= t_cov + 2'b10;
  //               end
  //               else begin
  //                 TB_ena_new <= 1'b0;
  //                 TB_wea_new <= 1'b0;
  //                 TB_addra_new <= 0;

  //                 TB_enb_new <= 1'b0;
  //                 TB_web_new <= 1'b0;
  //                 TB_addrb_new <= 0;
  //               end
  //             end
  //             PRD_3: begin
  //             /*
  //               cov_mv * F_xi_T = cov_mv
  //               X=3 Y=3 N=3
  //               Ain: CB-A
  //               Bin: TB-B
  //               Min: TB-A   //PRD_2 adder
  //               Cout: CB-B
  //             */
  //             end
  //             default: begin
  //               TB_douta_sel_new <= 1'b0;  
  //               TB_dinb_sel_new <= 1'b0;
  //               TB_doutb_sel_new <= 1'b0;

  //               TB_ena_new <= 1'b0;
  //               TB_wea_new <= 1'b0;
  //               TB_addra_new <= 0;

  //               TB_enb_new <= 1'b0;
  //               TB_web_new <= 1'b0;
  //               TB_addrb_new <= 0;
  //             end
  //           endcase
  //         end
  //         STAGE_NEW: begin
            
  //         end
  //         STAGE_UPD: begin
            
  //         end
          
  //       endcase
  //     end  
        
  //   end

//(old2, using PRD_1_END, manual) 配置TB A B端口 输入数据及数据选择
  // always @(posedge clk) begin
  //   if(sys_rst) begin
  //     TB_douta_sel_new <= 2'b00;  
  //     TB_dinb_sel_new <= 1'b0;
  //     TB_doutb_sel_new <= 1'b0;

  //     TB_ena_new <= 1'b0;
  //     TB_wea_new <= 1'b0;
  //     TB_addra_new <= 0;

  //     TB_enb_new <= 1'b0;
  //     TB_web_new <= 1'b0;
  //     TB_addrb_new <= 0;
  //   end
  //   else begin
  //     case(stage_cur)
  //       IDLE: begin
  //         TB_douta_sel_new <= 2'b00;   
  //         TB_dinb_sel_new <= 1'b0;
  //         TB_doutb_sel_new <= 1'b0;

  //         TB_ena_new <= 1'b0;
  //         TB_wea_new <= 1'b0;
  //         TB_addra_new <= 0;

  //         TB_enb_new <= 1'b0;
  //         TB_web_new <= 1'b0;
  //         TB_addrb_new <= 0;
  //       end
  //       STAGE_PRD: begin
  //         case(prd_cur)
  //           PRD_1: begin
  //           /*
  //             F_xi * t_cov = F_cov
  //             X=3 Y=3 N=3
  //             Ain: TB-A
  //             bin: TB-B
  //             Cout: TB-A
  //           */
  //             TB_douta_sel_new <= 2'b00;   
  //             TB_dinb_sel_new <= 1'b0;
  //             TB_doutb_sel_new <= 1'b0;
              
  //             if (seq_cnt < PRD_1_N) begin
  //               TB_ena_new <= 1'b1;
  //               TB_wea_new <= 1'b0;
  //               TB_addra_new <= F_xi + seq_cnt;

  //               TB_enb_new <= 1'b1;
  //               TB_web_new <= 1'b0;
  //               TB_addrb_new <= t_cov + seq_cnt;
  //             end
  //             else if(seq_cnt == SET_2_PEin+PRD_1_N+2+ADDER_2_NEW) begin
  //               TB_ena_new <= 1'b0;
  //               TB_wea_new <= 1'b0;
  //               TB_addra_new <= 0;

  //               TB_enb_new <= 1'b1;
  //               TB_web_new <= 1'b1;
  //               TB_addrb_new <= F_cov;
  //             end
  //             else if(seq_cnt == SET_2_PEin+PRD_1_N+2+ADDER_2_NEW + 2) begin
  //               TB_ena_new <= 1'b0;
  //               TB_wea_new <= 1'b0;
  //               TB_addra_new <= 0;

  //               TB_enb_new <= 1'b1;
  //               TB_web_new <= 1'b1;
  //               TB_addrb_new <= F_cov + 1'b1;
  //             end
  //             else if(seq_cnt == SET_2_PEin+PRD_1_N+2+ADDER_2_NEW + 4) begin
  //               TB_ena_new <= 1'b0;
  //               TB_wea_new <= 1'b0;
  //               TB_addra_new <= 0;

  //               TB_enb_new <= 1'b1;
  //               TB_web_new <= 1'b1;
  //               TB_addrb_new <= F_cov + 2'b10;
  //             end
  //             else begin
  //               TB_ena_new <= 1'b0;
  //               TB_wea_new <= 1'b0;
  //               TB_addra_new <= 0;

  //               TB_enb_new <= 1'b0;
  //               TB_web_new <= 1'b0;
  //               TB_addrb_new <= 0;
  //             end
  //           end
  //           PRD_2: begin
  //           /*
  //             F_cov * t_cov + M= cov
  //             X=3 Y=3 N=3
  //             Ain: TB-A
  //             Bin: TB-B
  //             Min: 0    //actual M input time is in PRD_3
  //             Cout: CB-B
  //           */
  //             TB_dinb_sel_new <= 1'b0;
  //             TB_doutb_sel_new <= 1'b0;
              
  //             if (seq_cnt < PRD_2_N) begin
  //               TB_ena_new <= 1'b1;
  //               TB_wea_new <= 1'b0;
  //               TB_addra_new <= F_cov + seq_cnt;
                
  //               TB_douta_sel_new <= 2'b00;   

  //               TB_enb_new <= 1'b1;
  //               TB_web_new <= 1'b0;
  //               TB_addrb_new <= F_xi + seq_cnt;
  //             end
  //             else if(seq_cnt == PRD_2_N + 1) begin
  //               TB_ena_new <= 1'b1;
  //               TB_wea_new <= 1'b0;
  //               TB_addra_new <= M_t;
                
  //               TB_douta_sel_new <= 2'b10; 

  //               TB_enb_new <= 1'b0;
  //               TB_web_new <= 1'b0;
  //               TB_addrb_new <= 0;
  //             end
  //             else if(seq_cnt == PRD_2_N + 3) begin
  //               TB_ena_new <= 1'b1;
  //               TB_wea_new <= 1'b0;
  //               TB_addra_new <= M_t + 1'b1;

  //               TB_enb_new <= 1'b0;
  //               TB_web_new <= 1'b0;
  //               TB_addrb_new <= 0;
  //             end
  //             else if(seq_cnt == PRD_2_N + 5) begin
  //               TB_ena_new <= 1'b1;
  //               TB_wea_new <= 1'b0;
  //               TB_addra_new <= M_t + 2'b10;

  //               TB_enb_new <= 1'b0;
  //               TB_web_new <= 1'b0;
  //               TB_addrb_new <= 0;
  //             end
  //             else if(seq_cnt == SET_2_PEin+PRD_2_N+2+ADDER_2_NEW) begin
  //               TB_ena_new <= 1'b0;
  //               TB_wea_new <= 1'b0;
  //               TB_addra_new <= 0;

  //               TB_enb_new <= 1'b1;
  //               TB_web_new <= 1'b1;
  //               TB_addrb_new <= t_cov;
  //             end
  //             else if(seq_cnt == SET_2_PEin+PRD_1_N+2+ADDER_2_NEW + 2) begin
  //               TB_ena_new <= 1'b0;
  //               TB_wea_new <= 1'b0;
  //               TB_addra_new <= 0;

  //               TB_enb_new <= 1'b1;
  //               TB_web_new <= 1'b1;
  //               TB_addrb_new <= t_cov + 1'b1;
  //             end
  //             else if(seq_cnt == SET_2_PEin+PRD_1_N+2+ADDER_2_NEW + 4) begin
  //               TB_ena_new <= 1'b0;
  //               TB_wea_new <= 1'b0;
  //               TB_addra_new <= 0;

  //               TB_enb_new <= 1'b1;
  //               TB_web_new <= 1'b1;
  //               TB_addrb_new <= t_cov + 2'b10;
  //             end
  //             else begin
  //               TB_ena_new <= 1'b0;
  //               TB_wea_new <= 1'b0;
  //               TB_addra_new <= 0;

  //               TB_enb_new <= 1'b0;
  //               TB_web_new <= 1'b0;
  //               TB_addrb_new <= 0;
  //             end
  //           end
  //           PRD_3: begin
  //           /*
  //             cov_mv * F_xi_T = cov_mv
  //             X=3 Y=3 N=3
  //             Ain: CB-A
  //             Bin: TB-B
  //             Min: TB-A   //PRD_2 adder
  //             Cout: CB-B
  //           */
  //             TB_dinb_sel_new <= 1'b0;
  //             TB_doutb_sel_new <= 1'b0;
              
  //             TB_douta_sel_new <= 2'b00;   
  //             TB_ena_new <= 1'b0;
  //             TB_wea_new <= 1'b0;
  //             TB_addra_new <= 0;
  //             if (seq_cnt < PRD_1_N) begin
  //               TB_enb_new <= 1'b1;
  //               TB_web_new <= 1'b0;
  //               TB_addrb_new <= F_xi + seq_cnt;
  //             end
  //             else begin
  //               TB_enb_new <= 1'b0;
  //               TB_web_new <= 1'b0;
  //               TB_addrb_new <= 0;
  //             end
  //           end
  //           default: begin
  //             TB_douta_sel_new <= 1'b0;  
  //             TB_dinb_sel_new <= 1'b0;
  //             TB_doutb_sel_new <= 1'b0;

  //             TB_ena_new <= 1'b0;
  //             TB_wea_new <= 1'b0;
  //             TB_addra_new <= 0;

  //             TB_enb_new <= 1'b0;
  //             TB_web_new <= 1'b0;
  //             TB_addrb_new <= 0;
  //           end
  //         endcase
  //       end
  //       STAGE_NEW: begin
          
  //       end
  //       STAGE_UPD: begin
          
  //       end
        
  //     endcase
  //   end  
      
  // end

//配置 CB-portA 输入数据及数据选择
  
/*
  *****************************CB-portA READ*****************************
*/  
  always @(posedge clk) begin
    if(sys_rst) begin
      CBa_shift_dir <= DIR_POS;
      CB_douta_sel_new <= {CBa_IDLE, DIR_IDLE};  

      CB_ena_new <= 1'b0;
      CB_wea_new <= 1'b0;
      CB_addra_new <= 0;

      CBa_vm_AGD_en <= 0;
      CBa_vm_AGD_rst <= 0;
    end
    else begin
      case(stage_cur)
        IDLE: begin
          CBa_shift_dir <= DIR_POS;
          CB_douta_sel_new <= {CBa_IDLE, DIR_IDLE};  

          CB_ena_new <= 1'b0;
          CB_wea_new <= 1'b0;
          CB_addra_new <= 0;

          CBa_vm_AGD_en <= 0;
          CBa_vm_AGD_rst <= 0;
        end
        STAGE_PRD: begin
          case(prd_cur)
            PRD_3: begin
            /*
              cov_mv * F_xi_T = cov_mv
              X=3 Y=3 N=3
              Ain: CB-A
              Bin: TB-B
              Min: TB-A   //PRD_2 adder
              Cout: CB-B
            */  
              CB_wea_new <= 1'b0;
              case(seq_cnt)
                'd0: begin
                  CB_ena_new <= 1'b0;
                  CB_addra_new <= 0;
                end  
                'd1: begin
                  CBa_shift_dir <= DIR_POS;
                  CB_ena_new <= 1'b1;
                  CB_addra_new <= CB_addra_base;
                end     
                'd2: begin
                  CB_douta_sel_new <= {CBa_A, DIR_POS};
                  CB_ena_new <= 1'b1;
                  CB_addra_new <= CB_addra_base + 'b1;
                end
                'd3: begin
                  CB_ena_new <= 1'b1;
                  CB_addra_new <= CB_addra_base + 'b10;
                  CBa_vm_AGD_en <= 1'b1;
                end
                'd4: begin
                  CB_ena_new <= 1'b0;
                  CB_addra_new <= 0;
                end
                'd5: begin
                  CB_ena_new <= 1'b0;
                  CB_addra_new <= 0;
                  CBa_vm_AGD_en <= 1'b0;
                end
                default: begin
                  CB_ena_new <= 1'b0;
                  CB_addra_new <= 0;
                end
              endcase 
            end
            default: begin
              CBa_shift_dir <= DIR_POS;
              CB_douta_sel_new <= {CBa_IDLE, DIR_IDLE};  

              CB_ena_new <= 1'b0;
              CB_wea_new <= 1'b0;
              CB_addra_new <= 0;

              CBa_vm_AGD_en <= 0;
              CBa_vm_AGD_rst <= 0;
            end
          endcase
        end
        STAGE_NEW: begin
          case(prd_cur)
            NEW_2: begin
              CB_wea_new <= 1'b0;
                case(seq_cnt)
                  'd0: begin
                    CB_ena_new <= 1'b0;
                    CB_addra_new <= 0;
                  end  
                  'd1: begin
                    CBa_shift_dir <= group_cnt[0] ? DIR_NEG : DIR_POS; //0-POS 1-NEG
                    CB_ena_new <= 1'b1;
                    CB_addra_new <= CB_addra_base;
                  end     
                  'd2: begin
                    CB_douta_sel_new <= group_cnt[0] ? {CBa_B,DIR_NEG} : {CBa_B,DIR_POS}; //0-POS 1-NEG
                    CB_ena_new <= 1'b1;
                    CB_addra_new <= CB_addra_base + 'b1;
                  end
                  'd3: begin
                    CB_ena_new <= 1'b1;
                    CB_addra_new <= CB_addra_base + 'b10;
                    CBa_vm_AGD_en <= 1'b1;
                  end
                  'd4: begin
                    CB_ena_new <= 1'b0;
                    CB_addra_new <= 0;
                  end
                  'd5: begin
                    CB_ena_new <= 1'b0;
                    CB_addra_new <= 0;
                    CBa_vm_AGD_en <= 1'b0;
                  end
                  default: begin
                    CB_ena_new <= 1'b0;
                    CB_addra_new <= 0;
                  end
                endcase 
            end
            NEW_3: begin
              CB_wea_new <= 1'b0;
                case(seq_cnt)
                  'd0: begin
                    CB_ena_new <= 1'b0;
                    CB_addra_new <= 0;
                  end  
                  'd1: begin
                    CBa_shift_dir <= DIR_NEW; //0-POS 1-NEG
                    CB_ena_new <= 1'b1;
                    CB_addra_new <= CB_addra_base;
                  end     
                  'd2: begin
                    CB_douta_sel_new <= DIR_NEW;
                    CB_ena_new <= 1'b1;
                    CB_addra_new <= CB_addra_base + 'b1;
                  end
                  'd3: begin
                    CB_ena_new <= 1'b1;
                    CB_addra_new <= CB_addra_base + 'b10;
                    CBa_vm_AGD_en <= 1'b1;
                  end
                  'd4: begin
                    CB_ena_new <= 1'b0;
                    CB_addra_new <= 0;
                  end
                  'd5: begin
                    CB_ena_new <= 1'b0;
                    CB_addra_new <= 0;
                    CBa_vm_AGD_en <= 1'b0;
                  end
                  default: begin
                    CB_ena_new <= 1'b0;
                    CB_addra_new <= 0;
                  end
                endcase 
            end
          endcase
        end
        STAGE_UPD: begin
          
        end
        
      endcase
    end       
  end

//CB portB
  wire [2:0]       stage_cur_CB_B;
  wire [3:0]       prd_cur_CB_B;
  wire [ROW_LEN-1 : 0] seq_cnt_CB_B;
  wire [ROW_LEN-1 : 0] group_cnt_CB_B;

  //stage_cur, prd_cur, seq_cnt, group_cnt的七级延迟（7=N+2+2）
    dynamic_shreg 
    #(
      .DW  (3  ),
      .AW  (4  )
    )
    stage_cur_shreg(
      .clk  (clk  ),
      .ce   (1'b1   ),
      .addr (PRD_3_DELAY ),
      .din  (stage_cur  ),
      .dout (stage_cur_CB_B )
    );
    
    dynamic_shreg 
    #(
      .DW  (4  ),
      .AW  (4  )
    )
    prd_cur_shreg(
      .clk  (clk  ),
      .ce   (1'b1  ),
      .addr (PRD_3_DELAY ),
      .din  (prd_cur  ),
      .dout (prd_cur_CB_B )
    );
    
    dynamic_shreg 
    #(
      .DW  (ROW_LEN  ),
      .AW  (4  )
    )
    seq_cnt_shreg(
      .clk  (clk  ),
      .ce   (1'b1  ),
      .addr (PRD_3_DELAY ),
      .din  (seq_cnt  ),
      .dout (seq_cnt_CB_B )
    );

    dynamic_shreg 
    #(
      .DW  (ROW_LEN  ),
      .AW  (4  )
    )
    group_cnt_shreg(
      .clk  (clk  ),
      .ce   (1'b1  ),
      .addr (PRD_3_DELAY ),
      .din  (group_cnt  ),
      .dout (group_cnt_CB_B )
    );

/*
    ************************ CB-portB config *****************
*/
  always @(posedge clk) begin
    if(sys_rst) begin   
      CB_dinb_sel_new <= 1'b0;

      CB_enb_new <= 1'b0;
      CB_web_new <= 1'b0;
      CB_addrb_new <= 0;

      CBb_vm_AGD_en <= 0;
    end
    else begin
      case(stage_cur_CB_B)
        IDLE: begin   
          CB_dinb_sel_new <= 1'b0;

          CB_enb_new <= 1'b0;
          CB_web_new <= 1'b0;
          CB_addrb_new <= 0;
        end
        STAGE_PRD: begin
          case(prd_cur_CB_B)
            PRD_3: begin
            /*
              cov_mv * F_xi_T = cov_mv
              X=3 Y=3 N=3
              Ain: CB-A
              Bin: TB-B
              Min: TB-A   //PRD_2 adder
              Cout: CB-B
            */  
              CB_dinb_sel_new <= 1'b0;

              CB_web_new <= 1'b1;

              case(seq_cnt_CB_B)
                'd0: begin
                  CB_enb_new <= 1'b1;
                  CB_addrb_new <= CB_addrb_base;
                end  
                'd1: begin
                  CB_enb_new <= 1'b0;
                  CB_addrb_new <= 0;
                end
                'd2: begin
                  CB_enb_new <= 1'b1;
                  CB_addrb_new <= CB_addrb_base + 'b1;
                  CBb_vm_AGD_en <= 1'b1;
                end
                'd3: begin
                  CB_enb_new <= 1'b0;
                  CB_addrb_new <= 0;
                end
                'd4: begin
                  CB_enb_new <= 1'b1;
                  CB_addrb_new <= CB_addrb_base + 'b10;
                  CBb_vm_AGD_en <= 1'b0;
                end
                'd5: begin
                  CB_enb_new <= 1'b0;
                  CB_addrb_new <= 0;
                end
                default: begin
                  CB_enb_new <= 1'b0;
                  CB_addrb_new <= 0;
                end
              endcase 
            end
            default: begin
              CB_dinb_sel_new <= 1'b0;

              CB_enb_new <= 1'b0;
              CB_web_new <= 1'b0;
              CB_addrb_new <= 0;
            end
          endcase
        end
        STAGE_NEW: begin
          
        end
        STAGE_UPD: begin
          
        end
        
      endcase
    end       
  end

/*
  new_cal_en & new_cal_done
*/
  wire [ROW_LEN-1 : 0] seq_cnt_cal_en;
  dynamic_shreg 
    #(
      .DW  (ROW_LEN  ),
      .AW  (2  )
    )
    seq_cnt_cal_en_shreg(
      .clk  (clk  ),
      .ce   (1'b1  ),
      .addr (2'b11 ),
      .din  (seq_cnt  ),
      .dout (seq_cnt_cal_en )
    );

  reg new_cal_en_new;
  reg new_cal_done_new;
  //由于实际的new_cal_en[0]为new_cal_en_new的一级延迟，所以均比实际数据流提前一个T
  always @(posedge clk) begin
    if(sys_rst) begin
      new_cal_en_new <= 0;
    end
    else begin
      case(prd_cur)
        PRD_1: begin
          if(seq_cnt >= SET_2_PEin -1'b1 && seq_cnt < SET_2_PEin + PRD_1_N -1'b1) begin
            new_cal_en_new <= 1'b1;
          end
          else
            new_cal_en_new <= 1'b0;
        end
        PRD_2: begin
          if(seq_cnt >= SET_2_PEin -1'b1 && seq_cnt < SET_2_PEin + PRD_2_N -1'b1) begin
            new_cal_en_new <= 1'b1;
          end
          else
            new_cal_en_new <= 1'b0;
        end
        PRD_3: begin
          if(seq_cnt_cal_en >= 0 && seq_cnt_cal_en <= PRD_2_N -1'b1) begin
            new_cal_en_new <= 1'b1;
          end
          else
            new_cal_en_new <= 1'b0;
        end
        default:  new_cal_en_new <= 1'b0;
      endcase
    end  
  end

  always @(posedge clk) begin
    if(sys_rst)
      new_cal_done_new <= 0;
    else begin
      case(prd_cur)
        PRD_1: begin
          if(seq_cnt == SET_2_PEin + PRD_1_N -1'b1) begin
            new_cal_done_new <= 1'b1;
          end
          else
            new_cal_done_new <= 1'b0;
        end
        PRD_2: begin
          if(seq_cnt == SET_2_PEin + PRD_2_N -1'b1) begin
            new_cal_done_new <= 1'b1;
          end
          else
            new_cal_done_new <= 1'b0;
        end
        PRD_3: begin
          if(seq_cnt_cal_en == PRD_2_N) begin
            new_cal_done_new <= 1'b1;
          end
          else
            new_cal_done_new <= 1'b0;
        end
        default:  new_cal_done_new <= 1'b0;
      endcase
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
      .dir   (PE_mode[1]   ),
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
      .dir   (PE_mode[1]   ),
      .din   (new_cal_done_new   ),
      .dout  (new_cal_done  )
    );
    

//CB_dina, TB_dina
always @(posedge clk) begin
  if(sys_rst)
    TB_dina <= 0;
  else 
    TB_dina <= 0;
end
always @(posedge clk) begin
  if(sys_rst)
    CB_dina <= 0;
  else 
    CB_dina <= 0;
end


/*
  prd_cur_M & prd_cur_C
  M：4级延迟
  均为读取
  从输入数据到得到dout N+1=4

  C：9级延迟(3 + 5 + 1)

  从输入地址到给写入地址
  * 输入地址到输入数据 3
  * 输入数据到输出结果 N+2=5
  * 输出结果到给写入地址 1

*/
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
      .sys_rst ( sys_rst),
      .din  (TB_wea_new  ),
      .dout (TB_wea )
    );

    dshift 
    #(
      .DW  (TB_DOUTA_SEL_DW ),
      .DEPTH (L )
    )
    TB_douta_sel_dshift(
      .clk  (clk  ),
      .dir  (TBa_shift_dir   ),
      .sys_rst ( sys_rst),
      .din  (TB_douta_sel_new  ),
      .dout (TB_douta_sel )
    );

    dshift 
    #(
      .DW  (TB_AW  ),
      .DEPTH (L )
    )
    TB_addra_dshift(
      .clk  (clk  ),
      .dir   (TBa_shift_dir   ),
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
      .sys_rst ( sys_rst),
      .din  (TB_web_new  ),
      .dout (TB_web )
    );

    dshift 
    #(
      .DW  (TB_DINB_SEL_DW ),
      .DEPTH (L )
    )
    TB_dinb_sel_dshift(
      .clk  (clk  ),
      .dir   (TBb_shift_dir   ),
      .sys_rst ( sys_rst),
      .din  (TB_dinb_sel_new  ),
      .dout (TB_dinb_sel )
    );

    dshift 
    #(
      .DW  (TB_DOUTB_SEL_DW ),
      .DEPTH (L )
    )
    TB_doutb_sel_dshift(
      .clk  (clk  ),
      .sys_rst ( sys_rst),
      .dir   (TBb_shift_dir   ),
      .din  (TB_doutb_sel_new  ),
      .dout (TB_doutb_sel )
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
      .din  (TB_addrb_new  ),
      .dout (TB_addrb )
    );

/*
  *********************shift of CB-portA****************
*/
    CB_vm_AGD 
    #(
      .CB_AW   (CB_AW   ),
      .ROW_LEN (ROW_LEN )
    )
    CBa_vm_AGD(
    	.clk          (clk          ),
      .sys_rst      (sys_rst      ),
      .en           (CBa_vm_AGD_en           ),
      .user_reset   (CBa_vm_AGD_rst   ),
      .group_cnt    (group_cnt    ),
      .CB_base_addr (CB_addra_base )
    );

    CB_dshift 
    #(
      .DW  (1 ),
      .DEPTH (L )
    )
    CB_ena_dshift(
      .clk  (clk  ),
      .sys_rst ( sys_rst),
      .CB_dir          (CBa_shift_dir          ),
      .landmark_num_10 (landmark_num_10 ),
      .din  (CB_ena_new  ),
      .dout (CB_ena )
    );

    CB_dshift 
    #(
      .DW  (1 ),
      .DEPTH (L )
    )
    CB_wea_dshift(
      .clk  (clk  ),
      .sys_rst ( sys_rst),
      .CB_dir          (CBa_shift_dir          ),
      .landmark_num_10 (landmark_num_10 ),
      .din  (CB_wea_new  ),
      .dout (CB_wea )
    );

    CB_addr_shift 
    #(
      .L           (L           ),
      .CB_AW       (CB_AW       ),
      .ROW_LEN     (ROW_LEN     )
    )
    CB_addra_shift(
    	.clk             (clk             ),
      .sys_rst         (sys_rst         ),
      .CB_dir          (CBa_shift_dir          ),
      .landmark_num_10 (landmark_num_10 ),
      .group_cnt_0     (group_cnt_0     ),
      .CB_en_new       (CB_ena_new       ),
      .CB_en           (CB_ena           ),
      .CB_addr_new     (CB_addra_new     ),
      .CB_addr         (CB_addra        )
    );

    CB_dshift 
    #(
      .DW  (CB_DOUTA_SEL_DW ),
      .DEPTH (L )
    )
    CB_douta_sel_dshift(
      .clk  (clk  ),
      .sys_rst ( sys_rst),
      .CB_dir          (CBa_shift_dir          ),
      .landmark_num_10 (landmark_num_10 ),
      .din  (CB_douta_sel_new  ),
      .dout (CB_douta_sel )
    );
    
    
/*
  *********************shift of CB-portB****************
*/
    CB_vm_AGD 
    #(
      .CB_AW   (CB_AW   ),
      .ROW_LEN (ROW_LEN )
    )
    CBb_vm_AGD(
    	.clk          (clk          ),
      .sys_rst      (sys_rst      ),
      .en           (CBb_vm_AGD_en           ),
      .user_reset   (CBb_vm_AGD_rst   ),
      .group_cnt    (group_cnt    ),
      .CB_base_addr (CB_addrb_base )
    );

    CB_dshift 
    #(
      .DW  (1 ),
      .DEPTH (L )
    )
    CB_enb_dshift(
      .clk  (clk  ),
      .sys_rst ( sys_rst),
      .CB_dir          (CBb_shift_dir          ),
      .landmark_num_10 (landmark_num_10 ),
      .din  (CB_enb_new  ),
      .dout (CB_enb )
    );

    CB_dshift 
    #(
      .DW  (1 ),
      .DEPTH (L )
    )
    CB_web_dshift(
      .clk  (clk  ),
      .sys_rst ( sys_rst),
      .CB_dir          (CBb_shift_dir          ),
      .landmark_num_10 (landmark_num_10 ),
      .din  (CB_web_new  ),
      .dout (CB_web )
    );

    CB_addr_shift 
    #(
      .L           (L           ),
      .CB_AW       (CB_AW       ),
      .ROW_LEN     (ROW_LEN     )
    )
    CB_addrb_shift(
    	.clk             (clk             ),
      .sys_rst         (sys_rst         ),
      .CB_dir          (CBb_shift_dir          ),
      .landmark_num_10 (landmark_num_10 ),
      .group_cnt_0     (group_cnt_0     ),
      .CB_en_new       (CB_enb_new       ),
      .CB_en           (CB_enb           ),
      .CB_addr_new     (CB_addrb_new     ),
      .CB_addr         (CB_addrb       )
    );

    CB_dshift 
    #(
      .DW  (CB_DINB_SEL_DW ),
      .DEPTH (L )
    )
    CB_dinb_sel_dshift(
      .clk  (clk  ),
      .sys_rst ( sys_rst),
      .CB_dir          (CBb_shift_dir          ),
      .landmark_num_10 (landmark_num_10 ),
      .din  (CB_dinb_sel_new  ),
      .dout (CB_dinb_sel )
    );

endmodule