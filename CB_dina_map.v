module CB_dina_map #(
  parameter X = 4,
  parameter Y = 4,
  parameter L = 4,

  parameter RSA_DW =32,
  parameter SEQ_CNT_DW = 5,
  parameter CB_DINA_SEL_DW  = 2
) 
(
  input   clk,
  input   sys_rst,

  input [CB_DINA_SEL_DW-1 : 0]   CB_dina_sel,
  input [SEQ_CNT_DW-1 : 0]       seq_cnt_out,

  input signed [RSA_DW - 1 : 0] x_hat, y_hat, xita_hat,
  input signed [RSA_DW - 1 : 0] lkx, lky,
  output  reg  signed [L*RSA_DW-1 : 0]    CB_dina
);

//stage
  localparam  IDLE            = 2'b00 ;
  localparam  CB_DINA_xyxita  = 2'b10 ;
  localparam  CB_DINA_lxly    = 2'b11 ;


  always @(posedge clk) begin
    if(sys_rst)
      CB_dina <= 0;
    else begin
      case(CB_dina_sel)
        CB_DINA_xyxita: begin
          case(seq_cnt_out)
            'd1:begin
                  CB_dina[0 +: RSA_DW]        <= x_hat;
                  CB_dina[1*RSA_DW +: RSA_DW] <= 0;
                  CB_dina[2*RSA_DW +: RSA_DW] <= 0;
                  CB_dina[3*RSA_DW +: RSA_DW] <= 0;
              end
            'd2:begin
                  CB_dina[0 +: RSA_DW]        <= 0;
                  CB_dina[1*RSA_DW +: RSA_DW] <= y_hat;
                  CB_dina[2*RSA_DW +: RSA_DW] <= 0;
                  CB_dina[3*RSA_DW +: RSA_DW] <= 0;
                end
            'd3:begin
                  CB_dina[0 +: RSA_DW]        <= 0;
                  CB_dina[1*RSA_DW +: RSA_DW] <= 0;
                  CB_dina[2*RSA_DW +: RSA_DW] <= xita_hat;
                  CB_dina[3*RSA_DW +: RSA_DW] <= 0;
                end
            default:begin
                  CB_dina <= 0;
                end
          endcase
        end
        CB_DINA_lxly: begin
          case(seq_cnt_out)
            'd1:begin
                  CB_dina[0 +: RSA_DW]        <= lkx;
                  CB_dina[1*RSA_DW +: RSA_DW] <= 0;
                  CB_dina[2*RSA_DW +: RSA_DW] <= 0;
                  CB_dina[3*RSA_DW +: RSA_DW] <= 0;
              end
            'd2:begin
                  CB_dina[0 +: RSA_DW]        <= 0;
                  CB_dina[1*RSA_DW +: RSA_DW] <= lky;
                  CB_dina[2*RSA_DW +: RSA_DW] <= 0;
                  CB_dina[3*RSA_DW +: RSA_DW] <= 0;
                end
            default:begin
                  CB_dina <= 0;
                end
          endcase
        end
        default:begin
                  CB_dina <= 0;
                end
      endcase
    end  
  end
endmodule