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

  input   [X*RSA_DW-1 : 0]         C_TB_dinb,
  output  reg  [L*RSA_DW-1 : 0]    TB_dinb
);

localparam IDLE = 2'b00;
localparam POS  = 2'b01;
localparam NEG  = 2'b10;
localparam NEW  = 2'b11;
  
integer i_TB_C;
  always @(posedge clk) begin
    if(sys_rst)
      TB_dinb <= 0;
    else begin
      case(TB_dinb_sel)
        POS: begin
          for(i_TB_C=0; i_TB_C<X; i_TB_C=i_TB_C+1) begin
            TB_dinb[i_TB_C*RSA_DW +: RSA_DW] <= C_TB_dinb[i_TB_C*RSA_DW +: RSA_DW];
          end
        end
        NEG: begin
          for(i_TB_C=0; i_TB_C<X; i_TB_C=i_TB_C+1) begin
            TB_dinb[i_TB_C*RSA_DW +: RSA_DW] <= C_TB_dinb[(X-1-i_TB_C)*RSA_DW +: RSA_DW];
          end
        end
        default:
          TB_dinb <= 0;
      endcase
    end  
  end

endmodule