module TB_douta_map #(
  parameter X = 4,
  parameter Y = 4,
  parameter L = 4,

  parameter RSA_DW = 32,
  parameter TB_DOUTA_SEL_DW = 3
) 
(
  input   clk,
  input   sys_rst,

  input   [TB_DOUTA_SEL_DW-1 : 0]   TB_douta_sel,
  input           l_k_0,
  
  input   signed [L*RSA_DW-1 : 0]         TB_douta,
  output  reg  signed [X*RSA_DW-1 : 0]    A_TB_douta,
  output  reg  signed [X*RSA_DW-1 : 0]    M_TB_douta
);

//
/*
  TB_douta_sel[2]
    1: M
    0: A
  TB_douta_sel[1:0]
    00: DIR_IDLE
    01: 正向映射
    10：逆向映射
    11：X
*/
localparam TBa_A = 1'b0;
localparam TBa_M = 1'b1;

localparam DIR_IDLE = 2'b00;
localparam DIR_POS  = 2'b01;
localparam DIR_NEG  = 2'b10;
localparam DIR_NEW  = 2'b11;

localparam DIR_NEW_0  = 1'b0;
localparam DIR_NEW_1  = 1'b1;

/*
  A_TB_douta
*/
integer i_TB_A;
always @(posedge clk) begin
  if(sys_rst)
    A_TB_douta <= 0;
  else begin
    case(TB_douta_sel[2])
      TBa_A: begin
        case(TB_douta_sel[TB_DOUTA_SEL_DW-1:0])
          DIR_IDLE: A_TB_douta <= 0;
          DIR_POS : A_TB_douta <= TB_douta;
          DIR_NEG :begin
            for(i_TB_A=0; i_TB_A<X; i_TB_A=i_TB_A+1) begin
              A_TB_douta[i_TB_A*RSA_DW +: RSA_DW] <= TB_douta[(X-1-i_TB_A)*RSA_DW +: RSA_DW];
            end
          end
          DIR_NEW : begin
            case (l_k_0)
              DIR_NEW_1: begin
                A_TB_douta[0 +: RSA_DW]        <= TB_douta[0 +: RSA_DW];
                A_TB_douta[1*RSA_DW +: RSA_DW] <= TB_douta[1*RSA_DW +: RSA_DW];
                A_TB_douta[2*RSA_DW +: RSA_DW] <= 0;
                A_TB_douta[3*RSA_DW +: RSA_DW] <= 0;
              end
              DIR_NEW_0: begin
                A_TB_douta[0 +: RSA_DW]        <= TB_douta[2*RSA_DW +: RSA_DW];
                A_TB_douta[1*RSA_DW +: RSA_DW] <= TB_douta[3*RSA_DW +: RSA_DW];
                A_TB_douta[2*RSA_DW +: RSA_DW] <= 0;
                A_TB_douta[3*RSA_DW +: RSA_DW] <= 0;
              end
            endcase
          end
        endcase
      end
      default: A_TB_douta <= 0;
    endcase
  end     
end

/*
  M_TB_douta
*/
integer i_TB_M;
always @(posedge clk) begin
  if(sys_rst)
    M_TB_douta <= 0;
  else begin
    case(TB_douta_sel[TB_DOUTA_SEL_DW-1])
      TBa_M: begin
        case(TB_douta_sel[1:0])
          DIR_IDLE: M_TB_douta <= 0;
          DIR_POS : M_TB_douta <= TB_douta;
          DIR_NEG :begin
            for(i_TB_M=0; i_TB_M<X; i_TB_M=i_TB_M+1) begin
              M_TB_douta[i_TB_M*RSA_DW +: RSA_DW] <= TB_douta[(X-1-i_TB_M)*RSA_DW +: RSA_DW];
            end
          end
          DIR_NEW : begin
            case (l_k_0)
              DIR_NEW_1: begin
                M_TB_douta[0 +: RSA_DW]        <= TB_douta[0 +: RSA_DW];
                M_TB_douta[1*RSA_DW +: RSA_DW] <= TB_douta[1*RSA_DW +: RSA_DW];
                M_TB_douta[2*RSA_DW +: RSA_DW] <= 0;
                M_TB_douta[3*RSA_DW +: RSA_DW] <= 0;
              end
              DIR_NEW_0: begin
                M_TB_douta[0 +: RSA_DW]        <= TB_douta[2*RSA_DW +: RSA_DW];
                M_TB_douta[1*RSA_DW +: RSA_DW] <= TB_douta[3*RSA_DW +: RSA_DW];
                M_TB_douta[2*RSA_DW +: RSA_DW] <= 0;
                M_TB_douta[3*RSA_DW +: RSA_DW] <= 0;
              end
            endcase
          end
        endcase
      end
      default: M_TB_douta <= 0;
    endcase
  end     
end
endmodule