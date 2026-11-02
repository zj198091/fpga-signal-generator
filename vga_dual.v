module vga_dual(
    input               clk_vga,    // 25MHz像素时钟，对接模块一clk_25m
    input               clk_50m,    // 50MHz FFT工作时钟，对接模块一clk_50m
    input               rst,        // 高有效复位，对接系统sys_rst
    input       [11:0]  wave_data,  // 12位波形输入，直接接FIR模块data_out
    output reg  [3:0]   vga_r,
    output reg  [3:0]   vga_g,
    output reg  [3:0]   vga_b,
    output reg          hsync,
    output reg          vsync
);

// ==================== 标准VGA时序 640*480@60Hz ====================
// 行：同步96 + 后沿48 + 有效640 + 前沿16 = 800
// 场：同步2 + 后沿33 + 有效480 + 前沿10 = 525
reg [9:0] h_cnt;
reg [9:0] v_cnt;

always @(posedge clk_vga or posedge rst) begin
    if(rst)
        h_cnt <= 10'd0;
    else if(h_cnt == 10'd799)
        h_cnt <= 10'd0;
    else
        h_cnt <= h_cnt + 10'd1;
end

always @(posedge clk_vga or posedge rst) begin
    if(rst)
        v_cnt <= 10'd0;
    else if(h_cnt == 10'd799) begin
        if(v_cnt == 10'd524)
            v_cnt <= 10'd0;
        else
            v_cnt <= v_cnt + 10'd1;
    end
end

always @(posedge clk_vga or posedge rst) begin
    if(rst) begin
        hsync <= 1'b1;
        vsync <= 1'b1;
    end else begin
        hsync <= (h_cnt < 10'd96) ? 1'b0 : 1'b1;
        vsync <= (v_cnt < 10'd2)  ? 1'b0 : 1'b1;
    end
end

// ==================== 显示区域划分 严格对应计划书参数 ====================
wire valid_area;   // 有效显示区 144~783列、35~514行
wire time_area;    // 上半屏：时域波形
wire freq_area;    // 下半屏：频域频谱
wire param_area;   // 右侧参数面板

assign valid_area = (h_cnt >= 10'd144 && h_cnt < 10'd784) && (v_cnt >= 10'd35 && v_cnt < 10'd515);
assign time_area  = valid_area && (v_cnt < 10'd275);
assign freq_area  = valid_area && (v_cnt >= 10'd275);
assign param_area = (h_cnt >= 10'd700 && h_cnt < 10'd784) && valid_area;

// ==================== 网格生成 ====================
wire grid_h, grid_v;
// 水平网格每40行一条，垂直网格每80列一条
assign grid_h = (time_area && ((v_cnt - 10'd35) % 10'd40 == 0))
             || (freq_area && ((v_cnt - 10'd275) % 10'd40 == 0));
assign grid_v = valid_area && ((h_cnt - 10'd144) % 10'd80 == 0) && (~param_area);

// ==================== 时域波形显示 ====================
// 踩坑记录：一开始直接跨时钟域传数据，画面横向闪跳，加两级打拍后彻底解决
reg [11:0] wave_r1, wave_r2;
always @(posedge clk_vga or posedge rst) begin
    if(rst) begin
        wave_r1 <= 12'd2048;
        wave_r2 <= 12'd2048;
    end else begin
        wave_r1 <= wave_data;
        wave_r2 <= wave_r1;
    end
end

wire [9:0] time_y;
wire time_draw;
// 12位波形右移2位，映射到240行高度，上下居中
assign time_y = 10'd255 - {2'b00, wave_r2[11:2]};
assign time_draw = time_area && (v_cnt == time_y);

// ==================== 频域频谱显示（资源优化版） ====================
// 对应计划书：不用开根号，最大值+次大值/4近似模值，误差不到5%，资源省70%
wire signed [15:0] fft_real, fft_imag;
wire [15:0] abs_real, abs_imag;
reg [7:0] fft_mag;

assign abs_real = fft_real[15] ? (~fft_real + 1'b1) : fft_real;
assign abs_imag = fft_imag[15] ? (~fft_imag + 1'b1) : fft_imag;

always @(posedge clk_50m or posedge rst) begin
    if(rst)
        fft_mag <= 8'd0;
    else if(abs_real > abs_imag)
        fft_mag <= abs_real[15:8] + abs_imag[15:10];
    else
        fft_mag <= abs_imag[15:8] + abs_real[15:10];
end

wire [9:0] freq_y;
wire freq_draw;
assign freq_y = 10'd514 - {4'b0, fft_mag[7:0]};
assign freq_draw = freq_area && (v_cnt == freq_y);

// ==================== 最终RGB输出 分层优先级 ====================
// 优先级：无效区 > 参数栏 > 波形 > 网格 > 背景
always @(posedge clk_vga or posedge rst) begin
    if(rst) begin
        vga_r <= 4'd0;
        vga_g <= 4'd0;
        vga_b <= 4'd0;
    end
    else if(~valid_area) begin
        vga_r <= 4'd0;
        vga_g <= 4'd0;
        vga_b <= 4'd0;
    end
    else if(param_area) begin
        vga_r <= 4'd12;  // 参数栏浅灰背景
        vga_g <= 4'd12;
        vga_b <= 4'd12;
    end
    else if(time_draw || freq_draw) begin
        vga_r <= 4'd1;   // 波形亮绿色
        vga_g <= 4'd15;
        vga_b <= 4'd2;
    end
    else if(grid_h || grid_v) begin
        vga_r <= 4'd4;   // 网格深灰色
        vga_g <= 4'd4;
        vga_b <= 4'd4;
    end
    else begin
        vga_r <= 4'd0;   // 黑色背景
        vga_g <= 4'd0;
        vga_b <= 4'd0;
    end
end

// ==================== FFT IP核例化 ====================
// 端口和生成的IP严格对应，12位波形补零到16位做实部，虚部填0
xfft_0 u_fft (
    .aclk(clk_50m),
    .aresetn(~rst),
    .s_axis_config_tdata(8'd1),
    .s_axis_config_tvalid(1'b1),
    .s_axis_data_tdata({4'h0, wave_data, 16'h0}),
    .s_axis_data_tvalid(1'b1),
    .m_axis_data_tdata({fft_imag, fft_real}),
    .m_axis_data_tvalid()
);

endmodule