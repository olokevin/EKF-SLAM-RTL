//sync fifo without empty and full sign
module sync_fifo
#(
    parameter RSA_DW = 8,
    parameter DEPTH = 8,
    parameter ADDR_WIDTH = 3        //2^ADDR_WIDTH >=     
) 
(
    input   clk                           ,
    input   sys_rst                    ,
    input   wr_en                         ,
    input   rd_en                         ,
    input        [RSA_DW-1:0]   data_in      ,

    output  reg  [RSA_DW-1:0]   data_out

);
    reg [ADDR_WIDTH-1:0] wr_addr ;
    reg [ADDR_WIDTH-1:0] rd_addr ; 

    reg [RSA_DW-1:0] fifo [0:DEPTH-1] ; // 定义�?个二维的RAM

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
    always @(posedge clk) begin
        if(sys_rst)
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

    reg empty, full;
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

    //read and write
    always @(posedge clk) begin
        if(sys_rst)  begin
            data_out <= {RSA_DW{1'b0}};
        end
        case({wr_en,rd_en}) 
            2'b01:  begin
                if(empty==1'b0)
                    data_out <= fifo[rd_addr]; 
            end
            2'b10: begin
                if(full==1'b0) begin
                    fifo[wr_addr] <= data_in;
                    data_out <= 0;
                end   
            end
            2'b11: begin
                if(empty==1'b1)     //透传
                    data_out <= data_in;
                else
                    data_out <= fifo[rd_addr]; 
            end
            default: data_out <= 0;
        endcase
    end    
        // else if(rd_en == 1'b1) begin
        //     if(wr_en == 1'b1 && wr_addr == rd_addr)
        //         data_out <= data_in; 
        //     else
        //         data_out <= fifo[rd_addr]; 
        // end

    //写操�?
    // integer i_wr_addr;
    // always @(posedge clk) begin
    //     if(sys_rst)  begin
    //         for(i_wr_addr=0; i_wr_addr<DEPTH; i_wr_addr=i_wr_addr+1) begin
    //             fifo[i_wr_addr] <= {RSA_DW{1'b0}};
    //         end
    //     end
    //     else if(wr_en)  begin
    //         fifo[wr_addr] <= data_in;
    //     end
    // end

    //更新读地�?
    always @(posedge clk) begin
        if(sys_rst)  begin
            rd_addr <= {ADDR_WIDTH{1'b0}};
        end
        else if(rd_en && empty == 0) begin
            rd_addr <= rd_addr + 1'b1;
        end
    end

    //更新写地
    always @(posedge clk) begin
        if(sys_rst)  begin
            wr_addr <= {ADDR_WIDTH{1'b0}};
        end
        else if(wr_en && full == 0) begin
            wr_addr <= wr_addr + 1'b1;
        end
    end

endmodule