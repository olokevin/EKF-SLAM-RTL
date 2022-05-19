/*
    默认值0即为group 0的base_addr
    输入一次en信号后，计算一次 *下一group* 的base_addr
    生成每行的首地址(4,0) (8,0) (12,0) (16,0)...

    START有效后 3T得到新基址
*/

module CB_base_AGD #(
  parameter CB_AW        = 17,
  parameter ROW_LEN      = 10,
  parameter AGD_MODE     = 0
) (
    input clk,
    input sys_rst,

    input en,
    input [ROW_LEN-1 : 0]  group_cnt,

    output reg [CB_AW-1 : 0] CB_base_addr
);
  localparam NEXT_BASE = 0;
  localparam THIS_BASE = 1;

  /*
    group对应的首地址:
    2 * (1+group_cnt) * group_cnt = (group_cnt*group_cnt + group_cnt) << 1
    NEXT_BASE模式下，需计算下一group的首地址
    THIS_BASE模式下，计算当前输入的group的首地址

  */

  reg en_d;
  always @(posedge clk) begin
      if(sys_rst)
          en_d <= 0;
      else 
          en_d <= en;
  end

  reg [ROW_LEN-1 : 0]  group_cnt_T1;
  reg [ROW_LEN-1 : 0]  group_cnt_T2;
  reg [CB_AW-1 : 0] CB_base_addr_T2;
  reg [CB_AW-1 : 0] CB_base_addr_T3;

/*
  group_cnt更新后
  T1: group_cnt_T1 <= group_cnt + 1'b1;
  T2: CB_base_addr_T2 <= group_cnt_T1 * group_cnt_T1;
  T3: CB_base_addr_T3 <= CB_base_addr_T2 + group_cnt_T2;
  T4: CB_base_addr <= CB_base_addr_T3 << 1;
*/

  always @(posedge clk) begin
    if(sys_rst) begin
      group_cnt_T1 <= 0;
      group_cnt_T2 <= 0;
      CB_base_addr <= 0;
      CB_base_addr_T2 <= 0;
      CB_base_addr_T3 <= 0;
    end
    else begin
      if(en==1'b1) begin
        if(AGD_MODE == NEXT_BASE)
          group_cnt_T1 <= group_cnt + 1'b1;
        else
          group_cnt_T1 <= group_cnt;

        CB_base_addr_T2 <= group_cnt_T1 * group_cnt_T1;
        group_cnt_T2 <= group_cnt_T1;

        CB_base_addr_T3 <= CB_base_addr_T2 + group_cnt_T2;
        CB_base_addr <= CB_base_addr_T3 << 1;
      end
      else begin
        group_cnt_T1 <= 0;
        group_cnt_T2 <= 0;
        CB_base_addr <= 0;
        CB_base_addr_T2 <= 0;
        CB_base_addr_T3 <= 0;
      end
    end   
  end

  // always @(posedge clk) begin
  //   if(sys_rst) begin
  //     CB_base_addr <= 0;
  //     CB_base_addr_T2 <= 0;
  //     CB_base_addr_T3 <= 0;
  //   end
  //   else begin
  //     case({en_d, en})
  //       2'b00: begin
  //         CB_base_addr <= CB_base_addr;
  //       end 
  //       2'b01: begin
  //         CB_base_addr_T2 <= group_cnt_T1 * group_cnt_T1;
  //       end 
  //       2'b11: begin
  //         CB_base_addr_T3 <= CB_base_addr_T2 + group_cnt_T2;
  //       end
  //       2'b10: begin
  //         CB_base_addr <= CB_base_addr_T3 << 1;
  //       end
  //     endcase
  //   end   
  // end

  // reg [ROW_LEN+1 : 0] group_cnt_shift;
  // reg [3:0] group_offset;
  // reg [CB_AW-1 : 0] new_interval;
  // always @(posedge clk) begin
  //     if(sys_rst) begin
  //       group_cnt_shift <= 0;
  //       group_offset <= 0;
  //       new_interval <= 0;
  //       CB_base_addr <= 'd2;
  //     end
  //     else begin
  //       case({en_d, en})
  //         2'b00: begin
  //           group_cnt_shift <= 0;
  //           group_offset <= 0;
  //         end 
  //         2'b01: begin
  //           group_cnt_shift <= group_cnt[ROW_LEN-1 : 1] << 3;
  //           group_offset <= 4'b1000 + group_cnt[0];
  //         end 
  //         2'b11: begin
  //           new_interval <= group_cnt_shift + group_offset;
  //         end
  //         2'b10: begin
  //           CB_base_addr <= CB_base_addr + new_interval;
  //         end
  //       endcase
  //     end 
        
  // end
endmodule