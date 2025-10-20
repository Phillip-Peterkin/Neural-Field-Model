function data_out = load_raw_data(data_path, subject_id, session_id, config)
% Load BIDS EEG/iEEG data with session support
fprintf('Loading data for subject %s, session %s...\n', subject_id, session_id);

% Construct path based on whether sessions exist
if strcmp(session_id, 'none')
    sub_dir = fullfile(data_path, sprintf('sub-%s', subject_id));
else
    sub_dir = fullfile(data_path, sprintf('sub-%s', subject_id), sprintf('ses-%s', session_id));
end

% Look for eeg or ieeg directory
if exist(fullfile(sub_dir, 'eeg'), 'dir')
    data_dir = fullfile(sub_dir, 'eeg');
    modality = 'eeg';
elseif exist(fullfile(sub_dir, 'ieeg'), 'dir')
    data_dir = fullfile(sub_dir, 'ieeg');
    modality = 'ieeg';
else
    error('No eeg or ieeg directory found for subject %s session %s', subject_id, session_id);
end

fprintf('  Found %s data in: %s\n', modality, data_dir);

% Find EEG/iEEG file
eeg_files = [dir(fullfile(data_dir, '*.edf')); ...
             dir(fullfile(data_dir, '*.set')); ...
             dir(fullfile(data_dir, '*.vhdr'))];

if isempty(eeg_files)
    error('No EEG/iEEG file found in %s', data_dir);
end

% Use first file found
data_file = fullfile(data_dir, eeg_files(1).name);
fprintf('  Loading file: %s\n', eeg_files(1).name);

% Load using FieldTrip
cfg = [];
cfg.dataset = data_file;

try
    if contains(eeg_files(1).name, '.edf')
        cfg.dataformat = 'edf';
    elseif contains(eeg_files(1).name, '.set')
        cfg.dataformat = 'eeglab_set';
    elseif contains(eeg_files(1).name, '.vhdr')
        cfg.dataformat = 'brainvision_eeg';
    end
    data_out = ft_preprocessing(cfg);
catch ME
    warning('Error loading with FieldTrip: %s', ME.message);
    error('Could not load data');
end

% Load events
events_file = dir(fullfile(data_dir, '*_events.tsv'));
if ~isempty(events_file)
    events = readtable(fullfile(data_dir, events_file(1).name), 'FileType', 'text', 'Delimiter', '\t');
    data_out.events = events;
    fprintf('  Loaded %d events\n', height(events));
end

% Load channels
channels_file = dir(fullfile(data_dir, '*_channels.tsv'));
if ~isempty(channels_file)
    channels = readtable(fullfile(data_dir, channels_file(1).name), 'FileType', 'text', 'Delimiter', '\t');
    data_out.channel_info = channels;
    
    if ismember('type', channels.Properties.VariableNames)
        scalp_idx = strcmp(channels.type, 'EEG');
        ieeg_idx = strcmp(channels.type, 'SEEG') | strcmp(channels.type, 'ECOG');
        data_out.scalp_channels = channels.name(scalp_idx);
        data_out.ieeg_channels = channels.name(ieeg_idx);
        fprintf('  %d scalp EEG, %d depth channels\n', sum(scalp_idx), sum(ieeg_idx));
    end
end

data_out.subject = subject_id;
data_out.session = session_id;
fprintf('Data loaded: %d channels, %.1f Hz\n', length(data_out.label), data_out.fsample);
end
