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

localparam DEPTH = 2**AW;
reg [DW-1:0] ram [DEPTH-1:0];

always @(posedge clk) begin
  if(sys_rst) begin
    dout <= 0;
  end
  else begin
    if(en) begin
      case(we)
        1'b0: begin
          dout <= ram[addr];
        end
        1'b1: begin
          dout <= 0;
          ram[addr] <= din;
        end 
      endcase
    end
    else
      dout <= 0;
  end
end
  
endmodule