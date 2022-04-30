/*
  CB_addr移位模块
  无使能信号
  dir==0：左移  
  din为CB_BANK0的数据。先送入BANK0的地址，然后左移
  dir==1: 右移
  din为CB_BANK0的数据。先送入BANK3的地址，然后右移

  按照每一位对应的group_cnt_0决定左移/右移模式
  group_cnt: 0~3为group_0，4~7为group_1，...
  landmark_num: row4,5为L_1 row6,7为L_2, ...

*/
module CB_addr_shift #(
  parameter L = 4,
  parameter CB_AW = 17,
  parameter ROW_LEN    = 10
) (
  input clk,
  input sys_rst,

  input [L-1 : 0] CB_en,
  input dir,
  input group_cnt_0,
  
  input   [CB_AW-1 : 0] din,
  output  reg   [CB_AW*L-1 : 0]  dout
);
  localparam LEFT_SHIFT = 1'b0;
  localparam RIGHT_SHIFT = 1'b1;

  reg [L:1] group_cnt_0_d;
  always @(posedge clk) begin
      if(sys_rst)
        group_cnt_0_d <= 0;
      else 
        group_cnt_0_d <= {group_cnt_0_d[L-1:1], group_cnt_0};  
  end

/*
  group_cnt[0]:
  0:
    dir==LEFT_SHIFT : 不变，直接移
    dir==RIGHT_SHIFT: 不变，直接移 
  1: 
    dir==LEFT_SHIFT : +1
    dir==RIGHT_SHIFT: -1
*/
  integer i;
  always @(posedge clk) begin
      if(sys_rst)
        dout <= 0;
      else begin
        case(dir)
          LEFT_SHIFT: begin
            dout[0 +: CB_AW] <= din;
            for(i=1; i<L; i=i+1) begin
              case(group_cnt_0_d[i]) 
              1'b1: begin
                  dout[i*CB_AW +: CB_AW] <= (CB_en[i-1]) ? (dout[(i-1)*CB_AW +: CB_AW] + 1'b1) : 0;
                end
              1'b0: begin
                  dout[i*CB_AW +: CB_AW] <= dout[(i-1)*CB_AW +: CB_AW];
                end
              endcase
            end
          end
          RIGHT_SHIFT: begin
            dout[(L-1)*CB_AW +: CB_AW] <= din;
            for(i=0; i<L-1; i=i+1) begin
              case(group_cnt_0_d[i]) 
              1'b1: begin
                  dout[i*CB_AW +: CB_AW] <= (CB_en[i+1]) ? (dout[(i+1)*CB_AW +: CB_AW] - 1'b1) : 0;
                end
              1'b0: begin
                  dout[i*CB_AW +: CB_AW] <= dout[(i+1)*CB_AW +: CB_AW];
                end
              endcase
            end
          end
        endcase
      end   

      // else begin
      //   dout[0 +: CB_AW] <= din;
      //   for(i=1; i<L; i=i+1) begin
      //     case(group_cnt_0_d[i]) 
      //     1'b0: begin
      //       dout[i*CB_AW +: CB_AW] <= (CB_en[i-1]) ? (dout[(i-1)*CB_AW +: CB_AW]  + 1'b1) : 0;
      //     end
      //     1'b1: begin
      //       dout[i*CB_AW +: CB_AW] <= dout[(i-1)*CB_AW +: CB_AW];
      //     end
      //     endcase
      //   end


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
endmodule