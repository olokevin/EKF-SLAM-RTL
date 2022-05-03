module CB_dinb_map #(
  parameter X = 4,
  parameter Y = 4,
  parameter L = 4,

  parameter RSA_DW = 16,
  parameter ROW_LEN = 10
) 
(
  input   clk,
  input   sys_rst,

  input   [1:0]   CB_dinb_sel,

  input   [X*RSA_DW-1 : 0]         C_CB_dinb,
  output  reg  [L*RSA_DW-1 : 0]    CB_dinb
);
  
  localparam DIR_IDLE = 2'b00;
  localparam DIR_POS  = 2'b01;
  localparam DIR_NEW_0  = 2'b10;
  localparam DIR_NEW_1  = 2'b11;

  // localparam  DIR_NEW_11  = 2'b11; 
  // localparam  DIR_NEW_00  = 2'b00;
  // localparam  DIR_NEW_01  = 2'b01;
  // localparam  DIR_NEW_10  = 2'b10;

integer i_CB_C;
  always @(posedge clk) begin
    if(sys_rst)
      CB_dinb <= 0;
    else begin
      case(CB_dinb_sel)
        DIR_IDLE: CB_dinb <= 0;
        DIR_POS: begin
          for(i_CB_C=0; i_CB_C<X; i_CB_C=i_CB_C+1) begin
            CB_dinb[i_CB_C*RSA_DW +: RSA_DW] <= C_CB_dinb[i_CB_C*RSA_DW +: RSA_DW];
          end
        end
        DIR_NEW_1: begin
          CB_dinb[0 +: RSA_DW]        <= C_CB_dinb[0 +: RSA_DW];
          CB_dinb[1*RSA_DW +: RSA_DW] <= C_CB_dinb[1*RSA_DW +: RSA_DW];
          CB_dinb[2*RSA_DW +: RSA_DW] <= 0;
          CB_dinb[3*RSA_DW +: RSA_DW] <= 0;
        end
        DIR_NEW_0: begin
          CB_dinb[0 +: RSA_DW]        <= 0;
          CB_dinb[1*RSA_DW +: RSA_DW] <= 0;
          CB_dinb[2*RSA_DW +: RSA_DW] <= C_CB_dinb[0 +: RSA_DW];
          CB_dinb[3*RSA_DW +: RSA_DW] <= C_CB_dinb[1*RSA_DW +: RSA_DW];
        end
        default:
          CB_dinb <= 0;
      endcase
    end  
  end
endmodule