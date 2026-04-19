function out = num2intrange(values, data_type, data_range)
%NUM2INTRANGE  Convert double data to an integer type by mapping a physical range to its full int range
%
%   Usage:
%       out = num2intrange(values, data_type, data_range)
%
%   Inputs:
%       values     : 1xN numeric - data values to encode -- required
%       data_type  : char - target int type ('uint8','int16',...) -- required
%       data_range : 1x2 double - physical [min max] to map across full int range -- required
%
%   Outputs:
%       out : 1xN data_type - values quantized to the requested integer type
%
%   Notes:
%       Values outside data_range are clipped by the integer cast and a
%       warning is emitted.
%
%   Example:
%       data_types = {'uint8', 'int8', 'int32', 'int64'};
%       data_range = [-3000, 3000];
%       vals = rand(1,10000) * diff(data_range) + data_range(1);
%       for ii = 1:length(data_types)
%           data_type = data_types{ii};
%           idx_vals = num2intrange(vals, data_type, data_range);
%           dbl_vals = intrange2num(idx_vals, data_type, data_range);
%           disp(['MSE precision error for ' data_type ': ' num2str(mean(dbl_vals - vals))]);
%       end
%
%   See also: intrange2num, MBFread, MBFwrite
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿
%        Source: https://github.com/preraulab/labcode_main

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