module B_cache_dout_map #(
  parameter X = 4,
  parameter Y = 4,
  parameter L = 4,

  parameter RSA_DW = 32,
  parameter SEQ_CNT_DW = 5
) 
(
  input   clk,
  input   sys_rst,

  input   [3 : 0]   B_cache_out_sel,

  input   signed [L*RSA_DW-1 : 0]         B_cache_dout,
  output  reg  signed [X*RSA_DW-1 : 0]    B_cache_dout_A,
  output  reg  signed [Y*RSA_DW-1 : 0]    B_cache_dout_B
);

/*

*/
    localparam Bca_IDLE  = 4'b0000;
  //RD 首位为0
    localparam Bca_RD_A  = 4'b0001;
    localparam Bca_RD_B  = 4'b0010;

always @(posedge clk) begin
  if(sys_rst) begin
    B_cache_dout_A <= 0;
  end
  else begin
    case (B_cache_out_sel)
      Bca_RD_A: begin
        B_cache_dout_A <= B_cache_dout;
      end
      default: B_cache_dout_A <= 0;
    endcase
  end 
end

always @(posedge clk) begin
  if(sys_rst) begin
    B_cache_dout_B <= 0;
  end
  else begin
    case (B_cache_out_sel)
      Bca_RD_B: begin
        B_cache_dout_B <= B_cache_dout;
      end
      default: B_cache_dout_B <= 0;
    endcase
  end 
end

endmodule