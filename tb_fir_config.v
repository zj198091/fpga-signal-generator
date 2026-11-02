`timescale 1ns / 1ps

module tb_fir_config;

// ========== 参数定义 ==========
localparam  CLK_PERIOD = 10;    // 100MHz采样时钟
localparam  F_LOW  = 1_000_000; // 低频分量 1MHz
localparam  F_HIGH = 6_000_000; // 高频分量 6MHz
localparam  AMP    = 11'd1023;  // 单频幅值，叠加后除以2防止溢出

// ========== 信号定义 ==========
reg         clk;
reg         rst;
reg  [1:0]  mode_sel;   // 00低通 01带通 10高通
reg  [11:0] data_in;
wire [11:0] data_out;

integer     cnt;
real        sin1, sin2;

// ========== 实例化DUT ==========
fir_config u_fir_config (
    .clk        (clk),
    .rst        (rst),
    .mode_sel   (mode_sel),
    .data_in    (data_in),
    .data_out   (data_out)
);

// ========== 时钟生成 ==========
initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

// ========== 混合正弦输入生成 ==========
// 输入为12位无符号，直流偏置2048，与RTL内"减2048转有符号"对应
initial begin
    cnt = 0;
    forever begin
        @(posedge clk);
        cnt = cnt + 1;
        sin1 = AMP * $sin(2 * 3.14159265 * F_LOW  * cnt * CLK_PERIOD * 1e-9);
        sin2 = AMP * $sin(2 * 3.14159265 * F_HIGH * cnt * CLK_PERIOD * 1e-9);
        data_in = 12'd2048 + $rtoi(sin1 + sin2) / 2;
    end
end

// ========== 模式切换激励 ==========
initial begin
    rst = 1'b1;
    mode_sel = 2'b00;
    #(2*CLK_PERIOD) rst = 1'b0;
    
    // 16阶串行结构有群延迟，每种模式留足时间进入稳态
    #60000  mode_sel = 2'b00;
            $display("[FIR仿真] 当前模式：低通滤波");
    #60000  mode_sel = 2'b01;
            $display("[FIR仿真] 当前模式：带通滤波");
    #60000  mode_sel = 2'b10;
            $display("[FIR仿真] 当前模式：高通滤波");
    
    #60000  $stop;
end

endmodule