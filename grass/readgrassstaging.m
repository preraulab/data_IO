function [stage, events, comments, comment_times]=readgrassstaging(filename,saveprefix)
%READGRASSSTAGING  Read GRASS staging, events, and comments from an xls or txt export
%
%   Usage:
%       [stage, events, comments, comment_times] = readgrassstaging(filename)
%       [stage, events, comments, comment_times] = readgrassstaging(filename, saveprefix)
%
%   Inputs:
%       filename   : char - path to .xls or .txt scoring export -- required
%       saveprefix : char - if provided, write '<saveprefix>_scored.mat' with parsed outputs
%
%   Outputs:
%       stage         : struct with fields
%                         - stage : Nx1 double - stage code (5=Wake, 4=REM, 3=N1, 2=N2, 1=N3, 0=No Stage)
%                         - time  : Nx1 double - stage onset time in seconds
%       events        : struct with fields times, durs, name, and logical
%                       masks AR, DSAT, EKG, CA, OH, PLM, RERA, SNORE
%       comments      : cell of char - free-form comment strings
%       comment_times : 1xM double - times in seconds for each comment
%
%   Notes:
%       Timestamps are parsed from HH:MM:SS columns with a cumulative
%       modulo-86400 adjustment to handle midnight crossings.
%
%   See also: convert_grass_scoring, read_staging
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿
%        Source: https://github.com/preraulab/labcode_main

if strfind(filename,'xls')
    %Read in the excel file
    [~, txt]=xlsread(filename);
elseif strfind(filename,'txt')
    fid = fopen(filename);
    input=textscan(fid,'%s%s%*[^\n]','delimiter',',');
    
    txt=cell(length(input{1}),2);
    for i=true:2;
        for j=true:length(input{1});
            txt{j,i}=input{i}{j};
        end;
    end
    
    fclose(fid);
else
    error('Unknown file type');
end
stage=[];
events=[];
comments=[];
comment_times=[];

%Count the number of stages
stage_count=1;

%Count the number of events
event_count=1;

%Count the number of comments
comment_count=1;

%Get the hours, minutes and seconds for this
for i=2:length(txt(:,1))
    htime=txt{i,1};
    
    seps=strfind(htime,':');
    h(i-1)=str2double(htime(1:seps(1)-1));
    m(i-1)=str2double(htime(seps(1)+1:seps(2)-1));
    s(i-1)=str2double(htime(seps(2)+1:end));
end

%Compute the total time in seconds
times=[0 cumsum(mod(diff(h*60*60+m*60+s),60*60*24))];

%Handle the comments and build the structures
for i=2:length(txt(:,1))
    %Get the comment text
    comment_text=txt{i,2};
    
    %Check for stage or for arousal
    if strcmp(comment_text,'Stage - No Stage') || strcmp(comment_text,'Stage - W') || strcmp(comment_text,'Stage - R') || ...
            strcmp(comment_text,'Stage - N1') || strcmp(comment_text,'Stage - N2') || strcmp(comment_text,'Stage - N3')
        
        %Set the stage time
        stages.time(stage_count)=times(i-1);
        
        %Set the stage stage
        switch comment_text
            case 'Stage - No Stage'
                stages.stage(stage_count)=0;
            case 'Stage - N3'
                stages.stage(stage_count)=1;
            case 'Stage - N2'
                stages.stage(stage_count)=2;
            case 'Stage - N1'
                stages.stage(stage_count)=3;
            case 'Stage - R'
                stages.stage(stage_count)=4;
            case 'Stage - W'
                stages.stage(stage_count)=5;
        end
        
        %Increment the stage counter
        stage_count=stage_count+1;
    else
        if strfind(lower(comment_text),'arousal')
            %Set the arousal time
            events.times(event_count)=times(i-1);
            events.durs(event_count)=str2double(comment_text(strfind(lower(comment_text),':')+1:strfind(lower(comment_text),'sec')-1));
            events.name{event_count}=['Arousal - ' comment_text(strfind(comment_text,'. -')+4:end)];
            
            events.AR(event_count)=true;
            events.DSAT(event_count)=false;
            events.EKG(event_count)=false;
            events.CA(event_count)=false;
            events.OH(event_count)=false;
            events.PLM(event_count)=false;
            events.RERA(event_count)=false;
            events.SNORE(event_count)=false;
            
            %Increment the arousal counter
            event_count=event_count+1;
        elseif strfind(lower(comment_text),'desaturation')
            events.times(event_count)=times(i-1);
            events.durs(event_count)=str2double(comment_text(strfind(lower(comment_text),':')+1:strfind(lower(comment_text),'sec')-1));
            events.name{event_count}=comment_text;
            
            events.AR(event_count)=false;
            events.DSAT(event_count)=true;
            events.EKG(event_count)=false;
            events.CA(event_count)=false;
            events.OH(event_count)=false;
            events.PLM(event_count)=false;
            events.RERA(event_count)=false;
            events.SNORE(event_count)=false;
            
            %Increment the arousal counter
            event_count=event_count+1;
            
        elseif strfind(comment_text,'EKG Events')
            events.times(event_count)=times(i-1);
            events.durs(event_count)=str2double(comment_text(strfind(lower(comment_text),':')+1:strfind(lower(comment_text),'sec')-1));
            events.name{event_count}=comment_text;
            
            events.AR(event_count)=false;
            events.DSAT(event_count)=false;
            events.EKG(event_count)=true;
            events.CA(event_count)=false;
            events.OH(event_count)=false;
            events.PLM(event_count)=false;
            events.RERA(event_count)=false;
            events.SNORE(event_count)=false;
            
            %Increment the arousal counter
            event_count=event_count+1;
        elseif strfind(comment_text,'RERA')
            events.times(event_count)=times(i-1);
            events.durs(event_count)=str2double(comment_text(strfind(lower(comment_text),':')+1:strfind(lower(comment_text),'sec')-1));
            events.name{event_count}=comment_text;
            
            events.AR(event_count)=false;
            events.DSAT(event_count)=false;
            events.EKG(event_count)=false;
            events.CA(event_count)=false;
            events.OH(event_count)=false;
            events.PLM(event_count)=false;
            events.RERA(event_count)=true;
            events.SNORE(event_count)=false;
            
            %Increment the arousal counter
            event_count=event_count+1;
        elseif strfind(comment_text,'PLM') | strfind(lower(comment_text),'limb')
            events.times(event_count)=times(i-1);
            events.durs(event_count)=str2double(comment_text(strfind(lower(comment_text),':')+1:strfind(lower(comment_text),'sec')-1));
            events.name{event_count}=comment_text;
            
            events.AR(event_count)=false;
            events.DSAT(event_count)=false;
            events.EKG(event_count)=false;
            events.CA(event_count)=false;
            events.OH(event_count)=false;
            events.PLM(event_count)=true;
            events.RERA(event_count)=false;
            events.SNORE(event_count)=false;
            
            %Increment the arousal counter
            event_count=event_count+1;
        elseif strfind(comment_text,'Respiratory') & strfind(lower(comment_text),'central')
            events.times(event_count)=times(i-1);
            events.durs(event_count)=str2double(comment_text(strfind(lower(comment_text),':')+1:strfind(lower(comment_text),'sec')-1));
            events.name{event_count}=comment_text;
            
            events.AR(event_count)=false;
            events.DSAT(event_count)=false;
            events.EKG(event_count)=false;
            events.CA(event_count)=true;
            events.OH(event_count)=false;
            events.PLM(event_count)=false;
            events.RERA(event_count)=false;
            events.SNORE(event_count)=false;
            
            %Increment the arousal counter
            event_count=event_count+1;
        elseif strfind(comment_text,'Respiratory') & strfind(lower(comment_text),'hypopnea')
            events.times(event_count)=times(i-1);
            events.durs(event_count)=str2double(comment_text(strfind(lower(comment_text),':')+1:strfind(lower(comment_text),'sec')-1));
            events.name{event_count}=comment_text;
            
            events.AR(event_count)=false;
            events.DSAT(event_count)=false;
            events.EKG(event_count)=false;
            events.CA(event_count)=false;
            events.OH(event_count)=true;
            events.PLM(event_count)=false;
            events.RERA(event_count)=false;
            events.SNORE(event_count)=false;
            
            %Increment the arousal counter
            event_count=event_count+1;
        elseif strfind((comment_text),'Snore') & strfind((comment_text),'Dur')
            events.times(event_count)=times(i-1);
            events.durs(event_count)=str2double(comment_text(strfind(lower(comment_text),':')+1:strfind(lower(comment_text),'sec')-1));
            events.name{event_count}=comment_text;
            
            events.AR(event_count)=false;
            events.DSAT(event_count)=false;
            events.EKG(event_count)=false;
            events.CA(event_count)=false;
            events.OH(event_count)=false;
            events.PLM(event_count)=false;
            events.RERA(event_count)=false;
            events.SNORE(event_count)=true;
            
            %Increment the arousal counter
            event_count=event_count+1;
        else
            comment_times(comment_count)=times(i-1);
            comments{comment_count}=comment_text;
            comment_count=comment_count+1;
        end
    end
end

events.AR=logical(events.AR)';
events.DSAT=logical(events.DSAT)';
events.EKG=logical(events.EKG)';
events.CA=logical(events.CA)';
events.OH=logical(events.OH)';
events.PLM=logical(events.PLM)';
events.RERA=logical(events.RERA)';
events.SNORE=logical(events.SNORE)';

stages.stage=stages.stage';
stages.time=stages.time';

if nargin==2
    save([saveprefix '_scored.mat'],'stages', 'events', 'comments', 'comment_times');
end