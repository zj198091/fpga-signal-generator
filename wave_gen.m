clear;clc;
N = 1024;
width = 12;
max_val = 2^width - 1;

t = 0:N-1;
sin_wave = round(max_val/2 + max_val/2 * sin(2*pi*t/N));
square_wave = [ones(1,N/2)*max_val, zeros(1,N/2)];
saw_wave = round(linspace(0, max_val, N));
tri_wave = round([linspace(0,max_val,N/2), linspace(max_val,0,N/2)]);

fid = fopen('sin_wave.coe','w');
fprintf(fid,'MEMORY_INITIALIZATION_RADIX = 10;\n');
fprintf(fid,'MEMORY_INITIALIZATION_VECTOR = \n');
for i = 1:N
    if i == N
        fprintf(fid,'%d;',sin_wave(i));
    else
        fprintf(fid,'%d,\n',sin_wave(i));
    end
end
fclose(fid);

fid = fopen('square_wave.coe','w');
fprintf(fid,'MEMORY_INITIALIZATION_RADIX = 10;\n');
fprintf(fid,'MEMORY_INITIALIZATION_VECTOR = \n');
for i = 1:N
    if i == N
        fprintf(fid,'%d;',square_wave(i));
    else
        fprintf(fid,'%d,\n',square_wave(i));
    end
end
fclose(fid);

fid = fopen('saw_wave.coe','w');
fprintf(fid,'MEMORY_INITIALIZATION_RADIX = 10;\n');
fprintf(fid,'MEMORY_INITIALIZATION_VECTOR = \n');
for i = 1:N
    if i == N
        fprintf(fid,'%d;',saw_wave(i));
    else
        fprintf(fid,'%d,\n',saw_wave(i));
    end
end
fclose(fid);

fid = fopen('tri_wave.coe','w');
fprintf(fid,'MEMORY_INITIALIZATION_RADIX = 10;\n');
fprintf(fid,'MEMORY_INITIALIZATION_VECTOR = \n');
for i = 1:N
    if i == N
        fprintf(fid,'%d;',tri_wave(i));
    else
        fprintf(fid,'%d,\n',tri_wave(i));
    end
end
fclose(fid);

disp('4个波形coe文件全部生成完成！');