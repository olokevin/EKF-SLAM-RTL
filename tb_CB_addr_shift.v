`timescale  1ns / 1ps

module tb_CB_addr_shift;
parameter RST_START = 20;
// CB_addr_shift Parameters
parameter PERIOD   = 10;
parameter L        = 4 ;
parameter CB_AW    = 19;
parameter ROW_LEN  = 10;

// CB_addr_shift Inputs
  reg   clk                                  = 1 ;
  reg   sys_rst                              = 0 ;
  reg   [CB_AW-1 : 0]  CB_addra_new                   = 0 ;

  // CB_addr_shift Outputs
  wire  [CB_AW*L-1 : 0]  CB_addra                ;

// CB_vm_AGD Inputs
  reg   en                                   = 0 ;
  reg   [ROW_LEN-1 : 0]  group_cnt           = 0 ;

  // CB_vm_AGD Outputs
  wire  [CB_AW-1 : 0]  CB_base_addr          ;

//dshift
  reg CB_ena_new = 0;
  wire   [L-1 : 0]  CB_ena                        ;

initial
begin
    forever #(PERIOD/2)  clk=~clk;
end

initial
begin
    #(PERIOD*15) sys_rst  =  1;
    #(PERIOD*2) sys_rst  =  0;
end

//CB PORT-A
  // integer i;
  // initial
  // begin
  //     #(PERIOD*RST_START);
  //     for(i=0; i<32; i=i+1) begin
  //         @(negedge clk) 
  //           group_cnt = i;
  //           $display("time=%t, CB_base_addr%d: %d", $time, i, CB_base_addr) ;
  //           CB_ena_new = 1;
  //           CB_addra_new = CB_base_addr;
  //         @(negedge clk)
  //           CB_addra_new = CB_base_addr + 1;
  //         @(negedge clk) 
  //           en = 1;
  //           CB_addra_new = CB_base_addr + 2;
  //         @(negedge clk)
  //           CB_ena_new = 0;
  //           CB_addra_new = 0;
  //         @(negedge clk) en = 0;
  //         @(negedge clk) ;
  //     end
      
  // end

//CB PORT-B
  integer j;
  initial
  begin
      #(PERIOD*RST_START);
      for(j=0; j<32; j=j+1) begin
          @(negedge clk) 
            group_cnt = j;
            $display("time=%t, CB_base_addr%d: %d", $time, j, CB_base_addr) ;
            CB_ena_new = 1;
            CB_addra_new = CB_base_addr;
          @(negedge clk)
            CB_ena_new = 0;
            CB_addra_new = 0;
          @(negedge clk) 
            en = 1;
            CB_ena_new = 1;
            CB_addra_new = CB_base_addr + 1;
          @(negedge clk)
            CB_ena_new = 0;
            CB_addra_new = 0;
          @(negedge clk) 
            en = 0;
            CB_ena_new = 1;
            CB_addra_new = CB_base_addr + 2;
          @(negedge clk) 
            CB_ena_new = 0;
            CB_addra_new = 0;
            // group_cnt = j+1;
            // $display("time=%t, CB_base_addr%d: %d", $time, j, CB_base_addr) ;
      end
  end

CB_addr_shift #(
    .L       ( L       ),
    .CB_AW   ( CB_AW   ),
    .ROW_LEN ( ROW_LEN ))
 CB_addra_shift (
    .clk                     ( clk                          ),
    .sys_rst                 ( sys_rst                      ),
    .CB_en                   ( CB_ena           [L-2 : 0]       ),
    .group_cnt_0             ( group_cnt[0]                  ),
    .din                     ( CB_addra_new          [CB_AW-1 : 0]   ),

    .dout                    ( CB_addra         [CB_AW*L-1 : 0] )
);

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

  dshift 
  #(
      .DW    (1 ),
      .DEPTH (4 )
  )
  CB_ena_dshift(
      .clk  (clk  ),
      .sys_rst ( sys_rst                       ),
      .dir  (1'b0   ),
      .din  (CB_ena_new  ),
      .dout (CB_ena )
  );

endmodule