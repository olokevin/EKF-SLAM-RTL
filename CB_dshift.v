module CB_dshift #(
  parameter DW = 16,
  parameter DEPTH = 4
) (
  input clk,
  input sys_rst,

  input [1:0] CB_dir,
  input [1:0] landmark_num_10,
  
  input   [DW-1 : 0] din,
  output  reg   [DW*DEPTH-1 : 0]  dout
);

  localparam DIR_IDLE = 2'b00;
  localparam DIR_POS  = 2'b01;
  localparam DIR_NEG  = 2'b10;
  localparam DIR_NEW  = 2'b11;

  localparam  DIR_NEW_11  = 2'b11; 
  localparam  DIR_NEW_00  = 2'b00;
  localparam  DIR_NEW_01  = 2'b01;
  localparam  DIR_NEW_10  = 2'b10;

always @(posedge clk) begin
  if(sys_rst) begin
    dout <= 0;
  end
  else begin
    case (CB_dir)
      DIR_POS: dout <= {dout[0 +: (DEPTH-1)*DW], din};
      DIR_NEG: dout <= {din, dout[DW +: (DEPTH-1)*DW]};
      DIR_NEW: begin
        case(landmark_num_10)
          DIR_NEW_11: begin
            dout[0 +: DW]       <= din;
            dout[1*DW +: DW] <= dout[0 +: DW];
            dout[2*DW +: DW] <= 0;
            dout[3*DW +: DW] <= 0;
          end
          DIR_NEW_00: begin
            dout[0 +: DW]       <= 0;
            dout[1*DW +: DW] <= 0;
            dout[2*DW +: DW] <= din;
            dout[3*DW +: DW] <= dout[2*DW +: DW];
          end
          DIR_NEW_01: begin
            dout[0 +: DW]       <= 0;
            dout[1*DW +: DW] <= 0;
            dout[2*DW +: DW] <= dout[3*DW +: DW];
            dout[3*DW +: DW] <= din;
          end
          DIR_NEW_10: begin
            dout[0 +: DW]       <= dout[1*DW +: DW];
            dout[1*DW +: DW] <= din;
            dout[2*DW +: DW] <= 0;
            dout[3*DW +: DW] <= 0;
          end
        endcase
      end
      default: begin
        dout <= 0;
      end
    endcase
  end
end
endmodule