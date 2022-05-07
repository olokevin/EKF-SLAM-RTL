module TB_doutb_map #(
  parameter X = 4,
  parameter Y = 4,
  parameter L = 4,

  parameter RSA_DW = 16
) 
(
  input   clk,
  input   sys_rst,

  input   [2:0]   TB_doutb_sel,
  input           l_k_0,

  input   [L*RSA_DW-1 : 0]         TB_doutb,
  output  reg  [Y*RSA_DW-1 : 0]    B_TB_doutb,
  output  reg  [Y*RSA_DW-1 : 0]    B_cache_TB_doutb
);

//
/*
  TB_doutb_sel[2]
    1: B_cache
    0: B
  TB_douta_sel[1:0]
    00: DIR_IDLE
    01: 正向映射
    10：逆向映射
    11：X
*/
localparam TB_B = 1'b0;
localparam TB_B_cache = 1'b1;

localparam DIR_IDLE = 2'b00;
localparam DIR_POS  = 2'b01;
localparam DIR_NEG  = 2'b10;
localparam DIR_NEW  = 2'b11;

localparam DIR_NEW_0  = 1'b0;
localparam DIR_NEW_1  = 1'b1;

/*
  B_TB_doutb
*/
integer i_TB_B;
always @(posedge clk) begin
  if(sys_rst)
    B_TB_doutb <= 0;
  else begin
    case(TB_doutb_sel[2])
      TB_B: begin
        case(TB_doutb_sel[1:0])
          DIR_IDLE: B_TB_doutb <= 0;
          DIR_POS : B_TB_doutb <= TB_doutb;
          DIR_NEG :begin
            for(i_TB_B=0; i_TB_B<Y; i_TB_B=i_TB_B+1) begin
              B_TB_doutb[i_TB_B*RSA_DW +: RSA_DW] <= TB_doutb[(X-1-i_TB_B)*RSA_DW +: RSA_DW];
            end
          end
          DIR_NEW : begin
            case (l_k_0)
              DIR_NEW_1: begin
                B_TB_doutb[0 +: RSA_DW]        <= TB_doutb[0 +: RSA_DW];
                B_TB_doutb[1*RSA_DW +: RSA_DW] <= TB_doutb[1*RSA_DW +: RSA_DW];
                B_TB_doutb[2*RSA_DW +: RSA_DW] <= 0;
                B_TB_doutb[3*RSA_DW +: RSA_DW] <= 0;
              end
              DIR_NEW_0: begin
                B_TB_doutb[0 +: RSA_DW]        <= TB_doutb[2*RSA_DW +: RSA_DW];
                B_TB_doutb[1*RSA_DW +: RSA_DW] <= TB_doutb[3*RSA_DW +: RSA_DW];
                B_TB_doutb[2*RSA_DW +: RSA_DW] <= 0;
                B_TB_doutb[3*RSA_DW +: RSA_DW] <= 0;
              end
            endcase
          end
        endcase
      end
      default: B_TB_doutb <= 0;
    endcase
  end     
end

/*
  B_cache_TB_doutb
*/
integer i_TB_B_cache;
always @(posedge clk) begin
  if(sys_rst)
    B_cache_TB_doutb <= 0;
  else begin
    case(TB_doutb_sel[2])
      TB_B_cache: begin
        case(TB_doutb_sel[1:0])
          DIR_IDLE: B_cache_TB_doutb <= 0;
          DIR_POS : B_cache_TB_doutb <= TB_doutb;
          DIR_NEG :begin
            for(i_TB_B_cache=0; i_TB_B_cache<Y; i_TB_B_cache=i_TB_B_cache+1) begin
              B_cache_TB_doutb[i_TB_B_cache*RSA_DW +: RSA_DW] <= TB_doutb[(X-1-i_TB_B_cache)*RSA_DW +: RSA_DW];
            end
          end
          DIR_NEW : begin
            case (l_k_0)
              DIR_NEW_1: begin
                B_cache_TB_doutb[0 +: RSA_DW]        <= TB_doutb[0 +: RSA_DW];
                B_cache_TB_doutb[1*RSA_DW +: RSA_DW] <= TB_doutb[1*RSA_DW +: RSA_DW];
                B_cache_TB_doutb[2*RSA_DW +: RSA_DW] <= 0;
                B_cache_TB_doutb[3*RSA_DW +: RSA_DW] <= 0;
              end
              DIR_NEW_0: begin
                B_cache_TB_doutb[0 +: RSA_DW]        <= TB_doutb[2*RSA_DW +: RSA_DW];
                B_cache_TB_doutb[1*RSA_DW +: RSA_DW] <= TB_doutb[3*RSA_DW +: RSA_DW];
                B_cache_TB_doutb[2*RSA_DW +: RSA_DW] <= 0;
                B_cache_TB_doutb[3*RSA_DW +: RSA_DW] <= 0;
              end
            endcase
          end
        endcase
      end
      default: B_cache_TB_doutb <= 0;
    endcase
  end     
end
endmodule