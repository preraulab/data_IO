function [stages,times] = load_vmrk_scoring(filename,Fs)
% load_vmrk_scoring: extract stages and times from vmrk scoring file
%
% Inputs:
%       filename: char - full filepath to vmrk 
%       Fs: double - sampling frequency
%
% Outputs:
%       stages: 1D double - vector indicating stage at each time in times (5=WAKE,4=REM,
%                           3=NREM1,2=NREM2,1=NREM3,0=Undefined)
%       times: 1D double - vector of timestamps for stages (seconds)
%
%   Copyright 2020 Michael J. Prerau, Ph.D. - http://www.sleepEEG.org
%   Last modified 
%       06/03/2022 - created - Tom & Mike
%% ********************************************************************

% Load vmrk table
vmrk_table = import_vmrk(filename);

% Get events with valid values
event_mask = strcmpi(vmrk_table.EventType,'Event') & ~ismissing(vmrk_table.Description) & ~isnan(vmrk_table.TimeStamp); 

% Get description and time stamp for each event
stage_table = vmrk_table(event_mask,{'Description','TimeStamp'});

% Create time stamps 
times = (stage_table.TimeStamp - 1) ./ Fs;

% Preallocate stages
stages = zeros(sum(event_mask),1);

% Recode stages
stages(strcmpi(stage_table.Description,'Wake') | strcmpi(stage_table.Description,'W')) = 5;
stages(strcmpi(stage_table.Description,'REM') | strcmpi(stage_table.Description,'R')) = 4;
stages(strcmpi(stage_table.Description,'S1') | strcmpi(stage_table.Description,'Stage1') | strcmpi(stage_table.Description,'N1')) = 3;
stages(strcmpi(stage_table.Description,'S2') | strcmpi(stage_table.Description,'Stage2') | strcmpi(stage_table.Description,'N2')) = 2;
stages(strcmpi(stage_table.Description,'S3') | strcmpi(stage_table.Description,'Stage3') | strcmpi(stage_table.Description,'N3')) = 1;

% Add undefined stage at end to mark end of scoring
stages(end+1) = 0;
times(end+1) = times(end) + 1/Fs;


end

