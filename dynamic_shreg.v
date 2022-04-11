module dynamic_shreg #(
    parameter DW = 16,
    parameter AW = 5
) (
  input clk,
  input ce,
  
  input   [AW-1 : 0] addr,
  input   [DW-1 : 0] din,
  output  [DW-1 : 0] dout
);
   localparam DEPTH = 2**AW;
   reg  [DW-1 : 0] shreg_i  [DEPTH : 1];

   assign dout = shreg_i[addr];

    integer i;
   always @(posedge clk) begin
       if(ce) begin
          shreg_i[1] <= din;
          for(i=1; i<=DEPTH-1; i=i+1) begin
            shreg_i[i+1] <= shreg_i[i];
          end
       end     
   end

endmodule