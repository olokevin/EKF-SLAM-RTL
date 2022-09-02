module PLB_din_map #(
  parameter X = 4,
  parameter Y = 4,
  parameter L = 4,

  parameter RSA_DW = 32,
  parameter SEQ_CNT_DW = 5,
  parameter ROW_LEN = 10
) 
(
  input   clk,
  input   sys_rst,

  input   [ROW_LEN-1 : 0]    l_k,           //当前地标编号

  input   [SEQ_CNT_DW-1 : 0] seq_cnt_out,
  input   [3:0]              prd_cur_out,
  input   [5:0]              new_cur_out,
  input   [5:0]              upd_cur_out,
  input   [5:0]              assoc_cur_out,

//Output state vector to NonLinear
  output  reg  signed [RSA_DW-1 : 0]      xk, yk, xita,
  output  reg  signed [RSA_DW-1 : 0]      lkx, lky,
//Input  predict/init state from NonLinear
  input signed [RSA_DW - 1 : 0] x_hat, y_hat, xita_hat,
  input signed [RSA_DW - 1 : 0] lkx_hat, lky_hat,

//Testbench test
  // input   state_vector_start,

//Update state vector
  input   signed [X*RSA_DW-1 : 0]    C_PLB_din, 
  input   signed [RSA_DW-1 : 0]      PLB_dout,

  output  reg  PLB_en,
  output  reg  PLB_we,
  
  output  reg  [31:0]                   PLB_addr,
  output  reg  signed [RSA_DW-1 : 0]   PLB_din,

//output associated landmark number
  output  reg  [1:0]             assoc_status,
  output  reg  [ROW_LEN-1 : 0]   assoc_l_k
);

localparam xk_ADDR = 32'd1;
localparam yk_ADDR = 32'd2;
localparam xita_ADDR = 32'd3;

localparam PRD_NL_SEND   = 4'b1001;
localparam NEW_NL_SEND   = 6'b100001;
localparam UPD_NL_SEND   = 6'b10_0001;
localparam ASSOC_NL_SEND = 6'b100001;

localparam PRD_NL_RCV    = 4'b1011;
localparam NEW_NL_RCV    = 6'b100011;
localparam UPD_NL_RCV    = 6'b10_0011;
localparam ASSOC_NL_RCV    = 6'b100011;

localparam UPD_STATE     = 6'b1100;

localparam ASSOC_IDLE      = 6'b000000;
localparam ASSOC_10        = 6'b001100;

//SEQ_CNT_PARAM
  localparam [SEQ_CNT_DW-1 : 0] SEQ_0 = 5'd0;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_1 = 5'd1;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_2 = 5'd2;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_3 = 5'd3;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_4 = 5'd4;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_5 = 5'd5;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_6 = 5'd6;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_7 = 5'd7;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_8 = 5'd8;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_9 = 5'd9;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_10 = 5'd10;
  localparam [SEQ_CNT_DW-1 : 0] SEQ_11 = 5'd11;

/*
  *********************Input predict state/ init map ********************
*/

  reg [31:0]  PLB_lk_base_addr;
  always @(posedge clk) begin
    if(sys_rst) begin
      PLB_lk_base_addr <= 0;
    end
    else 
      PLB_lk_base_addr <= (l_k + 1'b1) <<< 1;
  end
/*
  *********************Update State Vector ********************
*/

//delay
  reg  [SEQ_CNT_DW-1 : 0]  seq_cnt_out_delay [1:8];
  reg  [5 : 0]             upd_cur_out_delay [1:8];

  wire [SEQ_CNT_DW-1 : 0]  seq_cnt_out_d8;
  wire [5 : 0]             upd_cur_out_d8;
  assign seq_cnt_out_d8 = seq_cnt_out_delay[8];
  assign upd_cur_out_d8 = upd_cur_out_delay[8];

  integer i_delay;
  always @(posedge clk) begin
    if(!sys_rst) begin
      seq_cnt_out_delay[1] <= seq_cnt_out;
      upd_cur_out_delay[1] <= upd_cur_out;
      for(i_delay=1; i_delay <= 7; i_delay=i_delay+1) begin
        seq_cnt_out_delay[i_delay+1] <= seq_cnt_out_delay[i_delay];
        upd_cur_out_delay[i_delay+1] <= upd_cur_out_delay[i_delay];
      end
    end
  end

//PLB_addr_base
  reg [31 : 0] PLB_addr_base;
  always @(posedge clk) begin
    if(sys_rst) begin
      PLB_addr_base <= 0;
    end
    else begin
      if(upd_cur_out_d8 == UPD_STATE) begin
        if(seq_cnt_out_d8 == SEQ_7)
          PLB_addr_base <= PLB_addr_base + 3'b100;
        else
          PLB_addr_base <= PLB_addr_base;
      end
      else begin
        PLB_addr_base <= 0;
      end
    end
  end

//des->ser temp result
  reg [RSA_DW-1 : 0] result_0;
  reg [RSA_DW-1 : 0] result_1;
  reg [RSA_DW-1 : 0] result_2;
  reg [RSA_DW-1 : 0] result_3;

//For Testbench

always @(posedge clk) begin
  if(sys_rst) begin
    PLB_en <= 1'b0;
    PLB_we <= 1'b0;

    PLB_din <= 0;
    PLB_addr <= 0;
  end
  //For Testbench
  // else if(state_vector_start) begin
  //   PLB_en <= 1'b1;
  //   PLB_we <= 1'b0;

  //   PLB_din <= 0;
  //   PLB_addr <= PLB_addr + 1'b1;
  // end
  
  else begin
  //Output state vector to NonLinear
    if(prd_cur_out == PRD_NL_SEND || new_cur_out == NEW_NL_SEND ||upd_cur_out == UPD_NL_SEND ||assoc_cur_out == ASSOC_NL_SEND) begin
      PLB_we <= 1'b0;
      PLB_din <= 0;
      case (seq_cnt_out)
        SEQ_1: begin
              PLB_en   <= 1'b1;
              PLB_addr <= xk_ADDR;
        end 
        SEQ_2: begin
              PLB_en   <= 1'b1;
              PLB_addr <= yk_ADDR;
        end 
        SEQ_3: begin
              PLB_en   <= 1'b1;
              PLB_addr <= xita_ADDR;

              xk <= PLB_dout;
        end 
        SEQ_4: begin
              PLB_en   <= 1'b1;
              PLB_addr <= PLB_lk_base_addr ;

              yk <= PLB_dout;
        end 
        SEQ_5: begin
              PLB_en   <= 1'b1;
              PLB_addr <= PLB_lk_base_addr + 1'b1 ;

              xita <= PLB_dout;
        end 
        SEQ_6: begin
              PLB_en   <= 1'b0;
              PLB_addr <= 0 ;

              lkx <= PLB_dout;
        end
        SEQ_7: begin
              PLB_en   <= 1'b0;
              PLB_addr <= 0 ;

              lky <= PLB_dout;
        end
        default: begin
              PLB_en   <= 1'b0;
              PLB_addr <= 0 ;
        end
      endcase
    end
  //Input  predict state from NonLinear
    else if(prd_cur_out == PRD_NL_RCV) begin
      case (seq_cnt_out)
        SEQ_1: begin
              PLB_en   <= 1'b1;
              PLB_we   <= 1'b1;
              PLB_addr <= xk_ADDR;
              PLB_din  <= x_hat;
        end 
        SEQ_2: begin
              PLB_en   <= 1'b1;
              PLB_we   <= 1'b1;
              PLB_addr <= yk_ADDR;
              PLB_din  <= y_hat;
        end 
        SEQ_3: begin
              PLB_en   <= 1'b1;
              PLB_we   <= 1'b1;
              PLB_addr <= xita_ADDR;
              PLB_din  <= xita_hat;
        end 
        default: begin
              PLB_en   <= 1'b0;
              PLB_we   <= 1'b0;
              PLB_addr <= 0;
              PLB_din  <= 0;
        end
      endcase
    end
  //Input  init state from NonLinear
    else if(new_cur_out == NEW_NL_RCV) begin
      case (seq_cnt_out)
        SEQ_1: begin
              PLB_en   <= 1'b1;
              PLB_we   <= 1'b1;
              PLB_addr <= PLB_lk_base_addr;
              PLB_din  <= lkx_hat;
        end 
        SEQ_2: begin
              PLB_en   <= 1'b1;
              PLB_we   <= 1'b1;
              PLB_addr <= PLB_lk_base_addr + 1'b1;
              PLB_din  <= lky_hat;
        end 
        default: begin
              PLB_en   <= 1'b0;
              PLB_we   <= 1'b0;
              PLB_addr <= 0;
              PLB_din  <= 0;
        end
      endcase
    end
  //Update State Vector
    else if(upd_cur_out_d8 == UPD_STATE) begin
      PLB_en <= 1'b1;
      case (seq_cnt_out_d8)
        SEQ_0: begin
              PLB_we <= 1'b0;
              PLB_addr <= PLB_addr_base;
        end
        SEQ_1: begin
              PLB_we <= 1'b0;
              PLB_addr <= PLB_addr + 1'b1;
        end
        SEQ_2: begin
              PLB_we <= 1'b0;
              PLB_addr <= PLB_addr + 1'b1;
              
              result_0 <= PLB_dout + C_PLB_din[0 +: RSA_DW];
        end
        SEQ_3: begin
              PLB_we <= 1'b0;
              PLB_addr <= PLB_addr + 1'b1;
              
              result_1 <= PLB_dout + C_PLB_din[1*RSA_DW +: RSA_DW];
        end
        SEQ_4: begin
              PLB_we <= 1'b1;
              PLB_addr <= PLB_addr_base;
              
              result_2 <= PLB_dout + C_PLB_din[2*RSA_DW +: RSA_DW];
              
              PLB_din <= result_0;
        end
        SEQ_5: begin
              PLB_we <= 1'b1;
              PLB_addr <= PLB_addr + 1'b1;

              result_3 <= PLB_dout + C_PLB_din[3*RSA_DW +: RSA_DW];
              
              PLB_din <= result_1;
        end
        SEQ_6: begin
              PLB_we <= 1'b1;
              PLB_addr <= PLB_addr + 1'b1;

              PLB_din <= result_2;
        end
        SEQ_7: begin
              PLB_we <= 1'b1;
              PLB_addr <= PLB_addr + 1'b1;

              PLB_din <= result_3;
        end
        default: begin
              PLB_en <= 1'b0;
              PLB_we <= 1'b0;

              PLB_din <= 0;
              PLB_addr <= 0;
        end
      endcase
    end
    else begin
      PLB_en <= 1'b0;
      PLB_we <= 1'b0;

      PLB_din <= 0;
      PLB_addr <= 0;
    end
  end
    
end

/*
    ******************data association*****************************
*/
localparam ASSOC_WAIT = 2'b00;
localparam ASSOC_NEW  = 2'b01;
localparam ASSOC_UPD  = 2'b10;
localparam ASSOC_FAIL = 2'b11;

localparam CHI_95  = 32'h2f_ee87; //5.99147f
localparam CHI_999 = 32'h6e_8625; //13.8155f

reg        [RSA_DW-1 : 0] min_chi;    //取绝对值
reg        [RSA_DW-1 : 0] temp_chi;

  always @(posedge clk) begin
    if(sys_rst) begin
      assoc_status <= ASSOC_WAIT;
    end
    else begin
      if(min_chi < CHI_95) begin
        assoc_status <= ASSOC_UPD;
      end
      else if(min_chi > CHI_999) begin
        assoc_status <= ASSOC_NEW;
      end
      else
        assoc_status <= ASSOC_FAIL;
    end
  end

  always @(posedge clk) begin
    if(sys_rst) begin
      temp_chi <= 0;
      min_chi  <= 0;
      assoc_l_k    <= 0;
    end
    else begin
      //Set zero at the start of each association
      if(assoc_cur_out == ASSOC_IDLE) begin
        temp_chi <= 0;
        min_chi  <= 0;
        assoc_l_k <= 0;
      end
      //Get result
      else if(assoc_cur_out == ASSOC_10) begin
        case(seq_cnt_out)
          SEQ_10: begin
              temp_chi <= C_PLB_din[RSA_DW] ? (- C_PLB_din[RSA_DW-1 : 0]) : C_PLB_din[RSA_DW-1 : 0];
          end
          SEQ_11: begin
            if(l_k == 32'b1) begin
              min_chi <= temp_chi;
              assoc_l_k <= l_k;
            end
            else begin
              if(temp_chi < min_chi) begin
                min_chi <= temp_chi;
                assoc_l_k <= l_k;
              end
              else begin
                min_chi <= min_chi;
                assoc_l_k <= assoc_l_k;
              end
            end
          end
          default: begin
            temp_chi <= 0;
            min_chi <= min_chi;
            assoc_l_k <= assoc_l_k;
          end
        endcase
      end
      else begin      //In between the association, save min_chi & assoc_l_k
        temp_chi <= 0;
        min_chi <= min_chi;
        assoc_l_k <= assoc_l_k;
      end
    end
  end

endmodule