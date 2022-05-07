`timescale  1ns / 10ps

module tb_RSA;

parameter RST_START = 20;

// RSA Parameters
parameter PERIOD        = 10 ;
parameter X             = 4  ;
parameter Y             = 4  ;
parameter L             = 4  ;
parameter RSA_DW        = 16 ;
parameter TB_AW         = 11 ;
parameter CB_AW         = 17 ;
parameter SEQ_CNT_DW    = 5;
parameter ROW_LEN       = 10 ;

// RSA Inputs
reg   clk                                  = 1 ;
reg   sys_rst                              = 0 ;
reg   [ROW_LEN-1 : 0] landmark_num         = 6 ;
reg   [ROW_LEN-1 : 0] l_k                  = 4 ;
reg   [2:0]  stage_val                     = 0 ;
reg   [2:0]  nonlinear_s_val               = 0 ;
reg   [2:0]  nonlinear_s_rdy               = 0 ;

// RSA Outputs
wire  [2:0]  stage_rdy                     ;
wire  [2:0]  nonlinear_m_rdy               ;
wire  [2:0]  nonlinear_m_val               ;

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
    #(PERIOD*15) sys_rst  =  1;
    #(PERIOD*2) sys_rst  =  0;
end

/*
    ************* PRD *****************
*/
// initial begin
//     #(PERIOD*RST_START)
//     stage_val = STAGE_PRD;
//     #(PERIOD * 2)
//     stage_val = 0;
// end

// initial begin
//     #(PERIOD*RST_START)
//     #(PERIOD * 5)
//     nonlinear_s_val = STAGE_PRD;
//     #(PERIOD * 2)
//     nonlinear_s_val = 0;
// end

// initial begin
//     #(PERIOD*RST_START)
//     #(PERIOD * 10)
//     nonlinear_s_rdy = STAGE_PRD;
//     #(PERIOD * 2)
//     nonlinear_s_rdy = 0;
// end

/*
    ************* NEW *****************
*/
// initial begin
//     #(PERIOD*RST_START)
//     stage_val = STAGE_NEW;
//     #(PERIOD * 2)
//     stage_val = 0;
// end

// initial begin
//     #(PERIOD*RST_START)
//     #(PERIOD * 5)
//     nonlinear_s_val = STAGE_NEW;
//     #(PERIOD * 2)
//     nonlinear_s_val = 0;
// end

// initial begin
//     #(PERIOD*RST_START)
//     #(PERIOD * 10)
//     nonlinear_s_rdy = STAGE_NEW;
//     #(PERIOD * 2)
//     nonlinear_s_rdy = 0;
// end

/*
    ************* UPD *****************
*/
initial begin
    #(PERIOD*RST_START)
    stage_val = STAGE_UPD;
    #(PERIOD * 2)
    stage_val = 0;
end

initial begin
    #(PERIOD*RST_START)
    #(PERIOD * 5)
    nonlinear_s_val = STAGE_UPD;
    #(PERIOD * 2)
    nonlinear_s_val = 0;
end

initial begin
    #(PERIOD*RST_START)
    #(PERIOD * 10)
    nonlinear_s_rdy = STAGE_UPD;
    #(PERIOD * 2)
    nonlinear_s_rdy = 0;
end

RSA #(
    .X            ( X            ),
    .Y            ( Y            ),
    .L            ( L            ),
    .RSA_DW       ( RSA_DW       ),
    .TB_AW        ( TB_AW        ),
    .CB_AW        ( CB_AW        ),
    .SEQ_CNT_DW ( SEQ_CNT_DW ),
    .ROW_LEN      ( ROW_LEN      ))
 u_RSA (
    .clk                     ( clk                    ),
    .sys_rst                 ( sys_rst                ),
    .landmark_num            (landmark_num            ),
    .l_k                     (l_k                     ),
    .stage_val               ( stage_val        [2:0] ),
    .nonlinear_s_val         ( nonlinear_s_val  [2:0] ),
    .nonlinear_s_rdy         ( nonlinear_s_rdy  [2:0] ),

    .stage_rdy               ( stage_rdy        [2:0] ),
    .nonlinear_m_rdy         ( nonlinear_m_rdy  [2:0] ),
    .nonlinear_m_val         ( nonlinear_m_val  [2:0] )
);


endmodule