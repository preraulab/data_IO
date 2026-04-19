function out = intrange2num(index_values, data_type, data_range)
%INTRANGE2NUM  Convert integer-indexed values back to double using a physical min/max range
%
%   Usage:
%       out = intrange2num(index_values, data_type, data_range)
%
%   Inputs:
%       index_values : 1xN numeric - integer-coded values -- required
%       data_type    : char - int type used for the coding ('uint8','int16',...) -- required
%       data_range   : 1x2 double - physical [min max] the integer range maps to -- required
%
%   Outputs:
%       out : 1xN double - values rescaled from integer index range back to physical range
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
%   See also: num2intrange, MBFread, MBFwrite
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿

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