module PE_config #(
    parameter X = 4,
    parameter Y = 4,
    parameter L = 4,

    parameter RSA_DW = 16,
    parameter TB_AW = 12,
    parameter CB_AW = 19,

    parameter MAX_LANDMARK = 500,
    parameter ROW_LEN    = 10
) (
    input clk,
    input sys_rst,

    //landmark numbers
    input   [ROW_LEN-1 : 0]  landmark_num,
    input   [ROW_LEN-1 : 0]  cov_row_num,
    input   [ROW_LEN-1 : 0]  group_num,
    //handshake of stage change
    input   [2:0]   stage_val,
    output  reg [2:0]   stage_rdy,

    //handshake of nonlinear calculation start & complete
    output   reg [2:0]   nonlinear_val,
    input    [2:0]   nonlinear_rdy,

    output reg [X-1 : 0]                A_in_sel,
    output reg [X-1 : 0]                A_in_en,     

    output reg [2*(Y-1) : 0]            B_in_sel,   
    output reg [Y-1 : 0]                B_in_en,  

    output reg [2*(X-1) : 0]            M_in_sel,  
    output reg [X-1 : 0]                M_in_en,  

    output reg [2*(X-1) : 0]            C_out_sel, 
    output reg [X-1 : 0]                C_out_en,

    output reg [L-1 : 0]                TB_dinb_sel,
    output reg [L-1 : 0]                TB_douta_sel,
    output reg [L-1 : 0]                TB_doutb_sel,

    output reg [L-1 : 0]                TB_ena,
    output reg [L-1 : 0]                TB_enb,

    output reg [L-1 : 0]                TB_wea,
    output reg [L-1 : 0]                TB_web,

    output reg [L*RSA_DW-1 : 0]         init_TB_dina,
    output reg [L*TB_AW-1 : 0]          TB_addra,
    output reg [L*TB_AW-1 : 0]          TB_addrb,

    output reg [L-1 : 0]                CB_dinb_sel,
    output reg [L-1 : 0]                CB_douta_sel,
    output reg [L-1 : 0]                CB_doutb_sel,

    output reg [L-1 : 0]                CB_ena,
    output reg [L-1 : 0]                CB_enb,

    output reg [L-1 : 0]                CB_wea,
    output reg [L-1 : 0]                CB_web,

    output reg [L*RSA_DW-1 : 0]         init_CB_dina,
    output reg [L*CB_AW-1 : 0]          CB_addra,
    output reg [L*RSA_DW-1 : 0]         CB_dinb,
    output reg [L*CB_AW-1 : 0]          CB_addrb

);
//delay
    parameter RD_DELAY = 3;
    parameter WR_DELAY = 2;
    parameter AGD_DELAY = 5;

//stage
    parameter            IDLE       = 3'b000 ;
    parameter            STAGE_PRD  = 3'b001 ;
    parameter            STAGE_NEW  = 3'b010 ;
    parameter            STAGE_UPD  = 3'b100 ;

//stage_rdy
    parameter BUSY    = 3'b000;
    parameter READY   = 3'b111;

// TEMP BANK offsets of PRD
    parameter F_xi = 0;
    parameter F_xi_T = 3;
    parameter t_cov = 6;
    parameter F_cov = 9;
    parameter M = 12;
// PREDICTION SERIES
    parameter PRD_IDLE = 'b0000;
    parameter PRD_NONLINEAR = 'b0001;
    parameter PRD_1 = 'b0010;           //prd_cur[1]
    parameter PRD_2 = 'b0100;
    parameter PRD_3 = 'b1000;

    localparam PRD_1_START = 0;
    localparam PRD_2_START = 'd18;
    localparam PRD_3_START = 'd36;
    localparam PRD_3_END = 'd80;

    localparam PRD_1_N = 3;
    localparam PRD_2_N = 3;
    localparam PRD_3_N = 3;

    localparam NEW_2_PEin = 4;      //给出addr_new到westin
    localparam ADDER_2_NEW = 1;     //adder输出到给addr_new

//shift def
reg       A_in_sel_new;
reg [1:0] B_in_sel_new;
reg [1:0] M_in_sel_new;
reg [1:0] C_out_sel_new;

reg               TB_ena_new;
reg               TB_wea_new;
reg               TB_douta_sel_new;
reg [TB_AW-1 : 0] TB_addra_new;

reg               TB_B_shift_dir;
reg               TB_enb_new;
reg               TB_web_new;
reg               TB_dinb_sel_new;
reg               TB_doutb_sel_new;
reg [TB_AW-1 : 0] TB_addrb_new;

localparam LEFT_SHIFT = 1'b0;
localparam RIGHT_SHIFT = 1'b1;

//shift of PE_sel
  dshift 
  #(
      .DW    (1 ),
      .DEPTH (4 )
  )
  A_in_sel_dshift(
      .clk  (clk  ),
      .dir  (RIGHT_SHIFT   ),
      .din  (A_in_sel_new  ),
      .dout (A_in_sel )
  );

  dshift 
  #(
      .DW    (2 ),
      .DEPTH (4 )
  )
  B_in_sel_dshift(
      .clk  (clk  ),
      .dir   (LEFT_SHIFT   ),
      .din  (B_in_sel_new  ),
      .dout (B_in_sel )
  );

  dshift 
  #(
      .DW    (2 ),
      .DEPTH (4 )
  )
  M_in_sel_dshift(
      .clk  (clk  ),
      .dir  (RIGHT_SHIFT   ),
      .din  (M_in_sel_new  ),
      .dout (M_in_sel )
  );

  dshift 
  #(
      .DW    (2 ),
      .DEPTH (4 )
  )
 C_out_sel_dshift(
      .clk  (clk  ),
      .ce   (RIGHT_SHIFT   ),
      .din  (C_out_sel_new  ),
      .dout (C_out_sel )
  );

//shift of TB_portA
  dshift 
  #(
      .DW    (1 ),
      .DEPTH (4 )
  )
  TB_ena_dshift(
      .clk  (clk  ),
      .dir  (RIGHT_SHIFT   ),
      .din  (TB_ena_new  ),
      .dout (TB_ena )
  );

  dshift 
  #(
      .DW    (1 ),
      .DEPTH (4 )
  )
  TB_wea_dshift(
      .clk  (clk  ),
      .dir   (RIGHT_SHIFT   ),
      .din  (TB_wea_new  ),
      .dout (TB_wea )
  );

  dshift 
  #(
      .DW    (1 ),
      .DEPTH (4 )
  )
  TB_douta_sel_dshift(
      .clk  (clk  ),
      .dir  (RIGHT_SHIFT   ),
      .din  (TB_douta_sel_new  ),
      .dout (TB_douta_sel )
  );

  dshift 
  #(
      .DW    (TB_AW    ),
      .DEPTH (4 )
  )
  TB_addra_dshift(
      .clk  (clk  ),
      .dir   (RIGHT_SHIFT   ),
      .din  (TB_addra_new  ),
      .dout (TB_addra )
  );

//shift of TB_portB
  dshift 
  #(
      .DW    (1 ),
      .DEPTH (4 )
  )
  TB_enb_dshift(
      .clk  (clk  ),
      .dir  (TB_B_shift_dir   ),
      .din  (TB_enb_new  ),
      .dout (TB_enb )
  );

  dshift 
  #(
      .DW    (1 ),
      .DEPTH (4 )
  )
  TB_web_dshift(
      .clk  (clk  ),
      .dir   (TB_B_shift_dir   ),
      .din  (TB_web_new  ),
      .dout (TB_web )
  );

  dshift 
  #(
      .DW    (1 ),
      .DEPTH (4 )
  )
  TB_doutb_sel_dshift(
      .clk  (clk  ),
      .dir   (TB_B_shift_dir   ),
      .din  (TB_doutb_sel_new  ),
      .dout (TB_doutb_sel )
  );

  dshift 
  #(
      .DW    (TB_AW    ),
      .DEPTH (4 )
  )
  TB_addrb_dshift(
      .clk  (clk  ),
      .dir  (TB_B_shift_dir   ),
      .din  (TB_addrb_new  ),
      .dout (TB_addrb )
  );

//CB_AGD
reg [ROW_LEN-1 : 0]  CB_row;
reg [ROW_LEN-1 : 0]  CB_col;

wire [CB_AW-1 : 0] CB_base_addr;

CB_AGD 
#(
    .CB_AW  (CB_AW  ),
    .MAX_LANDMARK (MAX_LANDMARK ),
    .ROW_LEN      (ROW_LEN      )
)
u_CB_AGD(
    .clk     (clk     ),
    .sys_rst (sys_rst ),
    .CB_row  (CB_row  ),
    .CB_col  (CB_col  ),
    .CB_base_addr (CB_base_addr )
);

/*
    FSM of STAGE(IDLE PRD NEW UPD)
*/

    //stage variables
    reg [2:0]            stage_next ;
    reg [2:0]            stage_cur ;
    reg                  stage_change_err;  

    //(1) state transfer
    always @(posedge clk) begin
        if (sys_rst) begin
            stage_cur      <= IDLE ;
        end
        else begin
            stage_cur      <= stage_next ;
        end
    end

    //(2) state switch
    always @(*) begin
        case(stage_cur)
            IDLE: begin
                case(stage_val & stage_rdy)
                    IDLE:       stage_next = IDLE;
                    STAGE_PRD:  stage_next = STAGE_PRD;
                    STAGE_NEW:  stage_next = STAGE_NEW;
                    STAGE_UPD:  stage_next = STAGE_UPD;
                    default: begin
                        stage_next = IDLE;
                        stage_change_err = 1'b1;
                    end    
                endcase
            end
            STAGE_PRD: begin
                case(stage_val & stage_rdy)
                   IDLE:       stage_next = IDLE; 
                endcase
            end
        endcase
    end

    //(3) output
    always @(posedge clk) begin
        if(sys_rst)
            stage_rdy <= READY;
        else if(stage_cur != IDLE) begin
            stage_rdy <= BUSY;
        end
        else
            stage_rdy <= READY;
    end

/*
    Prediction(PRD)
*/

    reg [TB_AW-1:0]   prd_cnt;
    reg [ROW_LEN-1:0]    group_cnt;     //n个特征点 2n行 n/2组
    reg [1:0]   prd_cur;
    reg [1:0]   prd_next;

//Prediciton cnt
    always @(posedge clk) begin
        if(sys_rst) begin
            prd_cnt <= 0;
        end
        case(stage_cur)  
            STAGE_PRD: begin
                case(prd_cur)
                    PRD_IDLE: prd_cnt <= 0;
                    PRD_NONLINEAR: prd_cnt <= 0;
                    default: prd_cnt <= prd_cnt + 1'b1;
                endcase
            end
            STAGE_NEW: begin
                
            end
            STAGE_UPD: begin
                
            end
            default: prd_cnt <= 0;
        endcase
    end

/*
    FSM of PRD stage
*/

    // //(1) state transfer
    // always @(posedge clk) begin
    //     if (sys_rst) begin
    //         prd_cur      <= PRD_IDLE ;
    //     end
    //     else begin
    //         prd_cur      <= prd_next ;
    //     end
    // end

    //(1)&(2)sequential: state transfer & state switch
    always @(posedge clk) begin
        case(prd_cur)
            PRD_IDLE: begin
                if(stage_val & stage_rdy == STAGE_PRD) begin
                    prd_cur <= PRD_NONLINEAR;
                end
                else
                    prd_cur <= PRD_IDLE;
            end
            PRD_NONLINEAR: begin
                if(nonlinear_val & nonlinear_rdy == 1'b1) begin
                    prd_cur <= PRD_1;
                end
                else
                    prd_cur <= PRD_NONLINEAR;
            end
            PRD_1: begin
                if(prd_cnt == PRD_2_START) begin
                    prd_cur <= PRD_2;
                end
                else
                    prd_cur <= PRD_1;
            end
            PRD_2: begin
                if(prd_cnt == PRD_3_START) begin
                    prd_cur <= PRD_3;
                end
                else
                    prd_cur <= PRD_2;
            end
            PRD_3: begin
                if(prd_cnt == PRD_3_END) begin
                    prd_cur <= PRD_IDLE;
                end
                else
                    prd_cur <= PRD_3;
            end
            default: begin
                prd_cur <= PRD_IDLE;
            end
        endcase
    end

/*
    For read(input) A B M, signals/data needed:
        X_in_sel:   sel of MUX
        X_in_en:       enable of MUX/deMUX

        pB_doutq_sel
        pB_weq

        //if
        pB_enq
        pB_addrq

    For write(output) C, signals/data needed:
        C_out_sel
        C_out_en

        CB_dinb_sel  / TB_dinb_sel
        CB_doutb_sel / TB_doutb_sel
        pB_weq

        //if
        pB_enq
        pB_addrq

*/
//(3) output: nonlinear_val, addr, en, we, val,
    always @(posedge clk) begin
        if(sys_rst)
            nonlinear_val <= 0;
        else if(prd_cur == PRD_NONLINEAR) begin
            nonlinear_val <= 1'b1;
        end
        else
            nonlinear_val <= 0;    
    end 


//(4) output: 配置A B输入模式
    always @(posedge clk) begin
        if(sys_rst) begin
            TB_ena_new <= 1'b0;
            TB_addra_new <= 0;

            TB_enb_new <= 1'b0;
            TB_addrb_new <= 0;
        end
        else begin
            case(prd_cur)
                PRD_1: begin
                /*
                    F_xi * t_cov = F_cov
                    X=3 Y=3 N=3
                    Ain: TB-A
                    bin: TB-B
                    Cout: TB-A
                */
                    A_in_en <= 4'b1110;  
                    B_in_en <= 4'b0111;
                    M_in_en <= 4'b0000;
                    C_out_en <= 4'b1110;
                    
                    A_in_sel_new <= 1'b0;   
                    B_in_sel_new <= 2'b00;
                    M_in_sel_new <= 2'b00;
                    C_out_sel_new <= 2'b00;

                    TB_douta_sel_new <= 1'b0;    
                    TB_dinb_sel_new <= 1'b0;
                    TB_doutb_sel_new <= 1'b0;
                    
                    if (prd_cnt < PRD_1_START+PRD_1_N) begin
                        TB_ena_new <= 1'b1;
                        TB_wea_new <= 1'b0;
                        TB_addra_new <= F_xi + prd_cnt;

                        TB_B_shift_dir <= 1'b0;
                        TB_enb_new <= 1'b1;
                        TB_web_new <= 1'b0;
                        TB_addrb_new <= t_cov + prd_cnt;
                    end
                    else if(prd_cnt == NEW_2_PEin+PRD_1_N+2+ADDER_2_NEW) begin
                        TB_ena_new <= 1'b0;
                        TB_wea_new <= 1'b0;
                        TB_addra_new <= 0;

                        TB_B_shift_dir <= 1'b1;
                        TB_enb_new <= 1'b1;
                        TB_web_new <= 1'b1;
                        TB_addrb_new <= F_cov;
                    end
                    else if(prd_cnt == NEW_2_PEin+PRD_1_N+2+ADDER_2_NEW + 2) begin
                        TB_ena_new <= 1'b0;
                        TB_wea_new <= 1'b0;
                        TB_addra_new <= 0;

                        TB_enb_new <= 1'b1;
                        TB_web_new <= 1'b1;
                        TB_addrb_new <= F_cov + 1'b1;
                    end
                    else if(prd_cnt == NEW_2_PEin+PRD_1_N+2+ADDER_2_NEW + 4) begin
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

                        TB_B_shift_dir <= TB_B_shift_dir;
                        TB_enb_new <= 1'b0;
                        TB_web_new <= 1'b0;
                        TB_addrb_new <= 0;
                    end
                    // if(prd_cnt < 'd3) begin
                    // //Ain TB-A
                    //     //ena 右移
                    //     TB_ena <= {1'b1, TB_ena[L-2:0]} & 'b1110;
                    //     //addr向低位传递
                    //     TB_addra[(L-1)*TB_AW +: TB_AW] <= F_xi + prd_cnt;
                    //     TB_addra[0 +: (L-1)*TB_AW ] <= TB_addra[TB_AW +: (L-1)*TB_AW];
                    // //Bin TB-B
                    //     //enb左移
                    //     TB_enb <= {TB_ena[L-1:1], 1'b1} & 'b0111;
                    //     //addr向高位传递
                    //     TB_addrb[0 +: TB_AW] <= t_cov + prd_cnt;
                    //     TB_addrb[TB_AW +: (L-1)*TB_AW] <= TB_addrb[0 +: (L-1)*TB_AW];
                    // end
                    // else begin
                    //     //Ain TB-A
                    //     //ena 右移
                    //     TB_ena <= {1'b0, TB_ena[L-2:0]} & 'b1110;
                    //     //addr向低位传递
                    //     TB_addra[(L-1)*TB_AW +: TB_AW] <= 0;
                    //     TB_addra[0 +: (L-1)*TB_AW ] <= TB_addra[TB_AW +: (L-1)*TB_AW];
                    // //Bin TB-B
                    //     //enb左移
                    //     TB_enb <= {TB_ena[L-1:1], 1'b0} & 'b0111;
                    //     //addr向高位传递
                    //     TB_addrb[0 +: TB_AW] <= 0;
                    //     TB_addrb[TB_AW +: (L-1)*TB_AW] <= TB_addrb[0 +: (L-1)*TB_AW];
                    // end
                end
                PRD_2: begin
                /*
                    F_cov * t_cov + M= cov
                    X=3 Y=3 N=3
                    Ain: TB-A
                    Bin: TB-B
                    Min: 0      //actual M input time is in PRD_3
                    Cout: CB-B
                */
                    A_in_en <= 4'b1110;  
                    B_in_en <= 4'b0111;
                    M_in_en <= 4'b1110;
                    C_out_en <= 4'b1110;
                    
                    A_in_sel_new <= 1'b0;   
                    B_in_sel_new <= 2'b00;
                    M_in_sel_new <= 2'b01;
                    C_out_sel_new <= 2'b00;

                    TB_B_shift_dir <= 1'b0;
                    TB_douta_sel_new <= 1'b0;    
                    TB_dinb_sel_new <= 1'b0;
                    TB_doutb_sel_new <= 1'b0;
                    
                    if (prd_cnt < PRD_1_START+PRD_1_N) begin
                        TB_ena_new <= 1'b1;
                        TB_wea_new <= 1'b0;
                        TB_addra_new <= F_xi + prd_cnt;

                        TB_enb_new <= 1'b1;
                        TB_web_new <= 1'b0;
                        TB_addrb_new <= t_cov + prd_cnt;
                    end
                    else if(prd_cnt == NEW_2_PEin+PRD_1_N+2+ADDER_2_NEW) begin
                        TB_ena_new <= 1'b0;
                        TB_wea_new <= 1'b0;
                        TB_addra_new <= 0;

                        TB_enb_new <= 1'b1;
                        TB_web_new <= 1'b1;
                        TB_addrb_new <= F_cov;
                    end
                    else if(prd_cnt == NEW_2_PEin+PRD_1_N+2+ADDER_2_NEW + 2) begin
                        TB_ena_new <= 1'b0;
                        TB_wea_new <= 1'b0;
                        TB_addra_new <= 0;

                        TB_enb_new <= 1'b1;
                        TB_web_new <= 1'b1;
                        TB_addrb_new <= F_cov + 1'b1;
                    end
                    else if(prd_cnt == NEW_2_PEin+PRD_1_N+2+ADDER_2_NEW + 4) begin
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
                PRD_3: begin
                /*
                    cov_mv * F_xi_T = cov_mv
                    X=3 Y=3 N=3
                    Ain: CB-A
                    Bin: TB-B
                    Min: TB-A   //PRD_2 adder
                    Cout: CB-B
                */
                    A_in_sel <= 4'b1111;   
                    A_in_en <= 4'b1111;       
                    TB_douta_sel <= 4'b0000;

                    B_in_sel <= 8'b00_00_00_00;   
                    B_in_en <= 4'b0111;       
                    TB_doutb_sel <= 4'b0000;
                end
                default: begin
                    A_in_sel <= 4'b0000;   
                    A_in_en <= 4'b0000;       
                    TB_douta_sel <= 4'b0000;
                    TB_wea <= 4'b0000;

                    B_in_sel <= 8'b00_00_00_00;   
                    B_in_en <= 4'b0000;       
                    TB_doutb_sel <= 4'b0000;
                    TB_web <= 4'b0000;

                    M_in_sel <= 8'b00_00_00_00;   
                    M_in_en  <= 4'b0000;
                end
            endcase
        end
            
    end

//(5) output: 配置A B输入数据及移位使能
// always @(posedge clk) begin
//     if(sys_rst)
//          <= 0;
//     else if(prd_cnt < 3) begin    //
        
//     end
// end

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