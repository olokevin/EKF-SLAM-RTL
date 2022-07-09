//~ `New testbench
`timescale  1ns / 1ps

module tb_RSA;

parameter RST_START = 10;

// RSA Parameters
parameter PERIOD           = 10;
parameter X                = 4 ;
parameter Y                = 4 ;
parameter L                = 4 ;
parameter RSA_DW           = 16;
parameter RSA_AW           = 17;
parameter TB_AW            = 11;
parameter CB_AW            = 17;
parameter SEQ_CNT_DW       = 5 ;
parameter ROW_LEN          = 10;
parameter A_IN_SEL_DW      = 2 ;
parameter B_IN_SEL_DW      = 2 ;
parameter M_IN_SEL_DW      = 2 ;
parameter C_OUT_SEL_DW     = 2 ;
parameter TB_DINA_SEL_DW   = 3 ;
parameter TB_DINB_SEL_DW   = 2 ;
parameter TB_DOUTA_SEL_DW  = 3 ;
parameter TB_DOUTB_SEL_DW  = 3 ;
parameter CB_DINA_SEL_DW   = 2 ;
parameter CB_DINB_SEL_DW   = 5 ;
parameter CB_DOUTA_SEL_DW  = 5 ;

// RSA Inputs

reg   clk                                  = 1 ;
reg   sys_rst                              = 0 ;

reg   [2:0]  stage_val                     = 0 ;
reg   [ROW_LEN-1 : 0]  landmark_num        = 6 ;
reg   [ROW_LEN-1 : 0]  l_k                 = 4 ;
reg   done_predict                         = 0 ;
reg   done_newlm                           = 0 ;
reg   done_update                          = 0 ;
reg   [RSA_DW - 1 : 0]  result_0           = 0 ;
reg   [RSA_DW - 1 : 0]  result_1           = 0 ;
reg   [RSA_DW - 1 : 0]  result_2           = 0 ;
reg   [RSA_DW - 1 : 0]  result_3           = 0 ;
reg   [RSA_DW - 1 : 0]  result_4           = 0 ;
reg   [RSA_DW - 1 : 0]  result_5           = 0 ;

// RSA Outputs
wire  [2:0]  stage_rdy                     ;
wire  [RSA_DW - 1 : 0]  S_data             ;
wire  init_predict                         ;
wire  init_newlm                           ;
wire  init_update                          ;
wire  [RSA_DW-1 : 0]  xk                   ;
wire  [RSA_DW-1 : 0]  yk                   ;
wire  [RSA_DW-1 : 0]  xita                 ;
wire  [RSA_DW-1 : 0]  lkx                  ;
wire  [RSA_DW-1 : 0]  lky                  ;

//stage
  localparam      IDLE     = 3'b000 ;
  localparam      STAGE_PRD  = 3'b001 ;
  localparam      STAGE_NEW  = 3'b010 ;
  localparam      STAGE_UPD  = 3'b100 ;

initial
begin
    forever #(PERIOD/2)  clk=~clk;
end

initial
begin
    #(PERIOD*7) sys_rst  =  1;
    #(PERIOD*2) sys_rst  =  0;
end

//Prediction
  // initial begin
  //     #(PERIOD*RST_START)
  //     stage_val = STAGE_PRD;
      
  //     #(PERIOD * 2)
  //     stage_val = 0;
  // end
  // initial begin
  //   #(PERIOD*RST_START*3)
  //   done_predict = 1;
  //   result_1 = 1;
  //   result_2 = 2;
  //   result_3 = 3;
  //   #(PERIOD)
  //   done_predict = 0;
  // end

//New Landmark Initialization
  initial begin
    #(PERIOD*RST_START)
      stage_val = STAGE_NEW;
    
    #(PERIOD * 2)
      stage_val = 0;
  end

  initial begin
    #(PERIOD*RST_START*3)
      done_newlm = 1;
      result_0 = -1;
      result_1 = 1;
      result_2 = 2;
      result_3 = 3;
    #(PERIOD)
      done_newlm = 0;
  end

//Update
  // initial begin
  //     #(PERIOD*RST_START)
  //     stage_val = STAGE_UPD;
      
  //     #(PERIOD * 2)
  //     stage_val = 0;
  // end

  // initial begin
  //   #(PERIOD*RST_START*3)
  //   done_update = 1;
  //   result_0 = -1;
  //   result_1 = 1;
  //   result_2 = 2;
  //   result_3 = 3;
  //   result_4 = 4;
  //   result_5 = 5;
  //   #(PERIOD)
  //   done_update = 0;
  // end


RSA #(
    .X               ( X               ),
    .Y               ( Y               ),
    .L               ( L               ),
    .RSA_DW          ( RSA_DW          ),
    .RSA_AW          ( RSA_AW          ),
    .TB_AW           ( TB_AW           ),
    .CB_AW           ( CB_AW           ),
    .SEQ_CNT_DW      ( SEQ_CNT_DW      ),
    .ROW_LEN         ( ROW_LEN         ))
 u_RSA (
    .clk                     ( clk                                      ),   
    .sys_rst                 ( sys_rst                                  ),
    .stage_val               ( stage_val               [2:0]            ),
    .landmark_num            ( landmark_num            [ROW_LEN-1 : 0]  ),
    .l_k                     ( l_k                     [ROW_LEN-1 : 0]  ),
    .done_predict            ( done_predict                             ),
    .done_newlm              ( done_newlm                               ),
    .done_update             ( done_update                              ),
    .result_0                ( result_0                [RSA_DW - 1 : 0] ),
    .result_1                ( result_1                [RSA_DW - 1 : 0] ),
    .result_2                ( result_2                [RSA_DW - 1 : 0] ),
    .result_3                ( result_3                [RSA_DW - 1 : 0] ),
    .result_4                ( result_4                [RSA_DW - 1 : 0] ),
    .result_5                ( result_5                [RSA_DW - 1 : 0] ),

    .stage_rdy               ( stage_rdy               [2:0]            ),
    .S_data                  ( S_data                  [RSA_DW - 1 : 0] ),
    .init_predict            ( init_predict                             ),
    .init_newlm              ( init_newlm                               ),
    .init_update             ( init_update                              ),
    .xk                      ( xk                      [RSA_DW-1 : 0]   ),
    .yk                      ( yk                      [RSA_DW-1 : 0]   ),
    .xita                    ( xita                    [RSA_DW-1 : 0]   ),
    .lkx                     ( lkx                     [RSA_DW-1 : 0]   ),
    .lky                     ( lky                     [RSA_DW-1 : 0]   )
);

endmodule