function [ stages, notation, start_time ] = convert_grass_scoring(fname)
%CONVERT_GRASS_SCORING  Extract sleep stages and notation from a GRASS CSV text file
%
%   Usage:
%       [stages, notation, start_time] = convert_grass_scoring(fname)
%
%   Inputs:
%       fname : char - path to GRASS comment/scoring CSV -- required
%
%   Outputs:
%       stages     : struct with fields
%                       - stage : 1xN double - stage code (5=Wake, 4=REM, 3=N1, 2=N2, 1=N3, 0=Other)
%                       - time  : 1xN double - stage onset time in seconds from recording start
%       notation   : struct with fields
%                       - time : 1xM double - annotation times in seconds
%                       - text : 1xM cell of char - annotation text
%       start_time : 1x3 double - [hour minute second] of first timestamp in file
%
%   Notes:
%       Time stamps are parsed with datetime using 'HH:mm:ss' and wrap
%       across midnight via cumulative modulo of the time-of-day
%       differences.
%
%   See also: readgrassstaging, read_staging
%
%   ∿∿∿  Prerau Laboratory MATLAB Codebase · sleepEEG.org  ∿∿∿

[comments, timestamps, ttimes]=convert_grass_comments(fname);

s=1;
n=1;
for i=1:length(comments)
    c=comments{i};
    if strfind(c,'Stage')
        switch c(9:end)
            case 'W'
                stage(s)=5;
            case 'N3'
                stage(s)=1;
            case 'N2'
                stage(s)=2;
            case 'N1'
                stage(s)=3;
            case 'R'
                stage(s)=4;
            otherwise
                stage(s)=0;
        end
        
        time(s)=timestamps(i);
        
        s=s+1;
    else
        if n==1
            clean_first = regexprep(ttimes{1}, '[^\d:.]', '');
            dt_first = datetime(clean_first, 'InputFormat', 'HH:mm:ss');
            start_time = [hour(dt_first) minute(dt_first) second(dt_first)];
        end
        
        ctime(n)=timestamps(i);
        text{n}=c;
        
        n=n+1;
    end
end

stages.stage=stage;
stages.time=time;

notation.time=ctime;
notation.text=text;

end

function [comments, timestamps, ttimes]=convert_grass_comments(fname)

%Read in the file
fid=fopen(fname);
%Read in a full line (make a fake delimiter)
cdata=textscan(fid,'%s','delimiter','###','multipledelimsasone',1);
fclose(fid);

cdata=cdata{1};

for i=1:length(cdata)
    %Get the line of text
    tline=cdata{i};
    if ~isempty(deblank(tline))
        %Find the field delimiters
        fields=strfind(tline,',');
%         if length(fields)>2
%             disp('extra comma');
%         end
%         
%         if length(fields)==1
%             fields(2)=fields(1);
%             fields(1)=0;
%         end
%         
%         %Get the text of the times
%         inds = fields(1)+1:fields(2)-1;
% 
% 
%         ttimes{i}=tline(inds); %PUT BACK IN FOR NSS DATA
%         
%         %Get the comments
%         comments{i}=tline(fields(2)+1:end); %PUT BACK IN FOR NSS DATA


tinds=1:(fields(1)-1);
cinds=(fields(1)+1):length(tline);

ttimes{i}=tline(tinds);
comments{i}=tline(cinds);
    end
end

%Compute the total time in seconds, adjusting for crossing days
cleaned = regexprep(ttimes, '[^\d:.]', '');
dt = datetime(cleaned, 'InputFormat', 'HH:mm:ss');
totalsecs = seconds(timeofday(dt));
timestamps = [0, cumsum(mod(diff(totalsecs), 86400))];
end
