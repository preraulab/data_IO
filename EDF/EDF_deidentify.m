function EDF_deidentify(filename, copy_file)
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
fprintf(fid, '%-80s', 'DEIDENTIFIED'); % Remove patient info
fprintf(fid,'%-80s', 'DEIDENTIFIED'); %Remove recording info
fprintf(fid, '%02i.%02i.%02i', 1,1,1); % Set date as 01.01.01

fclose(fid);