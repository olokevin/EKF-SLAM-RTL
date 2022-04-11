/*
  CB_addr移位模块
  无使能信号
  dir==0：左移  
  din为CB_BANK0的数据。送入的也为BANK0对应的行的基址。

  dir==1: 右移
*/
module CB_addr_shift #(
  parameter L = 4,
  parameter CB_AW = 19,
  parameter ROW_LEN    = 10
) (
  input clk,
  input sys_rst,

  input [L-2 : 0] CB_en,
  input group_cnt_0,
  
  input   [CB_AW-1 : 0] din,
  output  reg   [CB_AW*L-1 : 0]  dout
);
  reg [L:1] group_cnt_0_d;
  always @(posedge clk) begin
      if(sys_rst)
        group_cnt_0_d <= 0;
      else 
        group_cnt_0_d <= {group_cnt_0_d[L-1:1], group_cnt_0};  
  end

  integer i;
  always @(posedge clk) begin
      if(sys_rst)
        dout <= 0;
      else begin
        dout[0 +: CB_AW] <= din;
        for(i=1; i<L; i=i+1) begin
          case(group_cnt_0_d[i]) 
          1'b0: begin
            dout[i*CB_AW +: CB_AW] <= (CB_en[i-1]) ? (dout[(i-1)*CB_AW +: CB_AW]  + 1'b1) : 0;
          end
          1'b1: begin
            dout[i*CB_AW +: CB_AW] <= dout[(i-1)*CB_AW +: CB_AW];
          end
          endcase
        end


        // case(group_cnt_0)
        //   1'b0: begin
        //     for(i=1; i<L; i=i+1)begin
        //       dout[0 +: CB_AW] <= din;
        //       dout[i*CB_AW +: CB_AW] <= (CB_en[i-1]) ? (dout[(i-1)*CB_AW +: CB_AW]  + 1'b1) : 0;
        //     end
        //   end
        //   1'b1: begin
        //     dout <= {dout[0 +: (L-1)*CB_AW], din};
        //   end
        // endcase
      end
  end
endmodule