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
reg   signed [RSA_DW - 1 : 0]  vlr                = (2 <<< DATA_DEC_BIT);
reg   signed [RSA_DW - 1 : 0]  alpha              = (1 <<< (DATA_DEC_BIT-2));
reg   signed [RSA_DW - 1 : 0]  rk                 = (4 <<< DATA_DEC_BIT);
reg   signed [RSA_DW - 1 : 0]  phi                = (1 <<< (DATA_DEC_BIT-2));
// reg   [RSA_AW - 1 : 0]  phi                = (1 <<< (ANGLE_DEC_BIT-1));
reg  [31:0]  PLB_dout;


// Top Outputs
wire          stage_rdy                     ;

wire          PLB_clk;
wire          PLB_rst;

wire          PLB_en;  
wire          PLB_we;   
wire  [9:0]   PLB_addr;
wire   [31:0]  PLB_din;

//stage
  localparam      STAGE_IDLE       = 3'b000 ;
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
//读取文件
// localparam INT = 12;
// localparam DEC = 19;

// integer  odometry_fd, odometry_time;
// real    f_vlr, f_alpha, f_odometry_time;
// integer i_vlr, i_alpha, i_odometry_time;

// integer odometry_time;

// initial begin
//     odometry_fd = $fopen("D:/Top_EKF_sim/data/odometry.txt", "r");
//     if (!odometry_fd)
//         $display("odometry open error");
//     $fscanf(odometry_fd, "%f %f %f", f_vlr, f_alpha, f_odometry_time);
//     vlr   = $rtoi(f_vlr * $pow(2, 19));
//     alpha = $rtoi(f_vlr * $pow(2, 19));
//     odometry_time = $rtoi(f_odometry_time);
// end

// integer  observation_fd;
// initial begin
//     observation_fd = $fopen("D:/Top_EKF_sim/data/observation.txt", "r");
//     if (!observation_fd)
//         $display("observation open error");
// end

integer i_stage = 0;
/*
    ************* PRD *****************
*/

initial begin
    #(PERIOD*RST_START*2)
    stage_val <= STAGE_PRD;
    vlr <= 0;
    alpha <= -32'd2221;
    #(PERIOD * 2)
    stage_val <= 0;
end

// initial begin
//     #(PERIOD*RST_START*2)
//     stage_val <= STAGE_PRD;
//     vlr <= 0;
//     alpha <= -32'd2221;
//     #(PERIOD * 2)
//     stage_val <= 0;

//     while(i_stage < 100) begin
//       if(stage_rdy == 1'b1) begin
//         i_stage <= i_stage + 1;
//         if(i_stage % 10 == 0) begin
//           if(i_stage == 10) begin
//             //1st round new landmark initialization

//           end
//           else begin
//             //data association
//           end
//         end
//       end
//     end
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
// initial begin
//     #(PERIOD*RST_START*2)
//     rk        <= 32'd10730636;
//     phi       <= -32'd359159;     //1+12+19
//     stage_val <= STAGE_ASSOC;
//     #(PERIOD * 2)
//     stage_val <= 0;
// end

//Round 2
//10730636 15518183 25638967 15049531  6682245 12563146 12893941  6650043
//-359159  -288242  -247064  -155559  -114381   -43465   125820   176148


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
    // .landmark_num            ( landmark_num            [ROW_LEN-1 : 0]  ),
    // .l_k                     ( l_k                     [ROW_LEN-1 : 0]  ),
    
    // .PLB_clk       (PLB_clk       ),
	  // .PLB_rst       (PLB_rst       ),
	  // .PLB_en        (PLB_en        ),
    // .PLB_we        (PLB_we        ),
    // .PLB_addr      (PLB_addr      ),
    // .PLB_din       (PLB_din       ),
    // .PLB_dout      (PLB_dout      ),

    .vlr                     ( vlr                     [RSA_DW - 1 : 0] ),
    .alpha                   ( alpha                   [RSA_DW - 1 : 0] ),
    .rk                      ( rk                      [RSA_DW - 1 : 0] ),
    .phi                     ( phi                     [RSA_DW - 1 : 0] ),

    .stage_rdy               ( stage_rdy                           )

);

endmodule