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

  input [L-1 : 0] CB_en,
  input group_cnt_0,
  
  input   [CB_AW-1 : 0] din,
  output  reg   [CB_AW*L-1 : 0]  dout
);

  // localparam STATE_CNT_MAX = 5;
  // reg [2:0] state_cnt;
  // reg [ROW_LEN-1 : 0] group_cnt;

  // always @(posedge clk) begin
  //     if(sys_rst)
  //       state_cnt <= 0;
  //     else if(en) begin
  //       if(state_cnt == STATE_CNT_MAX) begin
  //         state_cnt <= 0;
  //       end
  //       else
  //         state_cnt <= state_cnt + 1'b1;
  //     end
  //     else
  //       state_cnt <= 0;
  // end

  // always @(posedge clk) begin
  //     if(sys_rst)
  //       group_cnt <= 0;
  //     else if(en) begin
  //       if(state_cnt == STATE_CNT_MAX) begin
  //         if(state_cnt == landmark_num)
  //           group_cnt <= group_cnt + 1'b1;
  //       end
  //       else begin
  //         group_cnt <= group_cnt;
  //       end
  //     end
  //     else
  //       group_cnt <= 0;  
  // end

  integer i;
  always @(posedge clk) begin
      if(sys_rst)
          dout <= 0;
      else begin
        case(group_cnt_0)
          1'b0: begin
            for(i=1; i<L; i=i+1)begin
              dout[0 +: CB_AW] <= din;
              dout[i*CB_AW +: CB_AW] <= (CB_en[i-1]) ? (dout[(i-1)*CB_AW +: CB_AW]  + 1'b1) : 0;
            end
          end
          1'b1: begin
            dout <= {dout[0 +: (L-1)*CB_AW], din};
          end
        endcase
      end
  end
endmodule