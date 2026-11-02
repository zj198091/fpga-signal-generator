clear; clc; close all;

Fs = 100e6;
N_order = 16;
win = hann(N_order+1);

f_pass_lp = 1e6;
b_lp = fir1(N_order, f_pass_lp/(Fs/2), 'low', win);
b_lp_q = round(b_lp * (2^11 - 1));
b_lp_q = max(min(b_lp_q, 2047), -2048);

f_pass_bp = [1e6, 3e6];
b_bp = fir1(N_order, f_pass_bp/(Fs/2), 'bandpass', win);
b_bp_q = round(b_bp * (2^11 - 1));
b_bp_q = max(min(b_bp_q, 2047), -2048);

f_pass_hp = 3e6;
b_hp = fir1(N_order, f_pass_hp/(Fs/2), 'high', win);
b_hp_q = round(b_hp * (2^11 - 1));
b_hp_q = max(min(b_hp_q, 2047), -2048);

disp('=== 低通滤波器系数 coe[0][0]~coe[0][16] ===');
disp(int16(b_lp_q));
disp('=== 带通滤波器系数 coe[1][0]~coe[1][16] ===');
disp(int16(b_bp_q));
disp('=== 高通滤波器系数 coe[2][0]~coe[2][16] ===');
disp(int16(b_hp_q));

filterAnalyzer(b_lp,1, b_bp,1, b_hp,1, Fs);
