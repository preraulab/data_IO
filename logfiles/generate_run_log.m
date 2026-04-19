function [run_ID, fname] = generate_run_log(structs, struct_names, varargin)
%GENERATE_RUN_LOG  Write a run-settings log file from a cell array of option structs
%
%   Usage:
%       [run_ID, fname] = generate_run_log(structs, struct_names, 'Name', Value, ...)
%
%   Inputs:
%       structs      : 1xV cell - option structures to log -- required
%       struct_names : 1xV cell of char - variable names for the structures -- required
%
%   Name-Value Pairs:
%       'run_start'  : char - run start timestamp; if empty, generated from datetime (default: '')
%       'file_path'  : char - directory to write the log file into (default: '')
%       'write_file' : logical - whether to write the log to disk (default: true)
%       'verbose'    : logical - whether to echo the log to the command window (default: false)
%
%   Outputs:
%       run_ID : char - unique identifier for the run (currently empty; retained for signature compatibility)
%       fname  : char - filename of the written log ('run_settings_<timestamp>.txt')
%
%   Example:
%       struct_names = {'opt_struct1', 'opt_struct2'};
%
%       opt_struct1.f1 = 'asdf';
%       opt_struct1.f2 = 23;
%       opt_struct1.f3 = [1 2 3 4 9454];
%
%       opt_struct2.f1 = {[1 23 4], 'cheese', 343, 'a'};
%       opt_struct2.f2 = 'this is a struct';
%       opt_struct2.f3 = 'goat';
%
%       structs = {opt_struct1, opt_struct2};
%       generate_run_log(structs, struct_names, 'verbose', true);
%
%   See also: create_log, struct2codestr
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿
%        Source: https://github.com/preraulab/labcode_main

run_ID = '';

% Generate example data
if nargin == 0
    %Run prefix
    struct_names = {'opt_struct1', 'opt_struct2'};

    opt_struct1.f1 = 'asdf';
    opt_struct1.f2 = 23;
    opt_struct1.f3 = [1 2 3 4 9454];

    opt_struct2.f1 = {[1 23 4], 'cheese', 343, 'a'};
    opt_struct2.f2 = 'this is a struct';
    opt_struct2.f3 = 'goat';

    structs{1} = opt_struct1;
    structs{2} = opt_struct2;

    generate_run_log(structs, struct_names, 'run_prefix', 'myrun', 'ID_len', 7);
    return;
end

% Create an input parser
p = inputParser;
p.CaseSensitive = false;

% Add parameters to the input parser
addParameter(p, 'run_start', '', @(x) validateattributes(x, {'char'}, {'row'}));
addParameter(p, 'file_path', '', @(x) validateattributes(x, {'char'}, {'row'}));
addParameter(p, 'write_file', true, @(x) validateattributes(x, {'logical'}, {'scalar'}));
addParameter(p, 'verbose', false, @(x) validateattributes(x, {'logical'}, {'scalar'}));

% Parse inputs
parse(p,varargin{:});

% Retrieve parsed inputs
run_start = p.Results.run_start;
file_path = p.Results.file_path;
write_file = p.Results.write_file;
verbose = p.Results.verbose;

assert(~(isempty(structs)),'Must have structs');
if ~isempty(structs)
    assert(iscell(structs),'Structs must be a cell');
end

%% WRITE TIME
% Log start time
if isempty(run_start)
    dtime = datetime;
    dtime.Format = 'yyyyMMdd_HHmmss';
    run_start = char(dtime);
end

fname = strcat('run_settings_',run_start,'.txt');

assert(is_valid_matlab_filename(fname),...
    ['Must be valid filename: Under 63 chars, start with a letter,' ...
    'contain only letters, digits, and underscores, no reserved keywords']);

%Open up the file
if write_file
    fid = fopen(fullfile(file_path,fname), 'w');
    assert(fid ~= -1, ['Could not open file for writing: ' fullfile(file_path,fname)]);
    cleanupObj = onCleanup(@() fclose(fid)); %#ok<NASGU>
end

%% WRITE ID
if verbose
    disp(['%% ' fname])
    disp(' ')
end

if write_file
    fprintf(fid, '%%%% %s\n\n', fname);
end

if verbose
    disp('% Start Time')
    disp(['run_start = ' run_start ''';'])
    disp(' ');
end

if write_file
    fprintf(fid, '%% Start Time\n');
    fprintf(fid, 'run_start = ''%s'';\n\n', run_start);
end

%% WRITE STRUCTS
if ~isempty(structs)
    % Generate structure code
    for ii = 1:length(structs)
        struct_name = struct_names{ii};
        % Generate Option Structure
        if verbose
            disp(['% Generate ' struct_name])
        end
        if write_file
            fprintf(fid, '%% Generate %s\n', struct_name);
        end

        struct_code = struct2codestr(structs{ii}, struct_name);
        if verbose
            disp(struct_code)
        end

        if write_file
            fprintf(fid, '%s\n', struct_code);
        end
    end
end

function valid = is_valid_matlab_filename(filename)
% Check if the filename is empty or exceeds 63 characters
if isempty(filename) || length(filename) > 63
    valid = false;
    return;
end

% Check if the filename starts with a letter
if ~isletter(filename(1))
    valid = false;
    return;
end

% Check if the filename contains only letters, digits, and underscores
% if ~isvarname(filename(1:end-2))
%     valid = false;
%     return;
% end

% Check if the filename is a reserved MATLAB keyword
if iskeyword(filename)
    valid = false;
    return;
end

% Check if the filename ends with a period or space
if endsWith(filename, '.') || endsWith(filename, ' ')
    valid = false;
    return;
end

% If all checks pass, the filename is valid
valid = true;
