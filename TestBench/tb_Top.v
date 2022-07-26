`timescale  1ns / 1ps
module tb_Top;

parameter RST_START = 10;
parameter PRD_WORK = 250;
parameter NEW_WORK = 200;
parameter UPD_WORK = 500;


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

//乘积 部分和  32-bit signed (Q1.12.19) multiplier
    localparam  DATA_INT_BIT = 12;
    localparam  DATA_DEC_BIT = 19;

    localparam  ANGLE_DEC_BIT = 15;

// Top Inputs
reg   clk                                  = 1 ;
reg   sys_rst                              = 0 ;
reg   [2:0]  stage_val                     = 0 ;
reg   [ROW_LEN-1 : 0]  landmark_num        = 4 ;
reg   [ROW_LEN-1 : 0]  l_k                 = 2 ;
reg   [RSA_DW - 1 : 0]  vlr                = (2 <<< DATA_DEC_BIT);
reg   [RSA_AW - 1 : 0]  alpha              = (1 <<< (ANGLE_DEC_BIT-1));
reg   [RSA_DW - 1 : 0]  rk                 = (4 <<< DATA_DEC_BIT);
reg   [RSA_AW - 1 : 0]  phi                = (1 <<< (ANGLE_DEC_BIT-1));

// Top Outputs
wire  [2:0]  stage_rdy                     ;
wire  signed [RSA_DW - 1 : 0] S_data       ;

//stage
  localparam      IDLE       = 3'b000 ;
  localparam      STAGE_PRD  = 3'b001 ;
  localparam      STAGE_NEW  = 3'b010 ;
  localparam      STAGE_UPD  = 3'b011 ;
  localparam      STAGE_ASSOC  = 3'b100 ;


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

    #(PERIOD*PRD_WORK)
    stage_val = STAGE_NEW;
    #(PERIOD * 2)
    stage_val = 0;

    #(PERIOD*NEW_WORK)
    stage_val = STAGE_UPD;
    #(PERIOD * 2)
    stage_val = 0;

    #(PERIOD*UPD_WORK)
    stage_val = STAGE_ASSOC;
    #(PERIOD * 2)
    stage_val = 0;
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