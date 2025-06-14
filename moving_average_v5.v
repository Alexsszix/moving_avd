`timescale 1ns / 1ps

module moving_average_v5 (
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire data_refresh,
    input wire output_refresh_mode,
    input wire signed [15:0] din,
    input wire [2:0] mode,
    output reg signed [15:0] dout,
    output reg output_pulse
);

// 增强版设计(性能优化)
reg signed [27:0] sum;    // 28位累加器(12位保护位)
reg signed [15:0] history [0:3]; // 4级历史数据
reg [3:0] cnt;
reg init_flag;

// 抗混叠预处理
wire signed [16:0] din_ext = {din[15], din}; // 符号扩展

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sum <= 28'b0;
        cnt <= 4'b0;
        for (integer i=0; i<4; i=i+1) begin
            history[i] <= 16'b0;
        end
        init_flag <= 1'b0;
        dout <= 16'b0;
        output_pulse <= 1'b0;
    end else if (enable) begin
        // 更新历史数据
        if (data_refresh) begin
            for (integer i=3; i>0; i=i-1) begin
                history[i] <= history[i-1];
            end
            history[0] <= din;
            
            if (!init_flag) begin
                // 高精度初始化
                if (cnt == 0) begin
                    sum <= $signed(din) << 12;
                end else if (cnt <= 15) begin
                    sum <= sum + ($signed(din) << 8);
                end
                if (cnt == 15) init_flag <= 1'b1;
                cnt <= cnt + 1;
            end else begin
                // 改进的滑动窗口
                sum <= sum + ($signed(din) << 4) - ($signed(history[3]) << 4);
            end
        end

        // 输出控制
        output_pulse <= 1'b0;
        if (enable && data_refresh) begin
            if (output_refresh_mode) begin
                output_pulse <= 1'b1;
            end else begin
                case (mode)
                    3'b000: output_pulse <= 1'b1;
                    3'b001: output_pulse <= (cnt[0] == 1'b1);
                    3'b010: output_pulse <= (cnt[1:0] == 2'b10);
                    3'b011: output_pulse <= (cnt[1:0] == 2'b11);
                    3'b100: output_pulse <= (cnt == 4'b0111);
                    3'b101: output_pulse <= (cnt == 4'b1111);
                    default: output_pulse <= 1'b1;
                endcase
            end
        end

        // 优化输出计算
        case (mode)
            3'b000: dout <= din;
            3'b001: dout <= ($signed(history[0]) + $signed(history[1])) >>> 1;
            3'b010: dout <= (($signed(history[0]) + 
                           ($signed(history[1]) << 1) + 
                           ($signed(history[2]))) >>> 2;
            3'b011: dout <= ($signed(history[0]) + $signed(history[1]) + 
                          $signed(history[2]) + $signed(sum[27:12])) >>> 2;
            3'b100: dout <= sum[27:12];
            3'b101: dout <= sum[27:12];
            default: dout <= din;
        endcase
    end
end

endmodule
