module TB_dinb_map #(
  parameter X = 4,
  parameter Y = 4,
  parameter L = 4,

  parameter RSA_DW = 16
) 
(
  input   clk,
  input   sys_rst,

  input   [1:0]   TB_dinb_sel,
  input           l_k_0,

  input   [X*RSA_DW-1 : 0]         C_TB_dinb,
  output  reg  [L*RSA_DW-1 : 0]    TB_dinb
);

localparam DIR_IDLE = 2'b00;
localparam DIR_POS  = 2'b01;
localparam DIR_NEG  = 2'b10;
localparam DIR_NEW  = 2'b11;

localparam DIR_NEW_0  = 1'b0;
localparam DIR_NEW_1  = 1'b1;
  
integer i_TB_C;
  always @(posedge clk) begin
    if(sys_rst)
      TB_dinb <= 0;
    else begin
      case(TB_dinb_sel)
        DIR_POS: begin
          TB_dinb <= C_TB_dinb;
        end
        DIR_NEG: begin
          for(i_TB_C=0; i_TB_C<X; i_TB_C=i_TB_C+1) begin
            TB_dinb[i_TB_C*RSA_DW +: RSA_DW] <= C_TB_dinb[(X-1-i_TB_C)*RSA_DW +: RSA_DW];
          end
        end
        DIR_NEW : begin
          case (l_k_0)
            DIR_NEW_1: begin
              TB_dinb[0 +: RSA_DW]        <= C_TB_dinb[0 +: RSA_DW];
              TB_dinb[1*RSA_DW +: RSA_DW] <= C_TB_dinb[1*RSA_DW +: RSA_DW];
              TB_dinb[2*RSA_DW +: RSA_DW] <= 0;
              TB_dinb[3*RSA_DW +: RSA_DW] <= 0;
            end
            DIR_NEW_0: begin
              TB_dinb[0 +: RSA_DW]        <= 0;
              TB_dinb[1*RSA_DW +: RSA_DW] <= 0;
              TB_dinb[2*RSA_DW +: RSA_DW] <= C_TB_dinb[0 +: RSA_DW];
              TB_dinb[3*RSA_DW +: RSA_DW] <= C_TB_dinb[1*RSA_DW +: RSA_DW];
            end
          endcase
        end
        default:
          TB_dinb <= 0;
      endcase
    end  
  end

endmodule