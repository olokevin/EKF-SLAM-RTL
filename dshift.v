module dshift #(
  parameter DW = 16,
  parameter DEPTH = 4
) (
  input clk,
  input dir,
  
  input   [DW-1 : 0] din,
  output  reg   [DW*DEPTH-1 : 0]  dout
);
  always @(posedge clk) begin
    if(dir == 1'b0) begin
      dout <= {dout[0 +: (DEPTH-1)*DW], din};
    end
    else if(dir == 1'b1) begin
      dout <= {din, dout[DW : (DEPTH-1)*DW]};
    end
    else
      dout <= 0;    
  end
endmodule