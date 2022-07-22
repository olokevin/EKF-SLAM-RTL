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

  input   [2 : 0]   B_cache_in_sel,

  input   [SEQ_CNT_DW-1 : 0] seq_cnt_out,

  input   signed [Y*RSA_DW-1:0] B_cache_TB_doutb,

  input   signed [RSA_DW - 1 : 0]         Fxi_13, Fxi_23,
  input   signed [RSA_DW - 1 : 0]         Gxi_13, Gxi_23, Gz_11, Gz_12, Gz_21, Gz_22,
  input   signed [RSA_DW - 1 : 0]         Hz_11, Hz_12, Hz_21, Hz_22,
  input   signed [RSA_DW - 1 : 0]         Hxi_11, Hxi_12, Hxi_21, Hxi_22,

  output  reg  signed [L*RSA_DW-1 : 0]    B_cache_din
);

localparam Bca_IDLE    = 3'b000;
localparam Bca_TBb     = 3'b001;
localparam Bca_NL_PRD  = 3'b101;
localparam Bca_NL_NEW  = 3'b110;
localparam Bca_NL_UPD  = 3'b111;

  always @(posedge clk) begin
    if(sys_rst)
      B_cache_din <= 0;
    else begin
      case(B_cache_in_sel)
        Bca_TBb: begin
          B_cache_din <= B_cache_TB_doutb;
        end
        Bca_NL_PRD: begin
                  case(seq_cnt_out)     //不用延迟时序
                    'd1:begin
                          B_cache_din[0 +: RSA_DW]        <= 1;
                          B_cache_din[1*RSA_DW +: RSA_DW] <= 0;
                          B_cache_din[2*RSA_DW +: RSA_DW] <= 0;
                          B_cache_din[3*RSA_DW +: RSA_DW] <= 0;
                        end
                    'd2:begin
                          B_cache_din[0 +: RSA_DW]        <= 0;
                          B_cache_din[1*RSA_DW +: RSA_DW] <= 1;
                          B_cache_din[2*RSA_DW +: RSA_DW] <= 0;
                          B_cache_din[3*RSA_DW +: RSA_DW] <= 0;
                        end
                    'd3:begin
                          B_cache_din[0 +: RSA_DW]        <= Fxi_13;
                          B_cache_din[1*RSA_DW +: RSA_DW] <= Fxi_23;
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
        Bca_NL_NEW: begin
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
                        B_cache_din[1*RSA_DW +: RSA_DW] <= Gxi_13;
                      end
                    'd5:begin
                        B_cache_din[0 +: RSA_DW]        <= Gz_12;
                        B_cache_din[1*RSA_DW +: RSA_DW] <= Gz_21;
                      end
                      'd5:begin
                        B_cache_din[0 +: RSA_DW]        <= 0;
                        B_cache_din[1*RSA_DW +: RSA_DW] <= Gz_22;
                      end
                    default:begin
                        B_cache_din[0 +: RSA_DW]        <= 0;
                        B_cache_din[1*RSA_DW +: RSA_DW] <= 0;
                      end
                  endcase
                end
        Bca_NL_UPD: begin
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
                    default:begin
                        B_cache_din[0 +: RSA_DW]        <= 0;
                        B_cache_din[1*RSA_DW +: RSA_DW] <= 0;
                      end
                  endcase
                end
        default:
            B_cache_din <= 0;
      endcase
    end  
  end
endmodule