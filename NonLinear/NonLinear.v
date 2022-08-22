module NonLinear #(parameter DW = 32, AW = 17, ITER = 4)(
    input wire clk, rst, init_predict, init_newlm, init_update,
    input wire signed [DW - 1 : 0] vlr, rk, lkx, lky, xk, yk,
    input wire signed [AW - 1 : 0] alpha, xita, phi,

    output reg done_predict, done_newlm, done_update,
    output reg signed [DW - 1 : 0] result_0, result_1, result_2, result_3, result_4, result_5       
);
/*
  ****************** multiplier *******************
*/
    reg signed [DW - 1 : 0] a, b;                                //the input of multiplier;
    wire signed [2 * DW - 1 : 0] c_temp;
    wire signed [DW - 1 : 0] c;                                  //the output of multiplier;

    //implement a 32-bit signed (Q1.12.19) multiplier
    assign c_temp = a * b;
    assign c = {c_temp[63], c_temp[49 : 19]};

/*
  ****************** divider *******************
*/
    reg signed [DW - 1 : 0] dividend, divisor;
    reg init_Div; 
    wire [55 : 0] quotient_temp;
    wire signed [DW - 1 : 0] quotient;
    wire valid_Div;

    //Get the sign in advance
    wire   quotient_sign;
    assign quotient_sign = divisor[31] ^ dividend[31];
    
    //Calculate the result of abs
    wire [DW-1 : 0] abs_dividend, abs_divisor, abs_quotient;
    assign abs_dividend = dividend[31] ? (~dividend + 1) : dividend;
    assign abs_divisor  = divisor[31] ? (~divisor + 1) : divisor;

    //Transform the final quotient
    assign abs_quotient = {1'b0, quotient_temp[31 : 20], quotient_temp[18 : 0]};
    assign quotient= quotient_sign ? (~abs_quotient + 1) : abs_quotient;
    
    //implement a 32-bit unsigned (Q1.12.19) divider
    div_gen_0 div_gen(
        .aclk(clk),
        .s_axis_divisor_tvalid(init_Div),
        .s_axis_divisor_tdata(abs_divisor),
        .s_axis_dividend_tvalid(init_Div),
        .s_axis_dividend_tdata(abs_dividend),
        
        .m_axis_dout_tvalid(valid_Div),
        .m_axis_dout_tdata(quotient_temp)
    );


/*
  ****************** AR CORDIC *******************
*/
    reg init_CORDIC, mode;
    reg signed [AW - 1 : 0] xin, yin, zin;
    wire signed [AW - 1 : 0] xout, yout, zout;
    wire done_CORDIC;

    //inplement a 17-bit signed (Q1.1.15) CORDIC module for sin(alpha) and cos(alpha)
    CORDIC_DualMode #(AW, AW, ITER) CORDIC_0(
        .clk(clk), 
        .rst(rst), 
        .init(init_CORDIC),
        .mode(mode),                    
        .xin(xin),    
        .yin(yin),     
        .zin(zin),     
        
        .done(done_CORDIC),                        
        .xout(xout),    
        .yout(yout),   
        .zout(zout)    
    );


    //Q1.1.15
    //localparam H_L = 'd8799;  2^(-2)+2^(-6)+2^(-9)+2^(-10)
    //localparam dT = 'd3276;   2^(-3)-2^(-5)+2^(-7)-2^(-9)+2^(-11)-2^(-13)+2^(-15)
    //localparam a_L = 'd43767;
    //dT*a/L                    2^(-3)+2^(-7)+2^(-10)-2^(-12)+2^(-15)
    //localparam b_L = 'd5789;
    //dT*b/L                    2^(-6)+2^(-9)+2^(-14)+2^(-15)
    //localparam dT_L = 'd1157; 2^(-5)+2^(-8)+2^(-13)+2^(-14)

    //state description
    //prediction steps
    localparam s_idle = 5'd0;
    localparam s_rotate_alpha = 5'd1;                                //calculate sin(alpha) and cos(alpha)
    localparam s_tanalpha = 5'd2;                                    //calculate tan(alpha)
    localparam s_vc = 5'd3;
    localparam s_rotate_xita = 5'd4;
    localparam s_vcsin = 5'd5;
    localparam s_vccos = 5'd6;
    localparam s_vctan = 5'd7;
    localparam s_vcsintan = 5'd8;
    localparam s_vccostan = 5'd9;
    localparam s_result_pre = 5'd10; 
    localparam s_rotate_gamma = 5'd11;
    localparam s_rksin = 5'd12;
    localparam s_rkcos = 5'd13;
    localparam s_result_newlm = 5'd14;
    localparam s_vector = 5'd15;
    localparam s_d2 = 5'd16;
    localparam s_dx_d2 = 5'd17;
    localparam s_dy_d2 = 5'd18;
    localparam s_dx_d = 5'd19;
    localparam s_dy_d = 5'd20;
    localparam s_result_update = 5'd21;

    reg [4 : 0] state, state_nxt;

    //state driving
    always@(posedge clk) begin
        if(rst) state <= s_idle;
        else state <= state_nxt;
    end

    //state transfer
    always@(*) begin
        state_nxt = state;
        case (state)
        s_idle:
            if(init_predict) state_nxt = s_rotate_alpha;
            else if(init_newlm) state_nxt = s_rotate_gamma;
            else if(init_update) state_nxt = s_vector;
        s_rotate_alpha:
            if(done_CORDIC) state_nxt = s_tanalpha;
        s_tanalpha:
            if(valid_Div) state_nxt = s_vc;
        s_vc:
            if(valid_Div) state_nxt = s_rotate_xita;
        s_rotate_xita:
            if(done_CORDIC) state_nxt = s_vcsin;
        s_vcsin:
            state_nxt = s_vccos;
        s_vccos:
            state_nxt = s_vctan;
        s_vctan:
            state_nxt = s_vcsintan;
        s_vcsintan:
            state_nxt = s_vccostan;
        s_vccostan:
            state_nxt = s_result_pre;
        s_result_pre:
            state_nxt = s_idle;
        s_rotate_gamma:
            if(done_CORDIC) state_nxt = s_rksin;
        s_rksin:
            state_nxt = s_rkcos;
        s_rkcos:
            state_nxt = s_result_newlm;
        s_result_newlm:
            state_nxt = s_idle;
        s_vector:
            if(done_CORDIC) state_nxt = s_d2;
        s_d2:
            state_nxt = s_dx_d2;
        s_dx_d2:
            if(valid_Div) state_nxt = s_dy_d2;
        s_dy_d2:
            if(valid_Div) state_nxt = s_dx_d;
        s_dx_d:
            if(valid_Div) state_nxt = s_dy_d;
        s_dy_d:
            if(valid_Div) state_nxt = s_result_update;
        s_result_update:
            state_nxt = s_idle;
        default: state_nxt = state;
        endcase
    end

    //output driving
    
    //---CORDIC
    //patch when the input data of s_vector are larger than 1
    wire signed [DW - 1 : 0] dinx_s_vector, diny_s_vector;
    wire [DW - 1 : 0] abs_dinx_s_vector, abs_diny_s_vector;
    wire [3 : 0] scale_dinx_s_vector, scale_diny_s_vector, scale_din_s_vector;
    assign dinx_s_vector = lkx - xk;
    assign diny_s_vector = lky - yk;
    assign abs_dinx_s_vector = dinx_s_vector[31] ? (~dinx_s_vector + 1) : dinx_s_vector;
    assign abs_diny_s_vector = diny_s_vector[31] ? (~diny_s_vector + 1) : diny_s_vector;
    assign scale_dinx_s_vector = abs_dinx_s_vector[30]    ? 4'd12 : 
                                    abs_dinx_s_vector[29] ? 4'd11 : 
                                    abs_dinx_s_vector[28] ? 4'd10 : 
                                    abs_dinx_s_vector[27] ? 4'd9 : 
                                    abs_dinx_s_vector[26] ? 4'd8 : 
                                    abs_dinx_s_vector[25] ? 4'd7 : 
                                    abs_dinx_s_vector[24] ? 4'd6 : 
                                    abs_dinx_s_vector[23] ? 4'd5 : 
                                    abs_dinx_s_vector[22] ? 4'd4 : 
                                    abs_dinx_s_vector[21] ? 4'd3 : 
                                    abs_dinx_s_vector[20] ? 4'd2 : 
                                    abs_dinx_s_vector[19] ? 4'd1 : 4'd0; 
    assign scale_diny_s_vector = abs_diny_s_vector[30]    ? 4'd12 : 
                                    abs_diny_s_vector[29] ? 4'd11 : 
                                    abs_diny_s_vector[28] ? 4'd10 : 
                                    abs_diny_s_vector[27] ? 4'd9 : 
                                    abs_diny_s_vector[26] ? 4'd8 : 
                                    abs_diny_s_vector[25] ? 4'd7 : 
                                    abs_diny_s_vector[24] ? 4'd6 : 
                                    abs_diny_s_vector[23] ? 4'd5 : 
                                    abs_diny_s_vector[22] ? 4'd4 : 
                                    abs_diny_s_vector[21] ? 4'd3 : 
                                    abs_diny_s_vector[20] ? 4'd2 : 
                                    abs_diny_s_vector[19] ? 4'd1 : 4'd0;
    assign scale_din_s_vector = (scale_dinx_s_vector > scale_diny_s_vector) ? scale_dinx_s_vector : scale_diny_s_vector;
    //end patch

    always@(posedge clk) begin
        if(rst) begin
            init_CORDIC <= 1'b0;
            mode <= 1'b0;
            xin <= 17'd0;
            yin <= 17'd0;
            zin <= 17'd0;
        end
        if(state == s_idle && state_nxt == s_rotate_alpha) begin
            init_CORDIC <= 1'b1;
            mode <= 1'b0;
            xin <= 17'd32768;
            yin <= 17'd0;
            zin <= alpha;
        end
        if(state == s_vc && state_nxt == s_rotate_xita) begin
            init_CORDIC <= 1'b1;
            mode <= 1'b0;
            xin <= 17'd32768;
            yin <= 17'd0;
            zin <= xita;
        end
        if(state == s_idle && state_nxt == s_rotate_gamma) begin
            init_CORDIC <= 1'b1;
            mode <= 1'b0;
            xin <= 17'd32768;
            yin <= 17'd0;
            zin <= phi + xita;
        end
        if(state == s_idle && state_nxt == s_vector) begin
            init_CORDIC <= 1'b1;
            mode <= 1'b1;
            //xin <= (lkx - xk) >>> 4;
            //yin <= (lky - yk) >>> 4;
            //patch
            xin <= dinx_s_vector >>> (4 + scale_din_s_vector);
            yin <= diny_s_vector >>> (4 + scale_din_s_vector);
            //end patch
            zin <= 17'd0;
        end
        if(init_CORDIC) init_CORDIC <= 1'b0;
    end

    //---multiplier
    always@(posedge clk) begin
        if(rst) begin
            a <= 'd0;
            b <= 'd0;
        end
        if(state_nxt == s_vcsin) begin
            a <= result_1;
            b <= result_3;
        end
        if(state_nxt == s_vccos) begin
            a <= result_1;
            b <= result_2;
        end
        if(state_nxt == s_vctan) begin
            a <= result_1;
            b <= result_0;
        end
        if(state_nxt == s_vcsintan) begin
            a <= result_3;
            b <= result_0;
        end
        if(state_nxt == s_vccostan) begin
            a <= result_2;
            b <= result_0;
        end
        if(state_nxt == s_rksin) begin
            a <= rk;
            b <= result_1;
        end
        if(state_nxt == s_rkcos) begin
            a <= rk;
            b <= result_0;
        end
        if(state_nxt == s_d2) begin
            a <= result_0;
            b <= result_0;
        end
    end

    //---divider
    always@(posedge clk) begin
        if(rst) begin
            init_Div <= 1'b0;
            dividend <= 'd0;
            divisor <= 'd0;
        end
        if(state == s_rotate_alpha && state_nxt == s_tanalpha) begin
            init_Div <= 1'b1;
            dividend <= yout <<< 4;
            divisor <= xout <<< 4;
        end
        if(state == s_tanalpha && state_nxt == s_vc) begin
            init_Div <= 1'b1;
            dividend <= vlr;
            divisor <= 32'd524288 - (quotient >>> 2) - (quotient >>> 6) - (quotient >>> 9) - (quotient >>> 10);
        end
        if(state == s_d2 && state_nxt == s_dx_d2) begin
            init_Div <= 1'b1;
            dividend <= lkx - xk;
            divisor <= c;
        end
        /*if(state == s_dx_d2) begin
            //init_Div <= 1'b1;
            //dividend <= lkx - xk;
            divisor <= result_2;
        end*/
        if(state == s_dx_d2 && state_nxt == s_dy_d2) begin
            init_Div <= 1'b1;
            dividend <= lky - yk;
            divisor <= result_2;
        end
        if(state == s_dy_d2 && state_nxt == s_dx_d) begin
            init_Div <= 1'b1;
            dividend <= lkx - xk;
            divisor <= result_0;
        end
        if(state == s_dx_d && state_nxt == s_dy_d) begin
            init_Div <= 1'b1;
            dividend <= lky - yk;
            divisor <= result_0;
        end
        if(init_Div) init_Div <= 1'b0;
    end

    //---output signal
    always@(posedge clk) begin
        if(rst) begin
            result_0 <= 'd0;
            result_1 <= 'd0;
            result_2 <= 'd0;
            result_3 <= 'd0;
            result_4 <= 'd0;
            result_5 <= 'd0;
        end
        //---prediction step: 
        if(state == s_tanalpha) begin
            result_0 <= quotient;
        end
        if(state == s_vc) begin
            result_1 <= quotient;
        end
        if(state == s_rotate_xita) begin
            result_2 <= xout <<< 4;
            result_3 <= yout <<< 4;
        end
        if(state == s_vcsin) begin
            result_3 <= c;
        end
        if(state == s_vccos) begin
            result_2 <= c;
        end
        if(state == s_vctan) begin
            result_1 <= c;
        end
        if(state == s_vcsintan) begin
            result_4 <= c;
        end
        if(state == s_vccostan) begin
            result_0 <= c;
        end
        if(state == s_result_pre) begin
            result_1 <= (result_1 >>> 5) + (result_1 >>> 8) + (result_1 >>> 13) + (result_1 >>> 14);
            result_2 <= ((result_2 >>> 3) - (result_2 >>> 5) + (result_2 >>> 7) - (result_2 >>> 9) + (result_2 >>> 11) - (result_2 >>> 13) + (result_2 >>> 15)) - 
                        ((result_4 >>> 3) + (result_4 >>> 7) + (result_4 >>> 10) - (result_4 >>> 12) + (result_4 >>> 15)) - 
                        ((result_0 >>> 6) + (result_0 >>> 9) + (result_0 >>> 14) + (result_0 >>> 15));
            result_3 <= ((result_3 >>> 3) - (result_3 >>> 5) + (result_3 >>> 7) - (result_3 >>> 9) + (result_3 >>> 11) - (result_3 >>> 13) + (result_3 >>> 15)) + 
                        ((result_0 >>> 3) + (result_0 >>> 7) + (result_0 >>> 10) - (result_0 >>> 12) + (result_0 >>> 15)) - 
                        ((result_4 >>> 6) + (result_4 >>> 9) + (result_4 >>> 14) + (result_4 >>> 15));
        end
        //---newlandmark initilization step
        if(state == s_rotate_gamma) begin
            result_0 <= xout <<< 4;
            result_1 <= yout <<< 4;
        end
        if(state == s_rksin) begin
            result_2 <= c;
        end
        if(state == s_rkcos) begin
            result_3 <= c;
        end
        //---update step
        if(state == s_vector) begin
            //result_0 <= xout <<< 4;
            //patch
            result_0 <= xout <<< (4 + scale_din_s_vector);  //输入移(4+scale)位, 开方输出移(2+scale/2)位 加法优先级高于移位
            //end patch
            result_1 <= (zout - xita) <<< 4;    //输出为arctan - xita(机器人位姿)
        end
        if(state == s_d2) begin
            result_2 <= c;
        end
        if(state == s_dx_d2) begin
            result_3 <= quotient;
        end
        if(state == s_dy_d2) begin
            result_2 <= quotient;
        end
        if(state == s_dx_d) begin
            result_4 <= quotient;
        end
        if(state == s_dy_d) begin
            result_5 <= quotient;
        end
    end

    //---done signal
    always@(posedge clk) begin
        done_predict <= (state_nxt == s_result_pre);
        done_newlm <= (state_nxt == s_result_newlm);
        done_update <= (state_nxt == s_result_update);
    end

endmodule