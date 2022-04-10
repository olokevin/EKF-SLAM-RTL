/*
  移位模块
  无使能信号
  dir==0：左移
  dir==1: 右移
*/
module dshift #(
  parameter DW = 16,
  parameter DEPTH = 4
) (
  input clk,
  input sys_rst,
  input dir,
  
  input   [DW-1 : 0] din,
  output  reg   [DW*DEPTH-1 : 0]  dout
);
  always @(posedge clk) begin
    if(sys_rst) begin
      dout <= 0;
    end
    else begin
      if(dir == 1'b0) begin
        dout <= {dout[0 +: (DEPTH-1)*DW], din};
      end
      else if(dir == 1'b1) begin
        dout <= {din, dout[DW +: (DEPTH-1)*DW]};
      end
    end
  end
endmodule