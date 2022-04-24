module Cout_mapping #(
  parameter X = 4,
  parameter Y = 4,
  parameter L = 4,

  parameter RSA_DW = 16
) 
(
  input   clk,
  input   sys_rst,

  input   [2:0]   C_map_mode,

  input   [X*RSA_DW-1 : 0]         C_data,
  output  reg  [L*RSA_DW-1 : 0]    C_TB_dinb,
  output  reg  [L*RSA_DW-1 : 0]    C_CB_dinb

);
  
localparam  TB_POS = 3'b000;
localparam  TB_NEG = 3'b001;
localparam  CB_POS = 3'b010;
localparam  CB_NEG = 3'b011;

//新地标初始化步，根据landmark后两位决定映射关系(进NEW步骤就先+1)
/*
  l_num[1:0]  CB_BANK   C_data
  11          0         0
              1         1 
              
  00          2         0
              3         1

  01          3         0
              2         1

  10          1         0
              0         1
*/
localparam  NEW_11  = 3'b111; 
localparam  NEW_00  = 3'b100;
localparam  NEW_01  = 3'b101;
localparam  NEW_10  = 3'b110;
  
integer i_TB;
  always @(posedge clk) begin
    if(sys_rst)
      C_TB_dinb <= 0;
    else begin
      case(C_map_mode)
        TB_POS: begin
          for(i_TB=0; i_TB<X; i_TB=i_TB+1) begin
            C_TB_dinb[i_TB*RSA_DW +: RSA_DW] <= C_data[i_TB*RSA_DW +: RSA_DW];
          end
        end
        TB_NEG: begin
          for(i_TB=0; i_TB<X; i_TB=i_TB+1) begin
            C_TB_dinb[i_TB*RSA_DW +: RSA_DW] <= C_data[(X-1-i_TB)*RSA_DW +: RSA_DW];
          end
        end
        default:
          C_TB_dinb <= 0;
      endcase
    end  
  end

integer i_CB;
  always @(posedge clk) begin
    if(sys_rst)
      C_CB_dinb <= 0;
    else begin
      case(C_map_mode)
        CB_POS: begin
          for(i_CB=0; i_CB<X; i_CB=i_CB+1) begin
            C_CB_dinb[i_CB*RSA_DW +: RSA_DW] <= C_data[i_CB*RSA_DW +: RSA_DW];
          end
        end
        CB_NEG: begin
          for(i_CB=0; i_CB<X; i_CB=i_CB+1) begin
            C_CB_dinb[i_CB*RSA_DW +: RSA_DW] <= C_data[(X-1-i_CB)*RSA_DW +: RSA_DW];
          end
        end
        NEW_11: begin
          C_CB_dinb[0 +: RSA_DW]        <= C_data[0 +: RSA_DW];
          C_CB_dinb[1*RSA_DW +: RSA_DW] <= C_data[1*RSA_DW +: RSA_DW];
          C_CB_dinb[2*RSA_DW +: RSA_DW] <= 0;
          C_CB_dinb[3*RSA_DW +: RSA_DW] <= 0;
        end
        NEW_00: begin
          C_CB_dinb[0 +: RSA_DW]        <= 0;
          C_CB_dinb[1*RSA_DW +: RSA_DW] <= 0;
          C_CB_dinb[2*RSA_DW +: RSA_DW] <= C_data[0 +: RSA_DW];
          C_CB_dinb[3*RSA_DW +: RSA_DW] <= C_data[1*RSA_DW +: RSA_DW];
        end
        NEW_01: begin
          C_CB_dinb[0 +: RSA_DW]        <= 0;
          C_CB_dinb[1*RSA_DW +: RSA_DW] <= 0;
          C_CB_dinb[2*RSA_DW +: RSA_DW] <= C_data[1*RSA_DW +: RSA_DW];
          C_CB_dinb[3*RSA_DW +: RSA_DW] <= C_data[0 +: RSA_DW];
        end
        NEW_10: begin
          C_CB_dinb[0 +: RSA_DW]        <= C_data[1*RSA_DW +: RSA_DW];
          C_CB_dinb[1*RSA_DW +: RSA_DW] <= C_data[0 +: RSA_DW];
          C_CB_dinb[2*RSA_DW +: RSA_DW] <= 0;
          C_CB_dinb[3*RSA_DW +: RSA_DW] <= 0;
        end
        default:
          C_CB_dinb <= 0;
      endcase
    end  
  end
endmodule