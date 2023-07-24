%% Data path
save_name = 'dataSorted_90_left.mat';
datapath = '/media/maikito/01D6CFB346EBEA501/work/dancause_data/stroke/stroke_data/20180608Y';
savepath = '/home/maikito/mad/cajal_summer_school/project/processed_data';
% savepath = 'D:\ub_neuroComp\dancause_data\processing\2_prestroke_actions\export';

%% Add Paths
% restoredefaultpath
addpath(datapath)
addpath('/media/maikito/01D6CFB346EBEA501/work/dancause_data/processing/2_prestroke_actions')
addpath('/media/maikito/01D6CFB346EBEA501/work/dancause_data/processing/2_prestroke_actions/utils')
addpath(savepath)

%% Detect and select files
hand = {'Left'}; %'Left'
precision_angle = {'Precision_90'}; % '0','45','90','135'};
aligned_to = {'GraspStart'}; %'CueOn'
spikes = {'spikes'}; % 'spikeFree', or any other string for spikes
% data_options = [hand, aligned_to, spikes]; 

%% Channel2Electrode Map
PMv_left = [110 112 105 107 109 111 97 99 101 103 98 100 102 104 106 108 90 88 86 92 94 96 89 91 93 95 173 175 177 179 81 83 85 87 82 84 169 171 166 168 170 172 174 176 178 180 154 160 162 164 157 159 161 163 165 167 149 151 153 155 150 152 158 156];
PMd_left = [137 139 141 143 133 135 130 132 134 136 138 140 142 144 118 124 126 128 121 123 125 127 129 131 113 115 117 119 114 116 122 120];
PMd_right = [78 80 73 75 77 79 65 67 69 71 66 68 70 72 74 76 58 56 54 60 62 64 57 59 61 63 37 44 46 48 49 51 53 55 50 52 22 24 26 28 30 32 34 36 39 41 29 35 38 40 42 43 45 47 18 20 17 19 21 23 25 27 33 31];
PMv_right = [220 218 216 214 219 217 215 213 231 229 227 225 223 221 228 226 224 222 244 242 240 238 236 234 232 230 235 233 210 212 205 207 209 211 243 241 239 237 197 199 201 203 198 200 202 204 206 208 190 188 186 192 194 196 189 191 193 195 181 183 185 187 182 184];
M1_left = [270 272 274 276 269 271 273 275 257 259 261 263 265 267 262 264 266 268 246 248 254 252 250 256 258 260 253 255 245 247 249 251];

channel_electrode_map = [PMv_left, PMd_left, PMd_right, PMv_right, M1_left];

%% Pre-process switches
standardize = false;  % z-score signal (on trial-by-trial basis)
rereference = false;  % "common median referencing"

%% Preprocessing Pipeline

excluded_channels = struct; excluded_channels.channelFlags = [];
channel_ids = struct; channel_ids.channels= [];

all_files = dir(datapath);
file_names = cell(1,length(all_files));
for i = 1:length(file_names)
   file_names{i} = all_files(i).name; 
end

if strcmp(spikes{1}, 'spikeFree')
    inds = contains(file_names, hand) & contains(file_names, aligned_to) & contains(file_names, precision_angle) & contains(file_names, spikes); 
else
    inds = contains(file_names, hand) & contains(file_names, aligned_to) & contains(file_names, precision_angle) & ~contains(file_names, 'spikeFree');
end

files_to_load_right = file_names(inds);
%% Load Data
n_trials = length(files_to_load_right);

cueOns = zeros(1,n_trials);
cueOffs = zeros(1,n_trials);
graspStarts = zeros(1,n_trials);

event_names = {'Right hand Precision_CueOn', 'Right hand Precision_CueOff', 'Right hand Precision_GraspStart'};
event_times = zeros([length(files_to_load_right), length(event_names)]);
fprintf('Loading Right %d files... \n', length(files_to_load_right))
for f = 1:length(files_to_load_right)
    if f == 1
        load(files_to_load_right{f});
        lfpData_right = F;
        channelFlags = ChannelFlag;

        events_ = {Events(:).label};
        event_inds = zeros([1, length(event_names)]);
        for e = 1:length(event_names)
            event_inds(e) = find(strcmp(events_, event_names(e)));
        end
        event_times(f,:) = [Events(event_inds).times];

        cueOns(f) = Events(1).times; cueOffs(f) = Events(5).times; graspStarts(f) = Events(9).times;
    else
        load(files_to_load_right{f});
        lfpData_right = cat(3, lfpData_right, F);
        channelFlags = cat(2, channelFlags, ChannelFlag);

        events_ = {Events(:).label};
        event_inds = zeros([1, length(event_names)]);
        for e = 1:length(event_names)
            event_inds(e) = find(strcmp(events_, event_names(e)));
        end
        event_times(f,:) = [Events(event_inds).times];
        
        % extract times
        cueOn_ind = find(strcmp({Events.label}, event_names{1}));
        cueOns(f) = Events(cueOn_ind).times;

        cueOff_ind = find(strcmp({Events.label}, event_names{2}));
        cueOffs(f) = Events(cueOff_ind).times;

        graspStart_ind = find(strcmp({Events.label}, event_names{3}));
        graspStarts(f) = Events(graspStart_ind).times;
    end
    fprintf('File %d loaded... \n', f)
    
    if f == n_trials
        break
    end
end

load([datapath,'/channel.mat'])
channel_ids(1).channels = Channel;

%% Rereference (Common Median Rereferencing) % FIIIIX
if rereference
    lfpData_right(PMv_left, :, :) = lfpData_right(PMv_left, :, :) - repmat(median(lfpData_right(PMv_left, :, :)),length(PMv_left), 1);
    lfpData_right(PMd_left, :, :) = lfpData_right(PMd_left, :, :) - repmat(median(lfpData_right(PMd_left, :, :)),length(PMd_left), 1);
    lfpData_right(PMd_right, :, :) = lfpData_right(PMd_right, :, :) - repmat(median(lfpData_right(PMd_right, :, :)),length(PMd_right), 1);
    lfpData_right(PMv_right, :, :) = lfpData_right(PMv_right, :, :) - repmat(median(lfpData_right(PMv_right, :, :)),length(PMv_right), 1);
    lfpData_right(M1_left, :, :) = lfpData_right(M1_left, :, :) - repmat(median(lfpData_right(M1_left, :, :)),length(M1_left), 1);
    fprintf('Rereference complete...\n')
end

%% Rearrange channels based on Channel2Electrode map
lfpData_right = lfpData_right(channel_electrode_map,:,:);
fprintf('Channel2Electrode mapping complete...\n')

%% Standardize (z-score)
if standardize
    for t = 1:size(lfpData_right,3)
            for ch = 1:size(lfpData_right,1)
                mu = mean(lfpData_right(ch,:,t));
                sdev = std(lfpData_right(ch,:,t));
                lfpData_right(ch,:,t) = (lfpData_right(ch,:,t) - mu) / (sdev+0.00001);
            end
    end
        fprintf('Data standardized...\n')
end
%% Separate actions
sample_duration = 0.25;

min_baseline = min(cueOns+Time(end));
min_pre_grasp = min(cueOffs - cueOns);
min_reach = min(graspStarts - cueOffs);
% min_grasp % grasp set to graspStart + sample_duration 
min_post_grasp = min(Time(end) - (graspStarts + sample_duration)); % check for too large duration
if  min_baseline < sample_duration ||  min_pre_grasp < sample_duration || min_reach < sample_duration ||  min_post_grasp < sample_duration
    error('Sample duration too large. Cannot make samples with identical durations.')
end
trial_duration = Time(end) - Time(1);
fs = length(Time)  / trial_duration;
samples_per_sample = floor(sample_duration * fs);

fprintf('Extracting baselines...\n')
baseline_inds = NaN(n_trials, 2);
for t = 1: n_trials %baselines
    min_ind = ceil(median(find(Time < cueOns(t)))) - floor(samples_per_sample / 2);
    max_ind = ceil(median(find(Time < cueOns(t)))) + floor(samples_per_sample / 2) - 1;
    baseline_inds(t, 1) = min_ind;
    baseline_inds(t, 2) = max_ind;
    if t == 1
        baselines = lfpData_right(:,min_ind:max_ind,t);
    else
        baseline = lfpData_right(:,min_ind:max_ind,t);
        baselines = cat(3,baselines,baseline);
    end   
end

fprintf('Extracting pre_grasps...\n')
pre_grasp_inds = NaN(n_trials, 2);
for t = 1: n_trials %pre_grasps
    min_ind = ceil(median(find(Time > cueOns(t) & Time < cueOffs(t)))) - floor(samples_per_sample / 2);
    max_ind = ceil(median(find(Time > cueOns(t) & Time < cueOffs(t)))) + floor(samples_per_sample / 2) - 1;
    pre_grasp_inds(t, 1) = min_ind;
    pre_grasp_inds(t, 2) = max_ind;
    if t == 1
        pre_grasps = lfpData_right(:,min_ind:max_ind,t);
    else
        pre_grasp = lfpData_right(:,min_ind:max_ind,t);
        pre_grasps = cat(3,pre_grasps,pre_grasp);
    end   
end
fprintf('Extracting reaches...\n')
reach_inds = NaN(n_trials, 2);
for t = 1: n_trials %reaches
    min_ind = ceil(median(find(Time > cueOffs(t) & Time < graspStarts(t)))) - floor(samples_per_sample / 2);
    max_ind = ceil(median(find(Time > cueOffs(t) & Time < graspStarts(t)))) + floor(samples_per_sample / 2) - 1;
    reach_inds(t, 1) = min_ind;
    reach_inds(t, 2) = max_ind;
    if t == 1
        reaches = lfpData_right(:,min_ind:max_ind,t);
    else
        reach = lfpData_right(:,min_ind:max_ind,t);
        reaches = cat(3,reaches,reach);
    end   
end
fprintf('Extraction grasps...\n')
grasp_inds = NaN(n_trials, 2);
for t = 1: n_trials %grasps
    min_ind = ceil(median(find(Time > graspStarts(t) & Time < (graspStarts(t)+sample_duration)))) - floor(samples_per_sample / 2);
    max_ind = ceil(median(find(Time > graspStarts(t) & Time < (graspStarts(t)+sample_duration)))) + floor(samples_per_sample / 2) - 1;
    grasp_inds(t, 1) = min_ind;
    grasp_inds(t, 2) = max_ind;
    if t == 1
        grasps = lfpData_right(:,min_ind:max_ind,t);
    else
        grasp = lfpData_right(:,min_ind:max_ind,t);
        grasps = cat(3,grasps,grasp);
    end   
end
fprintf('Extracting post_grasps...\n')
post_grasp_inds = NaN(n_trials, 2);
for t = 1: n_trials %post_grasps
    min_ind = ceil(median(find(Time > (graspStarts(t)+sample_duration)))) - floor(samples_per_sample / 2);
    max_ind = ceil(median(find(Time > graspStarts(t)+sample_duration))) + floor(samples_per_sample / 2) - 1;
    post_grasp_inds(t, 1) = min_ind;
    post_grasp_inds(t, 2) = max_ind;
    if t == 1
        post_grasps = lfpData_right(:,min_ind:max_ind,t);
    else
        post_grasp = lfpData_right(:,min_ind:max_ind,t);
        post_grasps = cat(3,post_grasps,post_grasp);
    end   
end

%% Join actions
out = cat(4, baselines, pre_grasps, reaches, grasps, post_grasps);
clear baselines
clear pre_grasps
clear reaches
clear grasps
clear post_grasps

%% Save preprocessed data
% dataSorted = lfpData; 
cd(savepath)
% save(save_name, 'lfpData', '-v7.3') % output format: dataSorted =
% n_channels x time_samples x trials x conditions

cd(savepath)
data = struct;
data.raw = lfpData_right;
data.epoched = out;
data.time = Time;
data.event_names = event_names;
data.event_times = event_times;
data.standardized = standardize;
data.rereferenced = rereference;

save(save_name, 'data')
fprintf('Preprocessed data saved...\nPreprocessing completed. \n')





