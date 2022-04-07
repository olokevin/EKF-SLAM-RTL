module RSA 
#(
    parameter X = 4,
    parameter Y = 4,
    parameter L = 4,

    parameter RSA_DW = 16,
    parameter TB_AW = 12,
    parameter CB_AW = 19
) 
(
    input   clk,
    input   sys_rst

    //initialize handshake

);

//PE互连信号线
wire    [(X-1)*Y:0]           n_cal_en;         //由于输出可能接到模块，故将输出的坐标与PE坐标绑定，输入与来源的PE坐标绑定
wire    [(X-1)*Y:0]           n_cal_done;       //n_cal_en[0]接到(1,1)的PE 其余与PE坐标一致

wire    [X*RSA_DW*Y:1]    westin;
wire    [Y*RSA_DW*X:1]    southin;

wire    [X*Y:1]           dout_val;
wire    [X*RSA_DW*Y:1]   dout;

//PE阵列
genvar i,j;
generate
    for(i=1; i<=X; i=i+1) begin:PE_MAC_X
        for(j=1; j<=Y; j=j+1) begin:PE_MAC_Y
        /*
            第(i,j)个PE data：[ LEN*((i-1)*Y+j) : LEN*((i-1)*Y+j-1) + 1 ]
            第(i,j)个PE sig:  [(i-1)*Y+j]

            n_cal_en n_cal_done dout_val: PE sig, 对应本PE的坐标
            westin southin dout: PE data, 对应本PE的坐标

            westin 向右传递
            southin 向上传递
            最后一行的n_cal_en, n_cal_done 向右传递
            其他行的n_cal_en, n_cal_done   向上传递
            dout dout_val 向左传递
        */
            //最后一行 cal_en cal_done
            //最后一行的cal_en cal_done来自所在列上一列 j-1
            if(i==X && j!=Y) begin
                PE_MAC 
                #(
                    .RSA_DW (RSA_DW )
                )
                u_PE_MAC(
                    .clk        (clk        ),
                    .sys_rst    (sys_rst  ),
                    .cal_en     (n_cal_en[j-1]     ),  //第一行的cal_en cal_done来自所在列上一列 j-1
                    .cal_done   (n_cal_done[j-1]   ),
                    .westin     (westin[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]     ),
                    .southin    (southin[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]    ),
                    .din_val    (dout_val[(i-1)*Y+j+1]    ),
                    .din        (dout[RSA_DW*((i-1)*Y+j+1) : RSA_DW*((i-1)*Y+j)+1]        ),
                    .n_cal_en   (n_cal_en[(i-1)*Y+j]   ),
                    .n_cal_done (n_cal_done[(i-1)*Y+j] ),
                    .eastout    (westin[RSA_DW*((i-1)*Y+j+1) : RSA_DW*((i-1)*Y+j)+1]    ),
                    .northout   (southin[RSA_DW*(i*Y+j) : RSA_DW*(i*Y+j-1)+1]   ),
                    .dout_val   (dout_val[(i-1)*Y+j]   ),  
                    .dout       (dout[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]       )
                );
            end
            //最后一行的最后一个，没有din din_val eastout
            else if(i==X && j==Y) begin
                PE_MAC 
                #(
                    .RSA_DW  (RSA_DW )
                )
                u_PE_MAC(
                    .clk        (clk        ),
                    .sys_rst  (sys_rst  ),
                    .cal_en     (n_cal_en[j-1]     ),  //第一列的cal_en cal_done来自该列上一列 j-1
                    .cal_done   (n_cal_done[j-1]   ),
                    .westin     (westin[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]     ),
                    .southin    (southin[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]    ),
                    .din_val    (din_val_gnd   ),
                    .din        (din_gnd      ),
                    .n_cal_en   (n_cal_en[(i-1)*Y+j]   ),
                    .n_cal_done (n_cal_done[(i-1)*Y+j] ),
                    .eastout    (    ),
                    .northout   (southin[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]   ),
                    .dout_val   (dout_val[(i-1)*Y+j]   ),  
                    .dout       (dout[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]       )
                );
            end
            //中间部分
            else if(i>1 && i<X && j<Y) begin
                PE_MAC 
                #(
                    .RSA_DW (RSA_DW )
                )
                u_PE_MAC(
                    .clk        (clk        ),
                    .sys_rst  (sys_rst  ),
                    .cal_en     (n_cal_en[(i)*Y+j]     ),                                       //cal_en cal_done来自下一行
                    .cal_done   (n_cal_done[(i)*Y+j]   ),
                    .westin     (westin[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]     ),     //westin，southin 按PE模块位置设置
                    .southin    (southin[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]    ),
                    .din_val    (dout_val[(i-1)*Y+j+1]    ),                                    //din来自右边 j+1
                    .din        (dout[RSA_DW*((i-1)*Y+j+1) : RSA_DW*((i-1)*Y+j)+1]        ),
                    .n_cal_en   (n_cal_en[(i-1)*Y+j]   ),                                       //n_cal_en 按PE模块位置设置
                    .n_cal_done (n_cal_done[(i-1)*Y+j] ),
                    .eastout    (westin[RSA_DW*((i-1)*Y+j+1) : RSA_DW*((i-1)*Y+j)+1]    ),      //eastout传到右边 j+1
                    .northout   (southin[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]   ),      //northout传到下边 i+1
                    .dout_val   (dout_val[(i-1)*Y+j]   ),                                       //dout  按PE模块位置设置
                    .dout       (dout[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]       )
                );
            end
            //第一行，没有northout, n_cal_en, n_cal_done
            else if(i==X && j!=Y) begin
                PE_MAC 
                #(
                    .RSA_DW (RSA_DW )
                )
                u_PE_MAC(
                    .clk        (clk        ),
                    .sys_rst  (sys_rst  ),
                    .cal_en     (n_cal_en[(i-2)*Y+j]     ),                                         
                    .cal_done   (n_cal_done[(i-2)*Y+j]   ),
                    .westin     (westin[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]     ),  
                    .southin    (southin[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]    ),
                    .din_val    (dout_val[(i-1)*Y+j+1]    ),    
                    .din        (dout[RSA_DW*((i-1)*Y+j+1) : RSA_DW*((i-1)*Y+j)+1]        ),
                    .n_cal_en   (  ),       
                    .n_cal_done (  ),
                    .eastout    (westin[RSA_DW*((i-1)*Y+j+1) : RSA_DW*((i-1)*Y+j)+1]    ),  
                    .northout   (  ),   
                    .dout_val   (dout_val[(i-1)*Y+j]   ),  
                    .dout       (dout[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]       )
                );
            end
            //最右一列，没有eastout，没有din
            else if(i!=X && j==Y) begin
                PE_MAC 
                #(
                    .RSA_DW (RSA_DW )
                )
                u_PE_MAC(
                    .clk        (clk        ),
                    .sys_rst  (sys_rst  ),
                    .cal_en     (n_cal_en[(i-2)*Y+j]     ),  
                    .cal_done   (n_cal_done[(i-2)*Y+j]   ),
                    .westin     (westin[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]     ),  
                    .southin    (southin[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]    ),
                    .din_val    (din_val_gnd    ),    
                    .din        (din_gnd  ),
                    .n_cal_en   (n_cal_en[(i-1)*Y+j]   ),       
                    .n_cal_done (n_cal_done[(i-1)*Y+j] ),
                    .eastout    (    ),  
                    .northout   (southin[RSA_DW*(i*Y+j) : RSA_DW*(i*Y+j-1)+1]   ),   
                    .dout_val   (dout_val[(i-1)*Y+j]   ),  
                    .dout       (dout[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]       )
                );
            end
            //右上角，没有eastout, northout, din, n_cal_en, n_cal_done
            else if(i==X && j==Y) begin
                PE_MAC 
                #(
                    .RSA_DW (RSA_DW )
                )
                u_PE_MAC(
                    .clk        (clk        ),
                    .sys_rst  (sys_rst  ),
                    .cal_en     (n_cal_en[(i-2)*Y+j]     ),  
                    .cal_done   (n_cal_done[(i-2)*Y+j]   ),
                    .westin     (westin[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]     ),  
                    .southin    (southin[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]    ),
                    .din_val    (din_val_gnd    ),    
                    .din        (din_gnd   ),
                    .n_cal_en   ( ),     
                    .n_cal_done ( ),
                    .eastout    ( ),  
                    .northout   ( ),  
                    .dout_val   (dout_val[(i-1)*Y+j]   ),  
                    .dout       (dout[RSA_DW*((i-1)*Y+j) : RSA_DW*((i-1)*Y+j-1)+1]       )
                );
            end
        end
    end
endgenerate

/*
    第(i,j)个data：[ LEN*((i-1)*Y+j) : LEN*((i-1)*Y+j-1) + 1 ]
    第(i,j)个sig:  [(i-1)*Y+j]
*/

//A in
wire [X*RSA_DW-1 : 0]         A_TB_douta;
wire [X*RSA_DW-1 : 0]         A_CB_douta;
wire [X-1 : 0]                  A_in_sel;
wire [X-1 : 0]                  A_in_en;     


//B in
wire [Y*RSA_DW-1 : 0]         B_TB_doutb; 
wire [Y*RSA_DW-1 : 0]         B_CB_douta;
wire [2*(Y-1) : 0]              B_in_sel;   
wire [Y-1 : 0]                  B_in_en;   

//M in
wire [X*RSA_DW-1 : 0]         M_TB_douta; 
wire [X*RSA_DW-1 : 0]         M_CB_doutb_0;
wire [X*RSA_DW-1 : 0]         M_CB_doutb_1;
wire [2*(X-1) : 0]              M_in_sel;  
wire [X-1 : 0]                  M_in_en;  

//C out
wire [X*RSA_DW-1 : 0]         C_TB_dinb_0;
wire [X*RSA_DW-1 : 0]         C_TB_dinb_1; 
wire [X*RSA_DW-1 : 0]         C_CB_dinb_0;
wire [X*RSA_DW-1 : 0]         C_CB_dinb_1;
wire [2*(X-1) : 0]              C_out_sel; 
wire [X-1 : 0]                  C_out_en; 

//adder
wire [X*RSA_DW-1 : 0]         M_adder_in;  
wire [X*RSA_DW-1 : 0]         C_adder_out;

genvar i_X;
generate
    for(i_X=0; i_X<=X-1; i_X=i_X+1) begin: PE_DATA_X
        regMUX_sel1 
        #(
            .RSA_DW (RSA_DW )
        )
        A_regMUX_sel1(
            .clk     (clk     ),
            .sys_rst (sys_rst ),
            .en      (A_in_en[i_X]      ),
            .sel     (A_in_sel[i_X]     ),
            .din_0   (A_TB_douta[RSA_DW*i_X +: RSA_DW]   ),
            .din_1   (A_CB_douta[RSA_DW*i_X +: RSA_DW]   ),
            .dout    (westin[RSA_DW*i_X*Y+1 +: RSA_DW]    )
        );

        regMUX_sel2 
        #(
            .RSA_DW (RSA_DW )
        )
        M_regMUX_sel1(
            .clk     (clk     ),
            .sys_rst (sys_rst ),
            .en      (M_in_en[i_X]      ),
            .sel     (M_in_sel[2*i_X +: 2]     ),
            .din_00  (0  ),
            .din_01  (M_TB_douta[RSA_DW*i_X +: RSA_DW]  ),
            .din_10  (M_CB_doutb_0[RSA_DW*i_X +: RSA_DW]  ),
            .din_11  (M_CB_doutb_1[RSA_DW*(X-i_X) +: RSA_DW]  ),
            .dout    (M_adder_in[RSA_DW*i_X +: RSA_DW]    )
        );

        regdeMUX_sel2 
        #(
            .RSA_DW (RSA_DW )
        )
        C_regdeMUX_sel2(
        	.clk     (clk     ),
            .sys_rst (sys_rst ),
            .en      (C_out_en[i_X]      ),
            .sel     (M_in_sel[2*i_X +: 2]     ),
            .din     (C_adder_out[RSA_DW*i_X +: RSA_DW]     ),
            .dout_00 (C_TB_dinb_0[RSA_DW*i_X +: RSA_DW] ),
            .dout_01 (C_TB_dinb_1[RSA_DW*(X-i_X) +: RSA_DW] ),
            .dout_10 (C_CB_dinb_0[RSA_DW*i_X +: RSA_DW] ),
            .dout_11 (C_CB_dinb_1[RSA_DW*(X-i_X) +: RSA_DW] )
        );

        sync_adder 
        #(
            .RSA_DW (RSA_DW )
        )
        MC_adder(
        	.clk     (clk     ),
            .sys_rst (sys_rst ),
            .mode    (M_in_sel[2*i_X +: 2]     ),
            .adder_M (M_adder_in[RSA_DW*i_X +: RSA_DW] ),
            .adder_C (dout[RSA_DW*i_X*Y +: RSA_DW] ),
            .sum     (C_adder_out[RSA_DW*i_X +: RSA_DW]     )
        );
        
    end
endgenerate

//Bin 临时寄存H
wire [L-1 : 0]        TB_doutb_sel;

wire [Y*RSA_DW-1:0] B_CONS_din;
reg [RSA_DW-1:0] B_CONS [Y-1:0];
reg [2:0] B_CONS_addr;

always @(posedge clk) begin
    if(TB_doutb_sel == 1'b1) begin
        B_CONS[B_CONS_addr] <= B_CONS_din;
        B_CONS_addr <= B_CONS_addr + 1'b1;
    end
    else begin
        B_CONS_addr <= 0;
    end 
end

genvar i_Y;
generate
    for(i_Y=0; i_Y<=Y-1; i_Y=i_Y+1) begin: PE_DATA_Y
        regMUX_sel2 
        #(
            .RSA_DW (RSA_DW )
        )
        B_regMUX_sel1(
            .clk     (clk     ),
            .sys_rst (sys_rst ),
            .en      (B_in_en[i_Y]      ),
            .sel     (B_in_sel[2*i_Y +: 2]     ),
            .din_00  (B_TB_doutb[RSA_DW*i_Y +: RSA_DW]  ),
            .din_01  (B_CONS[i_Y]  ),
            .din_10  (B_CB_douta[RSA_DW*i_Y +: RSA_DW]  ),
            .din_11  (0  ),
            .dout    (southin[RSA_DW*X*i_Y+1 +: RSA_DW]    )
        );
    end
endgenerate

//TEMP BRAM
wire [L-1 : 0]        TB_dinb_sel;
wire [L-1 : 0]        TB_douta_sel;
//定义提前
// wire [L-1 : 0]        TB_doutb_sel;

wire [L-1 : 0]          TB_ena;
wire [L-1 : 0]          TB_enb;

wire [L-1 : 0]          TB_wea;
wire [L-1 : 0]          TB_web;

wire [L*RSA_DW-1 : 0] init_TB_dina;
wire [L*TB_AW-1 : 0] TB_addra;
wire [L*RSA_DW-1 : 0] TB_dinb;
wire [L*TB_AW-1 : 0] TB_addrb;

wire [L*RSA_DW-1 : 0] TB_douta;
wire [L*RSA_DW-1 : 0] TB_doutb;

//COV BRAM
wire [L-1 : 0]        CB_dinb_sel;
wire [L-1 : 0]        CB_douta_sel;
wire [L-1 : 0]        CB_doutb_sel;

wire [L-1 : 0]          CB_ena;
wire [L-1 : 0]          CB_enb;

wire [L-1 : 0]          CB_wea;
wire [L-1 : 0]          CB_web;

wire [L*RSA_DW-1 : 0] init_CB_dina;
wire [L*CB_AW-1 : 0] CB_addra;
wire [L*RSA_DW-1 : 0] CB_dinb;
wire [L*CB_AW-1 : 0] CB_addrb;

wire [L*RSA_DW-1 : 0] CB_douta;
wire [L*RSA_DW-1 : 0] CB_doutb;

//BRAM_BANK 
genvar i_BANK;
generate
    for(i_BANK=0; i_BANK<L; i_BANK=i_BANK+1) begin:BANK
        TEMP_BANK TB (
            .clka(clk),    // input wire clka
            .rsta(sys_rst), 
            .ena(TB_ena[i_BANK]),      // input wire ena
            .wea(TB_wea[i_BANK]),      // input wire [0 : 0] wea
            .addra(TB_addra[i_BANK*TB_AW +: TB_AW]),  // input wire [11 : 0] addra
            .dina(init_TB_dina[i_BANK*RSA_DW +: RSA_DW]),    // input wire [15 : 0] dina
            .douta(TB_douta[i_BANK*RSA_DW +: RSA_DW]),  // output wire [15 : 0] douta
            .clkb(clk),    // input wire clkb
            .rstb(rstb), 
            .enb(TB_enb[i_BANK]),      // input wire enb
            .web(TB_web[i_BANK]),      // input wire [0 : 0] web
            .addrb(TB_addrb[i_BANK*TB_AW +: TB_AW]),  // input wire [11 : 0] addrb
            .dinb(TB_dinb[i_BANK*RSA_DW +: RSA_DW]),    // input wire [15 : 0] dinb
            .doutb(TB_doutb[i_BANK*RSA_DW +: RSA_DW])  // output wire [15 : 0] doutb
        );

        regdeMUX_sel1 
        #(
            .RSA_DW (RSA_DW )
        )
        TB_douta_regdeMUX_sel1(
        	.clk     (clk     ),
            .sys_rst (sys_rst ),
            .en      (TB_ena[i_BANK]       ),
            .sel     (TB_douta_sel     ),
            .din     (TB_douta[i_BANK*RSA_DW +: RSA_DW]     ),
            .dout_0  (A_TB_douta[i_BANK*RSA_DW +: RSA_DW]  ),
            .dout_1  (M_TB_douta[i_BANK*RSA_DW +: RSA_DW]   )
        );

        regMUX_sel1 
        #(
            .RSA_DW (RSA_DW )
        )
        TB_dinb_regMUX_sel1(
        	.clk     (clk     ),
            .sys_rst (sys_rst ),
            .en      (TB_enb[i_BANK]      ),
            .sel     (TB_dinb_sel     ),
            .din_0   (C_TB_dinb_0[RSA_DW*i_X +: RSA_DW]   ),
            .din_1   (C_TB_dinb_1[RSA_DW*(X-i_X) +: RSA_DW]   ),
            .dout    (dout    )
        );

        regdeMUX_sel1 
        #(
            .RSA_DW (RSA_DW )
        )
        TB_doutb_regdeMUX_sel1(
        	.clk     (clk     ),
            .sys_rst (sys_rst ),
            .en      (TB_enb[i_BANK]       ),
            .sel     (TB_doutb_sel     ),
            .din     (TB_doutb[i_BANK*RSA_DW +: RSA_DW]     ),
            .dout_0  (B_TB_doutb[i_BANK*RSA_DW +: RSA_DW]  ),
            .dout_1  (B_CONS_din[i_BANK*RSA_DW +: RSA_DW]   )
        );
        
        COV_BANK CB (
            .clka(clk),    // input wire clka
            .rsta(sys_rst), 
            .ena(CB_ena[i_BANK]),      // input wire ena
            .wea(CB_wea[i_BANK]),      // input wire [0 : 0] wea
            .addra(CB_addra[i_BANK*CB_AW +: CB_AW]),  // input wire [18 : 0] addra
            .dina(init_CB_dina[i_BANK*RSA_DW +: RSA_DW]),    // input wire [15 : 0] dina
            .douta(CB_douta[i_BANK*RSA_DW +: RSA_DW]),  // output wire [15 : 0] douta
            .clkb(clk),    // input wire clkb
            .rstb(rstb), 
            .enb(CB_enb[i_BANK]),      // input wire enb
            .web(CB_web[i_BANK]),      // input wire [0 : 0] web
            .addrb(CB_addrb[i_BANK*CB_AW +: CB_AW]),  // input wire [18 : 0] addrb
            .dinb(CB_dinb[i_BANK*RSA_DW +: RSA_DW]),    // input wire [15 : 0] dinb
            .doutb(CB_doutb[i_BANK*RSA_DW +: RSA_DW])  // output wire [15 : 0] doutb
        );

        regdeMUX_sel1 
        #(
            .RSA_DW (RSA_DW )
        )
        CB_douta_regdeMUX_sel1(
        	.clk     (clk     ),
            .sys_rst (sys_rst ),
            .en      (CB_ena[i_BANK]       ),
            .sel     (CB_douta_sel     ),
            .din     (CB_douta[i_BANK*RSA_DW +: RSA_DW]     ),
            .dout_0  (A_CB_douta[i_BANK*RSA_DW +: RSA_DW]  ),
            .dout_1  (B_CB_douta[i_BANK*RSA_DW +: RSA_DW]   )
        );

        regMUX_sel1 
        #(
            .RSA_DW (RSA_DW )
        )
        CB_dinb_regMUX_sel1(
        	.clk     (clk     ),
            .sys_rst (sys_rst ),
            .en      (CB_enb[i_BANK]      ),
            .sel     (CB_dinb_sel     ),
            .din_0   (C_CB_dinb_0[RSA_DW*i_X +: RSA_DW]   ),
            .din_1   (C_CB_dinb_1[RSA_DW*(X-i_X) +: RSA_DW]   ),
            .dout    (dout    )
        );

        regdeMUX_sel1 
        #(
            .RSA_DW (RSA_DW )
        )
        CB_doutB_regdeMUX_sel1(
        	.clk     (clk     ),
            .sys_rst (sys_rst ),
            .en      (CB_enb[i_BANK]       ),
            .sel     (CB_doutb_sel     ),
            .din     (CB_doutb[i_BANK*RSA_DW +: RSA_DW]     ),
            .dout_0  (M_CB_doutb_0[i_BANK*RSA_DW +: RSA_DW]  ),
            .dout_1  (M_CB_doutb_1[i_BANK*RSA_DW +: RSA_DW]   )
        );
    end
endgenerate

endmodule