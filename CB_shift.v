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
module CB_shift #(
  parameter L = 4,
  parameter CB_AW = 17,
  parameter ROW_LEN    = 10
) (
  input clk,
  input sys_rst,

  input [1:0] CB_dir,
  input [1:0] landmark_num_10,
  input group_cnt_0,
  
  input CB_en_new,
  output reg [L-1 : 0] CB_en,

  input CB_we_new,
  output reg [L-1 : 0] CB_we,

  input   [CB_AW-1 : 0] CB_addr_new,
  output  reg   [CB_AW*L-1 : 0]  CB_addr
);

/*
  CB_dir[1:0]
    00: DIR_IDLE
    01: 正向映射
    10：逆向映射
    11：X

 l_num[1:0]  CB_BANK   PE_BANK
  11          0         0
              1         1 
              
  00          2         0
              3         1

  01          3         0
              2         1

  10          1         0
              0         1
*/
  localparam LEFT_SHIFT = 1'b0;
  localparam RIGHT_SHIFT = 1'b1;

  localparam DIR_IDLE = 2'b00;
  localparam DIR_POS  = 2'b01;
  localparam DIR_NEG  = 2'b10;
  localparam DIR_NEW  = 2'b11;

  localparam  DIR_NEW_11  = 2'b11; 
  localparam  DIR_NEW_00  = 2'b00;
  localparam  DIR_NEW_01  = 2'b01;
  localparam  DIR_NEW_10  = 2'b10;


  reg [L:1] group_cnt_0_d;
  always @(posedge clk) begin
      if(sys_rst)
        group_cnt_0_d <= 0;
      else 
        group_cnt_0_d <= {group_cnt_0_d[L-1:1], group_cnt_0};  
  end

/*
  en shift
*/
always @(posedge clk) begin
  if(sys_rst) begin
    CB_en <= 0;
  end
  else begin
    case (CB_dir)
      DIR_POS: CB_en <= {CB_en[0 +: L-1], CB_en_new};
      DIR_NEG: CB_en <= {CB_en_new, CB_en[1 +: L-1]};
      DIR_NEW: begin
        case(landmark_num_10)
          DIR_NEW_11: begin
            CB_en[0] <= CB_en_new;
            CB_en[1] <= CB_en[0];
            CB_en[2] <= 0;
            CB_en[3] <= 0;
          end
          DIR_NEW_00: begin
            CB_en[0] <= 0;
            CB_en[1] <= 0;
            CB_en[2] <= CB_en_new;
            CB_en[3] <= CB_en[2];
          end
          DIR_NEW_01: begin
            CB_en[0] <= 0;
            CB_en[1] <= 0;
            CB_en[2] <= CB_en[3];
            CB_en[3] <= CB_en_new;
          end
          DIR_NEW_10: begin
            CB_en[0] <= CB_en[1];
            CB_en[1] <= CB_en_new;
            CB_en[2] <= 0;
            CB_en[3] <= 0;
          end
        endcase
      end
      default: begin
        CB_en <= 0;
      end
    endcase
  end
end

/*
  we shift
*/
always @(posedge clk) begin
  if(sys_rst) begin
    CB_we <= 0;
  end
  else begin
    case (CB_dir)
      DIR_POS: CB_we <= {CB_we[0 +: L-1], CB_we_new};
      DIR_NEG: CB_we <= {CB_we_new, CB_we[1 +: L-1]};
      DIR_NEW: begin
        case(landmark_num_10)
          DIR_NEW_11: begin
            CB_we[0] <= CB_we_new;
            CB_we[1] <= CB_we[0];
            CB_we[2] <= 0;
            CB_we[3] <= 0;
          end
          DIR_NEW_00: begin
            CB_we[0] <= 0;
            CB_we[1] <= 0;
            CB_we[2] <= CB_we_new;
            CB_we[3] <= CB_we[2];
          end
          DIR_NEW_01: begin
            CB_we[0] <= 0;
            CB_we[1] <= 0;
            CB_we[2] <= CB_we[3];
            CB_we[3] <= CB_we_new;
          end
          DIR_NEW_10: begin
            CB_we[0] <= CB_we[1];
            CB_we[1] <= CB_we_new;
            CB_we[2] <= 0;
            CB_we[3] <= 0;
          end
        endcase
      end
      default: begin
        CB_we <= 0;
      end
    endcase
  end
end

/*
  addr_shift
*/
  integer i;
  always @(posedge clk) begin
      if(sys_rst)
        CB_addr <= 0;
      else begin
        case(CB_dir)
          DIR_POS: begin
            CB_addr[0 +: CB_AW] <= CB_en_new ? CB_addr_new : 0;
            for(i=1; i<L; i=i+1) begin
              case(group_cnt_0_d[i]) 
              1'b1: begin
                  CB_addr[i*CB_AW +: CB_AW] <= (CB_en[i-1]) ? (CB_addr[(i-1)*CB_AW +: CB_AW] + 1'b1) : 0;
                end
              1'b0: begin
                  CB_addr[i*CB_AW +: CB_AW] <= CB_addr[(i-1)*CB_AW +: CB_AW];
                end
              endcase
            end
          end
          DIR_NEG: begin
            CB_addr[(L-1)*CB_AW +: CB_AW] <= CB_en_new ? (CB_addr_new + 2'b11) : 0;
            for(i=0; i<L-1; i=i+1) begin
              case(group_cnt_0_d[i]) 
              1'b1: begin
                  CB_addr[i*CB_AW +: CB_AW] <= (CB_en[i+1]) ? (CB_addr[(i+1)*CB_AW +: CB_AW] - 1'b1) : 0;
                end
              1'b0: begin
                  CB_addr[i*CB_AW +: CB_AW] <= CB_addr[(i+1)*CB_AW +: CB_AW];
                end
              endcase
            end
          end
          DIR_NEW: begin
            case(landmark_num_10)
              DIR_NEW_11: begin
                CB_addr[0 +: CB_AW]        <= CB_en_new ? CB_addr_new : 0;
                CB_addr[1*CB_AW +: CB_AW] <= (CB_en[0]) ? (CB_addr[0 +: CB_AW]) : 0;
                CB_addr[2*CB_AW +: CB_AW] <= 0;
                CB_addr[3*CB_AW +: CB_AW] <= 0;
              end
              DIR_NEW_00: begin
                CB_addr[0 +: CB_AW]        <= 0;
                CB_addr[1*CB_AW +: CB_AW] <= 0;
                CB_addr[2*CB_AW +: CB_AW] <= CB_en_new ? CB_addr_new : 0;
                CB_addr[3*CB_AW +: CB_AW] <= (CB_en[2]) ? (CB_addr[0 +: CB_AW]) : 0;
              end
              DIR_NEW_01: begin
                CB_addr[0 +: CB_AW]        <= 0;
                CB_addr[1*CB_AW +: CB_AW] <= 0;
                CB_addr[2*CB_AW +: CB_AW] <= (CB_en[3]) ? (CB_addr[3*CB_AW +: CB_AW] - 1'b1) : 0;
                CB_addr[3*CB_AW +: CB_AW] <= CB_en_new ? (CB_addr_new + 3'b11) : 0;
              end
              DIR_NEW_10: begin
                CB_addr[0 +: CB_AW]        <= (CB_en[1]) ? (CB_addr[3*CB_AW +: CB_AW] - 1'b1) : 0;
                CB_addr[1*CB_AW +: CB_AW] <= CB_en_new ? (CB_addr_new + 1'b1) : 0;
                CB_addr[2*CB_AW +: CB_AW] <= 0;
                CB_addr[3*CB_AW +: CB_AW] <= 0;
              end
            endcase
          end
        endcase
      end   
  end
endmodule