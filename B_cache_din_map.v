module B_cache_din_map #(
  parameter X = 4,
  parameter Y = 4,
  parameter L = 4,

  parameter RSA_DW = 32,
  parameter SEQ_CNT_DW = 10
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

  output  reg  signed [L*RSA_DW-1 : 0]    B_cache_din
);

localparam Bca_IDLE       = 4'b0000;

localparam Bca_WR_transpose     = 4'b1001;
localparam Bca_WR_inv     = 4'b1010;
localparam Bca_WR_chi     = 4'b1011;

localparam Bca_WR_NL_PRD  = 4'b1100;
localparam Bca_WR_NL_ASSOC= 4'b1101;
localparam Bca_WR_NL_NEW  = 4'b1110;
localparam Bca_WR_NL_UPD  = 4'b1111; 

localparam Q_11 = 32'h8_0000;   //定点量化
localparam Q_22 = 32'h8_0000;

localparam I_11 = 32'h8_0000;  
localparam I_22 = 32'h8_0000;   

//inverse
  reg signed [RSA_DW-1 : 0] S_11;
  reg signed [RSA_DW-1 : 0] S_12;
  reg signed [RSA_DW-1 : 0] S_22;
  reg signed [RSA_DW-1 : 0] S_11_S_22;
  reg signed [RSA_DW-1 : 0] S_12_S_21;
  reg signed [RSA_DW-1 : 0] S_det;

  reg signed [RSA_DW-1 : 0] S_inv_11;
  reg signed [RSA_DW-1 : 0] S_inv_12;
  reg signed [RSA_DW-1 : 0] S_inv_22;

  always @(posedge clk) begin
    if(sys_rst)
      B_cache_din <= 0;
    else begin
      case(B_cache_in_sel)
        Bca_WR_NL_PRD: begin
                  case(seq_cnt_out)     //不用延迟时序
                    'd1:begin
                          B_cache_din[0 +: RSA_DW]        <= 1;
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
                          B_cache_din[1*RSA_DW +: RSA_DW] <= 1;
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
                          B_cache_din[2*RSA_DW +: RSA_DW] <= 1;
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
                          B_cache_din[0 +: RSA_DW]        <= 1;
                          B_cache_din[1*RSA_DW +: RSA_DW] <= 0;
                        end
                    'd2:begin
                          B_cache_din[0 +: RSA_DW]        <= 0;
                          B_cache_din[1*RSA_DW +: RSA_DW] <= 0;
                        end
                    'd3:begin
                          B_cache_din[0 +: RSA_DW]        <= Gxi_13;
                          B_cache_din[1*RSA_DW +: RSA_DW] <= 1;
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
                        B_cache_din[1*RSA_DW +: RSA_DW] <= -1;
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
                        B_cache_din[1*RSA_DW +: RSA_DW] <= -1;
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
                        B_cache_din[1*RSA_DW +: RSA_DW] <= I_22;
                      end
                    default:begin
                        B_cache_din[0 +: RSA_DW]        <= 0;
                        B_cache_din[1*RSA_DW +: RSA_DW] <= 0;
                      end
                  endcase
                end
        Bca_WR_transpose: begin
          B_cache_din <= B_cache_TB_doutb;
        end
        Bca_WR_inv: begin
            B_cache_din[2*RSA_DW +: RSA_DW] <= 0;
            B_cache_din[3*RSA_DW +: RSA_DW] <= 0;
            case(seq_cnt_out)
              'd3:begin
                    S_11 <= C_B_cache_din[0 +: RSA_DW] + Q_11;    //加Q
                  end
              'd4:begin
                    S_12 <= C_B_cache_din[0 +: RSA_DW];
                    S_12_S_21 <= C_B_cache_din[0 +: RSA_DW] * C_B_cache_din[1*RSA_DW +: RSA_DW];
                  end
              'd5:begin
                    S_22 <= C_B_cache_din[1*RSA_DW +: RSA_DW] + Q_22;
                    S_11_S_22 <= S_11 * C_B_cache_din[1*RSA_DW +: RSA_DW];
                  end
              'd6:begin
                    S_det <= S_11_S_22 - S_12_S_21;
                  end
              // 'd7:begin
              //       B_cache_din[0 +: RSA_DW] <= S_11 / S_det;
              //       B_cache_din[1*RSA_DW +: RSA_DW] <= 0;
              //     end  
              // 'd8:begin
              //       B_cache_din[0 +: RSA_DW] <= S_12 / S_det;
              //       B_cache_din[1*RSA_DW +: RSA_DW] <= S_12 / S_det;
              //     end
              // 'd9:begin
              //       B_cache_din[0 +: RSA_DW] <= 0;
              //       B_cache_din[1*RSA_DW +: RSA_DW] <= S_22 / S_det;
              //     end

              /*temporary for test*/
              'd7:begin
                    B_cache_din[0 +: RSA_DW] <= (2 <<< 19);
                    B_cache_din[1*RSA_DW +: RSA_DW] <= 0;
                  end  
              'd8:begin
                    B_cache_din[0 +: RSA_DW] <= (3 <<< 19);
                    B_cache_din[1*RSA_DW +: RSA_DW] <= (3 <<< 19);
                  end
              'd9:begin
                    B_cache_din[0 +: RSA_DW] <= 0;
                    B_cache_din[1*RSA_DW +: RSA_DW] <= (1 <<< 19);
                  end
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
              'd11:begin
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