module PE_config 
#(
    parameter X = 3,
    parameter N = 3,
    parameter Y = 3,

    parameter IN_LEN = 8,
    parameter OUT_LEN = 8,
    parameter ADDR_WIDTH = 2
) 
(
    input   clk,
    input   sys_rst,

    //initialize handshake
    input   init_val,
    input   [IN_LEN:1]  init_data,
    output  reg init_rdy,

    //data input handshake
    output  reg Xin_rdy,
    output  reg Yin_rdy,
    input   Xin_val,
    input   Yin_val,

    //data output handshake
    input   out_rdy,
    output  reg out_val,

    //input->in_fifo
    output  reg [X:1]   westin_wr_en,       //e_westin_wr_en[0]为冗余位，初值位1，用于左移
    output  reg [Y:1]   northin_wr_en,
    //in_fifo->PEs
    output  reg [X:1]     westin_rd_en,  //输入，与N有关 westin和northin都是存N个数据
    output  reg [Y:1]     northin_rd_en,
    //PE calculation enable
    output  reg         cal_en,
    output  reg         cal_done,   
        // output           cal_en,
        // output           cal_done, 
    //out_fifo->output
    output  reg [X:1]   out_rd_en
);

parameter m_ADDR = 2'b00;
parameter n_ADDR = 2'b01;
parameter k_ADDR = 2'b10;
parameter mode_ADDR = 2'b11;

parameter MODE_0 = 2'b00;   //m<X n<Y
parameter MODE_1 = 2'b01;   //m>=X n<Y

//dalay of init_val, Xin_val, Yin_val, out_val, to judge the posedge and negedge
    reg init_val_d;
    always @(posedge clk) begin
        if(sys_rst)
            init_val_d <= 0;
        else 
            init_val_d <= init_val;    
    end

    reg Xin_val_d;  
    always @(posedge clk) begin
        if(sys_rst)
            Xin_val_d <= 0;
        else 
            Xin_val_d <= Xin_val;
    end

    reg Yin_val_d;
    always @(posedge clk) begin
        if(sys_rst)
            Yin_val_d <= 0;
        else 
            Yin_val_d <= Yin_val;
    end

    reg out_val_d;
    always @(posedge clk) begin
        if(sys_rst)
            out_val_d <= 0;
        else 
            out_val_d <= out_val;
    end

//generation of init_rdy
    always @(posedge clk) begin
        if(sys_rst)
            init_rdy <= 1'b1;
        else if({init_rdy,init_val_d,init_val}==3'b110)     //negedge of init_val, init data transfer ends
            init_rdy <= 0;
        else if({init_rdy,out_val_d,out_val}==3'b010)       //negedge of out_val, out data transfer ends
            init_rdy <= 1'b1;     
        else
            init_rdy <= init_rdy;
    end

//save RSA_args: m n k mode
    reg [IN_LEN:1]  RSA_args    [0:3];              //RSA_args: 0:m 1:n 2:k 3:mode
    reg [1:0]   RSA_args_addr;
    // reg [IN_LEN:1]  m,n,k;
    reg [IN_LEN:1] m;
    reg [IN_LEN:1] n;
    reg [IN_LEN:1] k;
    reg [1:0] mode;
    always @(posedge clk) begin
        if(sys_rst)
            RSA_args_addr <= 0;
        else if({init_rdy,init_val} == 2'b11) begin       //handshake available
            RSA_args[RSA_args_addr] <= init_data;
            RSA_args_addr <= RSA_args_addr + 1'b1;
        end    
    end

    always @(posedge clk) begin
        if(init_val_d == 1'b1) begin
            // m <= RSA_args[0];
            n <= RSA_args[1];
            k <= RSA_args[2];
            // mode <= RSA_args[3][2:1];   
        end
    end

//generate Xin_rdy,Yin_rdy
    always @(posedge clk) begin
        if(sys_rst) begin
            Xin_rdy <= 0;
            Yin_rdy <= 0;
        end
        else if({init_val_d, init_val} == 2'b10) begin
            Xin_rdy <= 1'b1;
            Yin_rdy <= 1'b1;
        end
    end

//Xin
    //westin_n_cnt: determine when to shift westin_wr_en
    //bit numbers: to be determined after X,Y is determined
    reg [N-1:0] westin_n_cnt;
    always @(posedge clk) begin
        if(sys_rst) begin
            westin_n_cnt <= 0; 
        end    
        //Xin上升沿，即使能westin_fifo[1]
        else if({Xin_val_d,Xin_val} == 2'b01) begin
            westin_n_cnt <= 1'b1;    
        end    
        //计数
        else if(Xin_val == 1'b1 && westin_n_cnt < n)    
            westin_n_cnt <= westin_n_cnt + 1'b1;
        //移位
        else if(Xin_val == 1'b1 && westin_n_cnt == n) begin
            westin_n_cnt <= 1'b1;
        end     
        else begin
            westin_n_cnt <= 0; 
        end  
    end

    //westin_m_cnt: determine when to shift back westin_wr_en
    //reg [N-1:0] westin_m_cnt;
    // always @(posedge clk) begin
    //     if(sys_rst)
    //         westin_m_cnt <= 0;
    //     else if(Xin_val == 1'b1 && westin_n_cnt == n-1) begin
    //         if((mode == MODE_0 && westin_m_cnt == m) || (mode == MODE_1 && westin_m_cnt == X))
    //             westin_m_cnt <= 1'b1;
    //         else
    //             westin_m_cnt <= westin_m_cnt + 1'b1;
    //     end
    //     else begin
    //         westin_m_cnt <= 0;
    //     end 
    // end

    always @(posedge clk) begin
        if(sys_rst)
            m <= 0;
        else begin
            case({Xin_val_d,Xin_val})
                2'b00: m <= 0;
                2'b01: m <= RSA_args[m_ADDR];
                2'b11: begin
                    if(westin_n_cnt == n && m >= X) begin
                        m <= m - 1'b1;
                    end
                    else
                        m <= m;
                end
                2'b10: m <= 0;
            endcase
        end       
    end

    always @(posedge clk) begin
        if(sys_rst)
            mode <= 0;
        else begin
            case({Xin_val_d,Xin_val})
                2'b00: mode <= 0;
                2'b01: mode <= RSA_args[mode_ADDR];
                2'b11: begin
                    if(mode == MODE_1 && m < X) begin
                        mode <= MODE_0;
                    end
                    else
                        mode <= mode;
                end
                2'b10: mode <= 0;
            endcase
        end       
    end

    //westin_wr_en. Only when m>X needs to roll back
    always @(posedge clk) begin
        if(sys_rst)
            westin_wr_en <= 0;
        else begin
            case({Xin_val_d,Xin_val})
                2'b00: westin_wr_en <= 0;
                2'b01: westin_wr_en <= 1'b1;
                2'b11: begin
                    if(westin_n_cnt == n) begin
                        westin_wr_en <= {westin_wr_en[X-1:1],westin_wr_en[X]};
                    end
                    else
                        westin_wr_en <= westin_wr_en;
                end
                2'b10: westin_wr_en <= 0;
            endcase
        end       
    end

//Yin 按列写入
    reg [Y:1]   northin_k_cnt;
    // reg [Y:1]   northin_n_cnt;   //if mode_2: k>Y, thus needed
    //northin_k_cnt: determine when to shift back northin_wr_en
    always @(posedge clk) begin
        if(sys_rst)
            northin_k_cnt <= 0;
        else if(Yin_val && northin_k_cnt < k) begin
            northin_k_cnt <= northin_k_cnt + 1'b1;
        end
        else if(Yin_val && northin_k_cnt == k) begin
            northin_k_cnt <= 1'b1;
        end
    end

    always @(posedge clk) begin
        if(sys_rst)
            northin_wr_en <= 0;
        else if({Yin_val_d,Yin_val} == 2'b01) begin
            northin_wr_en <= 1'b1;
        end
        else if(Yin_val && northin_k_cnt < k) begin
            northin_wr_en <= {northin_wr_en[Y-1:1] , northin_wr_en[Y]};
        end
        else if(Yin_val && northin_k_cnt == k) begin
            northin_wr_en <= 1'b1;
        end
        else
            northin_wr_en <= 0;   
    end

    // reg [N-1:0] Yin_cnt;
    // always @(posedge clk) begin
    //     if(sys_rst) begin
    //         Yin_cnt <= 0; 
    //         northin_wr_en <= 0;
    //     end    
    //     //Yin_val 第一列使能
    //     else if({Yin_val,Yin_val_d} == 2'b10) begin
    //         Yin_cnt <= 0; 
    //         northin_wr_en <= 1'b1;
    //     end    
    //     //计数
    //     else if(Yin_val == 1'b1 && Yin_cnt < N*Y) begin
    //         Yin_cnt <= Yin_cnt + 1'b1;
    //         northin_wr_en <= {northin_wr_en[Y-1:1] , northin_wr_en[Y]};
    //     end     
    //     else begin
    //         Yin_cnt <= 0; 
    //         northin_wr_en <= 0;
    //     end  
    // end

//westin.rd_en
    // reg [N*(X-1):1]   westin_delay_en_delay;
    // always @(posedge clk) begin
    //     if(sys_rst)
    //         westin_delay_en_delay <= 0;
    //     else 
    //         westin_delay_en_delay <= {westin_delay_en_delay[N*(X-1)-1:1],Xin_val};
    // end

    // reg westin_delay_en;    //生成第一个westin_rd_en
    // reg westin_delay_X_en;  //生成2~X后续westin_rd_en
    // always @(posedge clk) begin
    //     if(sys_rst)
    //         westin_delay_en <= 0;
    //     else begin
    //         westin_delay_en <= Xin_val | westin_delay_en_delay[N*(X-1)];
    //         westin_delay_X_en <= Xin_val | westin_delay_en_delay[N];
    //     end   
    // end

//west，north可以开始读出：(n-1)*(row-1)+1
    //(n-1)*(row-1)级延迟
    reg [(N-1)*(X-1):0]  dchain_westin_rd_en;
    always @(posedge clk) begin
        if(sys_rst)
            dchain_westin_rd_en <= 0;
        else
            dchain_westin_rd_en <= {dchain_westin_rd_en[(N-1)*(X-1)-2:0],westin_wr_en[1]};
        // else if(westin_delay_X_en == 1'b1)
        //     dchain_westin_rd_en <= {dchain_westin_rd_en[N*(X-1)-1:1],westin_wr_en[1]};
        // else
        //     dchain_westin_rd_en <= 0;
    end

    reg [IN_LEN:1] bit_westin_rd_en;
    always @(posedge clk) begin
        if(sys_rst)
            bit_westin_rd_en <= 0;
        else if(Xin_val_d == 1'b1 && mode == MODE_1) begin
            bit_westin_rd_en <= (n-1)*(X-1)-1'b1;
        end
        else if(Xin_val_d == 1'b1 && mode == MODE_0) begin
            bit_westin_rd_en <= (n-1)*(m-1)-1'b1;
        end
        else
            bit_westin_rd_en <= 0;
    end

    reg [X:1] row_en;
    always @(posedge clk) begin
        if(sys_rst)
            row_en <= 0;
        else if(mode == MODE_0) begin
            case(m)
                1: row_en <= 'b001;
                2: row_en <= 'b011;
                3: row_en <= 'b111;
                default: row_en <= 0;
            endcase
        end
        else if(mode == MODE_1) begin
            row_en <= 'b111;
        end
        else
            row_en <= 0;
            
    end

    always @(posedge clk) begin
        if(sys_rst)
            westin_rd_en <= 0;
        else
            westin_rd_en <= ({westin_rd_en[X-1:1],dchain_westin_rd_en[bit_westin_rd_en-:1]}) & row_en;
        // else if(mode == MODE_0)
        //     westin_rd_en <= {westin_rd_en[]}
        // else if(mode == MODE_1)
        //     westin_rd_en <= {westin_rd_en[X-1:1],dchain_westin_rd_en[bit_westin_rd_en-:1]};

        // else if(westin_delay_en == 1'b1) begin
        //     westin_rd_en <= {westin_rd_en[X-1:1],dchain_westin_rd_en[N*(X-1)]};
        // end
        // else
        //     westin_rd_en <= 0;
    end

//northin.rd_en
    // reg [N:1]   northin_delay_en_delay;
    // always @(posedge clk) begin
    //     if(sys_rst)
    //         northin_delay_en_delay <= 0;
    //     else 
    //         northin_delay_en_delay <= {northin_delay_en_delay[N-1:1],Yin_val};
    // end

    // reg northin_delay_en;
    // always @(posedge clk) begin
    //     if(sys_rst)
    //         northin_delay_en <= 0;
    //     else 
    //         northin_delay_en <= Yin_val | northin_delay_en_delay[N];
    // end

//Y always < Y
    reg [X:1] column_en;
    always @(posedge clk) begin
        if(sys_rst)
            column_en <= 0;
        else begin
            case(n)
                1: column_en <= 'b001;
                2: column_en <= 'b011;
                3: column_en <= 'b111;
                default: column_en <= 0;
            endcase
        end
    end

    always @(posedge clk) begin
        if(sys_rst)
            northin_rd_en <= 0;
        else
            northin_rd_en <= ({northin_rd_en[Y-1:1],dchain_westin_rd_en[bit_westin_rd_en-:1]}) & column_en;
        // else if(westin_delay_en == 1'b1) begin
        //     northin_rd_en <= {northin_rd_en[Y-1:1],dchain_westin_rd_en[N*(X-1)]};
        // end
        // else   
        //     northin_rd_en <= 0;
    end

    //cal_en
    // assign cal_en = westin_rd_en[2];
    always @(posedge clk) begin
        if(sys_rst) begin
            cal_en <= 0;
        end
        else begin
            cal_en <= westin_rd_en[1];
        end            
    end

    //cal_done
    // assign cal_done = ({westin_rd_en[3],westin_rd_en[2]} == 2'b10) ? 1'b1 : 1'b0;
    always @(posedge clk) begin
        if(sys_rst)
            cal_done <= 1'b0;
        else if({cal_en,westin_rd_en[1]} == 2'b10)
            cal_done <= 1'b1;
        else
            cal_done <= 1'b0;
    end

    //out: 
    reg [N+Y:0] cal_delay;
    always @(posedge clk) begin
        if(sys_rst)
            cal_delay <= 0;
        else begin
            cal_delay <= {cal_delay[N+Y-1:1],westin_rd_en[1]};
        end   
    end

    //out_rd_en[1]总计n+k+2级延迟
    always @(posedge clk) begin
        if(sys_rst)
            out_rd_en[1] <= 1'b0;
        else      
            out_rd_en[1] <= cal_delay[N+Y];  
    end

    genvar i_delay;
    generate
        for(i_delay=2; i_delay<=X; i_delay=i_delay+1) begin:out_rd_en_gen
            reg [N-1:1] out_rd_en_delay;
            always @(posedge clk) begin
                if(sys_rst)
                    out_rd_en_delay <= 0;
                else begin
                    out_rd_en_delay <= {out_rd_en_delay[N-2:1],out_rd_en[i_delay-1]};
                end     
            end

            always @(posedge clk) begin
                if(sys_rst)
                    out_rd_en[i_delay] <= 0;
                else begin
                    out_rd_en[i_delay] <= out_rd_en_delay[N-1];
                end
            end
        end
    endgenerate

    //输出有效
always @(posedge clk) begin
    if(sys_rst)
        out_val <= 1'b0;
    else if(out_rd_en != {X{1'b0}})
        out_val <= 1'b1;
    else
        out_val <= 1'b0;
end
    
//using outside out_rdy
    // reg out_val_r;
    // reg [Y-1:0] out_cnt;
    // always @(posedge clk) begin
    //     if(sys_rst) begin
    //         out_cnt <= 0; 
    //         out_rd_en <= 0;
    //     end    
    //     //Yin
    //     else if({out_val,out_val_r} == 2'b10) begin
    //         out_cnt <= 0; 
    //         out_rd_en <= 1'b1;
    //     end    
    //     //计数
    //     else if(out_val == 1'b1 && out_cnt < Y-1)    
    //         out_cnt <= out_cnt + 1'b1;
    //     else if(out_val == 1'b1 && out_cnt == Y-1) begin
    //         out_cnt <= 0;
    //         out_rd_en <= {out_rd_en[X-1:1] , out_rd_en[X]};
    //     end     
    //     else begin
    //         out_cnt <= 0; 
    //         out_rd_en <= 0;
    //     end  
    // end
    

endmodule