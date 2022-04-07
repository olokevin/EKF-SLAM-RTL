module PE_MAC 
#(
    parameter RSA_DW = 16
)
(
    input       clk                        ,
    input       sys_rst                  ,
    
    input       cal_en                     ,
    input       cal_done                   ,    

    input           [RSA_DW-1:0]  westin,
    input           [RSA_DW-1:0]  southin,

    input                         din_val,
    input           [RSA_DW-1:0] din,

    output   reg                   n_cal_en,
    output   reg                   n_cal_done,

    output   reg    [RSA_DW-1:0]  eastout,
    output   reg    [RSA_DW-1:0]  northout,
    output   reg                   dout_val,
    output   reg    [RSA_DW-1:0]  dout
);

    reg [RSA_DW-1:0] product;
    reg [RSA_DW-1:0] partial_sum;

    //下一模块的cal_en: n_cal_en
    always @(posedge clk) begin
        if(sys_rst)  begin
            n_cal_en <= 0;
        end
        else  begin
            n_cal_en <= cal_en;
        end
    end

    always @(posedge clk) begin
        if(sys_rst)  begin
            n_cal_done <= 0;
        end
        else  begin
            n_cal_done <= cal_done;
        end
    end

    //multiply
    always @(posedge clk) begin
        if(sys_rst)
            product <= 0;
        else if(cal_en == 1'b1)
            product <= westin * southin;
        else
            product <= 0;        
    end

    //add on partial sum
    always @(posedge clk) begin
        if(sys_rst)  begin
            partial_sum <= 0; 
        end
        else if(cal_en == 1'b1 && cal_done != 1'b1)
            partial_sum <= partial_sum + product;
        else 
            partial_sum <= 0; 
    end

    //dout 乘积+求和 传递din
    always @(posedge clk) begin
        if(sys_rst)  begin
            dout <= 0; 
        end
        else if(cal_done == 1'b1)
            dout <= partial_sum + product;
        else if(din_val == 1'b1)
            dout <= din;
        else 
            dout <= 0; 
    end

    //dout_val 输出有效
    always @(posedge clk) begin
        if(sys_rst)  begin
            dout_val <= 1'b0;
        end
        else if(cal_done == 1'b1 || din_val == 1) begin
            dout_val <= 1'b1;
        end
        else
            dout_val <= 1'b0;
    end

    //eastout 行数据复用
    always @(posedge clk) begin
        if(sys_rst)  begin
            eastout <= 0;
        end
        else if(cal_en == 1'b1) begin
            eastout <= westin;
        end
        else
            eastout <= 0;
    end

    //northout 列数据复用
    always @(posedge clk) begin
        if(sys_rst)  begin
            northout <= 0;
        end
        else if(cal_en == 1'b1) begin
            northout <= southin;
        end
        else
            northout <= 0;
    end
endmodule