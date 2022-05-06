module dshift #(
  parameter DW = 16,
  parameter DEPTH = 4
) (
  input clk,
  input sys_rst,

  input [1:0] dir,
  
  input   [DW-1 : 0] din,
  output  reg   [DW*DEPTH-1 : 0]  dout
);

  localparam DIR_IDLE = 2'b00;
  localparam DIR_POS  = 2'b01;
  localparam DIR_NEW_0  = 2'b10;
  localparam DIR_NEW_1  = 2'b11;

  // localparam  DIR_NEW_11  = 2'b11; 
  // localparam  DIR_NEW_00  = 2'b00;
  // localparam  DIR_NEW_01  = 2'b01;
  // localparam  DIR_NEW_10  = 2'b10;

always @(posedge clk) begin
  if(sys_rst) begin
    dout <= 0;
  end
  else begin
    case (dir)
      DIR_POS: dout <= {dout[0 +: (DEPTH-1)*DW], din};
      DIR_NEW_1: begin
        dout[0 +: DW]    <= din;
        dout[1*DW +: DW] <= dout[0 +: DW];
        dout[2*DW +: DW] <= 0;
        dout[3*DW +: DW] <= 0;
      end
      DIR_NEW_0: begin
        dout[0 +: DW]    <= 0;
        dout[1*DW +: DW] <= 0;
        dout[2*DW +: DW] <= din;
        dout[3*DW +: DW] <= dout[2*DW +: DW];
      end
      default: begin
        dout <= 0;
      end
    endcase
  end
end
endmodule