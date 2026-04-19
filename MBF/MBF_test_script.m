%MBF_TEST_SCRIPT  Benchmark MBF read/write throughput vs. native .mat for EEG-size data
%
%   Usage:
%       run MBF_test_script
%
%   Inputs:
%       none
%
%   Outputs:
%       none (prints timing comparison to the command window)
%
%   Notes:
%       Creates large random arrays, writes and reads them in both MBF
%       and .mat formats, reports the relative read/write speedup, then
%       deletes the temporary files.
%
%   See also: MBFread, MBFwrite
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿

clear;
clc;

%Create a test file
file_name = 'test_file';
file_info = 'This is the file info section';

%% CREATE SAMPLE DATA

%Create EEG-like data
% Fs = 500;
% hrs = 8;
% chans = 129;

spect_dim = [551581, 308];

Var_1 = single(randn(spect_dim(1), spect_dim(2)));
vars{1} = Var_1;
var_names{1} = 'spect';
var_types{1} = 'single';

% N-D single data
Var_2 = randn(1,spect_dim(1));
vars{2} = Var_2;
var_names{2} = 'stimes';
var_types{2} = 'double';

% N-D single data
Var_3 = randn(1,spect_dim(2));
vars{3} = Var_3;
var_names{3} = 'sfreqs';
var_types{3} = 'double';

% N-D single data
Var_4 = randn(1,spect_dim(1));
vars{4} = Var_4;
var_names{4} = 'stages_in_stimes';
var_types{4} = 'double';


% % String data
% Var_3 = 'This is my string variable';
% vars{3} = Var_3;
% var_names{3} = 'Var_3';
% var_types{3} = 'char';
% 
% % Cell array data
% Var_4 = {1,'234',34.5343,randn(3)};
% vars{4} = Var_4;
% var_names{4} = 'Var_4';
% var_types{4} = 'cell';
% 
% % Structure data
% LastName = {'Sanchez';'Johnson';'Li';'Diaz';'Brown'};
% Age = [38;43;38;40;49];
% Smoker = logical([1;0;1;0;1]);
% Height = [71;69;64;67;64];
% Weight = [176;163;131;133;119];
% BloodPressure = [124 93; 109 77; 125 83; 117 75; 122 80];
% Var_5 = table(LastName,Age,Smoker,Height,Weight,BloodPressure);
% vars{5} = Var_5;
% var_names{5} = 'Var_5';
% var_types{5} = 'table';
% 
% Var_6.field1 = 'field 1';
% Var_6.field2 = 23498;
% Var_6.field3 = 1:1000;
% vars{6} = Var_6;
% var_names{6} = 'Var_6';
% var_types{6} = 'structure';
% 
% % Int indexed data
% Var_7 = rand(3,10000)*6000-3000;
% vars{7} = Var_7;
% var_names{7} = 'Var_7';
% var_types{7} = 'int16 [-3000 3000]';

%% PERFORM IO TEST

%GDF write test
tic;
MBFwrite([file_name '.mbf'], vars, var_names, var_types, file_info);
MBF_write = toc;
disp(['MBF write in ' num2str(MBF_write) ' seconds']);

tic;
[hdr, out] = MBFread([file_name '.mbf']);
MBF_read = toc;
disp(['MBF read in ' num2str(MBF_read) ' seconds']);

disp(' ');

%Mat write test
tic;
% save([file_name '.mat'],'Var_1','Var_2','Var_3','Var_4','Var_5','Var_6','-v7.3');
save([file_name '.mat'],'Var_1','Var_2','Var_3','Var_4','-v7.3');
MAT_write = toc;
disp(['MAT write in ' num2str(MAT_write) ' seconds']);

tic;
load([file_name '.mat']);
MAT_read = toc;
disp(['MAT read in ' num2str(MAT_read) ' seconds']);

disp(' ');
pdiff = (MAT_read - MBF_read) / MBF_read * 100;
disp(['Read speed up of ' num2str(pdiff) '%']);
pdiff = (MAT_write - MBF_write) / MBF_read * 100;
disp(['Write speed up of ' num2str(pdiff) '%']);

%Delete test files
delete([file_name '.mbf']);
delete([file_name '.mat']);


