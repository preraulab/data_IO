function [ stages, notation, start_time ] = convert_grass_scoring(fname)
%CONVERT_GRASS_SCORING Extracts sleep stages and notation from GRASS CSV
%text files
%  [ stages, notation, start_time ] = convert_grass_scoring(fname)
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
            [~, hh, mm, ss]=hmstext2seconds({ttimes{1}});
            start_time=[hh mm ss];
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
timestamps=hmstext2seconds(ttimes);
end

function [seconds, hh, mm, ss]=hmstext2seconds(hmstext)

%Hours
hh=zeros(1,length(hmstext));
%Minutes
ss=hh;
%Seconds
mm=hh;

%Total seconds
totalsecs=hh;

%Loop through each cell of text
for i=1:length(hmstext)
    %Extract the hours minutes and seconds
    ctime=fixstring(hmstext{i});
    
    tfields=strfind(ctime,':');
    
    
    h=str2double(deblank(ctime(1:tfields(1)-1)));
    hh(i)=h(~isnan(h));
    m=str2double(deblank(ctime(tfields(1)+1:tfields(2)-1)));
    mm(i)=m(~isnan(m));
    s=str2double(deblank(ctime(tfields(2)+1:end)));
    ss(i)=s(~isnan(m));
end

%Compute the total time of the hour of the day
totalsecs=ss+mm*60+hh*3600;

%Convert to seconds with proper adjustment for overlappingd days
seconds=[0 cumsum(mod(diff(totalsecs),3600*24))];
end

function s_out = fixstring(s_in)
s_out=s_in(double(s_in) >= 46 & double(s_in)<=58);
end
