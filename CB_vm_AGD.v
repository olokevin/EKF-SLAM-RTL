module CB_vm_AGD #(
  parameter CB_AW        = 19,
  parameter ROW_LEN      = 10
) (
    input clk,
    input sys_rst,

    input en,
    input [ROW_LEN-1 : 0]  group_cnt,

    output reg [CB_AW-1 : 0] CB_base_addr
);
  
  reg [ROW_LEN+1 : 0] group_cnt_shift;
  reg [3:0] group_offset;
  reg [CB_AW-1 : 0] new_interval;

  reg en_d;
  always @(posedge clk) begin
      if(sys_rst)
          en_d <= 0;
      else 
          en_d <= en;
  end

  always @(posedge clk) begin
      if(sys_rst) begin
        group_cnt_shift <= 0;
        group_offset <= 0;
        new_interval <= 0;
        CB_base_addr <= 2'b10;
      end
      else begin
        case({en_d, en})
          2'b00: begin
            group_cnt_shift <= 0;
            group_offset <= 0;
          end 
          2'b01: begin
            group_cnt_shift <= group_cnt[ROW_LEN-1 : 1] << 3;
            group_offset <= 4'b1000 + group_cnt[0];
          end 
          2'b11: begin
            new_interval <= group_cnt_shift + group_offset;
          end
          2'b10: begin
            CB_base_addr <= CB_base_addr + new_interval;
          end
        endcase
      end 
        
  end
endmodule