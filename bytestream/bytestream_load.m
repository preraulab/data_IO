function out=bytestream_load(filename,varargin)
%BYTESTREAM_LOAD  Load variables stored as uint8 byte streams from a .mat file
%
%   Usage:
%       S = bytestream_load(filename, var1, var2, ...)
%
%   Inputs:
%       filename : char - path to .mat file -- required
%       varargin : char - names of byte-stream variables to load -- required
%
%   Outputs:
%       out : struct - fields named per requested variable, values are deserialized arrays
%
%   Notes:
%       Variables are loaded into the base workspace in addition to the
%       returned struct. Any requested variable that is not a uint8 byte
%       stream is skipped with a warning.
%
%   See also: bytestream_save, getArrayFromByteStream
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿

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


