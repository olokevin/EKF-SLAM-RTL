module CB_dinb_map #(
  parameter X = 4,
  parameter Y = 4,
  parameter L = 4,

  parameter RSA_DW =32,
  parameter SEQ_CNT_DW = 5,
  parameter CB_DINB_SEL_DW  = 5
) 
(
  input   clk,
  input   sys_rst,

  input   [CB_DINB_SEL_DW-1 : 0]   CB_dinb_sel,
  input           l_k_0,
  input [SEQ_CNT_DW-1 : 0]       seq_cnt_out,

  // input signed [RSA_DW - 1 : 0] x_hat, y_hat, xita_hat,
  // input signed [RSA_DW - 1 : 0] lkx_hat, lky_hat,

  input   signed [X*RSA_DW-1 : 0]         C_CB_dinb,
  output  reg  signed [L*RSA_DW-1 : 0]    CB_dinb
);
  
  localparam DIR_IDLE = 2'b00;
  localparam DIR_POS  = 2'b01;
  localparam DIR_NEG  = 2'b10;
  localparam DIR_NEW  = 2'b11;

  localparam DIR_NEW_0  = 1'b0;
  localparam DIR_NEW_1  = 1'b1;

  localparam CBb_IDLE = 3'b000;
  localparam CBb_C    = 3'b001;  
  localparam CBb_xyxita  = 3'b101 ;
  localparam CBb_lxly    = 3'b110 ;

integer i_CB_C;
  always @(posedge clk) begin
    if(sys_rst)
      CB_dinb <= 0;
    else begin
      case (CB_dinb_sel[CB_DINB_SEL_DW-1 : 2])
        CBb_C: begin
                case(CB_dinb_sel[1:0])
                  DIR_IDLE: CB_dinb <= 0;
                  DIR_POS: begin
                    CB_dinb <= C_CB_dinb;
                  end
                  DIR_NEG :begin
                    for(i_CB_C=0; i_CB_C<L; i_CB_C=i_CB_C+1) begin
                      CB_dinb[i_CB_C*RSA_DW +: RSA_DW] <= C_CB_dinb[(L-1-i_CB_C)*RSA_DW +: RSA_DW];
                    end
                  end
                  DIR_NEW : begin
                    case (l_k_0)
                      DIR_NEW_1: begin
                        CB_dinb[0 +: RSA_DW]        <= C_CB_dinb[0 +: RSA_DW];
                        CB_dinb[1*RSA_DW +: RSA_DW] <= C_CB_dinb[1*RSA_DW +: RSA_DW];
                        CB_dinb[2*RSA_DW +: RSA_DW] <= 0;
                        CB_dinb[3*RSA_DW +: RSA_DW] <= 0;
                      end
                      DIR_NEW_0: begin
                        CB_dinb[0 +: RSA_DW]        <= 0;
                        CB_dinb[1*RSA_DW +: RSA_DW] <= 0;
                        CB_dinb[2*RSA_DW +: RSA_DW] <= C_CB_dinb[0 +: RSA_DW];
                        CB_dinb[3*RSA_DW +: RSA_DW] <= C_CB_dinb[1*RSA_DW +: RSA_DW];
                      end
                    endcase
                  end
                  default:
                    CB_dinb <= 0;
                endcase
              end 
        // CBb_xyxita: begin
        //           case(seq_cnt_out)
        //             'd1:begin
        //                   CB_dinb[0 +: RSA_DW]        <= x_hat;
        //                   CB_dinb[1*RSA_DW +: RSA_DW] <= 0;
        //                   CB_dinb[2*RSA_DW +: RSA_DW] <= 0;
        //                   CB_dinb[3*RSA_DW +: RSA_DW] <= 0;
        //               end
        //             'd2:begin
        //                   CB_dinb[0 +: RSA_DW]        <= 0;
        //                   CB_dinb[1*RSA_DW +: RSA_DW] <= y_hat;
        //                   CB_dinb[2*RSA_DW +: RSA_DW] <= 0;
        //                   CB_dinb[3*RSA_DW +: RSA_DW] <= 0;
        //                 end
        //             'd3:begin
        //                   CB_dinb[0 +: RSA_DW]        <= 0;
        //                   CB_dinb[1*RSA_DW +: RSA_DW] <= 0;
        //                   CB_dinb[2*RSA_DW +: RSA_DW] <= xita_hat;
        //                   CB_dinb[3*RSA_DW +: RSA_DW] <= 0;
        //                 end
        //             default:begin
        //                   CB_dinb <= 0;
        //                 end
        //           endcase
        //         end
        // CBb_lxly: begin
        //           case(seq_cnt_out)
        //             'd1:begin
        //                   CB_dinb[0 +: RSA_DW]        <= l_k_0 ? lkx_hat : 0;
        //                   CB_dinb[1*RSA_DW +: RSA_DW] <= 0;
        //                   CB_dinb[2*RSA_DW +: RSA_DW] <= l_k_0 ? 0 : lkx_hat;
        //                   CB_dinb[3*RSA_DW +: RSA_DW] <= 0;
        //               end
        //             'd2:begin
        //                   CB_dinb[0 +: RSA_DW]        <= 0;
        //                   CB_dinb[1*RSA_DW +: RSA_DW] <= l_k_0 ? lky_hat : 0;
        //                   CB_dinb[2*RSA_DW +: RSA_DW] <= 0;
        //                   CB_dinb[3*RSA_DW +: RSA_DW] <= l_k_0 ? 0 : lky_hat;
        //                 end
        //             default:begin
        //                   CB_dinb <= 0;
        //                 end
        //           endcase
        //         end
        default:begin
                  CB_dinb <= 0;
                end
      endcase
      
    end  
  end
endmodule