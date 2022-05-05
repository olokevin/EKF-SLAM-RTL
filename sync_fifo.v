module sync_fifo
#(
    parameter RSA_DW = 8,
    parameter DEPTH = 8,
    parameter ADDR_WIDTH = 3        //2^ADDR_WIDTH >=     
) 
(
    input   clk                           ,
    input   sys_rst_n                     ,
    input   wr_en                         ,
    input   rd_en                         ,
    input        [RSA_DW-1:0]   data_in      ,

    output  reg  [RSA_DW-1:0]   data_out,
    // output  reg     n_rd_en               ,
    output  reg     empty                 ,
    output  reg     full

);

    reg [ADDR_WIDTH-1:0] wr_addr ;
    reg [ADDR_WIDTH-1:0] rd_addr ; 

    reg [RSA_DW-1:0] fifo [0:DEPTH-1] ; // 定义�?个二维的RAM

    // //n_rd_en
    // always @(posedge clk or negedge sys_rst_n) begin
    //     if(!sys_rst_n)
    //         n_rd_en <= 0;
    //     else 
    //         n_rd_en <= rd_en;
    // end

    //读操作
    always @(posedge clk or negedge sys_rst_n) begin
        if(!sys_rst_n)  begin
            data_out <= 0;
        end
        else if(rd_en && empty == 0)begin
            data_out <= fifo[rd_addr]; 
        end
        else
            data_out <= 0;
    end

    //写操作
    integer i_wr_addr;
    always @(posedge clk or negedge sys_rst_n) begin
        if(!sys_rst_n)  begin
            for(i_wr_addr=0; i_wr_addr<DEPTH; i_wr_addr=i_wr_addr+1) begin
                fifo[i_wr_addr] <= 0;
            end
        end
        else if(wr_en && full == 0)  begin
            fifo[wr_addr] <= data_in;
        end
    end

    //更新读地址
    always @(posedge clk or negedge sys_rst_n) begin
        if(!sys_rst_n)  begin
            rd_addr <= 0;
        end
        else if(rd_en && empty == 0) begin
            rd_addr <= rd_addr + 1'b1;
        end
    end

    //更新写地址
    always @(posedge clk or negedge sys_rst_n) begin
        if(!sys_rst_n)  begin
            wr_addr <= 0;
        end
        else if(wr_en && full == 0) begin
            wr_addr <= wr_addr + 1'b1;
        end
    end

    //更新标志�?
    /*每个时钟周期
        wr_en   rd_en   cnt
        0       0       不变
        0       1       cnt-1
        1       0       cnt+1
        1       1       不变

        cnt==0        ->  empty = 1
        cnt==DEPTH-1  ->  full = 1

        cnt==1 {01} cnt==0 -> empty==1
        cnt==0

        cnt==DEPTH-2 {10} ->  full==1
    */
    reg [ADDR_WIDTH:0] count ;
    always @(posedge clk or negedge sys_rst_n) begin
        if(!sys_rst_n)
            count <= 0;
        else begin
            case({wr_en,rd_en})
            2'b00: count <= count;
            2'b01: 
                if(count!==0)
                    count <= count - 1;
            2'b10:
                if(count!==DEPTH)
                    count <= count + 1;
            2'b11:
                count <= count;
            endcase
        end        
    end

    always @(count) begin
        if(count == 0)
            empty = 1;
        else
            empty = 0;
    end

    always @(count) begin
        if(count == DEPTH)
            full = 1;
        else
            full = 0;
    end

endmodule