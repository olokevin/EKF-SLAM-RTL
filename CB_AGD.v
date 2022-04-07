module CB_AGD 
#(
    parameter CB_AW = 19,

    parameter MAX_LANDMARK = 500,       //500 landmarks, 1003rows of data, 1003/8 = 126 groups
    parameter ROW_LEN      = 10
)
(
    input clk,
    input sys_rst,

    input [ROW_LEN-1 : 0]  CB_row,
    input [ROW_LEN-1 : 0]  CB_col,

    output reg [CB_AW-1 : 0] CB_base_addr
);

reg [ROW_LEN-4 : 0] k;       //组号
reg [ROW_LEN-4 : 0] k_r1;
reg [ROW_LEN-4 : 0] k_r2;

reg [2 : 0]  index;
reg [2 : 0]  index_r1;
reg [2 : 0]  index_r2;

reg [CB_AW-1 : 0] group_base;     //组起始位置
reg [CB_AW-1 : 0] group_base_r1;   //组起始位置
reg [CB_AW-1 : 0] group_base_r2;   //组起始位置

reg [ROW_LEN-1  : 0]  group_offset;   //组偏移量
reg [ROW_LEN-1  : 0]  group_offset_r1; //组偏移量
reg [ROW_LEN-1  : 0]  group_offset_r2; //组偏移量

/*
    0: k <= CB_row >> 3;
       index <= CB_row[2:0];
    1: group_base_r1 <= k*k;
       group_offset_t <= 0 / (k<<3) --index
    2: group_base   <= group_base_r1 + k;
       group_offset -- index
    3: CB_base_addr <= group_base + group_offset_t;
*/
//CB_row CB_col at T0

//k & index at T1
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

//group_base at T2
    always @(posedge clk) begin
        if(sys_rst) begin  
            group_base <= 0;
        end
        else begin
            group_base <= k * k;
        end
    end
//group_base at T3
    always @(posedge clk) begin
        if(sys_rst)
            group_base_r1 <= 0;
        else begin
            group_base_r1 <= (group_base << 3);
        end   
    end
//group_base at T4
    always @(posedge clk) begin
        if(sys_rst)
            group_base_r2 <= 0;
        else begin
            group_base_r2 <= group_base_r1 + k_r2;
        end   
    end

//offset at T2
    always @(posedge clk) begin
        if(sys_rst)
            group_offset <= 0;
        else begin
            case(index[2])
                1'b0: group_offset <= 0;
                1'b1: group_offset <= k<<3;
            endcase
        end        
    end
//offset at T3
    always @(posedge clk) begin
        if(sys_rst)
            group_offset_r1 <= 0;
        else begin
            case(index_r1)
                3'b000: group_offset_r1 <= 0;
                3'b001: group_offset_r1 <= 0;
                3'b010: group_offset_r1 <= 0;
                3'b011: group_offset_r1 <= 0;
                3'b100: group_offset_r1 <= group_offset + 3'b100;
                3'b101: group_offset_r1 <= group_offset + 3'b011;
                3'b110: group_offset_r1 <= group_offset + 3'b010;
                3'b111: group_offset_r1 <= group_offset + 3'b001;
            endcase
        end      
    end
//offset at T4
    always @(posedge clk) begin
        if(sys_rst)
            group_offset_r2 <= 0;
        else 
            group_offset_r2 <= group_offset_r1 + CB_col;
    end

//get CB_base_addr at T5
    always @(posedge clk) begin
        if(sys_rst)
            CB_base_addr <= 0;
        else begin
            CB_base_addr <= group_base_r2 + group_offset_r2;
        end
    end

endmodule