`timescale  1ns / 1ps

module tb_TB_doutb_map;

// TB_doutb_map Parameters
parameter PERIOD      = 10;
parameter X           = 4 ;
parameter Y           = 4 ;
parameter L           = 4 ;
parameter SEQ_CNT_DW  = 5 ;
parameter RSA_DW      = 16;

// TB_doutb_map Inputs
reg   clk                                  = 0 ;
reg   sys_rst                              = 0 ;
reg   [2:0]  TB_doutb_sel                  = 0 ;
reg   l_k_0                                = 0 ;
reg   [SEQ_CNT_DW-1 : 0]  seq_cnt_dout_sel = 0 ;
reg   [L*RSA_DW-1 : 0]  TB_doutb           = 0 ;

// TB_doutb_map Outputs
wire  [Y*RSA_DW-1 : 0]  B_TB_doutb         ;
wire  [Y*RSA_DW-1 : 0]  TB_doutb_TB_dina   ;


initial
begin
    forever #(PERIOD/2)  clk=~clk;
end

initial
begin
    #(PERIOD*15) sys_rst  =  1;
    #(PERIOD*2) sys_rst  =  0;
end

TB_doutb_map #(
    .X          ( X          ),
    .Y          ( Y          ),
    .L          ( L          ),
    .SEQ_CNT_DW ( SEQ_CNT_DW ),
    .RSA_DW     ( RSA_DW     ))
 u_TB_doutb_map (
    .clk                     ( clk                                  ),
    .sys_rst                 ( sys_rst                              ),
    .TB_doutb_sel            ( TB_doutb_sel      [2:0]              ),
    .l_k_0                   ( l_k_0                                ),
    .seq_cnt_dout_sel        ( seq_cnt_dout_sel  [SEQ_CNT_DW-1 : 0] ),
    .TB_doutb                ( TB_doutb          [L*RSA_DW-1 : 0]   ),

    .B_TB_doutb              ( B_TB_doutb        [Y*RSA_DW-1 : 0]   ),
    .TB_doutb_TB_dina        ( TB_doutb_TB_dina  [Y*RSA_DW-1 : 0]   )
);

endmodule