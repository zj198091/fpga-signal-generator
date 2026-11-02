%% ==============================================
%% 生成10位深度 12位位宽 正弦ROM初始化COE文件
%% 四舍五入量化，提升无抖动SFDR至60dB以上
%% ==============================================
clc; clear; close all;

depth = 1024;   % ROM深度：10位地址，和你的设计完全匹配
width = 12;     % 数据位宽：12位DAC输出

% 打开文件写入
fid = fopen('sin_rom_round.coe', 'w');

% COE文件头（Vivado标准格式，不能改）
fprintf(fid, 'memory_initialization_radix = 10;\n');
fprintf(fid, 'memory_initialization_vector =\n');

% 逐点生成正弦值，核心：四舍五入替代向下取整
for n = 0 : depth-1
    % 公式：幅值2047.5，直流偏置2047.5，对应0~4095满幅
    sin_val = 2047.5 * sin(2 * pi * n / depth) + 2047.5;
    val = round(sin_val);  % 四舍五入，量化误差正负对称，SFDR更高

    if n == depth-1
        fprintf(fid, '%d;\n', val);  % 最后一行用分号结尾
    else
        fprintf(fid, '%d,\n', val);
    end
end

fclose(fid);
disp('✅ 四舍五入版正弦ROM生成完成');
disp('✅ 文件名：sin_rom_round.coe');
disp('✅ 请用该文件替换Vivado中sin_rom IP的COE文件');