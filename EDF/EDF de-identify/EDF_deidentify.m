function EDF_deidentify(filename, copy_file)
%EDF_DEIDENTIFY  Deidentify one or more EDF files by blanking patient/recording header fields
%
%   Usage:
%       EDF_deidentify()
%       EDF_deidentify(filename)
%       EDF_deidentify(filename, copy_file)
%
%   Inputs:
%       filename  : char or cell of char - EDF filename(s); launches GUI if omitted
%       copy_file : logical - if true save a '*_deidentified.edf' copy, if false overwrite original (default: true)
%
%   Outputs:
%       none (side effects only)
%
%   Notes:
%       Overwrites the version, patient_id, local_recording_id, and
%       recording-start-date header fields in place. The EDF signal data
%       are not modified.
%
%   See also: EDF_read, blockEdfLoad
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿
%        Source: https://github.com/preraulab/labcode_main

%Sets default to copy file
if nargin == 1
    copy_file = true;
end

%Check to see if any file has been given
if nargin == 0
    [filename, path] = uigetfile('*.*',...
        'Select EDF File(s)', ...
        'MultiSelect', 'on');
    answer = questdlg('Do you want to save a copy or overwrite?', ...
        'Deidentification Menu', ...
        'Save a Copy', 'Overwrite', 'Cancel', 'Cancel');
    
    switch answer
        case 'Save a Copy'
            copy_file = true;
        case 'Overwrite'
            answer2 = questdlg('Are you sure you want to overwrite? Original information will be lost.', ...
                'Deidentification Menu', ...
                'Yes (Overwrite)', 'Cancel', 'Cancel');
            
            if strcmpi(answer2,'Yes (Overwrite)')
                copy_file = false;
            else
                return;
            end
            
        otherwise
            return;
    end
    
else
    path = ''; %Blank path
end

%If a single file, wrap in cell to work with the loop
if ~iscell(filename)
    filename = {filename};
end

%Loop through all files and deidentify
for ii = 1:length(filename)
    filename_full = fullfile(path, filename{ii});
    
    if ~exist(filename_full,'file')
        error(['Invalid filename: ' filename_full]);
    end
    
    if copy_file
        filename_new = [filename_full(1:end-4) '_deidentified.edf'];
        copyfile(filename_full, filename_new);
        
        deidentify(filename_new);
    else
        deidentify(filename_full);
    end
end

function deidentify(filename)
%Open the file to read/write without resetting it to an empty file
fid = fopen(filename, 'r+');

fprintf(fid, '%-8s', '0');   % Version must be 0
fprintf(fid, '%-80s', 'X X X X'); % Remove patient info
fprintf(fid,'%-80s', 'Startdate X X X X'); %Remove recording info
fprintf(fid, '%-8s', '01.01.01'); % Set date as 01.01.01

fclose(fid);