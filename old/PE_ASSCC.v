module PE_ASSCC 
#(
    parameter IN_LEN = 8,
    parameter OUT_LEN = 8
)
(
    input       clk                        ,
    input       sys_rst_n                  ,
    
    input       pe_en                      ,
    input       mode                       ,
    input       bypass                     ,

    input           [IN_LEN-1:0]  westin1,
    input           [IN_LEN-1:0]  westin2,
    input           [IN_LEN-1:0]  northin,

    output   reg    [OUT_LEN-1:0]  eastout,
    output   reg    [OUT_LEN-1:0]  southout
);

reg [OUT_LEN-1:0] multiplicand;
reg [OUT_LEN-1:0] eastout_buf;
reg [OUT_LEN-1:0] southout_buf;

//乘法器
always @(posedge clk or negedge sys_rst_n) begin
    if(!sys_rst_n)  begin
        multiplicand <= 0;
    end
    else begin
        if(pe_en == 1) begin
            if(mode == 0) begin
                multiplicand <= westin2 * northin;
            end
            else begin
                multiplicand <= westin2 * westin1;
            end
        end
    end
end

//eastout buffer
always @(posedge clk or negedge sys_rst_n) begin
    if(!sys_rst_n)  begin
        eastout_buf <= 0;
    end
    else begin
        if(pe_en == 1) begin
            if(mode == 0) begin
                eastout_buf <= multiplicand + westin1;
            end
            else begin
                eastout_buf <= westin1;
            end
        end
    end
end

//southout buffer
always @(posedge clk or negedge sys_rst_n) begin
    if(!sys_rst_n)  begin
        southout_buf <= 0;
    end
    else begin
        if(pe_en == 1) begin
            if(mode == 0) begin
                southout_buf <= northin;
            end
            else begin
                southout_buf <= multiplicand + northin;
            end
        end
    end
end

endmodule