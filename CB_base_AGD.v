/*
    默认值0即为group 0的base_addr
    输入一次en信号后，计算一次 *下一group* 的base_addr
    生成每行的首地址(4,0) (8,0) (12,0) (16,0)...

    START有效后 3T得到新基址
*/

module CB_base_AGD #(
  parameter CB_AW        = 17,
  parameter ROW_LEN      = 10
) (
    input clk,
    input sys_rst,

    input en,
    input [ROW_LEN-1 : 0]  group_cnt,

    output reg [CB_AW-1 : 0] CB_base_addr
);
  
  reg en_d;
  always @(posedge clk) begin
      if(sys_rst)
          en_d <= 0;
      else 
          en_d <= en;
  end

  reg [ROW_LEN-1 : 0]  n_group_cnt;
  reg [ROW_LEN-1 : 0]  n_group_cnt_r1;
  reg [CB_AW-1 : 0] CB_base_addr_r1;
  reg [CB_AW-1 : 0] CB_base_addr_r2;

  always @(posedge clk) begin
    if(sys_rst) begin
      n_group_cnt <= 0;
    end
    else 
      n_group_cnt <= group_cnt + 1'b1;
  end
  
  always @(posedge clk) begin
    if(sys_rst) begin
      n_group_cnt_r1 <= 0;
    end
    else 
      n_group_cnt_r1 <= n_group_cnt;
  end

  always @(posedge clk) begin
    if(sys_rst) begin
      CB_base_addr <= 0;
      CB_base_addr_r1 <= 0;
      CB_base_addr_r2 <= 0;
    end
    else begin
      case({en_d, en})
        2'b00: begin
          CB_base_addr <= CB_base_addr;
        end 
        2'b01: begin
          CB_base_addr_r1 <= n_group_cnt * n_group_cnt;
        end 
        2'b11: begin
          CB_base_addr_r2 <= CB_base_addr_r1 + n_group_cnt_r1;
        end
        2'b10: begin
          CB_base_addr <= CB_base_addr_r2 << 1;
        end
      endcase
    end   
  end

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