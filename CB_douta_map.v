module CB_douta_map #(
  parameter X = 4,
  parameter Y = 4,
  parameter L = 4,

  parameter RSA_DW = 32,
  parameter SEQ_CNT_DW = 10,
  parameter CB_DOUTA_SEL_DW = 5
) 
(
  input   clk,
  input   sys_rst,

  input   [CB_DOUTA_SEL_DW-1 : 0]   CB_douta_sel,
  input           l_k_0,
  input   [SEQ_CNT_DW-1 : 0] seq_cnt_dout_sel,

  input   signed [L*RSA_DW-1 : 0]         CB_douta,
  output  reg  signed [X*RSA_DW-1 : 0]    TB_dina_CB_douta,
  output  reg  signed [X*RSA_DW-1 : 0]    A_CB_douta,
  output  reg  signed [Y*RSA_DW-1 : 0]    B_CB_douta,
  output  reg  signed [X*RSA_DW-1 : 0]    M_CB_douta
);

//
/*
  CB_douta_sel[4:2]
    000: IDLE
    001: A
    010: B
    011: M
    100: CBa_TBa
    101: CBa_NL
  CB_douta_sel[1:0]
    00: DIR_IDLE
    01: 正向映射
    10：逆向映射
    11：NEW, 新地标初始化步，根据landmark后两位决定映射关系(进NEW步骤就先+1)
*/
localparam CBa_IDLE = 3'b000;
localparam CBa_A = 3'b001;
localparam CBa_B = 3'b010;
localparam CBa_M = 3'b011;

localparam CBa_TBa = 3'b100;
localparam CBa_NL  = 3'b101;

localparam DIR_IDLE = 2'b00;
localparam DIR_POS  = 2'b01;
localparam DIR_NEG  = 2'b10;
localparam DIR_NEW  = 2'b11;

localparam DIR_NEW_0  = 1'b0;
localparam DIR_NEW_1  = 1'b1;

/*
  旧地址映射方案

  l_num[1:0]  CBa_BANK   PE_BANK
  11          0         0
              1         1 
              
  00          2         0
              3         1

  01          3         0
              2         1

  10          1         0
              0         1

  localparam  DIR_NEW_11  = 2'b11; 
  localparam  DIR_NEW_00  = 2'b00;
  localparam  DIR_NEW_01  = 2'b01;
  localparam  DIR_NEW_10  = 2'b10;
*/


/*
  A_CB_douta
*/
integer i_CBa_A;
always @(posedge clk) begin
    if(sys_rst)
      A_CB_douta <= 0;
    else begin
      case(CB_douta_sel[CB_DOUTA_SEL_DW-1 : 2])
        CBa_A: begin
          case(CB_douta_sel[1:0])
            DIR_IDLE: A_CB_douta <= 0;
            DIR_POS : A_CB_douta <= CB_douta;
            DIR_NEG :begin
              for(i_CBa_A=0; i_CBa_A<L; i_CBa_A=i_CBa_A+1) begin
                A_CB_douta[i_CBa_A*RSA_DW +: RSA_DW] <= CB_douta[(L-1-i_CBa_A)*RSA_DW +: RSA_DW];
              end
            end
            DIR_NEW : begin
              case (l_k_0)
                DIR_NEW_1: begin
                  A_CB_douta[0 +: RSA_DW]        <= CB_douta[0 +: RSA_DW];
                  A_CB_douta[1*RSA_DW +: RSA_DW] <= CB_douta[1*RSA_DW +: RSA_DW];
                  A_CB_douta[2*RSA_DW +: RSA_DW] <= 0;
                  A_CB_douta[3*RSA_DW +: RSA_DW] <= 0;
                end
                DIR_NEW_0: begin
                  A_CB_douta[0 +: RSA_DW]        <= CB_douta[2*RSA_DW +: RSA_DW];
                  A_CB_douta[1*RSA_DW +: RSA_DW] <= CB_douta[3*RSA_DW +: RSA_DW];
                  A_CB_douta[2*RSA_DW +: RSA_DW] <= 0;
                  A_CB_douta[3*RSA_DW +: RSA_DW] <= 0;
                end
              endcase
            end
          endcase
        end
        default: A_CB_douta <= 0;
      endcase
    end     
end

/*
  B_CB_douta
*/
integer i_CBa_B;
always @(posedge clk) begin
    if(sys_rst)
      B_CB_douta <= 0;
    else begin
      case(CB_douta_sel[CB_DOUTA_SEL_DW-1 : 2])
        CBa_B: begin
          case(CB_douta_sel[1:0])
            DIR_IDLE: B_CB_douta <= 0;
            DIR_POS : B_CB_douta <= CB_douta;
            DIR_NEG :begin
              for(i_CBa_B=0; i_CBa_B<L; i_CBa_B=i_CBa_B+1) begin
                B_CB_douta[i_CBa_B*RSA_DW +: RSA_DW] <= CB_douta[(L-1-i_CBa_B)*RSA_DW +: RSA_DW];
              end
            end
            DIR_NEW : begin
              case (l_k_0)
                DIR_NEW_1: begin
                  B_CB_douta[0 +: RSA_DW]        <= CB_douta[0 +: RSA_DW];
                  B_CB_douta[1*RSA_DW +: RSA_DW] <= CB_douta[1*RSA_DW +: RSA_DW];
                  B_CB_douta[2*RSA_DW +: RSA_DW] <= 0;
                  B_CB_douta[3*RSA_DW +: RSA_DW] <= 0;
                end
                DIR_NEW_0: begin
                  B_CB_douta[0 +: RSA_DW]        <= CB_douta[2*RSA_DW +: RSA_DW];
                  B_CB_douta[1*RSA_DW +: RSA_DW] <= CB_douta[3*RSA_DW +: RSA_DW];
                  B_CB_douta[2*RSA_DW +: RSA_DW] <= 0;
                  B_CB_douta[3*RSA_DW +: RSA_DW] <= 0;
                end
              endcase
            end
          endcase
        end
        default: B_CB_douta <= 0;
      endcase
    end     
end

/*
  M_CB_douta
*/
integer i_CBa_M;
always @(posedge clk) begin
    if(sys_rst)
      M_CB_douta <= 0;
    else begin
      case(CB_douta_sel[CB_DOUTA_SEL_DW-1 : 2])
        CBa_M: begin
          case(CB_douta_sel[1:0])
            DIR_IDLE: M_CB_douta <= 0;
            DIR_POS : M_CB_douta <= CB_douta;
            DIR_NEG :begin
              for(i_CBa_M=0; i_CBa_M<L; i_CBa_M=i_CBa_M+1) begin
                M_CB_douta[i_CBa_M*RSA_DW +: RSA_DW] <= CB_douta[(L-1-i_CBa_M)*RSA_DW +: RSA_DW];
              end
            end
            DIR_NEW : begin
              case (l_k_0)
                DIR_NEW_1: begin
                  M_CB_douta[0 +: RSA_DW]        <= CB_douta[0 +: RSA_DW];
                  M_CB_douta[1*RSA_DW +: RSA_DW] <= CB_douta[1*RSA_DW +: RSA_DW];
                  M_CB_douta[2*RSA_DW +: RSA_DW] <= 0;
                  M_CB_douta[3*RSA_DW +: RSA_DW] <= 0;
                end
                DIR_NEW_0: begin
                  M_CB_douta[0 +: RSA_DW]        <= CB_douta[2*RSA_DW +: RSA_DW];
                  M_CB_douta[1*RSA_DW +: RSA_DW] <= CB_douta[3*RSA_DW +: RSA_DW];
                  M_CB_douta[2*RSA_DW +: RSA_DW] <= 0;
                  M_CB_douta[3*RSA_DW +: RSA_DW] <= 0;
                end
              endcase
            end
          endcase
        end
        default: M_CB_douta <= 0;
      endcase
    end     
end

/*
  TB_dina_CB_douta
*/
integer i_CBa_TBa;
always @(posedge clk) begin
    if(sys_rst)
      TB_dina_CB_douta <= 0;
    else begin
      case(CB_douta_sel[CB_DOUTA_SEL_DW-1 : 2])
        CBa_TBa: begin
          case(CB_douta_sel[1:0])
            DIR_IDLE: TB_dina_CB_douta <= 0;
            DIR_NEW: begin
              case(seq_cnt_dout_sel)
                'd0:begin 
                      TB_dina_CB_douta[0 +: RSA_DW]        <= 0;
                      TB_dina_CB_douta[1*RSA_DW +: RSA_DW] <= 0;
                      TB_dina_CB_douta[2*RSA_DW +: RSA_DW] <= 0;
                      TB_dina_CB_douta[3*RSA_DW +: RSA_DW] <= l_k_0 ? CB_douta[1*RSA_DW +: RSA_DW] : CB_douta[3*RSA_DW +: RSA_DW];
                    end
                'd1:begin
                      TB_dina_CB_douta[0 +: RSA_DW]        <= l_k_0 ? CB_douta[0 +: RSA_DW] : CB_douta[2*RSA_DW +: RSA_DW];
                      TB_dina_CB_douta[1*RSA_DW +: RSA_DW] <= 0;
                      TB_dina_CB_douta[2*RSA_DW +: RSA_DW] <= 0;
                      TB_dina_CB_douta[3*RSA_DW +: RSA_DW] <= 0;
                    end
                'd2:begin
                      TB_dina_CB_douta[0 +: RSA_DW]        <= l_k_0 ? CB_douta[1*RSA_DW +: RSA_DW] : CB_douta[3*RSA_DW +: RSA_DW];
                      TB_dina_CB_douta[1*RSA_DW +: RSA_DW] <= l_k_0 ? CB_douta[0 +: RSA_DW] : CB_douta[2*RSA_DW +: RSA_DW];
                      TB_dina_CB_douta[2*RSA_DW +: RSA_DW] <= 0;
                      TB_dina_CB_douta[3*RSA_DW +: RSA_DW] <= 0;
                    end
                'd3:begin
                      TB_dina_CB_douta[0 +: RSA_DW]        <= 0;
                      TB_dina_CB_douta[1*RSA_DW +: RSA_DW] <= l_k_0 ? CB_douta[1*RSA_DW +: RSA_DW] : CB_douta[3*RSA_DW +: RSA_DW];
                      TB_dina_CB_douta[2*RSA_DW +: RSA_DW] <= l_k_0 ? CB_douta[0 +: RSA_DW] : CB_douta[2*RSA_DW +: RSA_DW];
                      TB_dina_CB_douta[3*RSA_DW +: RSA_DW] <= 0;
                    end
                'd4:begin
                      TB_dina_CB_douta[0 +: RSA_DW]        <= 0;
                      TB_dina_CB_douta[1*RSA_DW +: RSA_DW] <= 0;
                      TB_dina_CB_douta[2*RSA_DW +: RSA_DW] <= l_k_0 ? CB_douta[1*RSA_DW +: RSA_DW] : CB_douta[3*RSA_DW +: RSA_DW];
                      TB_dina_CB_douta[3*RSA_DW +: RSA_DW] <= l_k_0 ? CB_douta[0 +: RSA_DW] : CB_douta[2*RSA_DW +: RSA_DW];
                    end
                default: TB_dina_CB_douta <= 0;
              endcase
            end
            default: TB_dina_CB_douta <= 0;
          endcase
        end
        default: TB_dina_CB_douta <= 0;
      endcase
    end     
end
endmodule