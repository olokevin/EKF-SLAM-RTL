`timescale 1ns/1ps

module tb_RSA;

// RSA Parameters
parameter PERIOD      = 10;
parameter M           = 8;
parameter N           = 4;
parameter K           = 2;

parameter X           = 3;
parameter Y           = 3;
parameter IN_LEN      = 8;
parameter OUT_LEN     = 8;
parameter ADDR_WIDTH  = 2;

parameter RESET_LEN = 5;

// RSA Inputs
reg   clk                                  = 1 ;
reg   sys_rst                              = 1 ;
reg   init_val = 0;
reg   [IN_LEN:1] init_data = 0;

reg   Xin_val                              = 0 ;
reg   [IN_LEN:1]  Xin_data                 = 0 ;
reg   Yin_val                              = 0 ;
reg   [IN_LEN:1]  Yin_data                 = 0 ;
reg     out_rdy     =  1;

// RSA Outputs
wire init_rdy;
wire Xin_rdy;
wire Yin_rdy;
wire out_val;
wire  [OUT_LEN:1]  out_data                ;


initial
begin
    forever #(PERIOD/2)  clk=~clk;
end

//读取文件
integer  Xin_fd, Xin_err, code, i;
reg [320:0] Xin_str;
initial begin
    Xin_fd = $fopen("data/Xin_data.HEX", "r");
    Xin_err = $ferror(Xin_fd, Xin_str);
end

integer  Yin_fd, Yin_err, j;
reg [320:0] Yin_str;
initial begin
    Yin_fd = $fopen("data/Yin_data.HEX", "r");
    Yin_err = $ferror(Yin_fd, Yin_str);
end

integer  init_fd, init_err, init_i;
reg [320:0] init_str;
initial begin
    init_fd = $fopen("data/init_data.HEX", "r");
    init_err = $ferror(init_fd, init_str);
end

initial begin
    #(PERIOD*RESET_LEN) 
        sys_rst  =  0;
    #(PERIOD*2) 
        init_val <= 1;      //非阻塞赋值，这样才符合真实信号。否则改时钟上升沿内部即可识别为init_val = 1
        if(!init_err) begin
        for(init_i=0; init_i<4; init_i=init_i+1) begin
            @(posedge clk);         //在每个时钟上升沿读取数据
            code = $fscanf(init_fd,"%h",init_data);
            // $display("Xin_data%d: %h", i, Xin_data) ;
        end
    end
    @(posedge clk) init_val <= 0;
end

initial begin
    #(PERIOD*(RESET_LEN+8)) Xin_val <= 1;
    if(!Xin_err) begin
        for(i=0; i<M*N; i=i+1) begin
            @(posedge clk);         //在每个时钟上升沿读取数据
            code = $fscanf(Xin_fd,"%h",Xin_data);
            // $display("Xin_data%d: %h", i, Xin_data) ;
        end
    end
    @(posedge clk); Xin_val <= 0;
    // #(PERIOD*(M*N)) Xin_val = 0;
end

initial begin
    #(PERIOD*(RESET_LEN+8)) Yin_val <= 1;
    if(!Yin_err) begin
        for(j=0; j<K*N; j=j+1) begin
            @(posedge clk);         //在每个时钟上升沿读取数据
            code = $fscanf(Yin_fd,"%h",Yin_data);
            // $display("Xin_data%d: %h", i, Xin_data) ;
        end
    end
    @(posedge clk); Yin_val <= 0;
    // #(PERIOD*(K*N)) Yin_val <= 0;
end

// RSA #(
//     .X          ( X          ),
//     .N          ( N          ),
//     .Y          ( Y          ),
//     .IN_LEN     ( IN_LEN     ),
//     .OUT_LEN    ( OUT_LEN    ),
//     .ADDR_WIDTH ( ADDR_WIDTH ))
//  u_RSA (
//     .clk                     ( clk                    ),
//     .sys_rst                 ( sys_rst              ),
//     // .SA_start                ( SA_start               ),
//     .Xin_val                 ( Xin_val                ),
//     .Xin_data                ( Xin_data   [IN_LEN:1]  ),
//     .Yin_val                 ( Yin_val                ),
//     .Yin_data                ( Yin_data   [IN_LEN:1]  ),
//     .out_val                 ( out_val                ),
//     .out_data                ( out_data   [OUT_LEN:1] )
// );

RSA 
#(
    .X          (X          ),
    .N          (N          ),
    .Y          (Y          ),
    .IN_LEN     (IN_LEN     ),
    .OUT_LEN    (OUT_LEN    ),
    .ADDR_WIDTH (ADDR_WIDTH )
)
u_RSA(
    .clk       (clk       ),
    .sys_rst   (sys_rst   ),
    .init_val  (init_val  ),
    .init_data (init_data ),
    .init_rdy  (init_rdy  ),
    .Xin_val   (Xin_val   ),
    .Xin_data  (Xin_data  ),
    .Xin_rdy   (Xin_rdy   ),
    .Yin_val   (Yin_val   ),
    .Yin_data  (Yin_data  ),
    .Yin_rdy   (Yin_rdy   ),
    .out_rdy   (out_rdy   ),
    .out_val   (out_val   ),
    .out_data  (out_data  )
);


endmodule
