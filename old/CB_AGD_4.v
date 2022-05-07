module CB_AGD 
#(
    parameter CB_AW = 19,

    parameter SEQ_CNT_DW = 500,
    parameter GROUP_LEN    = 16
)
(
    input clk,
    input sys_rst,

    input [GROUP_LEN-1 : 0]  CB_row,
    input [GROUP_LEN-1 : 0]  CB_col,

    output reg [CB_AW-1 : 0] CB_addr
);

reg [GROUP_LEN-4 : 0] k;       //组号
reg [GROUP_LEN-4 : 0] k_r1;
reg [GROUP_LEN-4 : 0] k_r2;

reg [2 : 0]  index;
reg [2 : 0]  index_r1;
reg [2 : 0]  index_r2;

reg [CB_AW-1 : 0] group_base_t;   //组起始位置
reg [CB_AW-1 : 0] group_base;     //组起始位置
reg [GROUP_LEN-1  : 0]  group_offset_t; //组偏移量
reg [GROUP_LEN-1  : 0]  group_offset;   //组偏移量

/*
    0: k <= CB_row >> 3;
       index <= CB_row[2:0];
    1: group_base_t <= k*k;
       group_offset_t <= 0 / (k<<3) --index
    2: group_base   <= group_base_t + k;
       group_offset -- index
    3: CB_addr <= group_base + group_offset_t;
*/
    always @(posedge clk) begin
        if(sys_rst) begin
            k <= 0;
            k_r2 <= 0;
            k_r1 <= 0;
        end      
        else begin
            k_r2 <= k_r1;
            k_r1 <= k;
            k <= CB_row >> 3;
        end      
    end

    always @(posedge clk) begin
        if(sys_rst) begin
            index <= 0;
            index_r2 <= 0;
            index_r1 <= 0;
        end
        else begin
            index_r2 <= index_r1;
            index_r1 <= index;
            index <= CB_row[2:0];
        end
    end

    always @(posedge clk) begin
        if(sys_rst) begin  
            group_base_t <= 0;
        end
        else begin
            group_base_t <= k * k;
        end
    end

    always @(posedge clk) begin
        if(sys_rst)
            group_base <= 0;
        else begin
            group_base <= (group_base_t << 3) + k_r1;
        end   
    end

    always @(posedge clk) begin
        if(sys_rst)
            group_offset_t <= 0;
        else begin
            case(index[2])
                1'b0: group_offset_t <= 0;
                1'b1: group_offset_t <= k<<3;
            endcase
        end        
    end

    always @(posedge clk) begin
        if(sys_rst)
            group_offset <= 0;
        else begin
            case(index_r1)
                3'b000: group_offset <= 0;
                3'b001: group_offset <= 0;
                3'b010: group_offset <= 0;
                3'b011: group_offset <= 0;
                3'b100: group_offset <= group_offset_t + 3'b100;
                3'b101: group_offset <= group_offset_t + 3'b011;
                3'b110: group_offset <= group_offset_t + 3'b010;
                3'b111: group_offset <= group_offset_t + 3'b001;
            endcase
        end
            
    end

    always @(posedge clk) begin
        if(sys_rst)
            CB_addr <= 0;
        else begin
            CB_addr <= group_base + group_offset;
        end
    end

endmodule