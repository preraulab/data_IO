function bytestream_save(filename,varargin)
%BYTESTREAM_SAVE Save data to bytestream file
%
%   Usage:
%   bytestream_save(filename, <variables>)
%
%   Input:
%   filename: filename as a string
%   <variables>: list of variables to save: VAR1, VAR2, ...
%
%   Copyright 2024 Michael J. Prerau, Ph.D.
%
%   Last modified 12/05/2017
%% ********************************************************************

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


