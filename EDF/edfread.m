%EDFREAD reads EEG data from the EDF data format
%
%   Usage:
%   [data, HDR] = edfread(filename, savename)
%
%   Input:
%   filename: string with name of .edf file to be read
%   savename: string to use as name of saved .mat file with data
%
%   Output:
%   data: EEG data in format <channels> X <time>, for SEDline, the third
%   channel is the FpZ reference electrode
%   HDR: structure containing information from header of .edf file
%
%   Example:
%
%   See also edfrepair, sopen, sread
%
%   Copyright 2011
%
%   Last modified 08/26/2011
%********************************************************************

function [data, HDR] = edfread(filename, savename)

%Add sopen function if not in header
if isempty(which('sopen'))
%         addpath(genpath('/autofs/cluster/purdonlab/code/matlab_packages/eeglab10.2.2.4b'));
    addpath(genpath('/autofs/cluster/purdonlab/code/matlab_packages/eeglab10.2.2.4b/external/biosig-partial/'));
end

% Get header information from EDF, repairing header if necessary
try
    HDR=sopen(filename,'r',1,'OVERFLOWDETECTION:OFF');
    sclose(HDR);
    
    if isfield(HDR,'Label');
        chanvars.labels_all=lower(HDR.Label);
    end
catch ME
    edfdata = fread(fopen(filename));
    
    for i=1:256*6
        if edfdata(i)==0;
            edfdata(i)=32;
        end
    end
    
    edfdata(89:97)=[83; 116; 97; 114; 116; 100; 97; 116; 101];
    
    fwrite(fopen([filename(1:end-4) '_repaired.edf'], 'w'), edfdata);
    filename=[filename(1:end-4) '_repaired.edf'];
    
    HDR=sopen(filename,'r',1,'OVERFLOWDETECTION:OFF');
    sclose(HDR);
    if isfield(HDR,'Label');
        chanvars.labels_all=lower(HDR.Label);
    end
end

% Get data channels
chanvars.labels={};
for i=1:length(chanvars.labels_all)
    chanvars.labels(end+1)=chanvars.labels_all(i);
    disp(['Extracting channel ' num2str(length(chanvars.labels)) ' of '...
        num2str(size(chanvars.labels_all,1)) '.']);
    HDR=sopen(filename,'r',i,'OVERFLOWDETECTION:OFF');
    [S,HDR]=sread(HDR);
    S=S(:)';
    %size(S)
    data(i,:) = S;
    
    sclose(HDR);
end

Fs = HDR.SampleRate;
t=[(1/Fs):(1/Fs):(size(data,2)/Fs)];

if nargin==2
    % Save data  and header structure to .mat file
    save(strcat(savename,'.mat'), 'data', 't', 'Fs', 'HDR','-v7.3');
end
