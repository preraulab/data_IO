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
%   Author: Michael J. Prerau, Ph.D.
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
end


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
end