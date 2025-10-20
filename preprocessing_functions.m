%% PREPROCESSING FUNCTIONS FOR ds004752 ANALYSIS
% Auto-detecting data discovery, loading, filtering, and cleaning

function subjects_info = discover_subjects_sessions(data_path)
% DISCOVER_SUBJECTS_SESSIONS - Auto-detect all subjects and sessions
%
% Just finds whatever exists, no assumptions about naming

fprintf('Discovering subjects and sessions in: %s\n', data_path);

subjects_info = struct();

% Find all directories starting with 'sub'
all_items = dir(fullfile(data_path, 'sub*'));
subject_dirs = all_items([all_items.isdir]);

for i = 1:length(subject_dirs)
    subj_name = subject_dirs(i).name;
    subj_path = fullfile(data_path, subj_name);
    
    % ONLY look for ses-* directories (not all directories)
    session_dirs = dir(fullfile(subj_path, 'ses-*'));
    session_dirs = session_dirs([session_dirs.isdir]);
    
    % Check each session directory for data
    session_names = {};
    for j = 1:length(session_dirs)
        sess_name = session_dirs(j).name;  % This will be 'ses-01', 'ses-02', etc.
        sess_path = fullfile(subj_path, sess_name);
        
        % Check if this directory contains eeg or ieeg data
        has_eeg = exist(fullfile(sess_path, 'eeg'), 'dir');
        has_ieeg = exist(fullfile(sess_path, 'ieeg'), 'dir');
        
        if has_eeg || has_ieeg
            session_names{end+1} = sess_name;  % Store full name like 'ses-01'
        end
    end
    
    if ~isempty(session_names)
        % Convert sub-01 to sub_01 for struct fieldname
        field_name = strrep(subj_name, '-', '_');
        subjects_info.(field_name) = session_names(:);
        
        fprintf('  %s: %d sessions\n', subj_name, length(session_names));
        fprintf('    Sessions: %s\n', strjoin(session_names, ', '));
    end
end

fprintf('Found %d subjects\n', length(fieldnames(subjects_info)));

end

function data = load_raw_data(data_path, subject_id, session_id, config)
% LOAD_RAW_DATA - Auto-detect and load whatever data exists
%
% Just finds the first .edf file it can

fprintf('Loading data for subject %s, session %s...\n', subject_id, session_id);

% Convert sub_01 back to sub-01 if needed
if contains(subject_id, '_')
    subject_id = strrep(subject_id, '_', '-');
end

% Build subject path
subject_path = fullfile(data_path, subject_id);
if ~exist(subject_path, 'dir')
    error('Subject directory not found: %s', subject_path);
end

% Try to find session directory (try multiple possibilities)
session_path = '';
possible_sessions = {
    session_id,                           % As provided (e.g., 'ses-01' or '01')
    ['ses-' session_id],                  % Add ses- prefix
    strrep(session_id, 'ses-', ''),       % Remove ses- prefix
    ['ses-' strrep(session_id, 'ses-', '')] % Ensure ses- prefix
};

for i = 1:length(possible_sessions)
    test_path = fullfile(subject_path, possible_sessions{i});
    fprintf('  Trying: %s... ', test_path);
    if exist(test_path, 'dir')
        session_path = test_path;
        fprintf('✓ Found!\n');
        break;
    else
        fprintf('✗\n');
    end
end

if isempty(session_path)
    error('Session directory not found. Tried:\n%s', ...
        strjoin(cellfun(@(x) fullfile(subject_path, x), possible_sessions, 'UniformOutput', false), '\n'));
end

% Look for data directories (try eeg first, then ieeg)
possible_dirs = {'eeg', 'ieeg'};
data_dir = '';

for i = 1:length(possible_dirs)
    test_dir = fullfile(session_path, possible_dirs{i});
    if exist(test_dir, 'dir')
        data_dir = test_dir;
        fprintf('  Found data in: %s\n', test_dir);
        break;
    end
end

if isempty(data_dir)
    error('No eeg or ieeg directory found in: %s', session_path);
end

% Find ANY .edf file
edf_files = dir(fullfile(data_dir, '*.edf'));
if isempty(edf_files)
    % Try .bdf
    edf_files = dir(fullfile(data_dir, '*.bdf'));
end
if isempty(edf_files)
    % Try .vhdr (BrainVision)
    edf_files = dir(fullfile(data_dir, '*.vhdr'));
end

if isempty(edf_files)
    error('No data files (.edf, .bdf, .vhdr) found in: %s', data_dir);
end

% Load first file found
data_file = fullfile(data_dir, edf_files(1).name);
fprintf('  Loading file: %s\n', edf_files(1).name);

% Use FieldTrip to load
cfg = [];
cfg.dataset = data_file;
cfg.continuous = 'yes';

try
    data = ft_preprocessing(cfg);
    fprintf('  Loaded: %d channels, %.1f Hz, %.1f seconds\n', ...
        length(data.label), data.fsample, data.time{1}(end));
catch ME
    error('Failed to load data: %s', ME.message);
end

% Try to load events (look for ANY events file)
events_files = dir(fullfile(data_dir, '*events.tsv'));
if ~isempty(events_files)
    try
        events = readtable(fullfile(data_dir, events_files(1).name), ...
            'FileType', 'text', 'Delimiter', '\t');
        data.events = events;
        fprintf('  Loaded %d events\n', height(events));
    catch
        fprintf('  Could not load events\n');
    end
end

% Try to load channel info
channels_files = dir(fullfile(data_dir, '*channels.tsv'));
if ~isempty(channels_files)
    try
        channels = readtable(fullfile(data_dir, channels_files(1).name), ...
            'FileType', 'text', 'Delimiter', '\t');
        data.channel_info = channels;
        fprintf('  Loaded channel info\n');
    catch
        fprintf('  Could not load channel info\n');
    end
end

% Classify channels
if isfield(data, 'channel_info') && istable(data.channel_info)
    try
        scalp_idx = strcmpi(data.channel_info.type, 'EEG');
        ieeg_idx = strcmpi(data.channel_info.type, 'SEEG') | ...
                   strcmpi(data.channel_info.type, 'ECOG') | ...
                   strcmpi(data.channel_info.type, 'DBS');
        
        data.scalp_channels = data.label(scalp_idx);
        data.ieeg_channels = data.label(ieeg_idx);
    catch
        % If classification fails, assume all are depth
        data.scalp_channels = {};
        data.ieeg_channels = data.label;
    end
else
    % No channel info, assume all are depth
    data.scalp_channels = {};
    data.ieeg_channels = data.label;
end

fprintf('  %d scalp EEG, %d depth channels\n', ...
    length(data.scalp_channels), length(data.ieeg_channels));

% Store metadata
data.subject = strrep(subject_id, 'sub-', '');
data.session = strrep(session_id, 'ses-', '');

end

function data_filtered = apply_filtering(data, preproc_cfg)
% APPLY_FILTERING - Apply filtering pipeline
%
% Resamples FIRST to ensure filter stability

fprintf('Applying preprocessing pipeline...\n');

%% STEP 1: RESAMPLE FIRST (critical for filter stability)
if ~isempty(preproc_cfg.resample_freq) && preproc_cfg.resample_freq ~= data.fsample
    fprintf('  1. Resampling: %.1f Hz -> %d Hz...', data.fsample, preproc_cfg.resample_freq);
    tic;
    
    cfg = [];
    cfg.resamplefs = preproc_cfg.resample_freq;
    cfg.detrend = 'no';
    cfg.demean = 'no';
    
    try
        data = ft_resampledata(cfg, data);
        fprintf(' ✓ (%.1f s)\n', toc);
    catch ME
        warning('Resampling failed: %s', ME.message);
        fprintf(' ✗ (skipped)\n');
    end
else
    fprintf('  1. Resampling: skipped\n');
end

%% STEP 2: DETREND
if preproc_cfg.detrend
    fprintf('  2. Detrending...');
    tic;
    
    cfg = [];
    cfg.detrend = 'yes';
    cfg.demean = 'no';
    
    try
        data = ft_preprocessing(cfg, data);
        fprintf(' ✓ (%.1f s)\n', toc);
    catch ME
        warning('Detrending failed: %s', ME.message);
        fprintf(' ✗ (failed)\n');
    end
else
    fprintf('  2. Detrending: skipped\n');
end

%% STEP 3: DEMEAN
if preproc_cfg.demean
    fprintf('  3. Demeaning...');
    tic;
    
    cfg = [];
    cfg.demean = 'yes';
    cfg.detrend = 'no';
    
    try
        data = ft_preprocessing(cfg, data);
        fprintf(' ✓ (%.1f s)\n', toc);
    catch ME
        warning('Demeaning failed: %s', ME.message);
        fprintf(' ✗ (failed)\n');
    end
else
    fprintf('  3. Demeaning: skipped\n');
end

%% STEP 4: BANDPASS FILTER
fprintf('  4. Bandpass filtering: %.1f-%.1f Hz (order %d)...', ...
    preproc_cfg.highpass, preproc_cfg.lowpass, preproc_cfg.order);
tic;

cfg = [];
cfg.bpfilter = 'yes';
cfg.bpfreq = [preproc_cfg.highpass preproc_cfg.lowpass];
cfg.bpfiltord = preproc_cfg.order;
cfg.bpfilttype = 'but';
cfg.bpfiltdir = 'twopass';
cfg.bpinstabilityfix = 'reduce';

try
    data = ft_preprocessing(cfg, data);
    fprintf(' ✓ (%.1f s)\n', toc);
catch ME
    error('Bandpass filtering failed: %s', ME.message);
end

%% STEP 5: NOTCH FILTER
if ~isempty(preproc_cfg.notch)
    fprintf('  5. Notch filtering: %s Hz...', mat2str(preproc_cfg.notch));
    tic;
    
    cfg = [];
    cfg.dftfilter = 'yes';
    cfg.dftfreq = preproc_cfg.notch;
    
    try
        data = ft_preprocessing(cfg, data);
        fprintf(' ✓ (%.1f s)\n', toc);
    catch ME
        warning('Notch filtering failed: %s', ME.message);
        fprintf(' ✗ (failed)\n');
    end
else
    fprintf('  5. Notch filtering: skipped\n');
end

data_filtered = data;
fprintf('✓ Preprocessing complete\n\n');

end

function data_clean = detect_and_remove_artifacts(data, preproc_cfg)
% DETECT_AND_REMOVE_ARTIFACTS - Simple artifact detection

fprintf('Detecting artifacts...\n');

if ~isfield(preproc_cfg, 'artifact')
    fprintf('  Artifact detection disabled\n');
    data_clean = data;
    return;
end

% Concatenate all trials
all_data = cat(2, data.trial{:});

% Detect bad channels
fprintf('  Checking channels...');
channel_std = std(all_data, 0, 2);
channel_max = max(abs(all_data), [], 2);

z_std = (channel_std - median(channel_std)) / mad(channel_std, 1);
z_max = (channel_max - median(channel_max)) / mad(channel_max, 1);

bad_channels = abs(z_std) > preproc_cfg.artifact.z_threshold | ...
               abs(z_max) > preproc_cfg.artifact.z_threshold;

fprintf(' %d bad channels\n', sum(bad_channels));

if any(bad_channels)
    cfg = [];
    cfg.channel = data.label(~bad_channels);
    data = ft_selectdata(cfg, data);
end

data_clean = data;
fprintf('✓ Artifact detection complete\n');

end

function data_reref = apply_rereferencing(data, preproc_cfg)
% APPLY_REREFERENCING - Optional rereferencing

fprintf('Applying rereferencing...\n');

if ~isfield(preproc_cfg, 'reref')
    data_reref = data;
    return;
end

if isfield(data, 'scalp_channels') && ~isempty(data.scalp_channels)
    cfg = [];
    cfg.channel = data.scalp_channels;
    cfg.reref = 'yes';
    cfg.refchannel = 'all';
    
    try
        data = ft_preprocessing(cfg, data);
        fprintf('  ✓ Average reference for scalp\n');
    catch
        fprintf('  ✗ Average reference failed\n');
    end
end

data_reref = data;
fprintf('✓ Rereferencing complete\n');

end

function data_epochs = create_epochs(data, preproc_cfg)
% CREATE_EPOCHS - Placeholder for epoching

fprintf('Creating epochs...\n');

if ~isfield(data, 'events') || isempty(data.events)
    fprintf('  No events, keeping continuous\n');
    data_epochs = data;
    return;
end

fprintf('  Epoching not implemented yet\n');
data_epochs = data;

end