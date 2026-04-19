function [header, out] = MBFread(filename)
%MBFREAD  Read a file in Multivariable Binary Format (MBF)
%
%   Usage:
%       header = MBFread(filename)
%       [header, variables] = MBFread(filename)
%
%   Inputs:
%       filename : char - path to .mbf file -- required
%
%   Outputs:
%       header    : struct with fields file_info, var_names, var_dims, var_types
%       variables : 1xV cell - loaded variables in file order (only returned when requested)
%
%   Notes:
%       The MBF file layout is:
%
%         Header (ASCII, line-based)
%           Line 1            : file info (filename by default)
%           Line 2            : blank
%           Line 3            : number of variables
%           Line 4            : blank
%           Per variable (4 lines):
%             name            : variable name (e.g. 'My_Var')
%             dimensions      : 'AxBxC...' (e.g. '1x3', '12x4x234')
%             type            : 'single', 'double', 'uint16', 'char', ...
%             blank
%
%         Data section (IEEE little-endian binary)
%           Each variable is written in its declared type. Types followed by
%           a bracketed physical range (e.g. 'int16 [-3000 3000]') are stored
%           as integer indices and are automatically rescaled on read.
%           Non-native types (table, struct, cell, ...) are written as
%           serialized uint8 byte streams.
%
%   See also: MBFwrite, intrange2num, num2intrange
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿
%        Source: https://github.com/preraulab/labcode_main

%Open the file for writing
fileID = fopen(filename,'r');

%Get the file info
file_info = fgetl(fileID);
fgetl(fileID);
%Get the number of variables
num_vars = str2double(fgetl(fileID));
fgetl(fileID);

%Preallocate size
var_names = cell(1, num_vars);
var_dims = cell(1, num_vars);
var_types = cell(1, num_vars);

%Loop and get vet variable info
for ii = 1:num_vars
    var_names{ii} = fgetl(fileID); %Name
    var_dims_str = fgetl(fileID);  %Dimensions
    var_types{ii} = fgetl(fileID); %Variable type
    fgetl(fileID); %Empty link
    
    %Read dimensions from string and truncate if bytestream
    if startsWith(lower(var_types{ii}), 'bytestream')
        var_dims_str = var_dims_str(1:strfind(var_dims_str,' (')-1);
    end
    
    var_dims{ii} = str2num(strrep(var_dims_str,'x',' '));
end

%Construct the header structure
header.file_info = file_info;
header.var_names = var_names;
header.var_dims = var_dims;
header.var_types = var_types;

%Read the data only if the output is selected
if nargout == 2
    out = cell(1, num_vars);
    
    for ii = 1:num_vars
        %Convert from indexed or byteStream if it is not a native data type
        if isnativetype(var_types{ii}) && ~contains(var_types{ii},'[')
            
            if length(var_dims{ii}) == 2
                var_data = fread(fileID, var_dims{ii} , var_types{ii}, 'ieee-le');
            else
                var_data = fread(fileID, prod(var_dims{ii}), var_types{ii}, 'ieee-le');
                var_data = reshape(var_data, var_dims{ii});
            end
            eval([var_names{ii} ' = ' var_types{ii} '(var_data);']);
        elseif contains(var_types{ii},'[') && contains(var_types{ii},']')
            dstring = var_types{ii};
            
            %Extract data and range
            data_type = dstring(1:strfind(dstring,'[')-2);
            data_range = str2num(dstring(strfind(dstring,'['):end));
            
            if ~isinttype(data_type)
                error(['Invalid indexed int data type: ' data_type '. Must be u/int/8/16/32/64.']);
            end
            
            %Read in indexed
            if length(var_dims{ii}) == 2
                idx_data = fread(fileID, var_dims{ii} , data_type, 'ieee-le');
            else
                idx_data = fread(fileID, prod(var_dims{ii}), data_type, 'ieee-le');
                idx_data = reshape(idx_data, var_dims{ii});
            end
            
            %Convert back to double
            var_data = intrange2num(idx_data, data_type, data_range);
            eval([var_names{ii} ' = double(var_data);']);
            
            header.var_types{ii} = ['double (' header.var_types{ii} ')'];
        else %Convert back from byteStream
            var_data = fread(fileID, var_dims{ii} , 'uint8', 'ieee-le');
            eval([var_names{ii} ' = getArrayFromByteStream(uint8(var_data));']);
            
            %Get the data type
            eval(['dtype = class(' var_names{ii} ');']);
            header.var_types{ii} = [dtype ' (byteStream)'];
        end
        
        eval(['out{' num2str(ii) '} = ' var_names{ii} ';']);
        clear var_data;
    end
end

%Close the file
fclose(fileID);

%Checks to see if we need to convert to bytestream
function result = isnativetype(typestr)
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
    'char',...
    'single'};

typestr = lower(typestr);
result = any(contains(typestr, nativetypes)) || contains(typestr,'bit') || contains(typestr,'ubit');

function out = intrange2num(index_values, data_type, data_range)
%INTRANGE2NUM  Converts index data in an integer range data type back to
%double
%
%   Usage:
%   Direct input:
%       out = intrange2num(index_values, data_type, data_range)
%
%   Input:
%       index_values: 1xN vector of index values
%       data_type: string - valid int data type: u/int/8/16/32/64
%       data_range: 1x2 max/min values for data (physical min/max)
%
%   Output:
%       out: 1xN vector of double - converted data values
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
%   Copyright 2024 Michael J. Prerau Laboratory. - http://www.sleepEEG.org
%   Authors: Michael J. Prerau, Ph.D.
%
%   Last modified 03/01/2021
%% ********************************************************************

%Cast back into double for precision
index_values = double(index_values);

%Get data type index range
if isinttype(data_type) %Check if valid int type
    index_range = double([intmin(data_type) intmax(data_type)]);
else
    error('Invalid int data type');
end

%Check that data range is valid
data_range = double(data_range);
if ~issorted(data_range)
    error('Data range (physical min/max) values must be monotonically increasing');
end

%Revert to original values
out = (index_values - index_range(1))/diff(index_range)*diff(data_range)+data_range(1);


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

