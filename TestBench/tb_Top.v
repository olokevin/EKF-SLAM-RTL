`timescale  1ns / 1ps
`include "macro.v"
module tb_Top;

parameter RST_START = 10;

// Top Parameters
parameter PERIOD      = 10;
parameter RSA_DW      = 32;
parameter RSA_AW      = 17;
parameter ROW_LEN     = 10;
parameter X           = 4 ;
parameter Y           = 4 ;
parameter L           = 4 ;
parameter TB_AW       = 11;
parameter CB_AW       = 17;
parameter SEQ_CNT_DW  = 5 ;

// Top Inputs
reg   clk                                  = 1 ;
reg   sys_rst                              = 0 ;
reg   [2:0]  stage_val                     = 0 ;
reg   [ROW_LEN-1 : 0]  landmark_num        = 4 ;
reg   [ROW_LEN-1 : 0]  l_k                 = 2 ;
reg   [RSA_DW - 1 : 0]  vlr                = 2 ;
reg   [RSA_AW - 1 : 0]  alpha              = 3 ;
reg   [RSA_DW - 1 : 0]  rk                 = 4 ;
reg   [RSA_AW - 1 : 0]  phi                = 5 ;

// Top Outputs
wire  [2:0]  stage_rdy                     ;
wire  signed [RSA_DW - 1 : 0] S_data       ;

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
    #(PERIOD*RST_START) sys_rst  =  1;
    #(PERIOD*2) sys_rst  =  0;
end

/*
    ************* PRD *****************
*/
initial begin
    #(PERIOD*RST_START*2)
    stage_val = STAGE_PRD;
    #(PERIOD * 2)
    stage_val = 0;
end


/*
    ************* NEW *****************
*/
// initial begin
//     #(PERIOD*RST_START)
//     stage_val = STAGE_NEW;
//     #(PERIOD * 2)
//     stage_val = 0;
// end


/*
    ************* UPD *****************
*/
// initial begin
//     #(PERIOD*RST_START)
//     stage_val = STAGE_UPD;
//     #(PERIOD * 2)
//     stage_val = 0;
// end


Top #(
    .RSA_DW     ( RSA_DW     ),
    .RSA_AW     ( RSA_AW     ),
    .ROW_LEN    ( ROW_LEN    ),
    .X          ( X          ),
    .Y          ( Y          ),
    .L          ( L          ),
    .TB_AW      ( TB_AW      ),
    .CB_AW      ( CB_AW      ),
    .SEQ_CNT_DW ( SEQ_CNT_DW ))
 u_Top (
    .clk                     ( clk                                      ),
    .sys_rst                 ( sys_rst                                  ),
    .stage_val               ( stage_val               [2:0]            ),
    .landmark_num            ( landmark_num            [ROW_LEN-1 : 0]  ),

    .l_k                     ( l_k                     [ROW_LEN-1 : 0]  ),
    .vlr                     ( vlr                     [RSA_DW - 1 : 0] ),
    .alpha                   ( alpha                   [RSA_AW - 1 : 0] ),
    .rk                      ( rk                      [RSA_DW - 1 : 0] ),
    .phi                     ( phi                     [RSA_AW - 1 : 0] ),

    .stage_rdy               ( stage_rdy               [2:0]            ),
    .S_data                  ( S_data                  [RSA_DW - 1 : 0] )
);

endmodule