function [stages,times] = load_vmrk_scoring(filename,Fs)
%LOAD_VMRK_SCORING  Extract stages and times from a BrainVision .vmrk scoring file
%
%   Usage:
%       [stages, times] = load_vmrk_scoring(filename, Fs)
%
%   Inputs:
%       filename : char - full filepath to .vmrk file -- required
%       Fs       : double - sampling frequency in Hz -- required
%
%   Outputs:
%       stages : Nx1 double - stage at each time (5=Wake, 4=REM, 3=N1, 2=N2, 1=N3, 0=Undefined)
%       times  : Nx1 double - timestamps for stages (seconds)
%
%   See also: import_vmrk, read_staging
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿
%        Source: https://github.com/preraulab/labcode_main

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


%%


