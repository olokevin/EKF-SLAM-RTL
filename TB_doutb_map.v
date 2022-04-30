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

  input   [L*RSA_DW-1 : 0]         TB_doutb,
  output  reg  [X*RSA_DW-1 : 0]    B_TB_doutb,
  output  reg  [X*RSA_DW-1 : 0]    B_CONS_TB_doutb
);

//
/*
  TB_doutb_sel[2]
    1: B_CONS
    0: B
  TB_douta_sel[1:0]
    00: DIR_IDLE
    01: 正向映射
    10：逆向映射
    11：X
*/
localparam TB_B = 1'b0;
localparam TB_B_CONS = 1'b1;

localparam DIR_IDLE = 2'b00;
localparam DIR_POS  = 2'b01;
localparam DIR_NEG  = 2'b10;
localparam DIR_NEW  = 2'b11;

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
          DIR_NEW : B_TB_doutb <= 0;
        endcase
      end
      default: B_TB_doutb <= 0;
    endcase
  end     
end

/*
  B_CONS_TB_doutb
*/
integer i_TB_B_CONS;
always @(posedge clk) begin
  if(sys_rst)
    B_CONS_TB_doutb <= 0;
  else begin
    case(TB_doutb_sel[2])
      TB_B_CONS: begin
        case(TB_doutb_sel[1:0])
          DIR_IDLE: B_CONS_TB_doutb <= 0;
          DIR_POS : B_CONS_TB_doutb <= TB_doutb;
          DIR_NEG :begin
            for(i_TB_B_CONS=0; i_TB_B_CONS<Y; i_TB_B_CONS=i_TB_B_CONS+1) begin
              B_CONS_TB_doutb[i_TB_B_CONS*RSA_DW +: RSA_DW] <= TB_doutb[(X-1-i_TB_B_CONS)*RSA_DW +: RSA_DW];
            end
          end
          DIR_NEW : B_CONS_TB_doutb <= 0;
        endcase
      end
      default: B_CONS_TB_doutb <= 0;
    endcase
  end     
end
endmodule