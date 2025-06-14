`timescale 1ns/1ps

module tb_moving_average;
    reg clk;
    reg rst_n;
    reg enable;
    reg data_refresh;
    reg [15:0] din;
    reg [2:0] mode;
    wire [15:0] dout;

    // 实例化被测模块
    moving_average uut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .data_refresh(data_refresh),
        .din(din),
        .mode(mode),
        .dout(dout)
    );

    // 时钟生成
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 测试激励
    initial begin
        // 初始化
        rst_n = 0;
        enable = 0;
        data_refresh = 0;
        din = 0;
        mode = 0;
        #20;

        // 释放复位
        rst_n = 1;
        enable = 1;
        #10;

        // 测试模式0:无平均
        mode = 3'b000;
        for (int i=1; i<=5; i++) begin
            din = i;
            data_refresh = 1;
            #10;
            data_refresh = 0;
            #10;
            $display("Mode 0: din=%d, dout=%d", din, dout);
        end

        // 测试模式1:2次平均
        mode = 3'b001;
        for (int i=1; i<=5; i++) begin
            din = i;
            data_refresh = 1;
            #10;
            data_refresh = 0;
            #10;
            $display("Mode 1: din=%d, dout=%d", din, dout);
        end

        // 测试模式2:加权平均(25%+25%+50%)
        mode = 3'b010;
        for (int i=1; i<=5; i++) begin
            din = i;
            data_refresh = 1;
            #10;
            data_refresh = 0;
            #10;
            $display("Mode 2: din=%d, dout=%d", din, dout);
        end

        // 测试模式3:4次平均
        mode = 3'b011;
        for (int i=1; i<=10; i++) begin
            din = i;
            data_refresh = 1;
            #10;
            data_refresh = 0;
            #10;
            $display("Mode 3: din=%d, dout=%d", din, dout);
        end

        // 测试模式4/5:16次平均
        mode = 3'b100;
        for (int i=1; i<=20; i++) begin
            din = i;
            data_refresh = 1;
            #10;
            data_refresh = 0;
            #10;
            if (i >= 16) begin
                $display("Mode 4: din=%d, dout=%d", din, dout);
            end
        end

        // 测试使能控制
        enable = 0;
        din = 100;
        data_refresh = 1;
        #10;
        $display("Disable test: din=%d, dout=%d (should not change)", din, dout);

        $finish;
    end

    // 波形记录
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_moving_average);
    end
endmodule
