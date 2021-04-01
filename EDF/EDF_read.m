function [header, data, annotations] = EDF_read(filename,varargin)
%EDF_read Read data from the EDF or EDF+ file (MJP edited from edfread)
%   [HEADER, DATA, ANNOTATIONS] = EDFREAD(FILENAME) reads signal data from each record in the
%   EDF or EDF+ file specified in FILENAME. DATA is returned as a
%   timetable. Each row of DATA is a record and each variable is a signal.
%   RowTimes of the timetable correspond to the start time of each data
%   record relative to the start time of the file recording.
%
%   [HEADER, DATA, ANNOTATIONS] = EDFREAD(...,'SelectedSignals',SIGNAMES) reads from FILENAME
%   the signals whose names are specified in the string vector SIGNAMES.
%   DATA is a timetable with a variable for each of the names specified in
%   SIGNAMES. If SIGNAMES is not specified, EDFREAD reads the data of all
%   the signals in the EDF or EDF+ file.
%
%   [HEADER, DATA, ANNOTATIONS] = EDFREAD(...,'SelectedDataRecords',RECORDINDICES) reads from
%   FILENAME the data records specified in the vector RECORDINDICES. The
%   integers in RECORDINDICES must be unique and strictly increasing.
%   DATA is a timetable with number of rows equal to the number of indices
%   specified in RECORDINDICES. If RECORDINDICES is not specified, EDFREAD
%   reads all the data records in the EDF or EDF+ file.
%
%
%   [HEADER, DATA, ANNOTATIONS] = = EDFREAD(...) also returns a timetable with any
%   annotations present in the data records. The ANNOTATIONS timetable
%   contains these variables:
%
%   Onset      - Time at which each annotation occurred, specified either
%                as a datetime array indicating absolute times or as a
%                duration array indicating relative times in seconds
%                measured from the start time of the file.
%   Annotation - A string containing the text of each annotation.
%   Duration   - A duration scalar indicating the duration of the event
%                described by each annotation. If the file does not specify
%                annotation durations, this variable is returned as
%                NaN.
%
%   If there are no annotations in the file, ANNOTATIONS is returned as
%   an empty timetable.
%
%   % Example 1:
%      % Read all the signal data from the EDF file example.edf
%      hdr = EDF_read('example.edf')
%
%   % Example 2:
%      % Read the data for the signal "ECG" in the EDF file example.edf
%      [hdr,data,annotations] = EDF_read('example.edf','SelectedSignals',"ECG")
%
%   % Example 3:
%      % Read the first, third, and fifth data records of the EDF file
%      % example.edf
%      [hdr, data] = EDF_read('example.edf','SelectedDataRecords',[1 3 5])
%
%   See also EDFREAD, EDFINFO.

%   References:
% 	  [1] Bob Kemp, Alpo Värri, Agostinho C. Rosa, Kim D. Nielsen, and
%         John Gade. "A simple format for exchange of digitized polygraphic
%         recordings." Electroencephalography and Clinical
%         Neurophysiology 82 (1992): 391-393.
% 	  [2] Bob Kemp and Jesus Olivan. "European data format 'plus' (EDF+),
%         an EDF alike standard format for the exchange of physiological
%         data." Clinical Neurophysiology 114 (2003): 1755-1761.

%   Copyright 2020 The MathWorks, Inc.

% Check number of input arguments
narginchk(1,9);

% Convert string to characters
[filename, varargin{:}] = convertStringsToChars(filename, varargin{:});

% Parse Name-Value pairs
[timeFormat, signals,  tempRecords] = parseInputs(filename,varargin{:});

% Error out when the file extension is not .edf/.EDF
[~, ~, ext] = fileparts(filename);
if ~strcmpi(ext,'.edf')
    error(message('signal:edf:InvalidFileExt'));
end

% Get file ID based on the file name.
[fid, fileInfo] = openFile(filename);

% Close the opened file using onCleanup
cleanup = onCleanup(@() fclose(fid));

try
    % Read the Header details
    [version, patient, recording, startDate, startTime, headerBytes,...
        reserve, numDataRecords, dataRecordDuration, numSignals,...
        sigLabels, transducerType, physicalDimension, physicalMinimum,...
        physicalMaximum, digitalMinimum, digitalMaximum, prefilter,...
        numSamples, sigReserve] = readHeader(fid);
    
catch
    error(message('signal:edf:EDFFileNotCompliant', filename));
end

% Validate EDF/EDF+ files
validateEDF(filename, fileInfo, version, startDate, startTime,...
    headerBytes, reserve, numDataRecords, numSignals,...
    sigLabels, numSamples, transducerType, physicalDimension,...
    physicalMinimum, physicalMaximum, digitalMinimum, digitalMaximum, ...
    prefilter, sigReserve, dataRecordDuration, mfilename);


if isempty(signals)
    signalsIdx = 1:numSignals;
else
    % Using ismember check whether all the signals
    [sigExists, signalsIdx] = ismember(signals,sigLabels);
    
    % Check whether all the signals are specified using SelectedSignals
    % are valid or not
    if ~all(sigExists)
        error(message('signal:edf:InvalidSignalLabel', filename));
    end
end

header.Filename = string(fileInfo.name);
header.FileModDate = string(datestr(fileInfo.datenum));
header.FileSize = fileInfo.bytes;
header.Version = string(version);
header.Patient = string(patient);
header.Recording = string(recording);
header.StartDate = string(startDate);
header.StartTime = string(startTime);
header.HeaderBytes = headerBytes;
header.Reserved = reserve;
header.NumDataRecords = numDataRecords;
header.DataRecordDuration = seconds(dataRecordDuration);
header.NumSignals = nnz(signalsIdx);
header.SignalLabels = sigLabels(signalsIdx);
header.TransducerTypes = transducerType(signalsIdx);
header.PhysicalDimensions = physicalDimension(signalsIdx);
header.PhysicalMin = physicalMinimum(signalsIdx);
header.PhysicalMax = physicalMaximum(signalsIdx);
header.DigitalMin = digitalMinimum(signalsIdx);
header.DigitalMax = digitalMaximum(signalsIdx);
header.Prefilter = prefilter(signalsIdx);
header.NumSamples = numSamples(signalsIdx);
header.SignalReserved = sigReserve(signalsIdx);


if nargout == 1
    return;
end

% Check for Annotations signal label
annotationExist = strcmpi(sigLabels, 'EDF Annotations');



if (~isempty(tempRecords))
    records = tempRecords;
elseif (numDataRecords ~= -1)
    records = 1:numDataRecords;
else
    records = [];
end

% Check whether the file has only annotations or not
tDataRecordDurationFlag = (dataRecordDuration == 0);

% Read annotations and data from EDF files
if tDataRecordDurationFlag
    % Read only annotations when dataRecordDuration is 0 which is supported
    % only in EDF+ files
    
    if isempty(records)
        [annotations,data] = readDataAll(fid, filename,...
            sigLabels, numDataRecords, physicalMaximum, physicalMinimum, ...
            digitalMaximum, digitalMinimum, numSignals, numSamples,...
            [], [], dataRecordDuration, true);
    else
        [annotations,data] = readData(fid, filename,...
            sigLabels, numDataRecords, physicalMaximum, physicalMinimum, ...
            digitalMaximum, digitalMinimum, numSignals, numSamples,...
            [], [], dataRecordDuration, true);
    end
else
    % Read annotations and data for non-zero dataRecordDuration
    if isempty(records)
        [annotations,data] = readDataAll(fid, filename,...
            sigLabels, numDataRecords, physicalMaximum, physicalMinimum, ...
            digitalMaximum, digitalMinimum, numSignals, numSamples,...
            signalsIdx, records, dataRecordDuration, false);
    else
        [annotations,data] = readData(fid, filename,...
            sigLabels, numDataRecords, physicalMaximum, physicalMinimum, ...
            digitalMaximum, digitalMinimum, numSignals, numSamples,...
            signalsIdx, records, dataRecordDuration, false);
    end
end

% if (isempty(records))
%     records = 1:size(data,1);
% end

% Time Table computations
if (any(annotationExist))
    [~, onset, annotations,...
        tempDuration] = readAnnotations(annotations);
    %recordTimes = recordTimes(records);
    annotations = timetable(onset,annotations,tempDuration,...
        'VariableNames',["Annotations","Duration"]);
else
    annotations = timetable(duration.empty(0,1),...
        [],duration.empty(0,1),'VariableNames',...
        ["Annotations","Duration"]);
    %   recordTimes = (records.'- 1).* seconds(dataRecordDuration);
end
annotations.Properties.DimensionNames{1} = 'Onset';

tTimeFormatFlag = strcmp(timeFormat,'datetime');
if tTimeFormatFlag
    startDate = datetime([startDate '.' startTime],'InputFormat',...
        'dd.MM.yy.HH.mm.ss');
    % recordTimes = recordTimes + startDate;
    if isempty(annotations)
        tEmpty = zeros(0,1);
        annotations.Onset = datetime(tEmpty, tEmpty, tEmpty);
    else
        annotations.Onset = annotations.Onset + startDate;
    end
end

if ~issortedrows(annotations)
    annotations = sortrows(annotations);
end

%Parse and validate given inputs
function [timeFormat, signals, records] = parseInputs(filename,...
    varargin)
ip = inputParser;
ip.addRequired('filename', ...
    @(x) validateattributes(x,{'char','string'},{'scalartext','nonempty'},...
    'EDFREAD','filename'));
ip.addParameter('SelectedSignals',[],...
    @(x) ((ischar(x)&&isrow(x)) || iscellstr(x)));%#ok<*ISCLSTR>
ip.addParameter('SelectedDataRecords',[],...
    @(x) validateattributes(x,{'numeric'},{'positive','integer','vector',...
    'increasing'}, 'EDFREAD','SelectedDataRecords'));
% ip.addParameter('DataRecordOutputType','vector');
ip.addParameter('TimeOutputType','duration');
ip.parse(filename,varargin{:});

% % Validate DataRecordOutputType
% sigFormat = validatestring(ip.Results.DataRecordOutputType,...
%     {'vector','timetable'},mfilename,"DataRecordOutputType");

%Validate TimeOutputType
timeFormat = validatestring(ip.Results.TimeOutputType,...
    {'datetime','duration'},mfilename,"TimeOutputType");

signals = ip.Results.SelectedSignals;

records = ip.Results.SelectedDataRecords;


function varargout = readHeader(fid)
%readHeader is a helper function to read the header content of EDF/EDF+ files
%
%   This function is for internal use only. It may change or be removed.
%
%     varargout is from 1 to 20 with variables extracted as follows:
%     ver       - Version.
%     pat       - Patient.
%     rec       - Recording.
%     sd        - Start date.
%     st        - Start time.
%     hb        - Header bytes.
%     rev       - Reserved.
%     numDR     - Number of data records.
%     drd       - Data record duration.
%     ns        - Number of signals.
%     sigLabels - Signal labels.
%     ttype     - Transducer type.
%     phyDim    - Physical dimension.
%     phyMin    - Physical minimum.
%     phyMax    - Physical maximum.
%     dMim      - Digital minimum.
%     dMax      - Digital maximum.
%     pf        - Prefilter.
%     numSamp   - Number of samples.
%     sigres    - Signal reserved.

%   Copyright 2020 The MathWorks, Inc.

% Read first 256 Bytes of the EDF file using fread
hdr_fixeddata = fread(fid,256,'*char').';

% Extract version of the data format
varargout{1} = strtrim(hdr_fixeddata(1:8));

% Extract local patient identification
varargout{2} = strtrim(hdr_fixeddata(9:88));

% Extract local recording identification
varargout{3} = strtrim(hdr_fixeddata(89:168));

% Extract start date of recording
varargout{4} = strtrim(hdr_fixeddata(168:176));

% Extract Start time of recording
varargout{5} = strtrim(hdr_fixeddata(177:184));

% Extract number of bytes in header record
varargout{6} = str2double(hdr_fixeddata(185:192));

% Extract reserved
varargout{7} = string(strtrim(hdr_fixeddata(193:236)));

% Extract number of data records
varargout{8} = str2double(hdr_fixeddata(237:244));

% Extract duration of a data record, in seconds
varargout{9} = str2double(hdr_fixeddata(245:252));

% Extract number of signals (ns) in data record
ns = str2double(hdr_fixeddata(253:256));
varargout{10} = ns;

% Next ns * 256 Bytes
hdr_vardata = fread(fid,ns*256,'*char').';

% Extract labels of the signals
varargout{11} = strtrim(string(reshape(hdr_vardata(1:ns*16),16,ns).'));

% Extract transducer type
varargout{12} = strtrim(string(reshape(hdr_vardata(1+ns*16:ns*96),...
    80,ns).'));

% Extract physical dimension of signals
varargout{13} = strtrim(string(reshape(hdr_vardata(1+ns*96:ns*104),...
    8,ns).'));

% Extract physical minimum in units of physical dimension
varargout{14} = str2double(string(reshape(hdr_vardata(1+ns*104:ns*112),...
    8,ns).'));

% Extract physical maximum in units of physical dimension
varargout{15} = str2double(string(reshape(hdr_vardata(1+ns*112:ns*120),...
    8,ns).'));

% Extract digital minimum
varargout{16} = str2double(string(reshape(hdr_vardata(1+ns*120:ns*128),...
    8,ns).'));

% Extract digital maximum
varargout{17} = str2double(string(reshape(hdr_vardata(1+ns*128:ns*136),...
    8,ns).'));

% Extract prefiltering
varargout{18} = strtrim(string(reshape(hdr_vardata(1+ns*136:ns*216),...
    80,ns).'));

% Extract number of samples in each data record
varargout{19} = str2double(string(reshape(hdr_vardata(1+ns*216:ns*224),...
    8,ns).'));

% Extract reserved field
varargout{20} = strtrim(string(reshape(hdr_vardata(1+ns*224:ns*256),...
    32,ns).'));


function validateEDF(filename, fileInfo, version, startDate, startTime,...
    headerBytes, reserve, numDataRecords, numSignals,...
    sigLabels, numSamples, transducerType, physicalDimension,...
    physicalMinimum, physicalMaximum, digitalMinimum, digitalMaximum, ...
    prefilter, sigReserve, dataRecordDuration, mfile)
%validateEDF is used to validate EDF/EDF+ files
%
%   This function is for internal use only. It may change or be removed.

%   Copyright 2020 The MathWorks, Inc.

% Check whether version of data format is 0 or not
if ~(strcmpi(version,"0"))
    error(message('signal:edf:InvalidVersion', version, filename));
end

% Check startDate of EDF/EDF+ file is in 'dd.MM.yy' format or not
try
    datetime(startDate,'InputFormat','dd.MM.yy');
catch
    error(message('signal:edf:InvalidStartdate', filename));
end

% Check startTime of EDF/EDF+ file is in 'HH.mm.ss' format or not
try
    datetime(startTime,'InputFormat','HH.mm.ss');
catch
    error(message('signal:edf:InvalidStartTime', filename));
end

% Check numSamples has integer value
validateattributes(numSamples,{'numeric'},{'integer'},mfile);

% As per EDF/EDF+ spec file header has (256 + numSignals.*256) bytes
tExpectedHeaderbytes = (256 + numel(sigLabels).*256);

% Calculate file size based on header information as each sample value is
% represented as a 2-byte integer in 2's complement format as per EDF/EDF+
% spec
if numDataRecords ~= -1 && numDataRecords > 0
    tExpectedFileSize = (sum(numSamples).*numDataRecords.*2) + tExpectedHeaderbytes;
    
    % Check whether the file size is valid or not
    if tExpectedFileSize ~= fileInfo.bytes
        error(message('signal:edf:InvalidFileSize', fileInfo.bytes, tExpectedFileSize,...
            filename));
    end
end

% Check whether headerBytes field is valid or not
if tExpectedHeaderbytes ~= headerBytes
    error(message('signal:edf:InvalidHeaderBytes', filename,...
        tExpectedHeaderbytes));
end

% Check whether Reserved field is valid or not
reserve = validatestring(reserve,{'EDF+C','EDF+D',''},mfile,"Reserved");

% Check numDataRecords field is not -1 for EDF+ file
if ((~isempty(reserve) && numDataRecords <= 0) || ...
        (isempty(reserve) && (numDataRecords < -1)))
    error(message('signal:edf:InvalidDataRecord', filename));
end

% Check whether numSignals is equal to length of signalLabels
if (length(sigLabels) ~= numSignals)
    error(message('signal:edf:InvalidNumSignals', filename));
end

% Check whether the length of all the fields in the variable - header is
% numSignals or not
tExpectedLengths = {transducerType, physicalDimension,...
    physicalMinimum, physicalMaximum, digitalMinimum, digitalMaximum, ...
    prefilter, sigReserve, numSamples};
tLengthsIdx = cellfun(@length,tExpectedLengths) == numSignals;

if ~all(tLengthsIdx)
    error(message('signal:edf:HeaderDataMissing', filename));
end

% Check if the file is EDF and error out when dataRecordDuration is zero
if ((dataRecordDuration == 0) && isempty(reserve))
    error(message('signal:edf:ZeroDataRecordDuration'));
end

% Check number of samples values
validateattributes(numSamples, {'numeric'}, {'numel', numSignals, ...
    'positive', 'nonnan'});


function [annotations, data] = readData(fid,filename,siglabels,numDR,phymax,...
    phymin,dmax,dmin,ns,numsamp,signals,records,dataRecordDuration,infoflag)
%readData function is used to data and annotations of EDF/EDF+ files.
%
%   This function is for internal use only. It may change or be removed.

%   Copyright 2020 The MathWorks, Inc.

% Assuming data exist after the header
dataExist = true;
recordNum = 0;
recordIdx = 0;
data = {};
if (numDR ~= -1) && ~infoflag
    if (~isempty(records) && ~isempty(signals)) && (max(records) <= numDR)
        data = cell(numel(records), numel(signals));
    else
        error(message('signal:edf:InvalidDataRecordIdx', filename));
    end
end

annotationsIdx = find(strcmp(siglabels, 'EDF Annotations'),1);
if (isempty(annotationsIdx))
    annotationsIdx = -1;
    annotations = cell(1,1);
elseif (numDR ~= -1)
    annotations = cell(numDR,1);
else
    annotations = cell(1,1);
end

sc = (phymax - phymin) ./ (dmax - dmin);
dc = phymax - sc .* dmax;

% Run the loop until we reach end of file
while dataExist
    
    % We haven't reached the end of file, so assume data
    % is present and increment the record number.
    recordNum = recordNum+1;
    record_exist = any(recordNum == records);
    
    if (record_exist)
        recordIdx = recordIdx+1;
    end
    
    for ii = 1:ns
        
        % Find signal indices
        signalIdx = find(ii == signals,1);
        
        % Check if current signal is an annotation
        if (ii == annotationsIdx)
            annotations{recordNum} = fread(fid,numsamp(ii)*2,'*char').';
            if (isempty(annotations{recordNum}) && (dataRecordDuration == 0))
                annotations(recordNum) = [];
                dataExist = false;
                break;
            else
                continue;
            end
        elseif ((numDR == -1 || record_exist) && any(signalIdx))
            temp = fread(fid,numsamp(ii),'int16');
        else
            % If seeking is unsuccessful, assume we
            % reached the end of file
            if (fseek(fid,numsamp(ii)*2,'cof') == -1)
                dataExist = false;
                break;
            else
                continue;
            end
        end
        
        % if the data read is empty, then assume we reached
        % end of file.
        if (isempty(temp))
            dataExist = false;
            break;
        elseif (record_exist)
            data{recordIdx,signalIdx} = temp*sc(ii)+dc(ii);
        elseif (isempty(records))
            data{recordNum,signalIdx} = temp*sc(ii)+dc(ii);
        end
    end
end

function [annotations, data] = readDataAll(fid,filename,siglabels,numDR,phymax,...
    phymin,dmax,dmin,ns,numsamp,signals,records,dataRecordDuration,infoflag)
%readData function is used to data and annotations of EDF/EDF+ files.
%
%   This function is for internal use only. It may change or be removed.

%   Copyright 2020 The MathWorks, Inc.

% Assuming data exist after the header
dataExist = true;
recordNum = 0;
recordIdx = 0;
data = {};
if (numDR ~= -1) && ~infoflag
    if (~isempty(records) && ~isempty(signals)) && (max(records) <= numDR)
        data = cell(1, numel(signals));
    else
        error(message('signal:edf:InvalidDataRecordIdx', filename));
    end
end

annotationsIdx = find(strcmp(siglabels, 'EDF Annotations'),1);
if (isempty(annotationsIdx))
    annotationsIdx = -1;
    annotations = cell(1,1);
elseif (numDR ~= -1)
    annotations = cell(numDR,1);
else
    annotations = cell(1,1);
end

sc = (phymax - phymin) ./ (dmax - dmin);
dc = phymax - sc .* dmax;

signal_size = numsamp.*numDR;

% Run the loop until we reach end of file
while dataExist
    
    % We haven't reached the end of file, so assume data
    % is present and increment the record number.
    recordNum = recordNum+1;
    record_exist = any(recordNum == records);
    
    if (record_exist)
        recordIdx = recordIdx+1;
    end
    
    for ii = 1:ns
        
        % Find signal indices
        signalIdx = find(ii == signals,1);
        
        % Check if current signal is an annotation
        if (ii == annotationsIdx)
            annotations{recordNum} = fread(fid,numsamp(ii)*2,'*char').';
            if (isempty(annotations{recordNum}) && (dataRecordDuration == 0))
                annotations(recordNum) = [];
                dataExist = false;
                break;
            else
                continue;
            end
        elseif ((numDR == -1 || record_exist) && any(signalIdx))
            temp = fread(fid,signal_size(ii),'int16');
        else
            % If seeking is unsuccessful, assume we
            % reached the end of file
            if (fseek(fid,signal_size(ii)*2,'cof') == -1)
                dataExist = false;
                break;
            else
                continue;
            end
        end
        
        % if the data read is empty, then assume we reached
        % end of file.
        if (isempty(temp))
            dataExist = false;
            break;
        elseif (record_exist)
            data{recordIdx,signalIdx} = temp*sc(ii)+dc(ii);
        elseif (isempty(records))
            data{recordNum,signalIdx} = temp*sc(ii)+dc(ii);
        end
    end
end



function [fid,fileInfo] = openFile(filename)
%openFile function is used to open the file and return its file ID for reading its header
%
%   This function is for internal use only. It may change or be removed.

%   Copyright 2020 The MathWorks, Inc.

[tfid, errmsg] = fopen(filename,'r');

originalFilename = filename;
% fopen() returns -1 if file is not present
if tfid == -1
    % Look for filename with extensions.
    filename = [originalFilename '.edf'];
    [tfid, errmsg] = fopen(filename);
    
    if tfid == -1
        filename = [originalFilename '.EDF'];
        [tfid, errmsg] = fopen(filename);
    end
end

fid = tfid;

% Record filesystem details (fileInfo is empty object if the filename is
% not the same directory).
fileInfo = dir(filename);

% Get the fileInfo when the file is not in the same directory but it is in
% the matlab path.
if isempty(fileInfo) && tfid ~= -1
    filename =  fopen(fid);
    fileInfo = dir(filename);
end

% Error if file does not exists
if fid == -1
    if ~isempty(fileInfo)
        % String 'Too many open files' is from strerror. fopen() also
        % returns error messages as char output as per documentation which
        % we is now using for checking following error condition.
        if contains(errmsg, 'Too many open files')
            error(message('signal:edf:TooManyOpenFiles', originalFilename));
        else
            error(message('signal:edf:FileReadPermission', originalFilename));
        end
    elseif isempty(fileInfo)
        error(message('signal:edf:FileDoesNotExist', originalFilename));
    end
elseif ((fid ~= -1) && (fileInfo.bytes == 0))
    fclose(fid);
    error(message('signal:edf:ZeroFileSize', originalFilename));
end

function [recordTimes,onset,annotations,...
    annotationDuration] = readAnnotations(RawAnnotations)
%readAnnotations function is used to make Annotations of EDF/EDF+ files more readable
%
%   This function is for internal use only. It may change or be removed.

%   Copyright 2020 The MathWorks, Inc.

nr = numel(RawAnnotations);
x = zeros(nr,1);

for ii = 1:nr
    if ~ischar(RawAnnotations{ii})
        RawAnnotations{ii} = char(RawAnnotations{ii});
    end
    RawAnnotations{ii} = purifyAnnotation(RawAnnotations{ii});
    x(ii) = count(RawAnnotations{ii}, char(0));
end

idx = 0;
r_idx = zeros(nr,1);
tOnset = cell(sum(x),1);
tDuration = cell(sum(x),1);
annotations = strings(sum(x),1);

for ii = 1:nr
    n_idx = [0 find(RawAnnotations{ii} == char(0))];
    r_idx(ii) = 1+idx;
    
    for jj = 1:x(ii)
        idx = idx+1;
        temp = RawAnnotations{ii}(1+n_idx(jj):n_idx(jj+1)-1);
        o_idx = find(temp == char(20));
        d_idx = find(temp(1:o_idx(1)) == char(21));
        
        if (any(d_idx))
            tDuration{idx} = temp(1+d_idx(1):o_idx(1)-1);
            tOnset{idx} = temp(1:d_idx(1)-1);
        else
            tOnset{idx} = temp(1:o_idx(1)-1);
        end
        annotations(idx) = temp(1+o_idx(1):o_idx(end)-1);
    end
end

onset = seconds(str2double(tOnset));
annotationDuration = seconds(str2double(tDuration));
recordTimes = onset(r_idx);

n_idx = annotations == "";
onset(n_idx) = [];
annotationDuration(n_idx) = [];
annotations(n_idx) = [];

if isempty(onset)
    onset = onset(:);
    annotations = annotations(:);
    annotationDuration = annotationDuration(:);
end


function res = purifyAnnotation(input)
for ii = numel(input):-1:1
    if (input(ii) == char(0))
        input(ii) = ' ';
    else
        input(ii+1) = char(0);
        break;
    end
end

res = strtrim(input);



