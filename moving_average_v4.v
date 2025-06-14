`timescale 1ns / 1ps

module moving_average_v4 (
    input wire clk,          // 时钟信号
    input wire rst_n,        // 异步复位，低电平有效
    input wire enable,       // 模块使能信号
    input wire data_refresh, // 数据刷新脉冲
    input wire output_refresh_mode, // 输出刷新模式: 0-按平均次数,1-每次计算
    input wire signed [15:0] din,   // 输入数据(有符号)
    input wire [2:0] mode,   // 模式选择: 000-无平均, 001-2次, 010-3次, 011-4次, 100-8次, 101-16次
    output reg signed [15:0] dout,  // 输出数据(有符号)
    output reg output_pulse  // 输出数据有效脉冲
);

// 优化版设计(提高ADC性能)
reg signed [23:0] sum;    // 扩展累加器位宽(8位防止溢出和精度损失)
reg signed [15:0] init_din; // 初始din值
reg [3:0] cnt;           // 数据计数
reg [15:0] prev_din;     // 前一次输入数据
reg [15:0] prev_prev_din; // 前两次输入数据
reg init_flag;           // 初始化标志

// 移除乘法器，仅使用加减法
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sum <= 24'b0;
        cnt <= 4'b0;
        prev_din <= 16'b0;
        prev_prev_din <= 16'b0;
        init_flag <= 1'b0;
        dout <= 16'b0;
        output_pulse <= 1'b0;
    end else if (enable) begin
        // 仅在使能状态下工作
        if (data_refresh) begin
            // 更新历史数据
            prev_prev_din <= prev_din;
            prev_din <= din;
            
            if (!init_flag) begin
                // 优化初始化过程
                if (cnt == 0) begin
                    init_din <= din;
                    sum <= $signed(din) << 8;  // 更高精度初始化
                end else if (cnt <= 15) begin
                    sum <= sum - $signed(init_din) + $signed(din);  // 保持高精度计算
                end
                if (cnt == 15) begin
                    init_flag <= 1'b1;
                end
                cnt <= cnt + 1;
            end else begin
                // 改进的滑动窗口计算
                sum <= sum + ($signed(din) << 4) - ($signed(sum[23:4]) << 4);  // 保持高精度
            end
        end
        
        // 输出脉冲控制(同v3)
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

        // 优化输出计算(对称加权)
        if (enable) begin
            case (mode)
                3'b000: dout <= din;
                3'b001: dout <= ($signed(prev_din) + $signed(din)) >>> 1;
                3'b010: dout <= (($signed(prev_prev_din) >>> 2) +  // 25%
                               ($signed(prev_din) >>> 2) +       // 25%
                               ($signed(din) >>> 1));            // 50%
                3'b011: dout <= ($signed(prev_prev_din) + $signed(prev_din) + 
                               $signed(din) + $signed(sum[23:4])) >>> 2;
                3'b100: dout <= sum[23:8];   // 16次平均(更高精度)
                3'b101: dout <= sum[23:8];   // 16次平均
                default: dout <= din;
            endcase
        end
    end
end

endmodule
