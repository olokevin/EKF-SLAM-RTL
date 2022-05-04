module t_ram #(
  parameter DW = 16,
  parameter AW = 4
) (
  input clk,
  input sys_rst,

  input en,
  input we,
  input [AW-1 : 0] addr,

  input [DW-1 : 0] din,
  output reg [DW-1 : 0] dout
);

reg [DW-1:0] ram [AW-1:0];

always @(posedge clk) begin
  if(sys_rst) begin
    dout <= 0;
  end
  else begin
    if(en) begin
      case(we)
        1'b0: dout <= ram[addr];
        1'b1: ram[addr] <= din;
      endcase
    end 
  end
end
  
endmodule