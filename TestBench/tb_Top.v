`timescale  1ns / 1ps
module tb_Top;

parameter RST_START = 10;
parameter PRD_WORK = 600;
parameter NEW_WORK = 500;
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
reg   sys_rst_n                            = 1 ;
reg   [2:0]  stage_val                     = 0 ;
reg   [ROW_LEN-1 : 0]  landmark_num        = 4 ;
reg   [ROW_LEN-1 : 0]  l_k                 = 2 ;
reg   [RSA_DW - 1 : 0]  vlr                = (2 <<< DATA_DEC_BIT);
reg   [RSA_DW - 1 : 0]  alpha              = (1 <<< (DATA_DEC_BIT-2));
reg   [RSA_DW - 1 : 0]  rk                 = (4 <<< DATA_DEC_BIT);
reg   [RSA_DW - 1 : 0]  phi                = (1 <<< (DATA_DEC_BIT-2));
// reg   [RSA_AW - 1 : 0]  phi                = (1 <<< (ANGLE_DEC_BIT-1));
reg  [31:0]  PLB_dout;


// Top Outputs
wire  [2:0]  stage_rdy                     ;

wire          PLB_clk;
wire          PLB_rst;

wire          PLB_en;  
wire          PLB_we;   
wire  [9:0]   PLB_addr;
wire   [31:0]  PLB_din;

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
    #(PERIOD*RST_START) sys_rst_n  =  0;
    #(PERIOD*2) sys_rst_n  =  1;
end

/*
    ************* test *****************
*/
// initial begin
//     #(PERIOD*RST_START*2)
//     stage_val <= STAGE_PRD;
//     #(PERIOD * 2)
//     stage_val <= 0;

//     #(PERIOD*PRD_WORK)
//     stage_val <= STAGE_NEW;
//     #(PERIOD * 2)
//     stage_val <= 0;

//     #(PERIOD*NEW_WORK)
//     stage_val <= STAGE_UPD;
//     #(PERIOD * 2)
//     stage_val <= 0;

//     #(PERIOD*UPD_WORK)
//     stage_val <= STAGE_ASSOC;
//     #(PERIOD * 2)
//     stage_val <= 0;
// end

/*
    ************* PRD *****************
*/
// initial begin
//     #(PERIOD*RST_START*2)
//     stage_val = STAGE_PRD;
//     #(PERIOD * 2)
//     stage_val = 0;
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


/*
    ************* UPD *****************
*/
// initial begin
//     #(PERIOD*RST_START*2)
//     stage_val = STAGE_UPD;
//     #(PERIOD * 2)
//     stage_val = 0;
// end

/*
    ************* ASSOC *****************
*/
initial begin
    #(PERIOD*RST_START*2)
    stage_val = STAGE_ASSOC;
    #(PERIOD * 2)
    stage_val = 0;
end


Top 
  // #(
  //   .RSA_DW     ( RSA_DW     ),
  //   .RSA_AW     ( RSA_AW     ),
  //   .ROW_LEN    ( ROW_LEN    ),
  //   .X          ( X          ),
  //   .Y          ( Y          ),
  //   .L          ( L          ),
  //   .TB_AW      ( TB_AW      ),
  //   .CB_AW      ( CB_AW      ),
  //   .SEQ_CNT_DW ( SEQ_CNT_DW ))
 u_Top (
    .clk                     ( clk                                      ),
    .sys_rst_n               ( sys_rst_n                                  ),
    .stage_val               ( stage_val               [2:0]            ),
    .landmark_num            ( landmark_num            [ROW_LEN-1 : 0]  ),

    .l_k                     ( l_k                     [ROW_LEN-1 : 0]  ),
    .vlr                     ( vlr                     [RSA_DW - 1 : 0] ),
    .alpha                   ( alpha                   [RSA_AW - 1 : 0] ),
    .rk                      ( rk                      [RSA_DW - 1 : 0] ),
    .phi                     ( phi                     [RSA_AW - 1 : 0] ),

    .stage_rdy               ( stage_rdy               [2:0]            )
    // .PLB_clk       (PLB_clk       ),
	  // .PLB_rst       (PLB_rst       ),
	  // .PLB_en        (PLB_en        ),
    // .PLB_we        (PLB_we        ),
    // .PLB_addr      (PLB_addr      ),
    // .PLB_din       (PLB_din       ),
    // .PLB_dout      (PLB_dout      )
);

endmodule