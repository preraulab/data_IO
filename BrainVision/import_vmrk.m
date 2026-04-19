function vmrk_table = import_vmrk(filename, dataLines)
%IMPORT_VMRK  Import data from a BrainVision marker (.vmrk) text file
%
%   Usage:
%       vmrk_table = import_vmrk(filename)
%       vmrk_table = import_vmrk(filename, dataLines)
%
%   Inputs:
%       filename  : char - path to .vmrk file -- required
%       dataLines : Nx2 double - row interval(s) to read (default: [13, Inf])
%
%   Outputs:
%       vmrk_table : table - columns EventType, Description, TimeStamp
%
%   Example:
%       vmrk_table = import_vmrk('/data/archive/ez_4A.vmrk', [13, Inf]);
%
%   See also: load_vmrk_scoring, readtable
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿

%% Input handling

% If dataLines is not specified, define defaults
if nargin < 2
    dataLines = [13, Inf];
end

%% Set up the Import Options and import the data
opts = delimitedTextImportOptions("NumVariables", 7);

% Specify range and delimiter
opts.DataLines = dataLines;
opts.Delimiter = [",", "="];

% Specify column names and types
opts.VariableNames = ["Var1", "EventType", "Description", "TimeStamp", "Var5", "Var6", "Var7"];
opts.SelectedVariableNames = ["EventType", "Description", "TimeStamp"];
opts.VariableTypes = ["string", "string", "string", "double", "string", "string", "string"];

% Specify file level properties
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";

% Specify variable properties
opts = setvaropts(opts, ["Var1", "Var5", "Var6", "Var7"], "WhitespaceRule", "preserve");
opts = setvaropts(opts, ["Var1", "EventType", "Var5", "Var6", "Var7"], "EmptyFieldRule", "auto");

% Import the data
vmrk_table = readtable(filename, opts);

end