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
parameter MAX_LANDMARK  = 500;
parameter ROW_LEN       = 10 ;

// RSA Inputs
reg   clk                                  = 1 ;
reg   sys_rst                              = 0 ;
reg   [ROW_LEN-1 : 0] landmark_num         = 5 ;
reg   [2:0]  stage_val                     = 0 ;
reg   [2:0]  nonlinear_s_val               = 0 ;
reg   [2:0]  nonlinear_s_rdy               = 0 ;

// RSA Outputs
wire  [2:0]  stage_rdy                     ;
wire  [2:0]  nonlinear_m_rdy               ;
wire  [2:0]  nonlinear_m_val               ;


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

RSA #(
    .X            ( X            ),
    .Y            ( Y            ),
    .L            ( L            ),
    .RSA_DW       ( RSA_DW       ),
    .TB_AW        ( TB_AW        ),
    .CB_AW        ( CB_AW        ),
    .MAX_LANDMARK ( MAX_LANDMARK ),
    .ROW_LEN      ( ROW_LEN      ))
 u_RSA (
    .clk                     ( clk                    ),
    .sys_rst                 ( sys_rst                ),
    .landmark_num            (landmark_num            ),
    .stage_val               ( stage_val        [2:0] ),
    .nonlinear_s_val         ( nonlinear_s_val  [2:0] ),
    .nonlinear_s_rdy         ( nonlinear_s_rdy  [2:0] ),

    .stage_rdy               ( stage_rdy        [2:0] ),
    .nonlinear_m_rdy         ( nonlinear_m_rdy  [2:0] ),
    .nonlinear_m_val         ( nonlinear_m_val  [2:0] )
);


endmodule