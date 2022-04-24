module PE_config #(
  parameter X = 4,
  parameter Y = 4,
  parameter L = 4,

  parameter RSA_DW = 16,
  parameter TB_AW = 11,
  parameter CB_AW = 17,

  parameter MAX_LANDMARK = 500,
  parameter ROW_LEN  = 10
) (
  input clk,
  input sys_rst,

//landmark numbers
  input   [ROW_LEN-1 : 0]  landmark_num,
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
  output  [2*X-1 : 0]         A_in_sel,
  output reg [X-1 : 0]        A_in_en,   

  output  [2*Y-1 : 0]         B_in_sel,   
  output reg [Y-1 : 0]        B_in_en,  

  output  [2*X-1 : 0]         M_in_sel,  
  output reg [X-1 : 0]        M_in_en,  
  output [2*X-1 : 0]          M_adder_mode,  

  // output  [2*X-1 : 0]        C_out_sel, 
  output reg [2:0]           C_map_mode,
  output reg [X-1 : 0]       C_out_en,

  output  [L-1 : 0]        TB_dinb_sel,
  output  [2*L-1 : 0]        TB_douta_sel,
  output  [L-1 : 0]        TB_doutb_sel,

  output  [L-1 : 0]        TB_ena,
  output  [L-1 : 0]        TB_enb,

  output  [L-1 : 0]        TB_wea,
  output  [L-1 : 0]        TB_web,

  output reg [L*RSA_DW-1 : 0]    TB_dina,
  output  [L*TB_AW-1 : 0]      TB_addra,
  output  [L*TB_AW-1 : 0]      TB_addrb,

  output [L-1 : 0]        CB_dinb_sel,
  output [3*L-1 : 0]        CB_douta_sel,

  output [L-1 : 0]        CB_ena,
  output [L-1 : 0]        CB_enb,

  output [L-1 : 0]        CB_wea,
  output [L-1 : 0]        CB_web,

  output reg [L*RSA_DW-1 : 0]     CB_dina,
  output [L*CB_AW-1 : 0]      CB_addra,
  output [L*CB_AW-1 : 0]      CB_addrb,

  output reg [1:0]   PE_mode,
  output  [Y-1 : 0] new_cal_en,
  output  [Y-1 : 0] new_cal_done

);
//delay
  localparam RD_DELAY = 3;
  localparam WR_DELAY = 2;
  localparam AGD_DELAY = 5;

  localparam NEW_2_ADDR = 'd1;
  localparam ADDR_2_PEin = 'd3;
  localparam NEW_2_PEin = 'd4;    //给出addr_new到westin
  localparam ADDER_2_NEW = 'd1;   //adder输出到给addr_new

//PE_mode
  localparam N_W = 2'b00;
  localparam S_W = 2'b10;
  localparam N_E = 2'b01;
  localparam S_E = 2'b11;

//C map mode
  localparam  TB_POS = 3'b000;
  localparam  TB_NEG = 3'b001;
  localparam  CB_POS = 3'b010;
  localparam  CB_NEG = 3'b011;
  localparam  NEW_11  = 3'b111; 
  localparam  NEW_00  = 3'b100;
  localparam  NEW_01  = 3'b101;
  localparam  NEW_10  = 3'b110;

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

    localparam PRD_1_N = 'd3;
    localparam PRD_2_N = 'd3;
    localparam PRD_3_N = 'd3;
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

    localparam NEW_1_N       = 'd3;
    localparam NEW_2_N       = 'd3;
    localparam NEW_3_N       = 'd3;
    localparam NEW_4_N       = 'd2;
    localparam NEW_5_N       = 'd2;
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
  ***************************************************
  data shift
  ***************************************************
*/
  //shift def
  reg [1:0] A_in_sel_new;
  reg [1:0] B_in_sel_new;
  reg [1:0] M_in_sel_new;
  reg [1:0] M_adder_mode_new;
  // reg [1:0] C_out_sel_new;

  reg [1:0]     TB_douta_sel_new;
  reg         TB_ena_new;
  reg         TB_wea_new;
  reg [TB_AW-1 : 0] TB_addra_new;

  reg         TB_dinb_sel_new;
  reg         TB_doutb_sel_new;
  reg         TB_enb_new;
  reg         TB_web_new;
  reg [TB_AW-1 : 0] TB_addrb_new;

  localparam LEFT_SHIFT = 1'b0;
  localparam RIGHT_SHIFT = 1'b1;

  reg A_shift_dir;
  reg B_shift_dir;
  reg M_shift_dir;
  reg C_shift_dir;
/*
  ************************ABCM shift***************************
*/
  //shift of PE_sel
    dshift 
    #(
      .DW  (2 ),
      .DEPTH (4 )
    )
    A_in_sel_dshift(
      .clk  (clk  ),
      .dir  (LEFT_SHIFT   ),
      .sys_rst ( sys_rst),
      .din  (A_in_sel_new  ),
      .dout (A_in_sel )
    );

    dshift 
    #(
      .DW  (2 ),
      .DEPTH (4 )
    )
    B_in_sel_dshift(
      .clk  (clk  ),
      .dir   (LEFT_SHIFT   ),
      .sys_rst ( sys_rst),
      .din  (B_in_sel_new  ),
      .dout (B_in_sel )
    );

    dshift 
    #(
      .DW  (2 ),
      .DEPTH (4 )
    )
    M_in_sel_dshift(
      .clk  (clk  ),
      .dir  (LEFT_SHIFT   ),
      .sys_rst ( sys_rst),
      .din  (M_in_sel_new  ),
      .dout (M_in_sel )
    );

    dshift 
    #(
      .DW  (2 ),
      .DEPTH (4 )
    )
    M_adder_mode_dshift(
      .clk  (clk  ),
      .dir  (LEFT_SHIFT   ),
      .sys_rst ( sys_rst),
      .din  (M_adder_mode_new  ),
      .dout (M_adder_mode )
    );

  //   dshift 
  //   #(
  //     .DW  (2 ),
  //     .DEPTH (4 )
  //   )
  //  C_out_sel_dshift(
  //     .clk  (clk  ),
  //     .dir   (LEFT_SHIFT   ),
  //     .sys_rst ( sys_rst),
  //     .din  (C_out_sel_new  ),
  //     .dout (C_out_sel )
  //   );

  //shift of TB_portA
    dshift 
    #(
      .DW  (1 ),
      .DEPTH (4 )
    )
    TB_ena_dshift(
      .clk  (clk  ),
      .dir  (LEFT_SHIFT   ),
      .sys_rst ( sys_rst),
      .din  (TB_ena_new  ),
      .dout (TB_ena )
    );

    dshift 
    #(
      .DW  (1 ),
      .DEPTH (4 )
    )
    TB_wea_dshift(
      .clk  (clk  ),
      .dir   (LEFT_SHIFT   ),
      .sys_rst ( sys_rst),
      .din  (TB_wea_new  ),
      .dout (TB_wea )
    );

    dshift 
    #(
      .DW  (2 ),
      .DEPTH (4 )
    )
    TB_douta_sel_dshift(
      .clk  (clk  ),
      .dir  (LEFT_SHIFT   ),
      .sys_rst ( sys_rst),
      .din  (TB_douta_sel_new  ),
      .dout (TB_douta_sel )
    );

    dshift 
    #(
      .DW  (TB_AW  ),
      .DEPTH (4 )
    )
    TB_addra_dshift(
      .clk  (clk  ),
      .dir   (LEFT_SHIFT   ),
      .sys_rst ( sys_rst),
      .din  (TB_addra_new  ),
      .dout (TB_addra )
    );

  //shift of TB_portB
    dshift 
    #(
      .DW  (1 ),
      .DEPTH (4 )
    )
    TB_enb_dshift(
      .clk  (clk  ),
      .dir  (LEFT_SHIFT   ),
      .sys_rst ( sys_rst),
      .din  (TB_enb_new  ),
      .dout (TB_enb )
    );

    dshift 
    #(
      .DW  (1 ),
      .DEPTH (4 )
    )
    TB_web_dshift(
      .clk  (clk  ),
      .dir   (LEFT_SHIFT   ),
      .sys_rst ( sys_rst),
      .din  (TB_web_new  ),
      .dout (TB_web )
    );

    dshift 
    #(
      .DW  (1 ),
      .DEPTH (4 )
    )
    TB_dinb_sel_dshift(
      .clk  (clk  ),
      .dir   (LEFT_SHIFT   ),
      .sys_rst ( sys_rst),
      .din  (TB_dinb_sel_new  ),
      .dout (TB_dinb_sel )
    );

    dshift 
    #(
      .DW  (1 ),
      .DEPTH (4 )
    )
    TB_doutb_sel_dshift(
      .clk  (clk  ),
      .sys_rst ( sys_rst),
      .dir   (LEFT_SHIFT   ),
      .din  (TB_doutb_sel_new  ),
      .dout (TB_doutb_sel )
    );

    dshift 
    #(
      .DW  (TB_AW  ),
      .DEPTH (4 )
    )
    TB_addrb_dshift(
      .clk  (clk  ),
      .sys_rst ( sys_rst),
      .dir  (LEFT_SHIFT   ),
      .din  (TB_addrb_new  ),
      .dout (TB_addrb )
    );

reg         CB_ena_new;
reg         CB_wea_new;
reg [2:0]     CB_douta_sel_new;
reg [CB_AW-1 : 0] CB_addra_new;

reg         CB_enb_new;
reg         CB_web_new;
reg         CB_dinb_sel_new;
reg [CB_AW-1 : 0] CB_addrb_new;

/*
  shift of BRAM BANK new
*/
    dshift 
    #(
      .DW  (1 ),
      .DEPTH (4 )
    )
    CB_ena_dshift(
      .clk  (clk  ),
      .sys_rst ( sys_rst),
      .dir  (LEFT_SHIFT   ),
      .din  (CB_ena_new  ),
      .dout (CB_ena )
    );

    dshift 
    #(
      .DW  (1 ),
      .DEPTH (4 )
    )
    CB_wea_dshift(
      .clk  (clk  ),
      .sys_rst ( sys_rst),
      .dir   (LEFT_SHIFT   ),
      .din  (CB_wea_new  ),
      .dout (CB_wea )
    );

    dshift 
    #(
      .DW  (3 ),
      .DEPTH (4 )
    )
    CB_douta_sel_dshift(
      .clk  (clk  ),
      .sys_rst ( sys_rst),
      .dir  (LEFT_SHIFT   ),
      .din  (CB_douta_sel_new  ),
      .dout (CB_douta_sel )
    );


  //shift of CB_portB
    dshift 
    #(
      .DW  (1 ),
      .DEPTH (4 )
    )
    CB_enb_dshift(
      .clk  (clk  ),
      .sys_rst ( sys_rst),
      .dir  (LEFT_SHIFT   ),
      .din  (CB_enb_new  ),
      .dout (CB_enb )
    );

    dshift 
    #(
      .DW  (1 ),
      .DEPTH (4 )
    )
    CB_web_dshift(
      .clk  (clk  ),
      .sys_rst ( sys_rst),
      .dir   (LEFT_SHIFT   ),
      .din  (CB_web_new  ),
      .dout (CB_web )
    );

    dshift 
    #(
      .DW  (1 ),
      .DEPTH (4 )
    )
    CB_dinb_sel_dshift(
      .clk  (clk  ),
      .sys_rst ( sys_rst),
      .dir   (LEFT_SHIFT   ),
      .din  (CB_dinb_sel_new  ),
      .dout (CB_dinb_sel )
    );

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
  // reg [ROW_LEN-1 : 0]  landmark_num;

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
  // always @(posedge clk) begin
  //   if(sys_rst)
  //     landmark_num <= 0;
  //   else begin
  //     case(stage_rdy & stage_val)
  //       STAGE_NEW: landmark_num <= landmark_num + 1'b1;
  //       default: landmark_num <= landmark_num;
  //     endcase 
  //   end
  // end
  
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
  always @(posedge clk) begin
    if(sys_rst) begin
      A_in_en <= 4'b0000;  
      B_in_en <= 4'b0000;
      M_in_en <= 4'b0000;
      C_out_en <= 4'b0000;
      
      A_in_sel_new <= 2'b00;   
      B_in_sel_new <= 2'b00;
      M_in_sel_new <= 2'b00;
      // C_out_sel_new <= 2'b00;

      C_map_mode   <= TB_POS;
      PE_mode <= N_W;
      M_adder_mode_new <= 2'b00;

      A_shift_dir <= LEFT_SHIFT;
      B_shift_dir <= LEFT_SHIFT;
      M_shift_dir <= LEFT_SHIFT;
      C_shift_dir <= LEFT_SHIFT;
    end
    else begin
      case(stage_cur)
        IDLE: begin
          A_in_en <= 4'b0000;  
          B_in_en <= 4'b0000;
          M_in_en <= 4'b0000;
          C_out_en <= 4'b0000;
          
          A_in_sel_new <= 2'b00;  
          B_in_sel_new <= 2'b00;
          M_in_sel_new <= 2'b00;
          // C_out_sel_new <= 2'b00;
          
          C_map_mode   <= TB_POS;
          PE_mode <= N_W;
          M_adder_mode_new <= 2'b00;
        end
        STAGE_PRD: begin
          case(prd_cur)
            PRD_1: begin
            /*
              F_xi * t_cov = F_cov
              X=3 Y=3 N=3
              Ain: TB-A
              bin: TB-B
              Cout: TB-A
            */
              A_in_en <= 4'b0111;  
              B_in_en <= 4'b0111;
              M_in_en <= 4'b0000;
              C_out_en <= 4'b0111;
              
              A_in_sel_new <= 2'b00;   
              B_in_sel_new <= 2'b00;
              M_in_sel_new <= 2'b00;
              // C_out_sel_new <= 2'b00;

              C_map_mode   <= TB_POS;
              PE_mode <= N_W;
              M_adder_mode_new <= 2'b00;
            
            end
            PRD_2: begin
            /*
              F_cov * t_cov + M= cov
              X=3 Y=3 N=3
              Ain: TB-A
              Bin: TB-B
              Min: 0    //actual M input time is in PRD_3
              Cout: CB-B
            */
              A_in_en <= 4'b0111;  
              B_in_en <= 4'b0111;
              M_in_en <= 4'b0111;
              C_out_en <= 4'b0111;
              
              A_in_sel_new <= 2'b00;  
              B_in_sel_new <= 2'b00;
              M_in_sel_new <= 2'b00;
              // C_out_sel_new <= 2'b00;

              C_map_mode   <= TB_POS;
              PE_mode <= N_W;
              M_adder_mode_new <= 2'b01;
            end
            PRD_3: begin
            /*
              cov_mv * F_xi_T = cov_mv
              X=3 Y=3 N=3
              Ain: CB-A
              Bin: TB-B
              Min: TB-A   //PRD_2 adder
              Cout: CB-B
            */
              A_in_en <= 4'b1111;  
              B_in_en <= 4'b0111;
              M_in_en <= 4'b0000;
              C_out_en <= 4'b1111;
              
              A_in_sel_new <= 2'b10; 
              B_in_sel_new <= 2'b00;
              M_in_sel_new <= 2'b00;
              // C_out_sel_new <= 2'b10;

              C_map_mode   <= CB_POS;
              PE_mode <= N_W;
              M_adder_mode_new <= 2'b00;
            end
            default: begin
              A_in_en <= 4'b0000;  
              B_in_en <= 4'b0000;
              M_in_en <= 4'b0000;
              C_out_en <= 4'b0000;
              
              A_in_sel_new <= 2'b00;   
              B_in_sel_new <= 2'b00;
              M_in_sel_new <= 2'b00;
              // C_out_sel_new <= 2'b00;

              C_map_mode   <= TB_POS;
              PE_mode <= N_W;
              M_adder_mode_new <= 2'b00;
            end
          endcase
        end
        STAGE_NEW: begin
          case(new_cur)
            NEW_1: begin
            /*
              F_xi * t_cov = F_cov
              X=3 Y=3 N=3
              Ain: TB-A
              bin: TB-B
              Cout: TB-A
            */
              A_in_en <= 4'b0011;  
              B_in_en <= 4'b0111;
              M_in_en <= 4'b0000;
              C_out_en <= 4'b0011;
              
              A_in_sel_new <= 2'b00;   
              B_in_sel_new <= 2'b00;
              M_in_sel_new <= 2'b00;
              // C_out_sel_new <= 2'b00;

              C_map_mode   <= TB_POS;
              PE_mode <= N_W;
              M_adder_mode_new <= 2'b00;
            
            end
            NEW_2: begin
            /*
              F_cov * t_cov + M= cov
              X=3 Y=3 N=3
              Ain: TB-A
              Bin: TB-B
              Min: 0    //actual M input time is in NEW_3
              Cout: CB-B
            */
              A_in_en <= 4'b0011;  
              B_in_en <= 4'b1111;
              M_in_en <= 4'b0000;
              C_out_en <= 4'b0011;
              
              A_in_sel_new <= 2'b00;  

              case(group_num[0])
                1'b0: B_in_sel_new <= 2'b11;  //逆向
                1'b1: B_in_sel_new <= 2'b10;  //正向
              endcase

              case(group_num[0])
                1'b0: B_shift_dir <= RIGHT_SHIFT;  //逆向
                1'b1: B_shift_dir <= LEFT_SHIFT;  //正向
              endcase
              
              M_in_sel_new <= 2'b00;
              // C_out_sel_new <= 2'b00;

              case(landmark_num[1:0])
                2'b00: C_map_mode   <= NEW_00;
                2'b01: C_map_mode   <= NEW_01;
                2'b10: C_map_mode   <= NEW_10;
                2'b11: C_map_mode   <= NEW_11;
              endcase

              PE_mode <= N_W;
              M_adder_mode_new <= 2'b00;
            end
            NEW_3: begin
            /*
              cov_mv * F_xi_T = cov_mv
              X=3 Y=3 N=3
              Ain: CB-A
              Bin: TB-B
              Min: TB-A   //NEW_2 adder
              Cout: CB-B
            */
              A_in_en <= 4'b0011;  
              B_in_en <= 4'b0011;
              M_in_en <= 4'b0000;
              C_out_en <= 4'b0011;
              
              A_in_sel_new <= 2'b10; 
              B_in_sel_new <= 2'b00;
              M_in_sel_new <= 2'b00;
              // C_out_sel_new <= 2'b10;

              C_map_mode   <= CB_POS;
              PE_mode <= N_W;
              M_adder_mode_new <= 2'b00;
            end
            default: begin
              A_in_en <= 4'b0000;  
              B_in_en <= 4'b0000;
              M_in_en <= 4'b0000;
              C_out_en <= 4'b0000;
              
              A_in_sel_new <= 2'b00;   
              B_in_sel_new <= 2'b00;
              M_in_sel_new <= 2'b00;
              // C_out_sel_new <= 2'b00;

              C_map_mode   <= TB_POS;
              PE_mode <= N_W;
              M_adder_mode_new <= 2'b00;
            end
          endcase
        end
        STAGE_UPD: begin
          
        end
        
      endcase
    end  
  end

//(old, using PRD_1_START) 配置TB A B端口 输入数据及数据选择
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
  //               else if(seq_cnt == NEW_2_PEin+PRD_1_N+2+ADDER_2_NEW) begin
  //                 TB_ena_new <= 1'b0;
  //                 TB_wea_new <= 1'b0;
  //                 TB_addra_new <= 0;

  //                 TB_enb_new <= 1'b1;
  //                 TB_web_new <= 1'b1;
  //                 TB_addrb_new <= F_cov;
  //               end
  //               else if(seq_cnt == NEW_2_PEin+PRD_1_N+2+ADDER_2_NEW + 2) begin
  //                 TB_ena_new <= 1'b0;
  //                 TB_wea_new <= 1'b0;
  //                 TB_addra_new <= 0;

  //                 TB_enb_new <= 1'b1;
  //                 TB_web_new <= 1'b1;
  //                 TB_addrb_new <= F_cov + 1'b1;
  //               end
  //               else if(seq_cnt == NEW_2_PEin+PRD_1_N+2+ADDER_2_NEW + 4) begin
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
  //               else if(seq_cnt ==  + NEW_2_PEin+PRD_2_N+2+ADDER_2_NEW) begin
  //                 TB_ena_new <= 1'b0;
  //                 TB_wea_new <= 1'b0;
  //                 TB_addra_new <= 0;

  //                 TB_enb_new <= 1'b1;
  //                 TB_web_new <= 1'b1;
  //                 TB_addrb_new <= t_cov;
  //               end
  //               else if(seq_cnt ==  + NEW_2_PEin+PRD_1_N+2+ADDER_2_NEW + 2) begin
  //                 TB_ena_new <= 1'b0;
  //                 TB_wea_new <= 1'b0;
  //                 TB_addra_new <= 0;

  //                 TB_enb_new <= 1'b1;
  //                 TB_web_new <= 1'b1;
  //                 TB_addrb_new <= t_cov + 1'b1;
  //               end
  //               else if(seq_cnt ==  + NEW_2_PEin+PRD_1_N+2+ADDER_2_NEW + 4) begin
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

//(using, using PRD_1_END) 配置TB A B端口 输入数据及数据选择
  always @(posedge clk) begin
    if(sys_rst) begin
      TB_douta_sel_new <= 2'b00;  
      TB_dinb_sel_new <= 1'b0;
      TB_doutb_sel_new <= 1'b0;

      TB_ena_new <= 1'b0;
      TB_wea_new <= 1'b0;
      TB_addra_new <= 0;

      TB_enb_new <= 1'b0;
      TB_web_new <= 1'b0;
      TB_addrb_new <= 0;
    end
    else begin
      case(stage_cur)
        IDLE: begin
          TB_douta_sel_new <= 2'b00;   
          TB_dinb_sel_new <= 1'b0;
          TB_doutb_sel_new <= 1'b0;

          TB_ena_new <= 1'b0;
          TB_wea_new <= 1'b0;
          TB_addra_new <= 0;

          TB_enb_new <= 1'b0;
          TB_web_new <= 1'b0;
          TB_addrb_new <= 0;
        end
        STAGE_PRD: begin
          case(prd_cur)
            PRD_1: begin
            /*
              F_xi * t_cov = F_cov
              X=3 Y=3 N=3
              Ain: TB-A
              bin: TB-B
              Cout: TB-A
            */
              TB_douta_sel_new <= 2'b00;   
              TB_dinb_sel_new <= 1'b0;
              TB_doutb_sel_new <= 1'b0;
              
              if (seq_cnt < PRD_1_N) begin
                TB_ena_new <= 1'b1;
                TB_wea_new <= 1'b0;
                TB_addra_new <= F_xi + seq_cnt;

                TB_enb_new <= 1'b1;
                TB_web_new <= 1'b0;
                TB_addrb_new <= t_cov + seq_cnt;
              end
              else if(seq_cnt == NEW_2_PEin+PRD_1_N+2+ADDER_2_NEW) begin
                TB_ena_new <= 1'b0;
                TB_wea_new <= 1'b0;
                TB_addra_new <= 0;

                TB_enb_new <= 1'b1;
                TB_web_new <= 1'b1;
                TB_addrb_new <= F_cov;
              end
              else if(seq_cnt == NEW_2_PEin+PRD_1_N+2+ADDER_2_NEW + 2) begin
                TB_ena_new <= 1'b0;
                TB_wea_new <= 1'b0;
                TB_addra_new <= 0;

                TB_enb_new <= 1'b1;
                TB_web_new <= 1'b1;
                TB_addrb_new <= F_cov + 1'b1;
              end
              else if(seq_cnt == NEW_2_PEin+PRD_1_N+2+ADDER_2_NEW + 4) begin
                TB_ena_new <= 1'b0;
                TB_wea_new <= 1'b0;
                TB_addra_new <= 0;

                TB_enb_new <= 1'b1;
                TB_web_new <= 1'b1;
                TB_addrb_new <= F_cov + 2'b10;
              end
              else begin
                TB_ena_new <= 1'b0;
                TB_wea_new <= 1'b0;
                TB_addra_new <= 0;

                TB_enb_new <= 1'b0;
                TB_web_new <= 1'b0;
                TB_addrb_new <= 0;
              end
            end
            PRD_2: begin
            /*
              F_cov * t_cov + M= cov
              X=3 Y=3 N=3
              Ain: TB-A
              Bin: TB-B
              Min: 0    //actual M input time is in PRD_3
              Cout: CB-B
            */
              TB_dinb_sel_new <= 1'b0;
              TB_doutb_sel_new <= 1'b0;
              
              if (seq_cnt < PRD_2_N) begin
                TB_ena_new <= 1'b1;
                TB_wea_new <= 1'b0;
                TB_addra_new <= F_cov + seq_cnt;
                
                TB_douta_sel_new <= 2'b00;   

                TB_enb_new <= 1'b1;
                TB_web_new <= 1'b0;
                TB_addrb_new <= F_xi + seq_cnt;
              end
              else if(seq_cnt == PRD_2_N + 1) begin
                TB_ena_new <= 1'b1;
                TB_wea_new <= 1'b0;
                TB_addra_new <= M_t;
                
                TB_douta_sel_new <= 2'b10; 

                TB_enb_new <= 1'b0;
                TB_web_new <= 1'b0;
                TB_addrb_new <= 0;
              end
              else if(seq_cnt == PRD_2_N + 3) begin
                TB_ena_new <= 1'b1;
                TB_wea_new <= 1'b0;
                TB_addra_new <= M_t + 1'b1;

                TB_enb_new <= 1'b0;
                TB_web_new <= 1'b0;
                TB_addrb_new <= 0;
              end
              else if(seq_cnt == PRD_2_N + 5) begin
                TB_ena_new <= 1'b1;
                TB_wea_new <= 1'b0;
                TB_addra_new <= M_t + 2'b10;

                TB_enb_new <= 1'b0;
                TB_web_new <= 1'b0;
                TB_addrb_new <= 0;
              end
              else if(seq_cnt == NEW_2_PEin+PRD_2_N+2+ADDER_2_NEW) begin
                TB_ena_new <= 1'b0;
                TB_wea_new <= 1'b0;
                TB_addra_new <= 0;

                TB_enb_new <= 1'b1;
                TB_web_new <= 1'b1;
                TB_addrb_new <= t_cov;
              end
              else if(seq_cnt == NEW_2_PEin+PRD_1_N+2+ADDER_2_NEW + 2) begin
                TB_ena_new <= 1'b0;
                TB_wea_new <= 1'b0;
                TB_addra_new <= 0;

                TB_enb_new <= 1'b1;
                TB_web_new <= 1'b1;
                TB_addrb_new <= t_cov + 1'b1;
              end
              else if(seq_cnt == NEW_2_PEin+PRD_1_N+2+ADDER_2_NEW + 4) begin
                TB_ena_new <= 1'b0;
                TB_wea_new <= 1'b0;
                TB_addra_new <= 0;

                TB_enb_new <= 1'b1;
                TB_web_new <= 1'b1;
                TB_addrb_new <= t_cov + 2'b10;
              end
              else begin
                TB_ena_new <= 1'b0;
                TB_wea_new <= 1'b0;
                TB_addra_new <= 0;

                TB_enb_new <= 1'b0;
                TB_web_new <= 1'b0;
                TB_addrb_new <= 0;
              end
            end
            PRD_3: begin
            /*
              cov_mv * F_xi_T = cov_mv
              X=3 Y=3 N=3
              Ain: CB-A
              Bin: TB-B
              Min: TB-A   //PRD_2 adder
              Cout: CB-B
            */
              TB_dinb_sel_new <= 1'b0;
              TB_doutb_sel_new <= 1'b0;
              
              TB_douta_sel_new <= 2'b00;   
              TB_ena_new <= 1'b0;
              TB_wea_new <= 1'b0;
              TB_addra_new <= 0;
              if (seq_cnt < PRD_1_N) begin
                TB_enb_new <= 1'b1;
                TB_web_new <= 1'b0;
                TB_addrb_new <= F_xi + seq_cnt;
              end
              else begin
                TB_enb_new <= 1'b0;
                TB_web_new <= 1'b0;
                TB_addrb_new <= 0;
              end
            end
            default: begin
              TB_douta_sel_new <= 1'b0;  
              TB_dinb_sel_new <= 1'b0;
              TB_doutb_sel_new <= 1'b0;

              TB_ena_new <= 1'b0;
              TB_wea_new <= 1'b0;
              TB_addra_new <= 0;

              TB_enb_new <= 1'b0;
              TB_web_new <= 1'b0;
              TB_addrb_new <= 0;
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

//配置 CB-portA 输入数据及数据选择
wire [CB_AW-1 : 0] CB_addra_base;
reg CB_addra_base_gen;
CB_addr_shift #(
  .L     ( L     ),
  .CB_AW   ( CB_AW   ),
  .ROW_LEN ( ROW_LEN ))
 CB_addr_shift_portA (
  .clk           ( clk              ),
  .sys_rst         ( sys_rst            ),
  .CB_en           ( CB_ena       [L-2 : 0]     ),
  .group_cnt_0       ( group_cnt[0]          ),
  .din           ( CB_addra_new      [CB_AW-1 : 0]   ),
  .dout          ( CB_addra     [CB_AW*L-1 : 0] )
);

CB_vm_AGD #(
  .CB_AW   ( CB_AW   ),
  .ROW_LEN ( ROW_LEN ))
 CB_vm_AGD_portA (
  .clk           ( clk               ),
  .sys_rst         ( sys_rst             ),
  .en            ( CB_addra_base_gen              ),
  .group_cnt         ( group_cnt   [ROW_LEN-1 : 0] ),
  .CB_base_addr      ( CB_addra_base  [CB_AW-1 : 0]   )
);

  always @(posedge clk) begin
    if(sys_rst) begin
      CB_douta_sel_new <= 3'b000;     

      CB_ena_new <= 1'b0;
      CB_wea_new <= 1'b0;
      CB_addra_new <= 0;

      CB_addra_base_gen <= 0;
    end
    else begin
      case(stage_cur)
        IDLE: begin
          CB_douta_sel_new <= 3'b000;  

          CB_ena_new <= 1'b0;
          CB_wea_new <= 1'b0;
          CB_addra_new <= 0;
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
              CB_douta_sel_new <= 3'b000;     

              CB_wea_new <= 1'b0;
              case(seq_cnt)
                'd0: begin
                  CB_ena_new <= 1'b1;
                  CB_addra_new <= CB_addra_base;
                end     
                'd1: begin
                  CB_ena_new <= 1'b1;
                  CB_addra_new <= CB_addra_base + 'b1;
                end
                'd2: begin
                  CB_ena_new <= 1'b1;
                  CB_addra_new <= CB_addra_base + 'b10;
                  CB_addra_base_gen <= 1'b1;
                end
                'd3: begin
                  CB_ena_new <= 1'b0;
                  CB_addra_new <= 0;
                end
                'd4: begin
                  CB_ena_new <= 1'b0;
                  CB_addra_new <= 0;
                  CB_addra_base_gen <= 1'b0;
                end
                'd5: begin
                  CB_ena_new <= 1'b0;
                  CB_addra_new <= 0;
                end
                default: begin
                  CB_ena_new <= 1'b0;
                  CB_addra_new <= 0;
                end
              endcase 
            end
            default: begin
              CB_douta_sel_new <= 3'b000;   

              CB_ena_new <= 1'b0;
              CB_wea_new <= 1'b0;
              CB_addra_new <= 0;
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

  wire [CB_AW-1 : 0] CB_addrb_base;
  reg CB_addrb_base_gen;
  //地址生成及移位
    CB_addr_shift #(
      .L     ( L     ),
      .CB_AW   ( CB_AW   ),
      .ROW_LEN ( ROW_LEN ))
    CB_addr_shift_portB (
      .clk           ( clk              ),
      .sys_rst         ( sys_rst            ),
      .CB_en           ( CB_enb       [L-2 : 0]     ),
      .group_cnt_0       ( group_cnt_CB_B[0]          ),
      .din           ( CB_addrb_new      [CB_AW-1 : 0]   ),
      .dout          ( CB_addrb     [CB_AW*L-1 : 0] )
    );

    CB_vm_AGD #(
      .CB_AW   ( CB_AW   ),
      .ROW_LEN ( ROW_LEN ))
    CB_vm_AGD_portB (
      .clk           ( clk               ),
      .sys_rst         ( sys_rst             ),
      .en            ( CB_addrb_base_gen              ),
      .group_cnt         ( group_cnt_CB_B   [ROW_LEN-1 : 0] ),
      .CB_base_addr      ( CB_addrb_base  [CB_AW-1 : 0]   )
    );
  

  always @(posedge clk) begin
    if(sys_rst) begin   
      CB_dinb_sel_new <= 1'b0;

      CB_enb_new <= 1'b0;
      CB_web_new <= 1'b0;
      CB_addrb_new <= 0;

      CB_addrb_base_gen <= 0;
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
                  CB_addrb_base_gen <= 1'b1;
                end
                'd3: begin
                  CB_enb_new <= 1'b0;
                  CB_addrb_new <= 0;
                end
                'd4: begin
                  CB_enb_new <= 1'b1;
                  CB_addrb_new <= CB_addrb_base + 'b10;
                  CB_addrb_base_gen <= 1'b0;
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
          if(seq_cnt >= NEW_2_PEin -1'b1 && seq_cnt < NEW_2_PEin + PRD_1_N -1'b1) begin
            new_cal_en_new <= 1'b1;
          end
          else
            new_cal_en_new <= 1'b0;
        end
        PRD_2: begin
          if(seq_cnt >= NEW_2_PEin -1'b1 && seq_cnt < NEW_2_PEin + PRD_2_N -1'b1) begin
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
          if(seq_cnt == NEW_2_PEin + PRD_1_N -1'b1) begin
            new_cal_done_new <= 1'b1;
          end
          else
            new_cal_done_new <= 1'b0;
        end
        PRD_2: begin
          if(seq_cnt == NEW_2_PEin + PRD_2_N -1'b1) begin
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





endmodule