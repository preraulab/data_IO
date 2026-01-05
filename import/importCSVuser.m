function tbl = importCSVuser(columnNames, filepath)
%IMPORTCSVUSER  Import selected columns from a delimited file via a modern UI
%
%   Usage:
%       tbl = importCSVuser(columnNames)
%       tbl = importCSVuser(columnNames, filepath)
%
%   Input:
%       columnNames: cell array or string array of column labels to extract (required)
%       filepath: optional string specifying the starting directory (default: current directory)
%
%   Output:
%       tbl: table containing only the selected columns from the file
%********************************************************************

%************************************************************
%                      INPUT HANDLING
%************************************************************
if nargin < 1
    error('At least one input, columnNames, is required.');
end

if ischar(columnNames) || isstring(columnNames)
    columnNames = cellstr(columnNames);
elseif ~iscellstr(columnNames)
    error('columnNames must be a cell array of strings or string array.');
end

if nargin < 2 || isempty(filepath)
    filepath = pwd;
end

%************************************************************
%                      FILE SELECTION
%************************************************************
[filename, pathname] = uigetfile({'*.*', 'All Files (*.*)'}, 'Select a delimited file', filepath);
if isequal(filename,0)
    error('File selection canceled.');
end
fullfilePath = fullfile(pathname, filename);

%************************************************************
%                      CREATE MODERN UI FIGURE
%************************************************************
numCols = length(columnNames);
figHeight = max(350, 130 + 40*numCols); % extra bottom margin
dlgFig = uifigure('Name','Import CSV Settings','Position',[500 300 450 figHeight]);

% Grid layout
grid = uigridlayout(dlgFig, [numCols+3, 2]);
grid.RowHeight = repmat({35},1,numCols+3); 
grid.ColumnWidth = {'1x','0.5x'};
grid.Padding = [15 15 15 40]; % larger bottom margin

%************************************************************
%                      DELIMITER
%************************************************************
uilabel(grid, 'Text','Delimiter:','HorizontalAlignment','right','Tooltip','Select the delimiter used in the file');
delimiterDrop = uidropdown(grid,'Items',{'comma','tab','space','semicolon','pipe'}, ...
    'Value','comma','Tooltip','Select the delimiter used in the file');

%************************************************************
%                      HEADER LINES (text input)
%************************************************************
uilabel(grid,'Text','Header Lines:','HorizontalAlignment','right','Tooltip','Number of header lines (leave blank for autodetect)');
headerEdit = uieditfield(grid,'text','Tooltip','Number of header lines (leave blank for autodetect)');

%************************************************************
%                      COLUMN SELECTION (text input)
%************************************************************
colEdits = gobjects(1,numCols);
for k = 1:numCols
    uilabel(grid,'Text',[columnNames{k} ' Column:'],'HorizontalAlignment','right', ...
        'Tooltip',['Column number for ' columnNames{k}]);
    colEdits(k) = uieditfield(grid,'text','Tooltip',['Enter the column number (integer >=1) for ' columnNames{k}]);
end

%************************************************************
%                      OK BUTTON
%************************************************************
okBtn = uibutton(grid,'Text','OK','ButtonPushedFcn',@(src,event) uiresume(dlgFig));
okBtn.Layout.Row = numCols+3;
okBtn.Layout.Column = [1 2];

% Wait for user
uiwait(dlgFig);

%************************************************************
%                      READ UI VALUES
%************************************************************
if ~isvalid(dlgFig)
    error('Dialog closed before selection.');
end

delimiterStr = delimiterDrop.Value;
switch delimiterStr
    case 'comma', delimiter = ',';
    case 'tab', delimiter = '\t';
    case 'space', delimiter = ' ';
    case 'semicolon', delimiter = ';';
    case 'pipe', delimiter = '|';
    otherwise, delimiter = ','; 
end

% Header lines: validate integer or blank
headerStr = strtrim(headerEdit.Value);
if isempty(headerStr)
    % autodetect
    fid = fopen(fullfilePath,'r');
    firstLine = fgetl(fid);
    fclose(fid);
    if all(isstrprop(firstLine,'digit') | ismember(firstLine,{' ','\t',',',';','|'}))
        headerLines = 0;
    else
        headerLines = 1;
    end
else
    headerLines = str2double(headerStr);
    if isnan(headerLines) || headerLines < 0
        error('Header lines must be a non-negative integer or blank.');
    end
    headerLines = round(headerLines);
end

% Columns: validate integers
colIdx = zeros(1,numCols);
for k = 1:numCols
    colStr = strtrim(colEdits(k).Value);
    colNum = str2double(colStr);
    if isempty(colStr) || isnan(colNum) || colNum < 1
        error('Column number for "%s" must be an integer >= 1.', columnNames{k});
    end
    colIdx(k) = round(colNum);
end

close(dlgFig);

%************************************************************
%                      READ FILE AND EXTRACT COLUMNS
%************************************************************
opts = detectImportOptions(fullfilePath,'Delimiter',delimiter,'NumHeaderLines',headerLines);
opts.SelectedVariableNames = opts.VariableNames(colIdx);
tbl = readtable(fullfilePath, opts);

% Rename output table columns to match input columnNames
tbl.Properties.VariableNames = columnNames;

end
