module CORDIC_DualMode #(parameter DW = 17, AW = 17, ITER = 4)(
    input wire clk, rst, init,
    input wire mode,                        //mode = 0 -> Rotate, mode = 1 -> Vector 
    input wire signed [DW - 1 : 0] xin,     //Rotate mode: Q1.1.15
    input wire signed [DW - 1 : 0] yin,     //Rotate mode: Q1.1.15
    input wire signed [AW - 1 : 0] zin,     //Rotate mode: [-1, 1) -> [-pi, pi)
    
    output reg done,                        //done = 1 stays for 1 clk
    output reg signed [DW - 1 : 0] xout,    //Rotate mode: Q1.1.15
    output reg signed [DW - 1 : 0] yout,    //Rotate mode: Q1.1.15
    output wire signed [AW - 1 : 0] zout     //Rotate mode: [-1, 1) -> [-pi, pi)
);
    reg init_delay;                         //make sure the init signal last for one clk;
    always@(posedge clk) begin
        if(rst) begin
            init_delay <= 1'b0;
        end
        else init_delay <= init;
    end
    reg en_0;
    reg signed [DW : 0] x_i;                //Rotate mode: Q1.2.15 to against overflow
    reg signed [DW : 0] y_i;                //Rotate mode: Q1.2.15 to against overflow
    reg signed [AW : 0] z_i;                //Rotate mode: [-1, 1) -> [-pi, pi)

    reg signed [DW : 0] x, y, z, y_abs, z_abs;

    reg [AW - 2 : 0] r;
    reg [ITER - 1 : 0] i;                   //index of LUT
    
    reg [AW - 1 : 0] tangle;                //LUT of Radian Measure

    always@(*) begin
        case (i)
            4'b0000: tangle = 17'd25735;    //  1/1
            4'b0001: tangle = 17'd15192;    //  1/2
            4'b0010: tangle = 17'd8027;     //  1/4
            4'b0011: tangle = 17'd4075;     //  1/8
            4'b0100: tangle = 17'd2045;     //  1/16
            4'b0101: tangle = 17'd1024;     //  1/32
            4'b0110: tangle = 17'd512;      //  1/64
            4'b0111: tangle = 17'd256;      //  1/128
            4'b1000: tangle = 17'd128;      //  1/256
            4'b1001: tangle = 17'd64;       //  1/512
            4'b1010: tangle = 17'd32;       //  1/1024
            4'b1011: tangle = 17'd16;       //  1/2048
            4'b1100: tangle = 17'd8;        //  1/4096
            4'b1101: tangle = 17'd4;        //  1/8192
            4'b1110: tangle = 17'd2;        //  1/16k
            4'b1111: tangle = 17'd1;        //  1/32k
        endcase
    end

    //find the optimum iteration angle
    always@(*) begin
        if(rst) begin
            z_abs = 'd0;
            y_abs = 'd0;
        end
        else begin
            z_abs = z[AW]? ~z + 1'b1 : z;
            y_abs = y[DW]? ~y + 1'b1 : y;
        end
    end

    always@(*) begin
        if(rst) begin
            r = 'd0;
        end
        else if(en_0 && !mode) begin
            r[0] = (z_abs >= 17'd25735);
            r[1] = (z_abs >= 17'd15192);
            r[2] = (z_abs >= 17'd8027);
            r[3] = (z_abs >= 17'd4075);
            r[4] = (z_abs >= 17'd2045);
            r[5] = (z_abs >= 17'd1024);
            r[6] = (z_abs >= 17'd512);
            r[7] = (z_abs >= 17'd256);
            r[8] = (z_abs >= 17'd128);
            r[9] = (z_abs >= 17'd64);
            r[10] = (z_abs >= 17'd32);
            r[11] = (z_abs >= 17'd16);
            r[12] = (z_abs >= 17'd8);
            r[13] = (z_abs >= 17'd4);
            r[14] = (z_abs >= 17'd2);
            r[15] = (z_abs >= 17'd1);
        end
        else if(en_0 && mode) begin
            r[0] = (y_abs >= x);
            r[1] = (y_abs >= x >>> 1);
            r[2] = (y_abs >= x >>> 2);
            r[3] = (y_abs >= x >>> 3);
            r[4] = (y_abs >= x >>> 4);
            r[5] = (y_abs >= x >>> 5);
            r[6] = (y_abs >= x >>> 6);
            r[7] = (y_abs >= x >>> 7);
            r[8] = (y_abs >= x >>> 8);
            r[9] = (y_abs >= x >>> 9);
            r[10] = (y_abs >= x >>> 10);
            r[11] = (y_abs >= x >>> 11);
            r[12] = (y_abs >= x >>> 12);
            r[13] = (y_abs >= x >>> 13);
            r[14] = (y_abs >= x >>> 14);
            r[15] = (y_abs >= x >>> 15);
        end
        else r = r;
    end

    always@(*) begin
        if(rst) begin
            i = 'd0;
        end
        else begin
            case(r)
                16'b1111111111111111: i = 4'd0;
                16'b0111111111111110: i = 4'd1;
                16'b1111111111111100: i = 4'd2;
                16'b1111111111111000: i = 4'd3;
                16'b1111111111110000: i = 4'd4;
                16'b1111111111100000: i = 4'd5;
                16'b1111111111000000: i = 4'd6;
                16'b1111111110000000: i = 4'd7;
                16'b1111111100000000: i = 4'd8;
                16'b1111111000000000: i = 4'd9;
                16'b1111110000000000: i = 4'd10;
                16'b1111100000000000: i = 4'd11;
                16'b1111000000000000: i = 4'd12;
                16'b1110000000000000: i = 4'd13;
                16'b1100000000000000: i = 4'd14;
                16'b1000000000000000: i = 4'd15;
                default: i = i;
            endcase
            //i <= r[0] + r[1] + r[2] + r[3] + r[4] + r[5] + r[6] + r[7] + r[8] + r[9] + r[10] + r[11] + r[12] + r[13] + r[14] + r[15];
        end
    end    

    //prepare the input value for the next iteration
    always@(*) begin
        if(rst) begin
            x <= 'd0;
            y <= 'd0;
            z <= 'd0;
        end
        else begin
            x <= (init_delay || !en_0) ? xin : xout;
            y <= (init_delay || !en_0) ? yin : yout;
            z <= (init_delay || !en_0) ? zin : zout;
        end
    end

    //done signal generates
    always@(posedge clk) begin
        if(rst) begin
            done <= 1'b0;
        end
        else if(init) begin
            done <= 1'b0;
        end
        else if(en_0 && ((mode && (y == 0)) || (!mode && (z == 0)))) begin
            done <= 1'b1;
        end
        else if(done) begin
            done <= 1'b0;
        end
        else begin
            done <= done;
        end
    end

    //enable signals generate for 3 stage pipeline (find angle, iteration, scaling)
    always@(posedge clk) begin
        if(rst) begin
            en_0 <= 1'b0;
        end
        else if(init) begin
            en_0 <= 1'b1;
        end
        else if(en_0 && ((mode && (y == 0)) || (!mode && (z == 0)))) begin
            en_0 <= 1'b0;
        end
        else en_0 <= en_0;
    end

    //iteration
    always@(posedge clk) begin
        if(rst) begin
            x_i <= 'd0;
            y_i <= 'd0;
            z_i <= 'd0;
        end
        else if(en_0 && ((mode && (y < 0)) || (!mode && (z > 0)))) begin
            x_i <= x - (y >>> i);
            y_i <= y + (x >>> i);
            z_i <= z - tangle;
        end
        else if(en_0 && ((mode && (y > 0)) || (!mode && (z < 0)))) begin
            x_i <= x + (y >>> i);
            y_i <= y - (x >>> i);
            z_i <= z + tangle;
        end
        else begin
            x_i <= x_i;
            y_i <= y_i;
            z_i <= z_i;
        end
    end    

    assign zout = z_i;

    //scaling
    reg [ITER - 1 : 0] i_delay;
    always@(posedge clk) begin
        if(rst) begin
            i_delay <= 'd0;
        end
        else begin
            i_delay <= i;
        end
    end
    always@(*) begin                                                                                                   //  0 -1 -2 -3 -4 -5 -6 -7 -8 -9-10-11-12-13-14-15
      if(rst) begin
          xout = 'd0;
          yout = 'd0;
      end
      else if(en_0) begin
        case (i_delay)
          4'b0000: begin xout = x_i - (x_i >>> 2) - (x_i >>> 5) - (x_i >>> 7) - (x_i >>> 8) + (x_i >>> 14);
                         yout = y_i - (y_i >>> 2) - (y_i >>> 5) - (y_i >>> 7) - (y_i >>> 8) + (y_i >>> 14); end        //  1  0 -1  0  0 -1  0 -1 -1  0  0  0  0  0  1 
          4'b0001: begin xout = x_i - (x_i >>> 3) + (x_i >>> 6) + (x_i >>> 8) - (x_i >>> 13) + (x_i >>> 15);
                         yout = y_i - (y_i >>> 3) + (y_i >>> 6) + (y_i >>> 8) - (y_i >>> 13) + (y_i >>> 15); end       //  1  0  0 -1  0  0  1  0  1  0  0  0  0 -1  0  1 
          4'b0010: begin xout = x_i - (x_i >>> 5) + (x_i >>> 10) + (x_i >>> 11) - (x_i >>> 14);
                         yout = y_i - (y_i >>> 5) + (y_i >>> 10) + (y_i >>> 11) - (y_i >>> 14); end                    //  1  0  0  0  0 -1  0  0  0  0  1  1  0  0 -1
          4'b0011: begin xout = x_i - (x_i >>> 7) + (x_i >>> 14) + (x_i >>> 15);
                         yout = y_i - (y_i >>> 7) + (y_i >>> 14) + (y_i >>> 15); end                                   //  1  0  0  0  0  0  0 -1  0  0  0  0  0  0  1  1
          4'b0100: begin xout = x_i - (x_i >>> 9);
                         yout = y_i - (y_i >>> 9); end                                                                 //  1  0  0  0  0  0  0  0  0 -1
          4'b0101: begin xout = x_i - (x_i >>> 11);
                         yout = y_i - (y_i >>> 11); end                                                                //  1  0  0  0  0  0  0  0  0  0  0 -1 
          4'b0110: begin xout = x_i - (x_i >>> 13);
                         yout = y_i - (y_i >>> 13); end                                                                //  1  0  0  0  0  0  0  0  0  0  0  0  0 -1 
          4'b0111: begin xout = x_i - (x_i >>> 15);
                         yout = y_i - (y_i >>> 15); end                                                                //  1  0  0  0  0  0  0  0  0  0  0  0  0  0  0 -1
          4'b1000: begin xout = x_i;
                         yout = y_i; end                                                                               //  1  
          4'b1001: begin xout = x_i;
                         yout = y_i; end                                                                               //  1
          4'b1010: begin xout = x_i;
                         yout = y_i; end                                                                               //  1
          4'b1011: begin xout = x_i;
                         yout = y_i; end                                                                               //  1
          4'b1100: begin xout = x_i;
                         yout = y_i; end                                                                               //  1
          4'b1101: begin xout = x_i;
                         yout = y_i; end                                                                               //  1
          4'b1110: begin xout = x_i;
                         yout = y_i; end                                                                               //  1
          4'b1111: begin xout = x_i;
                         yout = y_i; end                                                                               //  1
          default: begin xout = x_i;
                         yout = y_i; end
        endcase
      end
    end

endmodule