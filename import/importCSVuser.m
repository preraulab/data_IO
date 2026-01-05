function tbl = importCSVuser(columnNames, filepath)
%IMPORTCSVUSER  Import selected columns from a delimited file via a modern UI
%
%   Usage:
%       tbl = importCSVuser(columnNames)
%       tbl = importCSVuser(columnNames, filepath)
%
%   Input:
%       columnNames: char, string scalar, string array, or cell array of strings
%                    specifying column labels to extract (required)
%       filepath: optional string specifying the starting directory
%                 (default: current directory)
%
%   Output:
%       tbl: table containing only the selected columns from the file
%
%   Example:
%       tbl = importCSVuser("Temperature");
%
%       cols = {'Time','Pressure','Velocity'};
%       tbl = importCSVuser(cols);
%
%********************************************************************

%************************************************************
%                      INPUT HANDLING
%************************************************************
if nargin < 1
    error('At least one input, columnNames, is required.');
end

% Normalize columnNames
if ischar(columnNames) || (isstring(columnNames) && isscalar(columnNames))
    columnNames = {char(columnNames)};
elseif isstring(columnNames)
    columnNames = cellstr(columnNames);
elseif ~iscellstr(columnNames)
    error('columnNames must be char, string, string array, or cell array of strings.');
end

if nargin < 2 || isempty(filepath)
    filepath = pwd;
end

%************************************************************
%                      FILE SELECTION
%************************************************************
[filename, pathname] = uigetfile({'*.*','All Files (*.*)'}, ...
    'Select a delimited file', filepath);
if isequal(filename,0)
    error('File selection canceled.');
end
fullfilePath = fullfile(pathname, filename);

%************************************************************
%                      CREATE UI
%************************************************************
numCols = numel(columnNames);
figHeight = max(350, 130 + 40*numCols);

dlgFig = uifigure('Name','Import CSV Settings', ...
    'Position',[500 300 460 figHeight]);

grid = uigridlayout(dlgFig, [numCols+3, 2]);
grid.RowHeight = repmat({34},1,numCols+3);
grid.ColumnWidth = {'1x','0.6x'};
grid.Padding = [15 15 15 40];

customDelimiter = [];
previousDelimiter = 'comma';

%************************************************************
%                      DELIMITER
%************************************************************
uilabel(grid,'Text','Delimiter:','HorizontalAlignment','right');
delimiterDrop = uidropdown(grid,...
    'Items',{'comma','tab','space','semicolon','pipe','custom'},...
    'Value','comma',...
    'ValueChangedFcn',@delimiterChanged);

%************************************************************
%                      HEADER LINES
%************************************************************
uilabel(grid,'Text','Header Lines:','HorizontalAlignment','right');
headerEdit = uieditfield(grid,'text',...
    'Tooltip','Leave blank to autodetect');
headerEdit.ValueChangedFcn = @(src,~)validateHeader(src);

%************************************************************
%                      COLUMN INPUTS
%************************************************************
colEdits = gobjects(1,numCols);
for k = 1:numCols
    uilabel(grid,'Text',[columnNames{k} ' Column:'],...
        'HorizontalAlignment','right');
    colEdits(k) = uieditfield(grid,'text',...
        'Tooltip','Required integer >= 1');
    colEdits(k).ValueChangedFcn = @(src,~)validateColumn(src);
end

%************************************************************
%                      OK BUTTON
%************************************************************
okBtn = uibutton(grid,'Text','OK',...
    'Enable','off',...
    'ButtonPushedFcn',@(src,~)uiresume(dlgFig));
okBtn.Layout.Row = numCols+3;
okBtn.Layout.Column = [1 2];

validateAll();
uiwait(dlgFig);

%************************************************************
%                      FINAL VALIDATION
%************************************************************
if ~isvalid(dlgFig)
    error('Dialog closed before completion.');
end
validateAll(true);

%************************************************************
%                      PARSE DELIMITER
%************************************************************
switch delimiterDrop.Value
    case 'comma', delimiter = ',';
    case 'tab', delimiter = '\t';
    case 'space', delimiter = ' ';
    case 'semicolon', delimiter = ';';
    case 'pipe', delimiter = '|';
    case 'custom', delimiter = customDelimiter;
end

%************************************************************
%                      HEADER LINES
%************************************************************
headerStr = strtrim(headerEdit.Value);
if isempty(headerStr)
    fid = fopen(fullfilePath,'r');
    firstLine = fgetl(fid);
    fclose(fid);
    if all(isstrprop(firstLine,'digit') | ...
            ismember(firstLine,{',',';','|',' ','\t'}))
        headerLines = 0;
    else
        headerLines = 1;
    end
else
    headerLines = round(str2double(headerStr));
end

%************************************************************
%                      COLUMN NUMBERS
%************************************************************
colIdx = zeros(1,numCols);
for k = 1:numCols
    colIdx(k) = round(str2double(colEdits(k).Value));
end

close(dlgFig);

%************************************************************
%                      READ FILE
%************************************************************
opts = detectImportOptions(fullfilePath,...
    'Delimiter',delimiter,...
    'NumHeaderLines',headerLines);

opts.SelectedVariableNames = opts.VariableNames(colIdx);
tbl = readtable(fullfilePath, opts);
tbl.Properties.VariableNames = columnNames;

%************************************************************
%                      NESTED FUNCTIONS
%************************************************************
    function delimiterChanged(src,~)
        if strcmp(src.Value,'custom')
            answer = inputdlg('Enter a single-character delimiter:', ...
                'Custom Delimiter',1,{'|'});
            if isempty(answer) || isempty(answer{1}) || numel(answer{1}) ~= 1
                src.Value = previousDelimiter;
                return
            end
            customDelimiter = answer{1};
        else
            previousDelimiter = src.Value;
        end
    end

    function validateHeader(src)
        v = strtrim(src.Value);
        if isempty(v)
            src.BackgroundColor = 'white';
        else
            n = str2double(v);
            if isnan(n) || n < 0 || mod(n,1)~=0
                src.BackgroundColor = [1 0.85 0.85];
            else
                src.BackgroundColor = 'white';
            end
        end
        validateAll();
    end

    function validateColumn(src)
        v = strtrim(src.Value);
        n = str2double(v);
        if isempty(v) || isnan(n) || n < 1 || mod(n,1)~=0
            src.BackgroundColor = [1 0.85 0.85];
        else
            src.BackgroundColor = 'white';
        end
        validateAll();
    end

    function validateAll(finalCheck)
        if nargin < 1, finalCheck = false; end
        valid = true;
        for i = 1:numCols
            v = strtrim(colEdits(i).Value);
            n = str2double(v);
            if isempty(v) || isnan(n) || n < 1 || mod(n,1)~=0
                valid = false;
            end
        end
        okBtn.Enable = matlab.lang.OnOffSwitchState(valid);
        if finalCheck && ~valid
            error('All column fields must contain valid integer values >= 1.');
        end
    end
end
