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

localparam INT = 12;
localparam DEC = 19;
// localparam frontCut = 63 - 2*DEC - INT;
// localparam ultimaCut = DEC + frontCut;

/*
    *********************** odometry ***************************
*/
integer  odometry_fd;
real     f_vlr, f_alpha, f_odometry_time;
reg signed [31:0] int_vlr, int_alpha;
integer odometry_time;

/*open odometry.txt*/
  initial begin
    odometry_fd = $fopen("D:/Top_EKF_sim/data/odometry.txt", "r");
    if (!odometry_fd)
      $display("odometry open error");
    else begin
      $display("odometry open OK");
    end
  end

/*odometry read task*/
  task odometry_read();
  begin
    $fscanf(odometry_fd, "%f %f %f", f_vlr, f_alpha, f_odometry_time);
    $display("f_vlr = %f",f_vlr);
    $display("f_alpha = %f",f_alpha);
    
    int_vlr   = $rtoi(f_vlr * $pow(2, 19));
    int_alpha = $rtoi(f_alpha * $pow(2, 19));
    odometry_time = $rtoi(f_odometry_time);

    $display("vlr = %d",int_vlr);
    $display("alpha = %d",int_alpha);
    $display("odometry_time = %d",odometry_time);
  end
  endtask

/*
    *********************** observation ***************************
*/

integer  observation_fd;
real    f_rk, f_phi, f_observation_time, f_zero;
reg signed [31:0] int_rk[1:20], int_phi[1:20];
integer feature_cnt = 0;    //本轮观测到的特征数量
integer i_feature = 0;

integer code;
reg [999:0]   line_buf;

integer observation_time;

/*open observation.txt*/
  initial begin
    observation_fd = $fopen("D:/Top_EKF_sim/data/observation.txt", "r");
    if (!observation_fd)
      $display("observation open error");
    else begin
      $display("observation open OK");
    end

  end

task observation_read();
  begin
  /*read observation starts*/
    feature_cnt = 0;
    $fscanf(observation_fd, "%f",f_observation_time);
    observation_time = $rtoi(f_observation_time);
    $display("observation_time = %d",observation_time);

    $fscanf(observation_fd, "%f",f_rk);
    $display("f_rk = %f", f_rk);
    while(f_rk > 0) begin
      feature_cnt = feature_cnt + 1;
      int_rk[feature_cnt] = $rtoi(f_rk * $pow(2, 19));
      $display("int_rk[%d] = %d", feature_cnt, int_rk[feature_cnt]);
      $fscanf(observation_fd, "%f",f_rk);
      $display("f_rk = %f", f_rk);
    end

    code = $fgets(line_buf, observation_fd) ;  //读完一行
    // $display("line_buf = %s", line_buf);
    $fscanf(observation_fd, "%f",f_zero);      //读角度的第一个
    
    for(i_feature=1; i_feature<=feature_cnt; i_feature=i_feature+1) begin
      $fscanf(observation_fd, "%f",f_phi);
      $display("f_phi = %f", f_phi);
      int_phi[i_feature] = $rtoi(f_phi * $pow(2, 19));
      // $display("int_phi[%d] = %d", i_feature, int_phi[i_feature]);
    end

    code = $fgets(line_buf, observation_fd) ;  //读完一行
  /*read observation ends*/
  end
endtask

/*
    ************************ From time 0 **************************
*/
integer i_stage = 0;
integer i_assoc = 0;

integer init_flag = 1;
integer assoc_flag = 1;  //Now data associating

initial begin
    //First odometry has beem read
    #(PERIOD*RST_START*2)
    wait(odometry_fd && observation_fd);
    
    odometry_read();
    //   vlr   = int_vlr;
    //   alpha = int_alpha;
    //   stage_val = STAGE_PRD;
    //   #(PERIOD * 2)
    //   stage_val = 0;
    // odometry_read();  //buffer one frame

    observation_read();

    // wait(stage_rdy == 1'b1);  //wait for 1st prediction

    while(i_stage < 100) begin
      i_stage = i_stage + 1;
      //Predicition
        vlr   = int_vlr;    //output buffered data
        alpha = int_alpha;
        stage_val = STAGE_PRD;
        #(PERIOD * 2)
        stage_val = 0;    
        odometry_read();    //buffer one frame
      
      wait(stage_rdy == 1'b1);  //wait for prediction
      //data association
      if(observation_time - odometry_time <= 20) begin
        if(init_flag == 1) begin
          $display("new landmark initialization");
          for(i_assoc=1; i_assoc<=feature_cnt; i_assoc=i_assoc+1) begin
            rk  = int_rk[i_assoc];
            phi = int_phi[i_assoc];
            $display("rk = %d", rk);
            $display("phi = %d", phi);
            stage_val = STAGE_NEW;
            #(PERIOD * 2)
            stage_val = 0;
            wait(stage_rdy == 1'b1);  
          end
          init_flag = 0;
          observation_read(); //read next observation
        end
        else begin
          $display("data association");
          for(i_assoc=1; i_assoc<=feature_cnt; i_assoc=i_assoc+1) begin
            rk  = int_rk[i_assoc];
            phi = int_phi[i_assoc];
            stage_val = STAGE_ASSOC;
            #(PERIOD * 2)
            stage_val = 0;
            wait(stage_rdy == 1'b1);  
          end
          observation_read(); //read next observation
        end
      end
    end
end

/*
    ************* PRD *****************
*/

// initial begin
//     #(PERIOD*RST_START*2)
//     stage_val <= STAGE_PRD;
//     vlr <= 0;
//     alpha <= -32'd2221;
//     #(PERIOD * 2)
//     stage_val <= 0;
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