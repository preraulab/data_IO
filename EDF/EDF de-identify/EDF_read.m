
function [header, data, annotations] = EDF_read(filename,varargin)
%edfread Read data from the EDF or EDF+ file
%   DATA = EDF_read(FILENAME) reads signal data from each record in the
%   EDF or EDF+ file specified in FILENAME. DATA is returned as a
%   timetable. Each row of DATA is a record and each variable is a signal.
%   RowTimes of the timetable correspond to the start time of each data
%   record relative to the start time of the file recording.
%
%   DATA = EDF_read(...,'SelectedSignals',SIGNAMES) reads from FILENAME
%   the signals whose names are specified in the string vector SIGNAMES.
%   DATA is a timetable with a variable for each of the names specified in
%   SIGNAMES. If SIGNAMES is not specified, EDFREAD reads the data of all
%   the signals in the EDF or EDF+ file.
%
%   DATA = EDF_read(...,'SelectedDataRecords',RECORDINDICES) reads from
%   FILENAME the data records specified in the vector RECORDINDICES. The
%   integers in RECORDINDICES must be unique and strictly increasing.
%   DATA is a timetable with number of rows equal to the number of indices
%   specified in RECORDINDICES. If RECORDINDICES is not specified, EDFREAD
%   reads all the data records in the EDF or EDF+ file.

%   DATA = EDF_read(...,'TimeOutputType',TTYPE) specifies time output type,
%   TTYPE, as 'duration' or 'datetime'. If TTYPE is specified as
%   'duration', the times in DATA are returned as durations. If TTYPE is
%   specified as 'datetime', the times in DATA are returned as datetimes.
%   If TTYPE is not specified, 'TimeOutputType' defaults to 'duration'.
%
%   [DATA ANNOTATIONS] = EDF_read(...) also returns a timetable with any
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
%      data = edfread('example.edf')
%
%   % Example 2:
%      % Read the data for the signal "ECG" in the EDF file example.edf
%      [data,annotations] = edfread('example.edf','SelectedSignals',"ECG")
%
%   % Example 3:
%      % Read the first, third, and fifth data records of the EDF file
%      % example.edf
%      data = edfread('example.edf','SelectedDataRecords',[1 3 5])
%
%   See also EDFINFO.

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
[~, timeFormat, signals,...
    tempRecords] = parseInputs(filename,varargin{:});

% Error out when the file extension is not .edf/.EDF
[~, ~, ext] = fileparts(filename);
if ~strcmpi(ext,'.edf')
    error(message('signal:edf:InvalidFileExt'));
end

% Get file ID based on the file name.
[fid, fileInfo] = signal.internal.edf.openFile(filename);

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
%
% % Validate EDF/EDF+ files
% signal.internal.edf.validateEDF(filename, fileInfo, version, startDate, startTime,...
%     headerBytes, reserve, numDataRecords, numSignals,...
%     sigLabels, numSamples, transducerType, physicalDimension,...
%     physicalMinimum, physicalMaximum, digitalMinimum, digitalMaximum, ...
%     prefilter, sigReserve, dataRecordDuration, mfilename);



% Check for Annotations signal label
annotationExist = strcmpi(sigLabels, 'EDF Annotations');

% Get signal indices
signalsIdx = getSignalIndices(filename, signals, sigLabels);


header.Filename = string(fileInfo.name);
header.FileModDate = string(datetime(fileInfo.datenum, 'ConvertFrom', 'datenum'));
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
header.Fs = numSamples(signalsIdx)./dataRecordDuration;

%Don't do anything more if they just want the header
if nargout == 1
    return;
end


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
    [annotations,tempData] = signal.internal.edf.readData(fid, filename,...
        sigLabels, numDataRecords, physicalMaximum, physicalMinimum, ...
        digitalMaximum, digitalMinimum, numSignals, numSamples,...
        [], [], dataRecordDuration, true);
else
    % Read annotations and data for non-zero dataRecordDuration
    [annotations,tempData] = signal.internal.edf.readData(fid, filename,...
        sigLabels, numDataRecords, physicalMaximum, physicalMinimum, ...
        digitalMaximum, digitalMinimum, numSignals, numSamples,...
        signalsIdx, records, dataRecordDuration, false);
end

% if (isempty(records))
%     records = 1:size(tempData,1);
% end

% Time Table computations
if (any(annotationExist))
    [~, onset, annotations,...
        tempDuration] = signal.internal.edf.readAnnotations(annotations);
    %recordTimes = recordTimes(records);
    annotations = timetable(onset,annotations,tempDuration,...
        'VariableNames',["Annotations","Duration"]);
else
    annotations = timetable(duration.empty(0,1),...
        [],duration.empty(0,1),'VariableNames',...
        ["Annotations","Duration"]);
    % recordTimes = (records.'- 1).* seconds(dataRecordDuration);
end
annotations.Properties.DimensionNames{1} = 'Onset';

tTimeFormatFlag = strcmp(timeFormat,'datetime');
if tTimeFormatFlag
    startDate = datetime([startDate '.' startTime],'InputFormat',...
        'dd.MM.yy.HH.mm.ss');
    %     recordTimes = recordTimes + startDate;
    if isempty(annotations)
        tEmpty = zeros(0,1);
        annotations.Onset = datetime(tEmpty, tEmpty, tEmpty);
    else
        annotations.Onset = annotations.Onset + startDate;
    end
end

if tDataRecordDurationFlag
    %     if tTimeFormatFlag
    %         tEmpty = zeros(0,1);
    %         recordTimes =  datetime(tEmpty,tEmpty,tEmpty);
    %     else
    %         recordTimes = duration.empty(0,1);
    %     end
    %     tblData = timetable(recordTimes,...
    %         [],duration.empty(0,1));
else
    reqSigLabels = sigLabels(signalsIdx);
    %     if (strcmp(sigFormat,'timetable'))
    %         tempData = convert2timetable(tempData,...
    %             recordTimes,seconds(dataRecordDuration ./ numSamples(signalsIdx)),...
    %             reqSigLabels);
    %     end
    
    % Check if all the signal names are different or not
    if length(unique(reqSigLabels)) < length(reqSigLabels)
        warning(message('signal:edf:UniqueLabels',filename));
        % Create variable names
        tempNo = strings(length(reqSigLabels),1);
        tempSignstr = "Signal Label ";
        for idx = 1:length(reqSigLabels)
            tempNo(idx) =  num2str(idx);
        end
        % reqSigLabels = strcat(tempSignstr,tempNo,":",reqSigLabels);
    end
    
    
    %     tblData = table2timetable(cell2table(tempData,'VariableNames',...
    %         matlab.lang.makeValidName(reqSigLabels)),'RowTimes',recordTimes);
end
% tblData.Properties.DimensionNames{1} = 'Record Time';
% data = tblData;

N = size(tempData,2);
data = cell(N,1);

for ii = 1:N
    data{ii} = cell2mat(tempData(:,ii));
end

if ~issortedrows(annotations)
    annotations = sortrows(annotations);
end

%Parse and validate given inputs
function [sigFormat, timeFormat, signals, records] = parseInputs(filename,...
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
ip.addParameter('DataRecordOutputType','vector');
ip.addParameter('TimeOutputType','duration');
ip.parse(filename,varargin{:});

% Validate DataRecordOutputType
sigFormat = validatestring(ip.Results.DataRecordOutputType,...
    {'vector','timetable'},mfilename,"DataRecordOutputType");

% Validate TimeOutputType
timeFormat = validatestring(ip.Results.TimeOutputType,...
    {'datetime','duration'},mfilename,"TimeOutputType");

signals = ip.Results.SelectedSignals;

records = ip.Results.SelectedDataRecords;

% Calculate indices of given signals
function indices = getSignalIndices(filename,signals,labels)

annotationExist = strcmpi(labels,"EDF Annotations");
tempIndices = 1:numel(labels);

% Populate signals if not present, else find their indices.
if (isempty(signals))
    indices = tempIndices;
    indices(annotationExist) = [];
elseif ischar(signals) || iscellstr(signals)
    if iscolumn(signals)
        signals = signals.';
    end
    
    % Using ismember check whether all the signals
    [sigExists, indices] = ismember(lower(signals),lower(labels));
    
    % Check whether all the signals are specified using SelectedSignals
    % are valid or not
    if ~all(sigExists)
        error(message('signal:edf:InvalidSignalLabel', filename));
    end
end

% % Change data to timetable
% function data = convert2timetable(tdata,rtimes,timeValue,labels)
% [nr,ns] = size(tdata);
% data = cell(nr,ns);
% for ii = 1:nr
%     for jj = 1:ns
%         data{ii,jj} = array2timetable(tdata{ii,jj},'TimeStep',timeValue(jj),...
%             'StartTime',rtimes(ii),'VariableNames',labels(jj));
%     end
% end


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
