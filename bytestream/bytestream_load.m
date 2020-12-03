function out=bytestream_load(filename,varargin)
%BYTESTREAM_LOAD  Load data from bytestream file
%
%   Usage:
%   S=bytestream_load(filename, <variables>)
%
%   Input:
%   filename: filename as a string
%   <variables>: list of variables to load: VAR1, VAR2, ...
%
%   Output:
%   S: a struct with the variables as fieldnames with associated values
%
%   Copyright 2017 Michael J. Prerau, Ph.D.
%
%   Last modified 12/05/2017
%% ********************************************************************

%Check inputs
if any(~cellfun(@isstr,varargin))
    error('Variable names must be strings');
end

%Load the bytestreams
load(filename, varargin{:});

%Set up output if it exists
   if nargout>0
        out=struct;
    end

%Convert the bytestream and add variable to current workspace
for vv=1:length(varargin)
    eval(['isbytestream = isa(' varargin{vv} ',''uint8'');']);

    if ~isbytestream
        warning([varargin{vv} ' is not a uint8 byte stream and will not be loaded']);
    else
        eval(['assignin(''base'', ''' varargin{vv} ''', getArrayFromByteStream(' varargin{vv} '));']);
    end
    
    %Assign output to struct if desired
    if nargout>0
        eval(['out=setfield(out, ''' varargin{vv} ''', ' varargin{vv} ');']);
    end
end


