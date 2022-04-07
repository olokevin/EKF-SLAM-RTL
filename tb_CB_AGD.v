`timescale  1ns / 1ps

module tb_CB_AGD;

// CB_AGD Parameters
parameter PERIOD        = 10 ;
parameter CB_AW  = 19;
parameter MAX_LANDMARK = 500;       //500 landmarks, 1003rows of data, 1003/8 = 126 groups
parameter ROW_LEN      = 10;

// CB_AGD Inputs
reg   clk                                  = 1 ;
reg   sys_rst                              = 0 ;
reg   [ROW_LEN-1 : 0]  CB_row            = 0 ;
reg   [ROW_LEN-1 : 0]  CB_col            = 0 ;

// CB_AGD Outputs
wire  [CB_AW-1 : 0]  CB_addr    ;


initial
begin
    forever #(PERIOD/2)  clk=~clk;
end

initial
begin
    #(PERIOD*15) sys_rst  =  1;
    #(PERIOD*2) sys_rst  =  0;
end

CB_AGD #(
    .CB_AW  ( CB_AW  ),
    .MAX_LANDMARK ( MAX_LANDMARK ),
    .ROW_LEN      ( ROW_LEN    ))
 u_CB_AGD (
    .clk                     ( clk                               ),
    .sys_rst                 ( sys_rst                           ),
    .CB_row                  ( CB_row        [ROW_LEN-1 : 0]   ),
    .CB_col                  ( CB_col        [ROW_LEN-1 : 0]   ),

    .CB_addr                 ( CB_addr  [CB_AW-1 : 0] )
);

integer i;
initial
begin
    #(PERIOD*20);
    for(i=8; i<32; i=i+1) begin
        @(negedge clk);
        CB_row <= i;
    end
    
end

// integer actual_addr;
integer j;
initial begin
    #(PERIOD*20);
    #(PERIOD*5)
    for(j=8; j<32; j=j+1) begin
        @(negedge clk);
        $display("time=%t, CB_addr%d: %d", $time, j, CB_addr) ;
    end
    
end

endmodule
