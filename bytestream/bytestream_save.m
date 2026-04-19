function bytestream_save(filename,varargin)
%BYTESTREAM_SAVE  Save variables as uint8 byte streams in a .mat file
%
%   Usage:
%       bytestream_save(filename, var1, var2, ...)
%
%   Inputs:
%       filename : char - path to target .mat file -- required
%       varargin : char - names of caller-workspace variables to save -- required
%
%   Outputs:
%       none (side effects only)
%
%   Notes:
%       Each variable is serialized with getByteStreamFromArray and appended
%       to the .mat file in v6 format.
%
%   See also: bytestream_load, getByteStreamFromArray
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿
%        Source: https://github.com/preraulab/labcode_main

%Check inputs
if any(~cellfun(@isstr,varargin))
    error('Variable names must be strings');
end

%Convert the bytestream and add variable to current workspace
for vv=1:length(varargin)
        eval([varargin{vv}  '= getByteStreamFromArray(evalin(''caller'', ''' varargin{vv} '''));']);
        if exist('test.mat','file')
            eval(['save(''' filename ''', ''' varargin{vv} ''', ''-v6'',''-append'');']);
        else
            eval(['save(''' filename ''', ''' varargin{vv} ''', ''-v6'');']);
        end
end


