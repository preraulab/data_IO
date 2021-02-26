clear;
clc;

%Create a test file
file_name = 'test_file';
file_info = 'This is the file info section';

%Create variables
Fs = 200;
hrs = 3;
chans = 6;

Var_1 = randn(Fs*3600*hrs, chans);
vars{1} = Var_1;
var_names{1} = 'Var_1';
var_types{1} = 'double';

Var_2 = single(randn(1,10,3,2,9));
vars{2} = Var_2;
var_names{2} = 'Var_2';
var_types{2} = 'single';

Var_3 = 'This is my string variable';
vars{3} = Var_3;
var_names{3} = 'Var_3';
var_types{3} = 'char';

Var_4 = {1,'234',34.5343,randn(3)};
vars{4} = Var_4;
var_names{4} = 'Var_4';
var_types{4} = 'cell';

LastName = {'Sanchez';'Johnson';'Li';'Diaz';'Brown'};
Age = [38;43;38;40;49];
Smoker = logical([1;0;1;0;1]);
Height = [71;69;64;67;64];
Weight = [176;163;131;133;119];
BloodPressure = [124 93; 109 77; 125 83; 117 75; 122 80];
Var_5 = table(LastName,Age,Smoker,Height,Weight,BloodPressure);
vars{5} = Var_5;
var_names{5} = 'Var_5';
var_types{5} = 'table';

Var_6.field1 = 'field 1';
Var_6.field2 = 23498;
Var_6.field3 = 1:1000;
vars{6} = Var_5;
var_names{6} = 'Var_6';
var_types{6} = 'structure';

%GDF write test
tic;
MBFwrite([file_name '.mbf'], vars, var_names, var_types, file_info);
[hdr, out] = MBFread([file_name '.mbf']);
MBFt = toc;
disp(['MBF I/O in ' num2str(MBFt) ' seconds']);

%Mat write test
tic;
save([file_name '.mat'],'Var_1','Var_2','Var_3','Var_4','Var_5','Var_6','-v7.3');
load([file_name '.mat']);
MATt = toc;
disp(['MAT I/O in ' num2str(MATt) ' seconds']);

disp(' ');
pdiff = (MATt - MBFt) / MBFt * 100;
disp(['Speed up of ' num2str(pdiff) '%']);

%Delete test files
delete([file_name '.mbf']);
delete([file_name '.mat']);


