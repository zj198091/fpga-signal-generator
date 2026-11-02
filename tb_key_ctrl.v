`timescale 1ns / 1ps

module tb_key_ctrl;

// ========== 参数定义 ==========
localparam  CLK_PERIOD = 10;    // 模块使用100MHz系统时钟，与RTL一致
// RTL消抖阈值20ms，模拟抖动控制在5~15ms内，验证消抖效果

// ========== 信号定义 ==========
reg         clk;
reg         rst;
reg  [3:0]  key;        // 4位按键输入，低有效，对应RTL的key端口
wire [1:0]  wave_sel;
wire [1:0]  mode_sel;
wire [7:0]  amp_ctrl;

integer     rand_t;     // 随机抖动时长

// ========== 实例化DUT ==========
// 内部信号 key_buf / key_stable / key_pulse 仿真时从 Scope 拖入波形窗口即可
key_ctrl u_key_ctrl (
    .clk        (clk),
    .rst        (rst),
    .key        (key),
    .wave_sel   (wave_sel),
    .mode_sel   (mode_sel),
    .amp_ctrl   (amp_ctrl)
);

// ========== 时钟生成 ==========
initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

// ========== 模拟按键抖动 ==========
// 仅测试 key[0] 一路，其余三路保持未按下状态（高电平）
// 抖动时长模拟机械按键的5~15ms随机毛刺，最终稳定20ms以上
initial begin
    // 初始状态
    rst = 1'b1;
    key = 4'b1111;   // 所有按键未按下，高电平
    #(5*CLK_PERIOD) rst = 1'b0;
    #100_000;        // 初始稳定100us
    
    $display("[按键仿真] 开始模拟按键按下+抖动");
    // 按下过程：5次随机跳变，模拟机械抖动
    repeat(5) begin
        rand_t = 500_000 + {$random} % 10_000_000;  // 0.5~10.5ms随机
        key[0] = ~key[0];
        #rand_t;
    end
    key[0] = 1'b0;   // 最终稳定按下
    $display("[按键仿真] 按键稳定按下");
    
    #30_000_000;     // 稳定30ms，超过20ms消抖阈值
    
    $display("[按键仿真] 开始模拟按键释放+抖动");
    // 释放过程抖动
    repeat(5) begin
        rand_t = 500_000 + {$random} % 10_000_000;
        key[0] = ~key[0];
        #rand_t;
    end
    key[0] = 1'b1;   // 最终稳定释放
    $display("[按键仿真] 按键稳定释放");
    
    #30_000_000;
    $stop;
end

endmodule