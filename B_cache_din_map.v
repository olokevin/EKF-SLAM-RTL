module B_cache_din_map #(
  parameter X = 4,
  parameter Y = 4,
  parameter L = 4,

  parameter RSA_DW = 32,
  parameter SEQ_CNT_DW = 5
) 
(
  input   clk,
  input   sys_rst,

  input   [3 : 0]   B_cache_in_sel,

  input   [SEQ_CNT_DW-1 : 0] seq_cnt_out,

  input   signed [Y*RSA_DW-1:0] B_cache_TB_doutb,
  input   signed [X*RSA_DW-1:0] C_B_cache_din,

  input   signed [RSA_DW - 1 : 0]         Fxi_13, Fxi_23,
  input   signed [RSA_DW - 1 : 0]         Gxi_13, Gxi_23, Gz_11, Gz_12, Gz_21, Gz_22,
  input   signed [RSA_DW - 1 : 0]         Hz_11, Hz_12, Hz_21, Hz_22,
  input   signed [RSA_DW - 1 : 0]         Hxi_11, Hxi_12, Hxi_21, Hxi_22,
  input   signed [RSA_DW - 1 : 0]         vt_1, vt_2,

  input        init_inv,
  output  reg  done_inv,

  output  reg  signed [L*RSA_DW-1 : 0]    B_cache_din
);

localparam Bca_IDLE       = 4'b0000;

localparam Bca_WR_cov_HT = 4'b1000;
localparam Bca_WR_H_lv_H  = 4'b1001;
localparam Bca_WR_inv     = 4'b1010;
localparam Bca_WR_chi     = 4'b1011;

localparam Bca_WR_NL_PRD  = 4'b1100;
localparam Bca_WR_NL_ASSOC= 4'b1101;
localparam Bca_WR_NL_NEW  = 4'b1110;
localparam Bca_WR_NL_UPD  = 4'b1111; 

localparam Q_11 = 32'd131072;   //定点量化
localparam Q_22 = 32'd3992;

localparam I_11 = 32'h8_0000;  
localparam I_22 = 32'h8_0000;   

/*
  *************************inverse*******************************
*/
  reg signed [RSA_DW-1 : 0] S_11;
  reg signed [RSA_DW-1 : 0] S_21;
  reg signed [RSA_DW-1 : 0] S_22;
  reg signed [RSA_DW-1 : 0] S_11_S_22;
  reg signed [RSA_DW-1 : 0] S_12_S_21;
  reg signed [RSA_DW-1 : 0] S_det;

  reg signed [RSA_DW-1 : 0] S_inv_11;
  reg signed [RSA_DW-1 : 0] S_inv_12;
  reg signed [RSA_DW-1 : 0] S_inv_22;

  //implement a 32-bit signed (Q1.12.19) multiplier
    reg  signed [RSA_DW-1 : 0]   mul_a, mul_b;
    wire signed [2*RSA_DW-1 : 0] mul_c_temp;
    wire signed [RSA_DW-1 : 0]   mul_c;

    assign mul_c_temp = mul_a * mul_b;
    assign mul_c = {mul_c_temp[63], mul_c_temp[49 : 19]};
  
  //implement a 32-bit unsigned (Q1.12.19) divider
    reg                        init_Div;
    reg signed [RSA_DW-1 : 0]  divisor;
    reg signed [RSA_DW-1 : 0]  dividend;
    wire                       valid_Div;
    wire signed [55:0]         quotient_temp;
    wire signed [RSA_DW-1 : 0] quotient;

    //Get the sign in advance
    wire   quotient_sign;
    assign quotient_sign = divisor[31] ^ dividend[31];
    
    //Calculate the result of abs
    wire [RSA_DW-1 : 0] abs_dividend, abs_divisor, abs_quotient;
    assign abs_dividend = dividend[31] ? (~dividend + 1) : dividend;
    assign abs_divisor  = divisor[31] ? (~divisor + 1) : divisor;

    //Transform the final quotient
    assign abs_quotient = {1'b0, quotient_temp[31 : 20], quotient_temp[18 : 0]};
    assign quotient= quotient_sign ? (~abs_quotient + 1) : abs_quotient;

    S_inv_div u_S_inv_div (
      .aclk(clk),                                      // input wire aclk
      .s_axis_divisor_tvalid(init_Div),    // input wire s_axis_divisor_tvalid
      .s_axis_divisor_tdata(abs_divisor),      // input wire [31 : 0] s_axis_divisor_tdata
      .s_axis_dividend_tvalid(init_Div),  // input wire s_axis_dividend_tvalid
      .s_axis_dividend_tdata(abs_dividend),    // input wire [31 : 0] s_axis_dividend_tdata
      .m_axis_dout_tvalid(valid_Div),          // output wire m_axis_dout_tvalid
      .m_axis_dout_tdata(quotient_temp)            // output wire [55 : 0] m_axis_dout_tdata
    );

    localparam INV_IDLE= 3'b000;
    localparam INV_RD  = 3'b001;
    localparam INV_S11 = 3'b010;
    localparam INV_S12 = 3'b011;
    localparam INV_S22 = 3'b100;
    localparam INV_DONE  = 3'b101;

    reg [2:0]  inv_stage;
    reg [2:0]  inv_stage_next;
    reg [2:0]  inv_RD_cnt;

    always@(posedge clk) begin
        if(sys_rst) inv_stage <= INV_IDLE;
        else inv_stage <= inv_stage_next;
    end

    always @(*) begin
      inv_stage_next = inv_stage;   //状态不切换则保持
      case(inv_stage)
        INV_IDLE: begin
          if(init_inv == 1'b1) inv_stage_next = INV_RD;
        end
        INV_RD: 
          if(inv_RD_cnt == 3'd7) inv_stage_next = INV_S11;
        INV_S11:
          if(valid_Div) inv_stage_next = INV_S12;
        INV_S12:
          if(valid_Div) inv_stage_next = INV_S22;
        INV_S22:
          if(valid_Div) inv_stage_next = INV_DONE;
        INV_DONE:
          inv_stage_next = INV_IDLE;
        default: inv_stage_next = inv_stage;
      endcase
    end

    always @(posedge clk) begin
      if(sys_rst) begin
        done_inv <= 1'b0;
      end
      else if(inv_stage == INV_DONE) begin
        done_inv <= 1'b1;
      end
      else
        done_inv <= 1'b0;
    end

    always @(posedge clk) begin
      if(sys_rst) begin
        inv_RD_cnt <= 0;
      end
      else if(inv_stage == INV_RD) begin
        inv_RD_cnt <= inv_RD_cnt + 1'b1;
      end
      else
        inv_RD_cnt <= 0;
    end

    always @(posedge clk) begin
      if(sys_rst) begin
        S_11 <= 0;
        S_21 <= 0;
        S_22 <= 0;
        S_12_S_21 <= 0;
        S_11_S_22 <= 0;
        S_det <= 0;
      end
      else if(inv_stage == INV_RD) begin
        case(inv_RD_cnt)
          'd1:begin
                S_11 <= C_B_cache_din[0 +: RSA_DW] + Q_11;    //加Q
              end
          'd2:begin
                S_21 <= C_B_cache_din[1*RSA_DW +: RSA_DW];

                mul_a <=  C_B_cache_din[1*RSA_DW +: RSA_DW];
                mul_b <=  C_B_cache_din[1*RSA_DW +: RSA_DW];
              end
          'd3:begin
                S_12_S_21 <= mul_c;
              end
          'd4:begin
                S_22  <= C_B_cache_din[1*RSA_DW +: RSA_DW] + Q_22;
                
                mul_a <=  S_11;
                mul_b <= C_B_cache_din[1*RSA_DW +: RSA_DW] + Q_22;
              end
          'd5:begin
                S_11_S_22 <= mul_c;
              end
          'd6: begin
                S_det <= S_11_S_22 - S_12_S_21;
               end
        endcase
      end
      else if(inv_stage == INV_IDLE) begin
        S_11 <= 0;
        S_21 <= 0;
        S_22 <= 0;
        S_12_S_21 <= 0;
        S_11_S_22 <= 0;
        S_det <= 0;
      end
    end

    always @(posedge clk) begin
      if(sys_rst) begin
        init_Div <= 1'b0;
        dividend <= 'd0;
        divisor <= 'd0;
      end
      else if(inv_stage == INV_IDLE) begin
        init_Div <= 1'b0;
        dividend <= 'd0;
        divisor <= 'd0;
      end
      else if (inv_stage == INV_RD && inv_stage_next == INV_S11) begin
        init_Div <= 1'b1;
        dividend <= S_22;
        divisor  <= S_det;
      end   
      else if (inv_stage == INV_S11 && inv_stage_next == INV_S12) begin
        init_Div <= 1'b1;
        dividend <= - S_21;
        divisor  <= S_det;
      end
      else if (inv_stage == INV_S12 && inv_stage_next == INV_S22) begin
        init_Div <= 1'b1;
        dividend <= S_11;
        divisor  <= S_det;
      end
      else begin
        init_Div <= 1'b0;
        dividend <= dividend;
        divisor  <= divisor;
      end
    end
  
  always @(posedge clk) begin
    if(sys_rst) begin
      S_inv_11 <= 0;
      S_inv_12 <= 0;
      S_inv_22 <= 0;
    end
    else if(valid_Div) begin
      case(inv_stage)
        INV_S11: S_inv_11 <= quotient;
        INV_S12: S_inv_12 <= quotient;
        INV_S22: S_inv_22 <= quotient;
      endcase
    end
  end

/*
  *************************B_cache_din*******************************
*/

  always @(posedge clk) begin
    if(sys_rst)
      B_cache_din <= 0;
    else begin
      case(B_cache_in_sel)
        Bca_WR_NL_PRD: begin
                  case(seq_cnt_out)     //不用延迟时序
                    'd1:begin
                          B_cache_din[0 +: RSA_DW]        <= I_11;
                          B_cache_din[1*RSA_DW +: RSA_DW] <= 0;
                          B_cache_din[2*RSA_DW +: RSA_DW] <= 0;
                          B_cache_din[3*RSA_DW +: RSA_DW] <= 0;
                        end
                    'd2:begin
                          B_cache_din[0 +: RSA_DW]        <= 0;
                          B_cache_din[1*RSA_DW +: RSA_DW] <= 0;
                          B_cache_din[2*RSA_DW +: RSA_DW] <= 0;
                          B_cache_din[3*RSA_DW +: RSA_DW] <= 0;
                        end
                    'd3:begin
                          B_cache_din[0 +: RSA_DW]        <= Fxi_13;
                          B_cache_din[1*RSA_DW +: RSA_DW] <= I_11;
                          B_cache_din[2*RSA_DW +: RSA_DW] <= 0;
                          B_cache_din[3*RSA_DW +: RSA_DW] <= 0;
                        end
                    'd4:begin
                          B_cache_din[0 +: RSA_DW]        <= 0;
                          B_cache_din[1*RSA_DW +: RSA_DW] <= Fxi_23;
                          B_cache_din[2*RSA_DW +: RSA_DW] <= 0;
                          B_cache_din[3*RSA_DW +: RSA_DW] <= 0;
                        end
                    'd5:begin
                          B_cache_din[0 +: RSA_DW]        <= 0;
                          B_cache_din[1*RSA_DW +: RSA_DW] <= 0;
                          B_cache_din[2*RSA_DW +: RSA_DW] <= I_11;
                          B_cache_din[3*RSA_DW +: RSA_DW] <= 0;
                        end
                    default:begin
                        B_cache_din[0 +: RSA_DW]        <= 0;
                        B_cache_din[1*RSA_DW +: RSA_DW] <= 0;
                        B_cache_din[2*RSA_DW +: RSA_DW] <= 0;
                        B_cache_din[3*RSA_DW +: RSA_DW] <= 0;
                      end
                  endcase
                end
        Bca_WR_NL_NEW: begin
                  B_cache_din[2*RSA_DW +: RSA_DW] <= 0;
                  B_cache_din[3*RSA_DW +: RSA_DW] <= 0;
                  case(seq_cnt_out)     //不用延迟时序
                    'd1:begin
                          B_cache_din[0 +: RSA_DW]        <= I_11;
                          B_cache_din[1*RSA_DW +: RSA_DW] <= 0;
                        end
                    'd2:begin
                          B_cache_din[0 +: RSA_DW]        <= 0;
                          B_cache_din[1*RSA_DW +: RSA_DW] <= 0;
                        end
                    'd3:begin
                          B_cache_din[0 +: RSA_DW]        <= Gxi_13;
                          B_cache_din[1*RSA_DW +: RSA_DW] <= I_11;
                        end
                    'd4:begin
                        B_cache_din[0 +: RSA_DW]        <= Gz_11;
                        B_cache_din[1*RSA_DW +: RSA_DW] <= Gxi_23;
                      end
                    'd5:begin
                        B_cache_din[0 +: RSA_DW]        <= Gz_12;
                        B_cache_din[1*RSA_DW +: RSA_DW] <= Gz_21;
                      end
                    'd6:begin
                      B_cache_din[0 +: RSA_DW]        <= 0;
                      B_cache_din[1*RSA_DW +: RSA_DW] <= Gz_22;
                    end
                    default:begin
                        B_cache_din[0 +: RSA_DW]        <= 0;
                        B_cache_din[1*RSA_DW +: RSA_DW] <= 0;
                      end
                  endcase
                end
        Bca_WR_NL_UPD: begin
                  B_cache_din[2*RSA_DW +: RSA_DW] <= 0;
                  B_cache_din[3*RSA_DW +: RSA_DW] <= 0;
                  case(seq_cnt_out)     //不用延迟时序
                    'd1:begin
                          B_cache_din[0 +: RSA_DW]        <= Hxi_11;
                          B_cache_din[1*RSA_DW +: RSA_DW] <= 0;
                        end
                    'd2:begin
                          B_cache_din[0 +: RSA_DW]        <= Hxi_12;
                          B_cache_din[1*RSA_DW +: RSA_DW] <= Hxi_21;
                        end
                    'd3:begin
                          B_cache_din[0 +: RSA_DW]        <= 0;
                          B_cache_din[1*RSA_DW +: RSA_DW] <= Hxi_22;
                        end
                    'd4:begin
                        B_cache_din[0 +: RSA_DW]        <= Hz_11;
                        B_cache_din[1*RSA_DW +: RSA_DW] <= -I_11;
                      end
                    'd5:begin
                        B_cache_din[0 +: RSA_DW]        <= Hz_12;
                        B_cache_din[1*RSA_DW +: RSA_DW] <= Hz_21;
                      end
                    'd6:begin
                        B_cache_din[0 +: RSA_DW]        <= vt_1;
                        B_cache_din[1*RSA_DW +: RSA_DW] <= Hz_22;
                      end
                    'd7:begin
                        B_cache_din[0 +: RSA_DW]        <= vt_2;
                        B_cache_din[1*RSA_DW +: RSA_DW] <= 0;
                      end
                    default:begin
                        B_cache_din[0 +: RSA_DW]        <= 0;
                        B_cache_din[1*RSA_DW +: RSA_DW] <= 0;
                      end
                  endcase
                end
        Bca_WR_NL_ASSOC: begin
                  B_cache_din[2*RSA_DW +: RSA_DW] <= 0;
                  B_cache_din[3*RSA_DW +: RSA_DW] <= 0;
                  case(seq_cnt_out)     //不用延迟时序
                    'd1:begin
                          B_cache_din[0 +: RSA_DW]        <= Hxi_11;
                          B_cache_din[1*RSA_DW +: RSA_DW] <= 0;
                        end
                    'd2:begin
                          B_cache_din[0 +: RSA_DW]        <= Hxi_12;
                          B_cache_din[1*RSA_DW +: RSA_DW] <= Hxi_21;
                        end
                    'd3:begin
                          B_cache_din[0 +: RSA_DW]        <= 0;
                          B_cache_din[1*RSA_DW +: RSA_DW] <= Hxi_22;
                        end
                    'd4:begin
                        B_cache_din[0 +: RSA_DW]        <= Hz_11;
                        B_cache_din[1*RSA_DW +: RSA_DW] <= -I_11;
                      end
                    'd5:begin
                        B_cache_din[0 +: RSA_DW]        <= Hz_12;
                        B_cache_din[1*RSA_DW +: RSA_DW] <= Hz_21;
                      end
                    'd6:begin
                        B_cache_din[0 +: RSA_DW]        <= I_11;
                        B_cache_din[1*RSA_DW +: RSA_DW] <= Hz_22;
                      end
                    'd7:begin
                        B_cache_din[0 +: RSA_DW]        <= 0;
                        B_cache_din[1*RSA_DW +: RSA_DW] <= 0;
                      end
                    'd8:begin
                        B_cache_din[0 +: RSA_DW]        <= 0;
                        B_cache_din[1*RSA_DW +: RSA_DW] <= I_22;
                      end
                    default:begin
                        B_cache_din[0 +: RSA_DW]        <= 0;
                        B_cache_din[1*RSA_DW +: RSA_DW] <= 0;
                      end
                  endcase
                end
        Bca_WR_cov_HT, Bca_WR_H_lv_H: begin
          B_cache_din <= B_cache_TB_doutb;
        end
        Bca_WR_inv: begin
            B_cache_din[2*RSA_DW +: RSA_DW] <= 0;
            B_cache_din[3*RSA_DW +: RSA_DW] <= 0;
            case(seq_cnt_out)
              'd1:begin
                    B_cache_din[0 +: RSA_DW] <= S_inv_11;
                    B_cache_din[1*RSA_DW +: RSA_DW] <= 0;
                  end  
              'd2:begin
                    B_cache_din[0 +: RSA_DW] <= S_inv_12;
                    B_cache_din[1*RSA_DW +: RSA_DW] <= S_inv_12;
                  end
              'd3:begin
                    B_cache_din[0 +: RSA_DW] <= 0;
                    B_cache_din[1*RSA_DW +: RSA_DW] <= S_inv_22;
                  end

              /*temporary for test*/
              // 'd1:begin
              //       B_cache_din[0 +: RSA_DW] <= (2 <<< 19);
              //       B_cache_din[1*RSA_DW +: RSA_DW] <= 0;
              //     end  
              // 'd2:begin
              //       B_cache_din[0 +: RSA_DW] <= (3 <<< 19);
              //       B_cache_din[1*RSA_DW +: RSA_DW] <= (3 <<< 19);
              //     end
              // 'd3:begin
              //       B_cache_din[0 +: RSA_DW] <= 0;
              //       B_cache_din[1*RSA_DW +: RSA_DW] <= (1 <<< 19);
              //     end
              default: begin
                    B_cache_din[0 +: RSA_DW] <= 0;
                    B_cache_din[1*RSA_DW +: RSA_DW] <= 0;
                  end
            endcase
        end
        Bca_WR_chi: begin
            B_cache_din[1*RSA_DW +: RSA_DW] <= 0;
            B_cache_din[2*RSA_DW +: RSA_DW] <= 0;
            B_cache_din[3*RSA_DW +: RSA_DW] <= 0;
            case(seq_cnt_out)
              'd10:begin
                    B_cache_din[0 +: RSA_DW] <= C_B_cache_din[0 +: RSA_DW];
                  end
              'd12:begin
                    B_cache_din[0 +: RSA_DW] <= C_B_cache_din[0 +: RSA_DW];
                  end
              default: begin
                    B_cache_din[0 +: RSA_DW] <= 0;
                  end
            endcase
        end
        default:
            B_cache_din <= 0;
      endcase
    end  
  end
endmodule