module key_ctrl(
    input               clk,        // 100MHz系统时钟，对接模块一clk_100m
    input               rst,        // 高有效复位，对接系统sys_rst
    input       [3:0]   key,        // 4位按键输入，接开发板物理按键，按下低电平
    output reg  [1:0]   wave_sel,   // 波形选择，直接接DDS模块wave_sel
    output reg  [1:0]   mode_sel,   // 滤波模式，直接接FIR模块mode_sel
    output reg  [7:0]   amp_ctrl    // 幅度控制，直接接DDS模块amp_ctrl
);

// ==================== 20ms硬件消抖 ====================
// 踩坑记录：开发板按键默认上拉，按下为低电平，机械抖动时间5~15ms
// 一开始没加消抖，按一次跳3~4次，20ms消抖后完全稳定不串键
parameter CNT_MAX = 20'd1_999_999; // 100MHz时钟，20ms对应200万个周期

reg [19:0] cnt [3:0];
reg [3:0] key_buf;
reg [3:0] key_stable;

genvar k;
generate
    for(k = 0; k < 4; k = k + 1) begin : key_debounce
        always @(posedge clk or posedge rst) begin
            if(rst) begin
                cnt[k] <= 20'd0;
                key_buf[k] <= 1'b1;
                key_stable[k] <= 1'b1;
            end
            else begin
                key_buf[k] <= key[k];
                if(key_buf[k] != key_stable[k]) begin
                    if(cnt[k] == CNT_MAX)
                        key_stable[k] <= key_buf[k];
                    else
                        cnt[k] <= cnt[k] + 20'd1;
                end
                else
                    cnt[k] <= 20'd0;
            end
        end
    end
endgenerate

// ==================== 按键下降沿检测 ====================
reg [3:0] key_dly;
wire [3:0] key_pulse;

always @(posedge clk or posedge rst) begin
    if(rst)
        key_dly <= 4'b1111;
    else
        key_dly <= key_stable;
end

// 按下瞬间产生一个时钟周期的高脉冲
assign key_pulse = key_dly & ~key_stable;

// ==================== 功能控制逻辑 ====================
// 初始状态：正弦波、低通滤波、50%幅度，上电即有正常输出
always @(posedge clk or posedge rst) begin
    if(rst) begin
        wave_sel <= 2'b00;    // 默认正弦波
        mode_sel <= 2'b00;    // 默认低通滤波
        amp_ctrl <= 8'd128;   // 默认50%幅度
    end
    else begin
        // key0：波形切换，循环四种波形
        if(key_pulse[0])
            wave_sel <= wave_sel + 2'd1;
        
        // key1：滤波切换，循环三种模式
        if(key_pulse[1]) begin
            if(mode_sel == 2'b10)
                mode_sel <= 2'b00;
            else
                mode_sel <= mode_sel + 2'd1;
        end
        
        // key2：幅度加，上限255
        if(key_pulse[2] && amp_ctrl < 8'd255)
            amp_ctrl <= amp_ctrl + 8'd1;
        
        // key3：幅度减，下限0
        if(key_pulse[3] && amp_ctrl > 8'd0)
            amp_ctrl <= amp_ctrl - 8'd1;
    end
end

endmodule