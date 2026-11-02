module fir_config(
    input               clk,        // 100MHz采样时钟，对接模块一clk_100m
    input               rst,        // 高有效复位，对接系统复位sys_rst
    input       [11:0]  data_in,    // 12位无符号输入，对接DDS模块wave_out
    input       [1:0]   mode_sel,   // 滤波模式选择 00=低通 01=带通 10=高通
    output reg  [11:0]  data_out    // 12位无符号输出，对接后续DAC/VGA
);

// 17级移位寄存器链，对应标准16阶FIR滤波器
reg [11:0] shift_reg [16:0];
// 3组17个12位有符号系数，对应低通/带通/高通
reg signed [11:0] coe [2:0][16:0];
// 28位累加器，彻底避免16阶乘加溢出
reg signed [27:0] sum;
integer i;

// ==================== 系数初始化 严格匹配MATLAB生成值 ====================
initial begin
    // 0号：低通滤波器 截止1MHz 汉宁窗 12位量化
    coe[0][0]  = 12'sd0;
    coe[0][1]  = 12'sd9;
    coe[0][2]  = 12'sd37;
    coe[0][3]  = 12'sd78;
    coe[0][4]  = 12'sd127;
    coe[0][5]  = 12'sd177;
    coe[0][6]  = 12'sd219;
    coe[0][7]  = 12'sd247;
    coe[0][8]  = 12'sd257;
    coe[0][9]  = 12'sd247;
    coe[0][10] = 12'sd219;
    coe[0][11] = 12'sd177;
    coe[0][12] = 12'sd127;
    coe[0][13] = 12'sd78;
    coe[0][14] = 12'sd37;
    coe[0][15] = 12'sd9;
    coe[0][16] = 12'sd0;

    // 1号：带通滤波器 1~3MHz 汉宁窗 12位量化
    coe[1][0]  = 12'sd0;
    coe[1][1]  = 12'sd7;
    coe[1][2]  = 12'sd30;
    coe[1][3]  = 12'sd72;
    coe[1][4]  = 12'sd126;
    coe[1][5]  = 12'sd186;
    coe[1][6]  = 12'sd241;
    coe[1][7]  = 12'sd278;
    coe[1][8]  = 12'sd292;
    coe[1][9]  = 12'sd278;
    coe[1][10] = 12'sd241;
    coe[1][11] = 12'sd186;
    coe[1][12] = 12'sd126;
    coe[1][13] = 12'sd72;
    coe[1][14] = 12'sd30;
    coe[1][15] = 12'sd7;
    coe[1][16] = 12'sd0;

    // 2号：高通滤波器 截止3MHz 汉宁窗 12位量化
    coe[2][0]  = 12'sd0;
    coe[2][1]  = -12'sd3;
    coe[2][2]  = -12'sd14;
    coe[2][3]  = -12'sd33;
    coe[2][4]  = -12'sd56;
    coe[2][5]  = -12'sd80;
    coe[2][6]  = -12'sd102;
    coe[2][7]  = -12'sd117;
    coe[2][8]  = 12'sd1924;
    coe[2][9]  = -12'sd117;
    coe[2][10] = -12'sd102;
    coe[2][11] = -12'sd80;
    coe[2][12] = -12'sd56;
    coe[2][13] = -12'sd33;
    coe[2][14] = -12'sd14;
    coe[2][15] = -12'sd3;
    coe[2][16] = 12'sd0;
end

// ==================== 17级串行移位寄存器 ====================
always @(posedge clk or posedge rst) begin
    if(rst) begin
        for(i = 0; i < 17; i = i + 1)
            shift_reg[i] <= 12'd0;
    end
    else begin
        shift_reg[0] <= data_in;
        for(i = 1; i < 17; i = i + 1)
            shift_reg[i] <= shift_reg[i-1];
    end
end

// ==================== 串行乘加运算 ====================
// 输入无符号转有符号（减去直流中点2048），匹配滤波器有符号运算
always @(posedge clk or posedge rst) begin
    if(rst) begin
        sum <= 28'sd0;
    end
    else begin
        sum <= 28'sd0;
        for(i = 0; i < 17; i = i + 1)
            sum <= sum + $signed(shift_reg[i] - 12'd2048) * coe[mode_sel][i];
    end
end

// ==================== 输出截位与格式转换 ====================
// 有符号结果转回无符号（加回直流中点2048），匹配DDS输出格式
always @(posedge clk or posedge rst) begin
    if(rst)
        data_out <= 12'd2048;
    else
        data_out <= sum[22:11] + 12'd2048;
end

endmodule