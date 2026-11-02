%% ==============================================
%% 整数周期采样版 SFDR 精准计算 + 标准双子图对比
%% 适配 8000点 / 100点每周期 = 80个完整周期
%% ==============================================
clc; clear; close all;

%% ========== 1. 读取数据 ==========
file_path_no = 'D:\FPGA_project\signal_gen\signal_gen\signal_gen.sim\sim_1\behav\xsim\wave_no_dither.txt';
file_path_with = 'D:\FPGA_project\signal_gen\signal_gen\signal_gen.sim\sim_1\behav\xsim\wave_with_dither.txt';

data_no_dither = load(file_path_no);
data_with_dither = load(file_path_with);

% 基础参数校验
fprintf('========================================\n');
fprintf('      波形基础参数校验\n');
fprintf('========================================\n');
fprintf('数据总长度：%d\n', length(data_no_dither));
fprintf('无抖动：最大值%d，最小值%d\n', max(data_no_dither), min(data_no_dither));
fprintf('带抖动：最大值%d，最小值%d\n', max(data_with_dither), min(data_with_dither));

% 单周期点数
zero_pos = find(data_no_dither == 0);
period_num = zero_pos(2) - zero_pos(1);
fprintf('单周期采样点数：%d\n\n', period_num);

%% ========== 2. SFDR计算（整数周期，不加窗，精度最高）==========
fft_point = 8000;  % 和数据长度一致，整数周期FFT
N = length(data_no_dither);

% 去直流
sig_no = double(data_no_dither(1:N)) - mean(double(data_no_dither(1:N)));
sig_with = double(data_with_dither(1:N)) - mean(double(data_with_dither(1:N)));

% FFT计算（不加窗，整数周期无泄漏）
Y_no = fft(sig_no, fft_point);
Y_with = fft(sig_with, fft_point);

% 单边幅度谱转dBc
P_no = abs(Y_no / fft_point);
P_no_single = P_no(1:fft_point/2+1);
P_no_single(2:end-1) = 2 * P_no_single(2:end-1);
P_no_dB = 20 * log10(P_no_single / max(P_no_single));

P_with = abs(Y_with / fft_point);
P_with_single = P_with(1:fft_point/2+1);
P_with_single(2:end-1) = 2 * P_with_single(2:end-1);
P_with_dB = 20 * log10(P_with_single / max(P_with_single));

f_norm = (0:fft_point/2) / fft_point;

% 手动计算SFDR：排除主瓣+直流
main_lobe_width = 3;  % 无窗主瓣很窄，排除3个点足够
[~, main_idx_no] = max(P_no_dB(2:end));
main_idx_no = main_idx_no + 1;

% 无抖动SFDR
spurs_no = P_no_dB;
spurs_no(max(1,main_idx_no-main_lobe_width) : min(end,main_idx_no+main_lobe_width)) = -inf;
spurs_no(1) = -inf;
[spur_val_no, spur_idx_no] = max(spurs_no);
sfdr_no = -spur_val_no;

% 带抖动SFDR
[~, main_idx_with] = max(P_with_dB(2:end));
main_idx_with = main_idx_with + 1;
spurs_with = P_with_dB;
spurs_with(max(1,main_idx_with-main_lobe_width) : min(end,main_idx_with+main_lobe_width)) = -inf;
spurs_with(1) = -inf;
spur_val_with = max(spurs_with);
sfdr_with = -spur_val_with;

% 打印结果
fprintf('========================================\n');
fprintf('      杂散性能对比（整数周期无窗）\n');
fprintf('========================================\n');
fprintf('无抖动 SFDR：%.2f dB\n', sfdr_no);
fprintf('带抖动 SFDR：%.2f dB\n', sfdr_with);
fprintf('抖动优化提升：%.2f dB\n\n', sfdr_with - sfdr_no);

%% ========== 3. 绘制双子图频谱对比（白底定稿版，保留完整杂散显示）==========
figure('Name','DDS相位抖动优化前后频谱对比','Position',[150,150,900,650],'Color','white');

% 子图1：优化前（无抖动）
subplot(2,1,1);
% 保留原显示逻辑：低于-95dB的部分拉平为基线，不改变SFDR计算结果
P_no_dB_show = P_no_dB;
P_no_dB_show(P_no_dB_show < -95) = -95;

plot(f_norm, P_no_dB_show, 'b-', 'LineWidth',1.5);
hold on;
% 标记最大杂散点
plot(f_norm(spur_idx_no), spur_val_no, 'bo', 'MarkerSize',7, 'MarkerFaceColor','b');
title('优化前：无抖动 DDS 输出频谱','FontSize',11);
ylabel('幅度 (dBc)','FontSize',10);
grid on; grid minor;
set(gca,'FontSize',9, 'Color','white');  % 坐标轴背景设为纯白
ylim([-90, 5]);
xlim([0, 0.5]);
text(0.6, -18, sprintf('SFDR = %.2f dB', sfdr_no), ...
    'Color','b','FontSize',10,'FontWeight','bold','BackgroundColor','white');

% 子图2：优化后（带相位抖动）
subplot(2,1,2);
plot(f_norm, P_with_dB, 'r-', 'LineWidth',1.5);
title('优化后：加入相位抖动 DDS 输出频谱','FontSize',11);
xlabel('归一化频率 f/Fs','FontSize',10);
ylabel('幅度 (dBc)','FontSize',10);
grid on; grid minor;
set(gca,'FontSize',9, 'Color','white');  % 坐标轴背景设为纯白
ylim([-90, 5]);
xlim([0, 0.5]);
text(0.6, -18, sprintf('SFDR = %.2f dB', sfdr_with), ...
    'Color','r','FontSize',10,'FontWeight','bold','BackgroundColor','white');
text(0.6, -35, sprintf('杂散抑制提升 = %.2f dB', sfdr_with - sfdr_no), ...
    'Color','k','FontSize',10,'FontWeight','bold','BackgroundColor','white');

% 导出300dpi高清图
print(gcf, 'DDS相位抖动优化频谱对比_终版.png', '-dpng', '-r300');
fprintf('✅ 白底最终版对比图已生成，可直接插入报告\n');