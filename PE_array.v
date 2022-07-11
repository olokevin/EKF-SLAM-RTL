module PE_array 
#(
  parameter X = 4,
  parameter Y = 4,
  parameter L = 4,

  parameter RSA_DW = 32
)
(
  input   clk,
  input   sys_rst,

  input   [1:0]               PE_mode,

  input   signed [X*RSA_DW-1 : 0]    A_data,
  input   signed [Y*RSA_DW-1 : 0]    B_data,
  input   signed [X*RSA_DW-1 : 0]    M_data,
  output  signed [X*RSA_DW-1 : 0]    C_data,

  input   [Y-1 : 0]           new_cal_en,
  input   [Y-1 : 0]           new_cal_done,

  input   [2*X-1 : 0]         M_adder_mode
);

    localparam W_2_E = 1'b0;
    localparam E_2_W = 1'b1;
    localparam N_2_S = 1'b0;
    localparam S_2_N = 1'b1;

//PE互连信号线
//由于输出可能接到模块，故将输出的坐标与PE坐标绑定，输入与来源的PE坐标绑定
wire    [(X+1)*(Y+1)-1:0]           cal_en;         
wire    [(X+1)*(Y+1)-1:0]           cal_done;       

wire    [(X+1)*(Y+1)*RSA_DW-1:0]    v_data;

wire    [(Y+1)*(X+1)*RSA_DW-1:0]    h_data;
wire    [(Y+1)*(X+1)*RSA_DW-1:0]    mulres;
wire    [(Y+1)*(X+1)-1:0]           mulres_val;

//送入加法器
wire    [(X+1)*RSA_DW-1 : 0]        mulres_out;
wire    [X : 0]                     mulres_val_out;

/*
  第(i,j)个PE data：[(i*(Y+1)+j)*LEN +: LEN]
  第(i,j)个PE sig:  [i*(Y+1)+j]
  最左：[i*(Y+1)*LEN +: LEN]
  最右：[((i+1)*(Y+1)-1)*LEN +: LEN]
  最上：[j*LEN +: LEN]
  最下：[(X*(Y+1)+j)*LEN +: LEN]

  0~X 0~Y
  总共(X+1)*(Y+1)
*/

//PE data mapping
generate
  genvar i_h;
  for(i_h=0; i_h<X; i_h=i_h+1) begin: h_map
    //输入 inout接口
    assign  h_data[i_h*(Y+1)*RSA_DW +: RSA_DW]         = A_data[i_h*RSA_DW +: RSA_DW];
    assign  h_data[((i_h+1)*(Y+1)-1)*RSA_DW +: RSA_DW] = {RSA_DW{1'bz}};
    //输出 直接接到
    assign  mulres_val_out[i_h]                  = mulres_val[i_h*(Y+1)];
    assign  mulres_out[i_h*RSA_DW +: RSA_DW]     = mulres[i_h*(Y+1)*RSA_DW +: RSA_DW];
    
    //adder of A*B + M 
    sync_adder 
      #(
          .RSA_DW (RSA_DW )
      )
      MC_adder(
        .clk     (clk     ),
        .sys_rst (sys_rst ),
        .mode    (M_adder_mode[2*i_h +: 2]     ),
        .adder_M (M_data[RSA_DW*i_h +: RSA_DW] ),
        .adder_C (mulres_out[i_h*RSA_DW +: RSA_DW] ),
        .sum     (C_data[RSA_DW*i_h +: RSA_DW]     )
      );
  end
endgenerate

generate
  genvar j_v;
  for(j_v=0; j_v<Y; j_v=j_v+1) begin: v_map
    assign  v_data[j_v*RSA_DW +: RSA_DW]            = B_data[j_v*RSA_DW +: RSA_DW];
    assign  v_data[(X*(Y+1)+j_v)*RSA_DW +: RSA_DW]  = {RSA_DW{1'bz}};
    assign  cal_en[j_v]                             = new_cal_en[j_v];
    assign  cal_en[(X*(Y+1)+j_v)]                   = 1'bz;
    assign  cal_done[j_v]                           = new_cal_done[j_v];
    assign  cal_done[(X*(Y+1)+j_v)]                 = 1'bz;
  end
endgenerate

//PE arrays
/*
  cal_en cal_done v_data:   纵向
  h_data mulres mulres_val: 横向

  PE坐标从(0,0)开始，对应左上角的PE单元
  取west north对应PE的坐标，则east对应(i,j+1), south对应(i+1,j)
  
  第(i,j)个PE data：[(i*(Y+1)+j)*LEN +: LEN]
  第(i,j)个PE sig:  [i*(Y+1)+j]
*/
  generate
    genvar i,j;
      for(i=0; i<X; i=i+1) begin: PE_X
        for(j=0; j<Y; j=j+1) begin: PE_Y
          PE_MAC 
          #(
            .RSA_DW (RSA_DW )
          )
          u_PE_MAC(
            .clk          (clk          ),
            .sys_rst      (sys_rst      ),
            .PE_mode      (PE_mode      ),
            .cal_en_N     (cal_en[i*(Y+1)+j]    ),
            .cal_en_S     (cal_en[(i+1)*(Y+1)+j]      ),
            .cal_done_N   (cal_done[i*(Y+1)+j]   ),
            .cal_done_S   (cal_done[(i+1)*(Y+1)+j]   ),
            .v_data_N     (v_data[(i*(Y+1)+j)*RSA_DW +: RSA_DW]     ),
            .v_data_S     (v_data[((i+1)*(Y+1)+j)*RSA_DW +: RSA_DW]     ),
            .h_data_W     (h_data[(i*(Y+1)+j)*RSA_DW +: RSA_DW]     ),
            .h_data_E     (h_data[(i*(Y+1)+j+1)*RSA_DW +: RSA_DW]     ),
            .mulres_val_W (mulres_val[i*(Y+1)+j] ),
            .mulres_val_E (mulres_val[i*(Y+1)+j+1] ),
            .mulres_W     (mulres[(i*(Y+1)+j)*RSA_DW +: RSA_DW]     ),
            .mulres_E     (mulres[(i*(Y+1)+j+1)*RSA_DW +: RSA_DW]     )
          );
        end
      end
  endgenerate

endmodule