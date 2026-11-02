`timescale 1ns / 1ps
module tb_dds_wave;

// ==================== 实验参数（两组仅修改DITHER_EN） ====================
localparam  DITHER_EN  = 1;        // 0=无抖动，1=有抖动，唯一变量
localparam  CLK_PERIOD = 10;       // 100MHz采样时钟，固定不变
localparam  FREQ_WORD  = 32'd42949673; // 1MHz标准测试频点，固定不变
localparam  SAMPLE_CNT = 8000;     // 8192点采样，高分辨率FFT

reg         clk;
reg         rst;
reg  [1:0]  wave_sel;
reg  [7:0]  amp_ctrl;
wire [11:0] wave_out;

integer file_id;
integer sample_cnt;

// ==================== DDS模块例化 ====================
dds_wave u_dds_wave (
    .clk        (clk),
    .rst        (rst),
    .dither_en  (DITHER_EN),
    .freq_word  (FREQ_WORD),
    .wave_sel   (wave_sel),
    .amp_ctrl   (amp_ctrl),
    .wave_out   (wave_out)
);

// ==================== 时钟生成 ====================
initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD/2) clk = ~clk;
end

// ==================== 激励 + 自动导出数据 ====================
initial begin
    // 初始状态
    rst      = 1'b1;
    wave_sel = 2'b00;   // 固定正弦波
    amp_ctrl = 8'hff;   // 固定满幅
    sample_cnt = 0;
    
    #20 rst = 1'b0;
    
    // 等待1μs跳过瞬态，波形完全稳定后再采样
    #1000;
    
    // 自动匹配输出文件名
    if(DITHER_EN == 0)
        file_id = $fopen("wave_no_dither.txt", "w");
    else
        file_id = $fopen("wave_with_dither.txt", "w");
    
    // 连续采样
    for(sample_cnt = 0; sample_cnt < SAMPLE_CNT; sample_cnt = sample_cnt + 1) begin
        @(posedge clk);
        $fwrite(file_id, "%d\n", wave_out);
    end
    $fclose(file_id);
    
    $display("数据导出完成，共 %0d 个采样点，抖动使能=%0d", SAMPLE_CNT, DITHER_EN);
    $stop;
end

endmodule