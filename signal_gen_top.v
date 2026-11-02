module signal_gen_top(
    input         sys_clk,    // 板载50MHz晶振输入
    input         sys_rst_n,  // 板载复位按键，低有效
    input  [3:0]  key,        // 4路功能按键，按下低电平
    output        dac_clk,    // DAC采样时钟输出
    output [11:0] dac_data    // DAC 12位并行数据，D11最高位
);

// ========== 内部连线声明 ==========
wire clk_100m;
wire clk_50m;
wire clk_25m;
wire sys_rst;

wire [1:0] wave_sel;
wire [1:0] mode_sel;
wire [7:0] amp_ctrl;
wire [11:0] dds_out;
wire [11:0] fir_out;

reg  [11:0] dac_data_reg;

// 1MHz标准频率控制字
// 公式：freq_word = 2^32 * 目标频率 / 采样频率 = 4294967296 * 1e6 / 100e6
wire [31:0] freq_word = 32'd42949673;

// ========== 模块1 时钟复位管理 ==========
clk_rst u_clk_rst(
    .sys_clk(sys_clk),
    .sys_rst_n(sys_rst_n),
    .clk_100m(clk_100m),
    .clk_50m(clk_50m),
    .clk_25m(clk_25m),
    .sys_rst(sys_rst)
);

// ========== 模块2 按键消抖与控制 ==========
key_ctrl u_key_ctrl(
    .clk(clk_100m),
    .rst(sys_rst),
    .key(key),
    .wave_sel(wave_sel),
    .mode_sel(mode_sel),
    .amp_ctrl(amp_ctrl)
);

// ========== 模块3 DDS波形生成 ==========
// 相位抖动默认开启，优化截断杂散
dds_wave u_dds_wave(
    .clk(clk_100m),
    .rst(sys_rst),
    .dither_en(1'b1),
    .freq_word(freq_word),
    .wave_sel(wave_sel),
    .amp_ctrl(amp_ctrl),
    .wave_out(dds_out)
);

// ========== 模块4 可重构FIR滤波器 ==========
fir_config u_fir_config(
    .clk(clk_100m),
    .rst(sys_rst),
    .data_in(dds_out),
    .mode_sel(mode_sel),
    .data_out(fir_out)
);

// ========== DAC输出寄存器打拍 ==========
// 踩坑记录：直接assign输出会带组合逻辑毛刺，后级DAC采样易出错
// 打一拍同步输出，同时改善建立时间，时序收敛更稳
always @(posedge clk_100m or posedge sys_rst) begin
    if(sys_rst)
        dac_data_reg <= 12'd2048;
    else
        dac_data_reg <= fir_out;
end

// DAC时钟与数据同源同相，匹配后级芯片采样沿
assign dac_clk  = clk_100m;
assign dac_data = dac_data_reg;

endmodule