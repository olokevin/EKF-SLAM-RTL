module TB_doutb_map #(
  parameter X = 4,
  parameter Y = 4,
  parameter L = 4,

  parameter SEQ_CNT_DW = 5,
  parameter RSA_DW = 32
) 
(
  input   clk,
  input   sys_rst,

  input   [2:0]   TB_doutb_sel,
  input           l_k_0,
  input   [SEQ_CNT_DW-1 : 0] seq_cnt_dout_sel,

  input   signed [L*RSA_DW-1 : 0]         TB_doutb,
  output  reg  signed [Y*RSA_DW-1 : 0]    B_TB_doutb,
  output  reg  signed [Y*RSA_DW-1 : 0]    B_cache_TB_doutb
);

//
/*
  TB_doutb_sel[2]
    1: B_cache
    0: B
  TB_doutb_sel[1:0]
          B             B_cache
    00: DIR_IDLE      B_cache_IDLE
    01: POS           B_cache_trnsfer
    10: NEG           B_cache_transpose  
    11: NEW           B_cache_inv
*/
localparam TB_doutb_B = 1'b0;
localparam TB_doutb_B_cache = 1'b1;


localparam DIR_IDLE = 2'b00;
localparam DIR_POS  = 2'b01;
localparam DIR_NEG  = 2'b10;
localparam DIR_NEW  = 2'b11;

localparam DIR_NEW_0  = 1'b0;
localparam DIR_NEW_1  = 1'b1;

localparam B_cache_IDLE = 2'b00;
localparam B_cache_trnsfer = 2'b01;
localparam B_cache_transpose = 2'b10;
localparam B_cache_inv = 2'b11;

/*
   ********************** B_TB_doutb ****************************
*/
integer i_TB_B;
always @(posedge clk) begin
  if(sys_rst)
    B_TB_doutb <= 0;
  else begin
    case(TB_doutb_sel[2])
      TB_doutb_B: begin
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
  ********************** B_cache_TB_doutb ****************************
*/

//inverse
  reg [RSA_DW-1 : 0] S_11;
  reg [RSA_DW-1 : 0] S_12;
  reg [RSA_DW-1 : 0] S_22;
  reg [RSA_DW-1 : 0] S_11_S_22;
  reg [RSA_DW-1 : 0] S_12_S_21;
  reg [RSA_DW-1 : 0] S_det;

integer i_TB_B_cache;
always @(posedge clk) begin
  if(sys_rst)
    B_cache_TB_doutb <= 0;
  else begin
    case(TB_doutb_sel[2])
      TB_doutb_B_cache: begin
        case(TB_doutb_sel[1:0])
          B_cache_IDLE: B_cache_TB_doutb <= 0;
          B_cache_trnsfer:begin
            B_cache_TB_doutb[0 +: RSA_DW]        <= TB_doutb[0 +: RSA_DW];
            B_cache_TB_doutb[1*RSA_DW +: RSA_DW] <= TB_doutb[1*RSA_DW +: RSA_DW];
            B_cache_TB_doutb[2*RSA_DW +: RSA_DW] <= 0;
            B_cache_TB_doutb[3*RSA_DW +: RSA_DW] <= 0;   
          end
          B_cache_transpose : begin
            B_cache_TB_doutb[2*RSA_DW +: RSA_DW] <= 0;
            B_cache_TB_doutb[3*RSA_DW +: RSA_DW] <= 0;
            case (seq_cnt_dout_sel)
              'd0:begin
                    B_cache_TB_doutb[0 +: RSA_DW]        <= 0;
                    B_cache_TB_doutb[1*RSA_DW +: RSA_DW] <= 0; 
                  end
              'd1:begin
                    B_cache_TB_doutb[0 +: RSA_DW]        <= TB_doutb[0 +: RSA_DW];
                    B_cache_TB_doutb[1*RSA_DW +: RSA_DW] <= 0;  
                  end
              'd2:begin
                    B_cache_TB_doutb[0 +: RSA_DW]        <= TB_doutb[1*RSA_DW +: RSA_DW];
                    B_cache_TB_doutb[1*RSA_DW +: RSA_DW] <= TB_doutb[0 +: RSA_DW];   
                  end
              'd3:begin
                    B_cache_TB_doutb[0 +: RSA_DW]        <= TB_doutb[2*RSA_DW +: RSA_DW];
                    B_cache_TB_doutb[1*RSA_DW +: RSA_DW] <= TB_doutb[1*RSA_DW +: RSA_DW]; 
                  end
              'd4:begin
                    B_cache_TB_doutb[0 +: RSA_DW]        <= 0;
                    B_cache_TB_doutb[1*RSA_DW +: RSA_DW] <= TB_doutb[2*RSA_DW +: RSA_DW]; 
                  end
              'd5:begin
                    B_cache_TB_doutb[0 +: RSA_DW]        <= l_k_0 ? TB_doutb[0 +: RSA_DW] : TB_doutb[2*RSA_DW +: RSA_DW];
                    B_cache_TB_doutb[1*RSA_DW +: RSA_DW] <= 0; 
                  end
              'd6:begin
                    B_cache_TB_doutb[0 +: RSA_DW]        <= l_k_0 ? TB_doutb[1*RSA_DW +: RSA_DW] : TB_doutb[3*RSA_DW +: RSA_DW];
                    B_cache_TB_doutb[1*RSA_DW +: RSA_DW] <= l_k_0 ? TB_doutb[0 +: RSA_DW] : TB_doutb[2*RSA_DW +: RSA_DW];
                  end
              'd7:begin
                    B_cache_TB_doutb[0 +: RSA_DW]        <= 0;
                    B_cache_TB_doutb[1*RSA_DW +: RSA_DW] <= l_k_0 ? TB_doutb[1*RSA_DW +: RSA_DW] : TB_doutb[3*RSA_DW +: RSA_DW];
                  end
              default: B_cache_TB_doutb <= 0;
            endcase
          end
          B_cache_inv :begin
            B_cache_TB_doutb[2*RSA_DW +: RSA_DW] <= 0;
            B_cache_TB_doutb[3*RSA_DW +: RSA_DW] <= 0;
            case(seq_cnt_dout_sel)
              'd1:begin
                    S_11 <= TB_doutb[0 +: RSA_DW];
                  end
              'd2:begin
                    S_12 <= TB_doutb[0 +: RSA_DW];
                    S_12_S_21 <= TB_doutb[0 +: RSA_DW] * TB_doutb[1*RSA_DW +: RSA_DW];
                  end
              'd3:begin
                    S_22 <= TB_doutb[1*RSA_DW +: RSA_DW];
                    S_11_S_22 <= S_11 * TB_doutb[1*RSA_DW +: RSA_DW];
                  end
              'd4:begin
                    S_det <= S_11_S_22 - S_12_S_21;
                  end
              'd5:begin
                    B_cache_TB_doutb[0 +: RSA_DW] <= S_11 / S_det;
                    B_cache_TB_doutb[1*RSA_DW +: RSA_DW] <= 0;
                  end  
              'd6:begin
                    B_cache_TB_doutb[0 +: RSA_DW] <= S_12 / S_det;
                    B_cache_TB_doutb[1*RSA_DW +: RSA_DW] <= S_12 / S_det;
                  end
              'd7:begin
                    B_cache_TB_doutb[0 +: RSA_DW] <= 0;
                    B_cache_TB_doutb[1*RSA_DW +: RSA_DW] <= S_22 / S_det;
                  end
              default: begin
                    B_cache_TB_doutb[0 +: RSA_DW] <= 0;
                    B_cache_TB_doutb[1*RSA_DW +: RSA_DW] <= 0;
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