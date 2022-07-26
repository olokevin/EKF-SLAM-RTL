`timescale  1ns / 1ps

module tb_CB_vm_AGD;

parameter RST_START = 20;

// CB_vm_AGD Parameters
parameter PERIOD   = 10;
parameter CB_AW    = 17;
parameter ROW_LEN  = 10;

// CB_vm_AGD Inputs
reg   clk                                  = 1 ;
reg   sys_rst                              = 0 ;
reg   en                                   = 0 ;
reg   [ROW_LEN-1 : 0]  group_cnt           = 0 ;

// CB_vm_AGD Outputs
wire  [CB_AW-1 : 0]  CB_base_addr          ;


initial
begin
    forever #(PERIOD/2)  clk=~clk;
end

initial
begin
    #(PERIOD*15) sys_rst  =  1;
    #(PERIOD*2) sys_rst  =  0;
end

integer i;
initial
begin
    #(PERIOD*RST_START);
    for(i=1; i<32; i=i+1) begin
        @(negedge clk);
        @(negedge clk);
        @(negedge clk) en = 1;
        @(negedge clk);
        @(negedge clk) en = 0;
        @(negedge clk) 
          group_cnt = i;
          $display("time=%t, CB_base_addr%d: %d", $time, i, CB_base_addr) ;
    end
    
end

CB_vm_AGD #(
    .CB_AW   ( CB_AW   ),
    .ROW_LEN ( ROW_LEN ))
 u_CB_vm_AGD (
    .clk                     ( clk                           ),
    .sys_rst                 ( sys_rst                       ),
    .en                      ( en                            ),
    .group_cnt               ( group_cnt     [ROW_LEN-1 : 0] ),

    .CB_base_addr            ( CB_base_addr  [CB_AW-1 : 0]   )
);

endmodule