%GDFREAD  Reads a file in Generic Data Format
%
%   Usage:
%   Direct input:
%       [header, variables] = GDFread(filename)
%
%   Input:
%       filename: string file name
%
%   Output:
%       header: header structure
%       variables: 1xV cell array of variables
%
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

function [hdr, out] = GDFread(filename)
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
hdr.file_info = file_info;
hdr.var_names = var_names;
hdr.var_dims = var_dims;
hdr.var_types = var_types;

%Read the data only if the output is selected
if nargout == 2
    out = cell(1, num_vars);
    
    for ii = 1:num_vars
        %Convert from byteStream if it is not a native data type
        if isnativetype(var_types{ii})
            if length(var_dims{ii}) == 2           
                var_data = fread(fileID, var_dims{ii} , var_types{ii}, 'ieee-le');
            else
                var_data = fread(fileID, prod(var_dims{ii}), var_types{ii}, 'ieee-le');
                var_data = reshape(var_data, var_dims{ii});
            end
            
            eval([var_names{ii} ' = ' var_types{ii} '(var_data);']);
        else
            var_data = fread(fileID, var_dims{ii} , 'uint8', 'ieee-le');
            eval([var_names{ii} ' = getArrayFromByteStream(uint8(var_data));']);
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
    'char',...
    'single'};

typestr = lower(typestr);
result = any(strcmpi(typestr, nativetypes)) || contains(typestr,'bit') || contains(typestr,'ubit');


