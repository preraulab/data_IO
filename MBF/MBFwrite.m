function MBFwrite(filename, vars, var_names, var_types, file_info)
%MDFWRITE  Reads a file in Multivariable Binary Format
%
%   Usage:
%   Direct input:
%       MBFwrite(filename, vars, var_names, var_types, file_info)
%
%   Input:
%       filename: string file name
%       vars: 1xV cell array of variables
%       var_names: 1xV cell array of strings with variable names
%       var_types: 1xV cell array of strings with variable data types
%       file_info: string with file info (optional)
%
%     ******* MBF Data Specs *************
%
%     The MBF data format is broken into two sections:
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
%         NOTE: If the data type is indexed to an integer, the data-type will be
%         followed by a range (physical min/max) in brackets (e.g. [-3000 3000]).
%         If the data passed are double, then they will be converted automatically.
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
    
    %Check to see if it needs to be converted to bytestrem
    if contains(var_types{ii},'[') && contains(var_types{ii},']') && isa(vars{ii},'double') || isa(vars,'single')
        dstring = var_types{ii};
        
        %Extract data and range
        data_type = dstring(1:strfind(dstring,'[')-2);
        data_range = str2num(dstring(strfind(dstring,'['):end));
        
        if ~isinttype(data_type)
            error(['Invalid indexed int data type: ' data_type '. Must be u/int/8/16/32/64.']);
        end
        
        %Convert to indexed form
        vars{ii} = num2intrange(vars{ii}, data_type, data_range);
        
        fprintf(fileID, '%s\n', var_dims{ii});
        fprintf(fileID, '%s\n', var_types{ii});
        
        %Replace in cell array for writing
        var_types{ii} = data_type;
        
    elseif ~isIOdatatype(var_types{ii})
        byteStream = getByteStreamFromArray(vars{ii});
        dimstr = ['1x' num2str(length(byteStream)) ' (' var_dims{ii} ')' ];
        fprintf(fileID, [dimstr '\n']);
        fprintf(fileID, ['byteStream (' var_types{ii} ')\n']);
        
        %Display warning when writing
        %warning(['Converting ' var_names{ii} ' from ' var_types{ii} ' to byteStream']);
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
            error('Variables must have a number of dimensions >1');
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
    'schar',...
    'signed char',...
    'short',...
    'long',...
    'double',...
    'float',...
    'float32',...
    'float64',...
    'char'...
    'bit',...
    'ubit',...
    'single'};

typestr = lower(typestr);
result = any(contains(typestr, nativetypes));

function out = num2intrange(values, data_type, data_range)
%NUM2INTRANGE  Converts data to an integer range data type
%
%   Usage:
%   Direct input:
%       out = num2intrange(values, data_type, data_range)
%
%   Input:
%       values: 1xN vector of data values 
%       data_type: string - valid int data type: u/int/8/16/32/64
%       data_range: 1x2 max/min values for data (physical min/max)
%
%   Output:
%       out: 1xN vector of data values index in type data_type
%
%   Example:
%         data_types = {'uint8', 'int8', 'int32', 'int64'}; %Select data type
%         data_range = [-3000,3000]; %Define data range
% 
%         %Create random data spanning range
%         vals = rand(1,10000)*diff(data_range)+data_range(1); 
% 
%         %Loop through several data types to show precision errors
%         for ii = 1:length(data_types)
%             %Select data type
%             data_type = data_types{ii};
% 
%             %Convert data to index
%             idx_vals = num2intrange(vals, data_type, data_range);
%             dbl_vals = intrange2num(idx_vals, data_type, data_range);
% 
%             disp(['MSE precision error for ' data_type ': ' num2str(mean(dbl_vals - vals))]);
%         end
%
%   Copyright 2021 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%   Authors: Michael J. Prerau, Ph.D.
%
%   Last modified 03/01/2021
%% ********************************************************************
%Get data type index range
if isinttype(data_type) %Check if valid int type
    index_range = cast([intmin(data_type) intmax(data_type)],'like',values);
else
    error('Invalid int data type');
end

%Check that data range is valid
data_range = cast(data_range,'like',values);
if ~issorted(data_range)
    error('Data range (physical min/max) values must be monotonically increasing');
end

%Give clipping warning
if max(values(:))> data_range(2) | min(values(:))<data_range(1)
    warning('Data exceeds specified range, clipping will occur.');
end

%Perform conversion in type value
out = (values - data_range(1))/diff(data_range)*diff(index_range) + index_range(1);

%Convert to desired data type for quantizing
out = cast(out,data_type);

%Checks to see if there is a valid int-based datatype
function result = isinttype(typestr)
nativetypes = ...
    {'uint',...
    'uint8',...
    'uint16',...
    'uint32',...
    'uint64',...
    'int8',...
    'int16',...
    'int32',...
    'int64'};

result = any(strcmpi(typestr, nativetypes));

