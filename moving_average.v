`timescale 1ns / 1ps

module moving_average (
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

// 最终简化设计
reg signed [19:0] sum;   // 累加器(存储16个历史数据)(有符号)
reg [3:0] cnt;           // 数据计数
reg [15:0] prev_din;     // 存储上一个din值
reg [15:0] prev_prev_din; // 存储上上个din值
reg [15:0] init_din;     // 存储cnt==0时的初始din值

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sum <= 20'b0;
        cnt <= 4'b0;
        prev_din <= 16'b0;
        prev_prev_din <= 16'b0;
        dout <= 16'b0;
    end else if (enable) begin
        // 仅在使能状态下工作
        if (data_refresh) begin
            // 存储最近两个输入值用于加权平均
            prev_prev_din <= prev_din;
            prev_din <= din;
            
            if (cnt == 0) begin
                // 第一个周期：存储初始值
                init_din <= din;
                sum <= $signed({din,4'b0});  // din<<4 (有符号扩展)
                cnt <= cnt + 1;
            end else if (cnt < 15) begin
                // 初始化阶段：滑动更新(简化版)
                sum <= sum - $signed(init_din) + $signed(din);
                cnt <= cnt + 1;
            end else begin
                // 完全初始化后正常滑动窗口更新
                sum <= sum + $signed(din) - $signed(sum[19:4]); // 减去最旧数据(相当于sum/16),加上新数据(有符号运算)
            end
        end
        
        // 输出脉冲控制
        output_pulse <= 1'b0;
        if (enable && data_refresh) begin
            if (output_refresh_mode) begin
                // 模式1:每次计算都输出脉冲
                output_pulse <= 1'b1;
            end else begin
                // 模式0:按平均次数输出脉冲
                case (mode)
                    3'b000: output_pulse <= 1'b1;  // 无平均:每次刷新
                    3'b001: output_pulse <= (cnt[0] == 1'b1);  // 2次平均:每2次
                    3'b010: output_pulse <= (cnt[1:0] == 2'b10); // 3次加权:每3次
                    3'b011: output_pulse <= (cnt[1:0] == 2'b11); // 4次平均:每4次
                    3'b100: output_pulse <= (cnt == 4'b0111);    // 8次平均:每8次
                    3'b101: output_pulse <= (cnt == 4'b1111);    // 16次平均:每16次
                    default: output_pulse <= 1'b1;
                endcase
            end
        end

        // 根据模式选择输出
        if (enable) begin
            case (mode)
                3'b000: dout <= din;         // 无平均
                3'b001: dout <= ($signed(prev_din) + $signed(din)) >>> 1;  // 2次平均(有符号右移)
                3'b010: dout <= ($signed(prev_prev_din) + $signed(prev_din) + $signed({din,1'b0}) >>> 2; // 加权平均 (25%+25%+50%)(有符号右移)
                3'b011: dout <= ($signed(prev_prev_din) + $signed(prev_din) + $signed(din) + $signed(sum[19:4])) >>> 2;  // 4次平均(有符号右移)
                3'b100: dout <= sum[19:4];   // 16次平均
                3'b101: dout <= sum[19:4];   // 16次平均
                default: dout <= din;        // 默认无平均
            endcase
        end
    end else begin
        // 模块禁用时保持输出不变
        dout <= dout;
    end
end

endmodule
