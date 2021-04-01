% lab_read_edf() - read eeg data in EDF+ format.
%
% Orignal Code-file:
% Jeng-Ren Duann, CNL/Salk Inst., 2001-12-21
%
% Modifications:
% 03-21-02 editing hdr, add help -ad 
% 05-03-12 FHatz Neurology Basel (Support for edf+)
%
% Usage: 
%    >> [data,header] = read_edf(filename);
%
% Input:
%    filename - file name of the eeg data
% 
% Output:
%    data   - eeg data in (channel, timepoint)
%    header - structured information about the read eeg data
%      header.events - events (structure: .POS .DUR .TYP)
%      header.numtimeframes - length of EEG data
%      header.samplingrate = samplingrate
%      header.numchannels - number of channels
%      header.numauxchannels - number of non EEG channels (only ECG channel is recognized)
%      header.channels - channel labels
%      header.year - timestamp recording
%      header.month - timestamp recording
%      header.day - timestamp recording
%      header.hour - timestamp recording
%      header.minute - timestamp recording
%      header.second - timestamp recording
%      header.ID - EEG number
%      header.technician - responsible investigator or technician
%      header.equipment - used equipment
%      header.subject.ID - local patient identification
%      header.subject.sex - M or F
%      header.subject.name - patients name
%      header.subject.year - birthdate
%      header.subject.month - birthdate
%      header.subject.day - birthdate
%      header.hdr - original header

function [data,header] = lab_read_edf(filename)

if nargin < 1
    help readedf;
    return;
end;
    
fp = fopen(filename,'r','ieee-le');
if fp == -1,
  error('File not found ...!');
  return;
end

hdr.intro = setstr(fread(fp,256,'uchar')');
hdr.length = str2num(hdr.intro(185:192));
hdr.records = str2num(hdr.intro(237:244));
hdr.duration = str2num(hdr.intro(245:252));
hdr.channels = str2num(hdr.intro(253:256));
hdr.channelname = setstr(fread(fp,[16,hdr.channels],'char')');
hdr.transducer = setstr(fread(fp,[80,hdr.channels],'char')');
hdr.physdime = setstr(fread(fp,[8,hdr.channels],'char')');
hdr.physmin = str2num(setstr(fread(fp,[8,hdr.channels],'char')'));
hdr.physmax = str2num(setstr(fread(fp,[8,hdr.channels],'char')'));
hdr.digimin = str2num(setstr(fread(fp,[8,hdr.channels],'char')'));
hdr.digimax = str2num(setstr(fread(fp,[8,hdr.channels],'char')'));
hdr.prefilt = setstr(fread(fp,[80,hdr.channels],'char')');
hdr.numbersperrecord = str2num(setstr(fread(fp,[8,hdr.channels],'char')'));

fseek(fp,hdr.length,-1);
data = fread(fp,'int16');
fclose(fp);

header.hdr = hdr;
header.samplingrate = hdr.numbersperrecord(1) / hdr.duration;
header.numchannels = hdr.channels;
header.numauxchannels = 0;
header.channels = hdr.channelname;
tmp = textscan(hdr.intro(89:168),'%s');
tmp = tmp{1,1};
[header.year header.month header.day] = datevec(tmp(2,1));
header.hour = str2num(hdr.intro(177:178));
header.minute = str2num(hdr.intro(177:178));
header.second = str2num(hdr.intro(177:178));
header.ID = tmp{3,1};
header.technician = tmp{4,1};
header.equipment = tmp{5,1};
tmp = textscan(hdr.intro(9:88),'%s');
tmp = tmp{1,1};
header.subject.ID = tmp{1,1};
header.subject.sex = tmp{2,1};
header.subject.name = tmp{4,1};
if ~strcmp(tmp(3,1),'X')
    [header.subject.year header.subject.month header.subject.day] = datevec(tmp(3,1));
end
clearvars tmp

% Look for annotations
if strcmp(hdr.channelname(end,1:15),'EDF Annotations') || strcmp(hdr.channelname(end,1:6),'Status')
    header.numchannels = header.numchannels -1;
    header.channels = header.channels(1:end-1,:);
    data = reshape(data,sum(hdr.numbersperrecord),hdr.records);
    eventstmp = data((end - hdr.numbersperrecord(end) + 1):end,:);
    data = data(1:end-hdr.numbersperrecord(end),:);
    data = reshape(data,hdr.numbersperrecord(1),header.numchannels,hdr.records);
    data = permute(data,[1 3 2]);
    data = reshape(data,hdr.numbersperrecord(1)*hdr.records,header.numchannels)';
    for i = 1:hdr.records
        eventsall(i,:) = typecast(int16(eventstmp(:,i)),'uint8')';
    end
    header.events.TYP = [];
    header.events.POS = [];
    header.events.DUR = [];
    header.events.OFF = [];
    eventsall = eventsall(find(eventsall(:,15) > 0),:);
    eventsmod = eventsall;
    eventsmod(find(eventsall == 32)) = 95;
    eventsmod(find(eventsall == 20)) = 32;
    eventsmod(find(eventsall == 21)) = 32;
    eventsmod(find(eventsall == 43)) = 32;
    eventsmod(find(eventsall == 0)) = 32; 
    for i = 1:size(eventsall,1)
        eventspos = find(eventsall(i,:) == 43);
        for j = 2:length(eventspos)
            tmp = textscan(native2unicode(eventsmod(i,eventspos(j):end)),'%s');
            tmp = tmp{1,1};
            header.events.POS = [header.events.POS (str2double(tmp(1,1))*header.samplingrate)];
            header.events.OFF = [header.events.OFF 0];
            if str2double(tmp(2,1)) > 0
                header.events.DUR = [header.events.DUR (str2double(tmp(2,1))*header.samplingrate)];
                header.events.TYP = [header.events.TYP tmp(3,1)];
            else
                header.events.DUR = [header.events.DUR 1];
                header.events.TYP = [header.events.TYP tmp(2,1)];
            end
        end
    end
else
    data = reshape(data,hdr.numbersperrecord(1),hdr.channels,hdr.records);
    temp = [];
    for i=1:hdr.records,
        temp = [temp data(:,:,i)'];
    end
    data = temp;
end

% Scale data
Scale = (hdr.physmax-hdr.physmin)./(hdr.digimax-hdr.digimin);
DC = hdr.physmin - Scale .* hdr.digimin;
Scale = Scale(1:size(data,1),:);
DC = DC(1:size(data,1),:);
tmp = find(Scale < 0);
Scale(tmp) = ones(size(tmp));
DC(tmp) = zeros(size(tmp));
clearvars tmp
data = (sparse(diag(Scale)) * data) + repmat(DC,1,size(data,2));

% Look for extra channel (ECG)
if strcmp(header.channels(end,1:3),'ECG')
    header.numauxchannels = 1;
    header.numdatachannels = header.numchannels -1;
else
    header.numdatachannels = header.numchannels;
end
header.numtimeframes = size(data,2);

