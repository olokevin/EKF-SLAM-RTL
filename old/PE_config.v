module PE_config #(
    parameter X = 3,
    parameter N = 4,
    parameter Y = 3 
) 
(
    input   clk,
    input   sys_rst_n,

    input   SA_start,      //阵列启动信号


    output  reg      cal_en,
    output  reg      cal_done,
    // output  reg      in_wr_en,      
    output  reg      westin_rd_en,  //输入，与N有关 westin和northin都是存N个数据
    output  reg      northin_rd_en
);
    reg     SA_work;
    reg     [N-1:0]         sum_cnt; 

    //SA_work
    always @(posedge clk or negedge sys_rst_n) begin
        if(!sys_rst_n)
            SA_work <= 1'b0;    
        else if(SA_start == 1'b1)
            SA_work <= 1'b1;
        else if(sum_cnt == N)
            SA_work <= 1'b0;
        else
            SA_work <= SA_work;
    end

    //计数器
    always @(posedge clk or negedge sys_rst_n) begin
        if(!sys_rst_n)
            sum_cnt <= 0;     
        else if(SA_work == 1'b1)    
            sum_cnt <= sum_cnt + 1'b1;
        else
            sum_cnt <= 0;  
    end

    //westin_rd_en
    always @(posedge clk or negedge sys_rst_n) begin
        if(!sys_rst_n)
            westin_rd_en <= 0;
        else if(SA_work == 1'b1 && sum_cnt < N)
            westin_rd_en <= 1'b1;
        else
            westin_rd_en <= 1'b0;
    end

    //northin_rd_en
    always @(posedge clk or negedge sys_rst_n) begin
        if(!sys_rst_n)
            northin_rd_en <= 0;
        else if(SA_work == 1'b1 && sum_cnt < N)
            northin_rd_en <= 1'b1;
        else
            northin_rd_en <= 1'b0;
    end
    
    //cal_en
    always @(posedge clk or negedge sys_rst_n) begin
        if(!sys_rst_n)
            cal_en <= 0;
        else if(sum_cnt >= 1 && sum_cnt <= N)
            cal_en <= 1'b1;
        else
            cal_en <= 1'b0;
    end

    //cal_done
    always @(posedge clk or negedge sys_rst_n) begin
        if(!sys_rst_n)
            cal_done <= 0;
        // else if(sum_cnt == N)       //提前一个时钟
        //     cal_done <= 1'b1;
        else if(sum_cnt == N+1)       //不提前
            cal_done <= 1'b1;
        else
            cal_done <= 1'b0;     
    end
endmodule