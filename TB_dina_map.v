module TB_dina_map #(
  parameter X = 4,
  parameter Y = 4,
  parameter L = 4,

  parameter RSA_DW = 16
) 
(
  input   clk,
  input   sys_rst,

  input   [2:0]   TB_dina_sel,
  input           l_k_0,

  input   [L*RSA_DW-1 : 0]         TB_dina_CB_douta,
  input   [L*RSA_DW-1 : 0]         TB_dina_non_linear,
  output  reg  [L*RSA_DW-1 : 0]    TB_dina
);

localparam TBa_CBa = 1'b0;
localparam TBa_non_linear = 2'b1;

localparam DIR_IDLE = 2'b00;
localparam DIR_POS  = 2'b01;
localparam DIR_NEG  = 2'b10;
localparam DIR_NEW  = 2'b11;

localparam DIR_NEW_0  = 1'b0;
localparam DIR_NEW_1  = 1'b1;

integer i_TB_CBa;
integer i_TB_non_linear;
  always @(posedge clk) begin
    if(sys_rst)
      TB_dina <= 0;
    else begin
      case(TB_dina_sel[2])
        TBa_CBa: begin
          case(TB_dina_sel[1:0])
            DIR_POS: begin
              TB_dina <= TB_dina_CB_douta;
            end
            DIR_NEG: begin
              for(i_TB_CBa=0; i_TB_CBa<X; i_TB_CBa=i_TB_CBa+1) begin
                TB_dina[i_TB_CBa*RSA_DW +: RSA_DW] <= TB_dina_CB_douta[(X-1-i_TB_CBa)*RSA_DW +: RSA_DW];
              end
            end
            DIR_NEW : begin
              case (l_k_0)
                DIR_NEW_1: begin
                  TB_dina[0 +: RSA_DW]        <= TB_dina_CB_douta[0 +: RSA_DW];
                  TB_dina[1*RSA_DW +: RSA_DW] <= TB_dina_CB_douta[1*RSA_DW +: RSA_DW];
                  TB_dina[2*RSA_DW +: RSA_DW] <= 0;
                  TB_dina[3*RSA_DW +: RSA_DW] <= 0;
                end
                DIR_NEW_0: begin
                  TB_dina[0 +: RSA_DW]        <= 0;
                  TB_dina[1*RSA_DW +: RSA_DW] <= 0;
                  TB_dina[2*RSA_DW +: RSA_DW] <= TB_dina_CB_douta[0 +: RSA_DW];
                  TB_dina[3*RSA_DW +: RSA_DW] <= TB_dina_CB_douta[1*RSA_DW +: RSA_DW];
                end
              endcase
            end
            default:
              TB_dina <= 0;
          endcase
        end
        TBa_non_linear: begin
                  case(TB_dina_sel[1:0])
                    DIR_POS: begin
                      TB_dina <= TB_dina_non_linear;
                    end
                    DIR_NEG: begin
                      for(i_TB_non_linear=0; i_TB_non_linear<X; i_TB_non_linear=i_TB_non_linear+1) begin
                        TB_dina[i_TB_non_linear*RSA_DW +: RSA_DW] <= TB_dina_non_linear[(X-1-i_TB_non_linear)*RSA_DW +: RSA_DW];
                      end
                    end
                    DIR_NEW : begin
                      case (l_k_0)
                        DIR_NEW_1: begin
                          TB_dina[0 +: RSA_DW]        <= TB_dina_non_linear[0 +: RSA_DW];
                          TB_dina[1*RSA_DW +: RSA_DW] <= TB_dina_non_linear[1*RSA_DW +: RSA_DW];
                          TB_dina[2*RSA_DW +: RSA_DW] <= 0;
                          TB_dina[3*RSA_DW +: RSA_DW] <= 0;
                        end
                        DIR_NEW_0: begin
                          TB_dina[0 +: RSA_DW]        <= 0;
                          TB_dina[1*RSA_DW +: RSA_DW] <= 0;
                          TB_dina[2*RSA_DW +: RSA_DW] <= TB_dina_non_linear[0 +: RSA_DW];
                          TB_dina[3*RSA_DW +: RSA_DW] <= TB_dina_non_linear[1*RSA_DW +: RSA_DW];
                        end
                      endcase
                    end
                    default:
                      TB_dina <= 0;
                  endcase
                end
        default:
            TB_dina <= 0;
      endcase
    end  
  end
endmodule