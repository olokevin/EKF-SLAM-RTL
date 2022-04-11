`timescale  1ns / 1ps

module tb_PE_config;

parameter RST_START = 20;
// PE_config Parameters
parameter PERIOD         = 10    ;
parameter X              = 4     ;
parameter Y              = 4     ;
parameter L              = 4     ;
parameter RSA_DW       = 16    ;
parameter TB_AW    = 12    ;
parameter CB_AW    = 19    ;
parameter MAX_LANDMARK   = 500   ;
parameter ROW_LEN      = 10    ;
parameter IDLE           = 3'b000;
parameter STAGE_PRD      = 3'b001;
parameter STAGE_NEW      = 3'b010;
parameter STAGE_UPD      = 3'b100;
parameter STAGE_BUSY     = 3'b000;
parameter STAGE_READY    = 3'b111;
parameter F_xi           = 0     ;
parameter F_xi_T         = 3     ;
parameter t_cov          = 6     ;
parameter F_cov          = 9     ;
parameter M              = 12    ;
parameter PRD_IDLE       = 'b0000;
parameter PRD_NONLINEAR  = 'b0001;
parameter PRD_1          = 'b0010;
parameter PRD_2          = 'b0100;
parameter PRD_3          = 'b1000;
parameter X_PRD_1        = 3     ;
parameter N_PRD_1        = 3     ;
parameter Y_PRD_1        = 3     ;
parameter RD_DELAY       = 3     ;
parameter WR_DELAY       = 1     ;
parameter AGD_DELAY      = 3     ;

// PE_config Inputs
reg   clk                                  = 1 ;
reg   sys_rst                              = 0 ;
reg   [ROW_LEN-1 : 0] landmark_num         = 5 ;
reg   [2:0]  stage_val                     = 0 ;
reg  [2:0]  nonlinear_s_val                 ;
reg  [2:0]  nonlinear_s_rdy                 ;


// PE_config Outputs
wire  [2:0]  stage_rdy                     ;
wire   [2:0]  nonlinear_m_rdy              ;
wire   [2:0]  nonlinear_m_val              ;

wire  [X-1 : 0]  A_in_sel                  ;
wire  [X-1 : 0]  A_in_en                   ;
wire  [2*Y-1 : 0]  B_in_sel              ;
wire  [Y-1 : 0]  B_in_en                   ;
wire  [2*X-1 : 0]  M_in_sel              ;
wire  [X-1 : 0]  M_in_en                   ;
wire  [2*X-1 : 0]  C_out_sel             ;
wire  [X-1 : 0]  C_out_en                  ;
wire  [L-1 : 0]  TB_dinb_sel               ;
wire  [L-1 : 0]  TB_douta_sel              ;
wire  [L-1 : 0]  TB_doutb_sel              ;
wire  [L-1 : 0]  TB_ena                    ;
wire  [L-1 : 0]  TB_enb                    ;
wire  [L-1 : 0]  TB_wea                    ;
wire  [L-1 : 0]  TB_web                    ;
wire  [L*RSA_DW-1 : 0]  TB_dina     ;
wire  [L*TB_AW-1 : 0]  TB_addra      ;
wire  [L*TB_AW-1 : 0]  TB_addrb      ;
wire  [L-1 : 0]  CB_dinb_sel               ;
wire  [L-1 : 0]  CB_douta_sel              ;
wire  [L-1 : 0]  CB_doutb_sel              ;
wire  [L-1 : 0]  CB_ena                    ;
wire  [L-1 : 0]  CB_enb                    ;
wire  [L-1 : 0]  CB_wea                    ;
wire  [L-1 : 0]  CB_web                    ;
wire  [L*RSA_DW-1 : 0]  CB_dina     ;
wire  [L*CB_AW-1 : 0]  CB_addra      ;
wire  [L*CB_AW-1 : 0]  CB_addrb      ;
wire  new_cal_en;
wire  new_cal_done;


initial
begin
    forever #(PERIOD/2)  clk=~clk;
end

initial
begin
    #(PERIOD*15) sys_rst  =  1;
    #(PERIOD*2) sys_rst  =  0;
end

initial begin
    #(PERIOD*RST_START)
    stage_val = 1;
    #(PERIOD * 2)
    stage_val = 0;
end

initial begin
    #(PERIOD*RST_START)
    #(PERIOD * 5)
    nonlinear_s_val = 1;
    #(PERIOD * 2)
    nonlinear_s_val = 0;
end

initial begin
    #(PERIOD*RST_START)
    #(PERIOD * 10)
    nonlinear_s_rdy = 1;
    #(PERIOD * 2)
    nonlinear_s_rdy = 0;
end

PE_config #(
    .X             ( X             ),
    .Y             ( Y             ),
    .L             ( L             ),
    .RSA_DW      ( RSA_DW      ),
    .TB_AW   ( TB_AW   ),
    .CB_AW   ( CB_AW   ),
    .MAX_LANDMARK  ( MAX_LANDMARK  ),
    .ROW_LEN     ( ROW_LEN     )
)
 u_PE_config (
    .clk                     ( clk                                  ),
    .sys_rst                 ( sys_rst                              ),
    .landmark_num    (landmark_num    ),
    .stage_val               ( stage_val      [2:0]                 ),
    .nonlinear_s_val           ( nonlinear_s_val  [2:0]                 ),
    .nonlinear_s_rdy           ( nonlinear_s_rdy  [2:0]                 ),

    .stage_rdy               ( stage_rdy      [2:0]                 ),
    .nonlinear_m_rdy              ( nonlinear_m_rdy      [2:0]                 ),
    .nonlinear_m_val               ( nonlinear_m_val      [2:0]                 ),
    .A_in_sel                ( A_in_sel       [X-1 : 0]             ),
    .A_in_en                 ( A_in_en        [X-1 : 0]             ),
    .B_in_sel                ( B_in_sel       [2*Y-1 : 0]         ),
    .B_in_en                 ( B_in_en        [Y-1 : 0]             ),
    .M_in_sel                ( M_in_sel       [2*X-1 : 0]         ),
    .M_in_en                 ( M_in_en        [X-1 : 0]             ),
    .C_out_sel               ( C_out_sel      [2*X-1 : 0]         ),
    .C_out_en                ( C_out_en       [X-1 : 0]             ),
    .TB_dinb_sel             ( TB_dinb_sel    [L-1 : 0]             ),
    .TB_douta_sel            ( TB_douta_sel   [L-1 : 0]             ),
    .TB_doutb_sel            ( TB_doutb_sel   [L-1 : 0]             ),
    .TB_ena                  ( TB_ena         [L-1 : 0]             ),
    .TB_enb                  ( TB_enb         [L-1 : 0]             ),
    .TB_wea                  ( TB_wea         [L-1 : 0]             ),
    .TB_web                  ( TB_web         [L-1 : 0]             ),
    .TB_dina            ( TB_dina   [L*RSA_DW-1 : 0]    ),
    .TB_addra                ( TB_addra       [L*TB_AW-1 : 0] ),
    .TB_addrb                ( TB_addrb       [L*TB_AW-1 : 0] ),
    .CB_dinb_sel             ( CB_dinb_sel    [L-1 : 0]             ),
    .CB_douta_sel            ( CB_douta_sel   [L-1 : 0]             ),
    .CB_doutb_sel            ( CB_doutb_sel   [L-1 : 0]             ),
    .CB_ena                  ( CB_ena         [L-1 : 0]             ),
    .CB_enb                  ( CB_enb         [L-1 : 0]             ),
    .CB_wea                  ( CB_wea         [L-1 : 0]             ),
    .CB_web                  ( CB_web         [L-1 : 0]             ),
    .CB_dina            ( CB_dina   [L*RSA_DW-1 : 0]    ),
    .CB_addra                ( CB_addra       [L*CB_AW-1 : 0] ),
    .CB_addrb                ( CB_addrb       [L*CB_AW-1 : 0] ),
    .new_cal_en              (new_cal_en),
    .new_cal_done            (new_cal_done)
);


endmodule