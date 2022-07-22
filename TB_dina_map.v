module TB_dina_map #(
  parameter X = 4,
  parameter Y = 4,
  parameter L = 4,

  parameter RSA_DW = 32,
  parameter SEQ_CNT_DW = 10,
  parameter TB_DINA_SEL_DW  = 5
) 
(
  input   clk,
  input   sys_rst,

  input   [TB_DINA_SEL_DW-1 : 0]   TB_dina_sel,
  input           l_k_0,

  input   [SEQ_CNT_DW-1 : 0] seq_cnt_out,

  input   signed [L*RSA_DW-1 : 0]         TB_dina_CB_douta,
  // input   signed [RSA_DW - 1 : 0]         Fxi_13, Fxi_23,
  // input   signed [RSA_DW - 1 : 0]         Gxi_13, Gxi_23, Gz_11, Gz_12, Gz_21, Gz_22,
  // input   signed [RSA_DW - 1 : 0]         Hz_11, Hz_12, Hz_21, Hz_22,
  // input   signed [RSA_DW - 1 : 0]         Hxi_11, Hxi_12, Hxi_21, Hxi_22,
  // input   signed [RSA_DW - 1 : 0]         vt_1, vt_2,

  output  reg  signed [L*RSA_DW-1 : 0]    TB_dina
);

/*
  TB_dina_sel[2]
    000: TBa_CBa        从CB读取的数据TB_dina_map   
    101: TBa_NL_PRD         PRD非线性单元输入
    110: TBa_NL_NEW         NEW非线性单元输入
    111: TBa_NL_UPD         UPD非线性单元输入
  TB_dina_sel[1:0]
    00: DIR_IDLE
    01: POS
    10: NEG
    11: NEW
*/

localparam TBa_CBa     = 3'b100;
localparam TBa_NL_PRD  = 3'b101;
localparam TBa_NL_NEW  = 3'b110;
localparam TBa_NL_UPD  = 3'b111;

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
      case(TB_dina_sel[TB_DINA_SEL_DW-1 : 2])
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
        // TBa_NL_PRD: begin
        //           case(seq_cnt_out)     //不用延迟时序
        //             'd1:begin
        //                   TB_dina[0 +: RSA_DW]        <= Fxi_13;
        //                   TB_dina[1*RSA_DW +: RSA_DW] <= 0;
        //                   TB_dina[2*RSA_DW +: RSA_DW] <= 0;
        //                   TB_dina[3*RSA_DW +: RSA_DW] <= 0;
        //                 end
        //             'd2:begin
        //                   TB_dina[0 +: RSA_DW]        <= 1;
        //                   TB_dina[1*RSA_DW +: RSA_DW] <= Fxi_23;
        //                   TB_dina[2*RSA_DW +: RSA_DW] <= 0;
        //                   TB_dina[3*RSA_DW +: RSA_DW] <= 0;
        //                 end
        //             'd3:begin
        //                   TB_dina[0 +: RSA_DW]        <= 0;
        //                   TB_dina[1*RSA_DW +: RSA_DW] <= 0;
        //                   TB_dina[2*RSA_DW +: RSA_DW] <= 1;
        //                   TB_dina[3*RSA_DW +: RSA_DW] <= 0;
        //                 end
        //             'd4:begin
        //                 TB_dina[0 +: RSA_DW]        <= 0;
        //                 TB_dina[1*RSA_DW +: RSA_DW] <= 1;
        //                 TB_dina[2*RSA_DW +: RSA_DW] <= Fxi_13;
        //                 TB_dina[3*RSA_DW +: RSA_DW] <= 0;
        //               end
        //             'd5:begin
        //                 TB_dina[0 +: RSA_DW]        <= 0;
        //                 TB_dina[1*RSA_DW +: RSA_DW] <= 0;
        //                 TB_dina[2*RSA_DW +: RSA_DW] <= Fxi_23;
        //                 TB_dina[3*RSA_DW +: RSA_DW] <= 0;
        //               end
        //             default:begin
        //                 TB_dina[0 +: RSA_DW]        <= 0;
        //                 TB_dina[1*RSA_DW +: RSA_DW] <= 0;
        //                 TB_dina[2*RSA_DW +: RSA_DW] <= 0;
        //                 TB_dina[3*RSA_DW +: RSA_DW] <= 0;
        //               end
        //           endcase
        //         end
        // TBa_NL_NEW: begin
        //           TB_dina[2*RSA_DW +: RSA_DW] <= 0;
        //           TB_dina[3*RSA_DW +: RSA_DW] <= 0;
        //           case(seq_cnt_out)     //不用延迟时序
        //             'd1:begin
        //                   TB_dina[0 +: RSA_DW]        <= Gxi_13;
        //                   TB_dina[1*RSA_DW +: RSA_DW] <= 0;
        //                 end
        //             'd2:begin
        //                   TB_dina[0 +: RSA_DW]        <= Gz_11;
        //                   TB_dina[1*RSA_DW +: RSA_DW] <= Gxi_23;
        //                 end
        //             'd3:begin
        //                   TB_dina[0 +: RSA_DW]        <= Gz_12;
        //                   TB_dina[1*RSA_DW +: RSA_DW] <= Gz_21;
        //                 end
        //             'd4:begin
        //                 TB_dina[0 +: RSA_DW]        <= 0;
        //                 TB_dina[1*RSA_DW +: RSA_DW] <= Gz_22;
        //               end
        //             default:begin
        //                 TB_dina[0 +: RSA_DW]        <= 0;
        //                 TB_dina[1*RSA_DW +: RSA_DW] <= 0;
        //               end
        //           endcase
        //         end
        // TBa_NL_UPD: begin
        //           case(seq_cnt_out)     //不用延迟时序
        //             'd1:begin
        //                   TB_dina[0 +: RSA_DW]        <= Hxi_11;
        //                   TB_dina[1*RSA_DW +: RSA_DW] <= 0;
        //                   TB_dina[2*RSA_DW +: RSA_DW] <= 0;
        //                   TB_dina[3*RSA_DW +: RSA_DW] <= 0;
        //                 end
        //             'd2:begin
        //                   TB_dina[0 +: RSA_DW]        <= Hxi_12;
        //                   TB_dina[1*RSA_DW +: RSA_DW] <= Hxi_21;
        //                   TB_dina[2*RSA_DW +: RSA_DW] <= 0;
        //                   TB_dina[3*RSA_DW +: RSA_DW] <= 0;
        //                 end
        //             'd3:begin
        //                   TB_dina[0 +: RSA_DW]        <= Hz_11;
        //                   TB_dina[1*RSA_DW +: RSA_DW] <= Hxi_22;
        //                   TB_dina[2*RSA_DW +: RSA_DW] <= 0;
        //                   TB_dina[3*RSA_DW +: RSA_DW] <= 0;
        //                 end
        //             'd4:begin
        //                 TB_dina[0 +: RSA_DW]        <= Hz_12;
        //                 TB_dina[1*RSA_DW +: RSA_DW] <= Hz_21;
        //                 TB_dina[2*RSA_DW +: RSA_DW] <= 0;
        //                 TB_dina[3*RSA_DW +: RSA_DW] <= 0;
        //               end
        //             'd5:begin
        //                 TB_dina[0 +: RSA_DW]        <= 0;
        //                 TB_dina[1*RSA_DW +: RSA_DW] <= Hz_22;
        //                 TB_dina[2*RSA_DW +: RSA_DW] <= Fxi_23;
        //                 TB_dina[3*RSA_DW +: RSA_DW] <= 0;
        //               end
        //             'd8:begin
        //                 TB_dina[0 +: RSA_DW]        <= 0;
        //                 TB_dina[1*RSA_DW +: RSA_DW] <= 0;
        //                 TB_dina[2*RSA_DW +: RSA_DW] <= 0;
        //                 TB_dina[3*RSA_DW +: RSA_DW] <= vt_1;
        //               end
        //             'd9:begin
        //                 TB_dina[0 +: RSA_DW]        <= 0;
        //                 TB_dina[1*RSA_DW +: RSA_DW] <= 0;
        //                 TB_dina[2*RSA_DW +: RSA_DW] <= 0;
        //                 TB_dina[3*RSA_DW +: RSA_DW] <= vt_2;
        //               end
        //             default:begin
        //                 TB_dina[0 +: RSA_DW]        <= 0;
        //                 TB_dina[1*RSA_DW +: RSA_DW] <= 0;
        //                 TB_dina[2*RSA_DW +: RSA_DW] <= 0;
        //                 TB_dina[3*RSA_DW +: RSA_DW] <= 0;
        //               end
        //           endcase
        //         end
        default:
            TB_dina <= 0;
      endcase
    end  
  end
endmodule