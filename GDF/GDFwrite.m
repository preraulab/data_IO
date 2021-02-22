function GDFwrite(filename, vars, var_names, var_types, file_info)
%GDFWRITE  Reads a file in Generic Data Format
%
%   Usage:
%   Direct input:
%       GDFwrite(filename, vars, var_names, var_types, file_info)
%
%   Input:
%       filename: string file name
%       vars: 1xV cell array of variables
%       var_names: 1xV cell array of strings with variable names
%       var_types: 1xV cell array of strings with variable data types
%       file_info: string with file info (optional)
%
%     ******* GDF Data Specs *************
%
%     The GDF data format is broken into two sections:
%         A header section, which is line-by-line ascii, and designed to be easily readable
%         A data section, which is binary
%
%     Header:
%         Line 1: File info - This is the filename by default but can contain any relevant information
%         Line 2: blank
%         Line 3: Number of variables
%         Line 4: blank
%
%         For each variable, the data are described as
%             Line 1 (n-1)*3+5: Variable name (e.g. 'My_Var', 'thisVar')
%             Line 2 (n-1)*3+6: Data dimensions (format: AxBxC..., e.g. '1x3', '12x4x234')
%             Line 3 (n-1)*3+7: Data type (e.g. 'single','double', 'uint18','char')
%             Line 4 (n-1)*3+8: blank
%
%     Data Section:
%         For each variable, the data are written in the specified type in binary (IEEE little endian).
%
%         NOTE: Variables can be any set of acceptable MATLAB data type. Native IO data types (e.g. double, uint18, char)
%         will be written as specified but others (e.g. table, struct, cell array, etc.) will be converted into
%         serialized uint8 byteStream format.
%
%   Copyright 2021 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%
%   Last modified 02/22/2021
%% ********************************************************************
%Get number of variables
num_vars = length(vars);

%Compute variable dimensions
var_dims = cell(1, num_vars);

for ii = 1:num_vars
    dimstring = sprintf('%ix',size(vars{ii}));
    dimstring = dimstring(1:end-1);
    var_dims{ii} = dimstring;
end

%Set info default to filename
if nargin<5 || isempty(file_info)
    file_info = filename;
end

%Open file for writing
fileID = fopen(filename,'w');

%Write header information
fprintf(fileID, '%s\n\n', file_info); %Info defaults to name
fprintf(fileID, '%s\n\n', num2str(num_vars)); %Number of variables

%Write variable information
for ii = 1:num_vars
    fprintf(fileID, '%s\n', var_names{ii}); %Variable name
    
    %Check to see if it needs to be converted
    if ~isIOdatatype(var_types{ii})
        byteStream = getByteStreamFromArray(vars{ii});
        dimstr = ['1x' num2str(length(byteStream)) ' (' var_dims{ii} ')' ];
        fprintf(fileID, [dimstr '\n']);
        fprintf(fileID, ['byteStream (' var_types{ii} ')\n']);
        
        %Display warning when writing
        warning(['Converting ' var_names{ii} ' from ' var_types{ii} ' to byteStream']);
        var_types{ii} = 'byteStream';
    else
        fprintf(fileID, '%s\n', var_dims{ii});
        fprintf(fileID, '%s\n', var_types{ii});
    end
    fprintf(fileID, '\n');
end

%Write the data
for ii = 1:num_vars
    if ~strcmpi(var_types{ii},'byteStream')
        if length(var_dims{ii})==2
            fwrite(fileID, vars{ii}, var_types{ii}, 'ieee-le');
        elseif length(var_dims{ii})>2
            fwrite(fileID, reshape(vars{ii}, 1, numel(vars{ii})), var_types{ii}, 'ieee-le');
        else
            error('Variables must have a ndims>1');
        end
    else
        %byteStreams are uint8
        fwrite(fileID, uint8(getByteStreamFromArray(vars{ii})), 'uint8', 'ieee-le');
    end
end

fclose(fileID);

%Checks to see if we need to convert to bytestream
function result = isIOdatatype(typestr)
nativetypes = ...
    {'uint',...
    'uint8',...
    'uint16',...
    'uint32',...
    'uint64',...
    'uchar',...
    'unsigned char',...
    'ushort',...
    'ulong',...
    'int8',...
    'int16',...
    'int32',...
    'int64',...
    'integer*1',...
    'integer*2',...
    'integer*4',...
    'integer*8',...
    'schar',...
    'signed char',...
    'short',...
    'long',...
    'double',...
    'float',...
    'float32',...
    'float64',...
    'real*4',...
    'real*8',...
    'char'...
    'single'};

typestr = lower(typestr);
result = any(strcmpi(typestr, nativetypes)) || contains(typestr,'bit') || contains(typestr,'ubit');
