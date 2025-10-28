classdef BIDSDataHandler < handle
    % BIDSDATAHANDLER
    % Intelligent BIDS dataset handler with automatic format detection
    % Handles memory-efficient loading of EEG/iEEG data
    
    properties
        data_root
        subjects
        sessions
        dataset_description
    end
    
    methods
        function obj = BIDSDataHandler(data_root)
            % Constructor
            if ~exist(data_root, 'dir')
                error('BIDSDataHandler:InvalidPath', 'Data root does not exist: %s', data_root);
            end
            obj.data_root = data_root;
            obj.subjects = {};
            obj.sessions = struct();
            
            % Load dataset description if available
            desc_file = fullfile(data_root, 'dataset_description.json');
            if exist(desc_file, 'file')
                obj.dataset_description = jsondecode(fileread(desc_file));
            else
                obj.dataset_description = struct('Name', 'Unknown');
            end
            
            fprintf('BIDS Data Handler initialized\n');
            fprintf('  Dataset: %s\n', obj.dataset_description.Name);
            fprintf('  Root: %s\n', data_root);
        end
        
        function subjects = discover_subjects(obj)
            % DISCOVER_SUBJECTS Find all subjects in BIDS directory
            
            subject_dirs = dir(fullfile(obj.data_root, 'sub-*'));
            subject_dirs = subject_dirs([subject_dirs.isdir]);
            
            subjects = cell(length(subject_dirs), 1);
            
            for i = 1:length(subject_dirs)
                subject_id = subject_dirs(i).name;
                subjects{i} = subject_id;
                
                % Store sessions using ORIGINAL subject_id (with hyphen)
                session_dirs = dir(fullfile(obj.data_root, subject_id, 'ses-*'));
                session_dirs = session_dirs([session_dirs.isdir]);
                
                if ~isempty(session_dirs)
                    obj.sessions.(subject_id) = {session_dirs.name}; % USE ORIGINAL NAME
                else
                    obj.sessions.(subject_id) = {''}; % No session subdirectory
                end
            end
            
            subjects = subjects(~cellfun(@isempty, subjects));
        end
                
        function data = load_subject_data(obj, subject_id, session_id, varargin)
            % LOAD_SUBJECT_DATA Load EEG/iEEG data for subject
            
            % Parse optional inputs
            p = inputParser;
            addParameter(p, 'modality', 'auto', @ischar);
            addParameter(p, 'chunk', [], @isnumeric);
            addParameter(p, 'channels', 'all', @(x) ischar(x) || iscell(x));
            parse(p, varargin{:});
            opts = p.Results;
            
            % Construct path to data
            if strcmp(opts.modality, 'auto')
                modality = obj.detect_modality(subject_id, session_id);
            else
                modality = opts.modality;
            end
            
            data_dir = fullfile(obj.data_root, subject_id, session_id, modality);
            if ~exist(data_dir, 'dir')
                error('BIDSDataHandler:DirectoryNotFound', 'Data directory not found: %s', data_dir);
            end
            
            % Find EDF file
            edf_files = dir(fullfile(data_dir, '*.edf'));
            if isempty(edf_files)
                error('BIDSDataHandler:NoEDFFile', 'No EDF file found in %s', data_dir);
            end
            edf_file = fullfile(data_dir, edf_files(1).name);
            
            fprintf('Loading: %s\n', edf_file);
            
            % Load with EEGLAB if available, otherwise use edfread
            try
                if exist('pop_biosig', 'file')
                    % Use EEGLAB
                    EEG = pop_biosig(edf_file, 'importevent', 'off');
                    
                    % Extract data
                    data.signal = double(EEG.data);
                    data.srate = EEG.srate;
                    data.channels = {EEG.chanlocs.labels};
                    data.time = (0:size(data.signal,2)-1) / data.srate;
                    
                else
                    % Use built-in edfread
                    [hdr, records] = edfread(edf_file);
                    
                    % Concatenate records
                    data.signal = [];
                    for i = 1:hdr.NumSignals
                        signal_i = cell2mat(records(i,:));
                        data.signal = [data.signal; signal_i(:)']; 
                    end
                    
                    data.srate = hdr.NumSamplesPerDataRecord(1) / hdr.DataRecordDuration;
                    data.channels = hdr.SignalLabels;
                    data.time = (0:size(data.signal,2)-1) / data.srate;
                end
                
                % Apply chunking if requested
                if ~isempty(opts.chunk)
                    idx_start = max(1, round(opts.chunk(1) * data.srate));
                    idx_end = min(size(data.signal,2), round(opts.chunk(2) * data.srate));
                    
                    data.signal = data.signal(:, idx_start:idx_end);
                    data.time = data.time(idx_start:idx_end);
                    
                    fprintf('  Chunk: %.1f - %.1f seconds\n', opts.chunk(1), opts.chunk(2));
                end
                
                % Select channels if specified
                if ~strcmp(opts.channels, 'all')
                    if ischar(opts.channels)
                        opts.channels = {opts.channels};
                    end
                    [~, chan_idx] = ismember(opts.channels, data.channels);
                    chan_idx = chan_idx(chan_idx > 0);
                    
                    data.signal = data.signal(chan_idx, :);
                    data.channels = data.channels(chan_idx);
                end
                
                fprintf('  Loaded: %d channels × %d samples (%.1f sec)\n', ...
                    size(data.signal,1), size(data.signal,2), data.time(end));
                
                % Load events
                data.events = obj.load_events(subject_id, session_id, modality);
                
                % Load channel info
                data.channel_info = obj.get_channel_info(subject_id, session_id, modality);
                
                % Metadata
                data.metadata.subject = subject_id;
                data.metadata.session = session_id;
                data.metadata.modality = modality;
                data.metadata.file = edf_file;
                data.metadata.duration = data.time(end);
                
            catch ME
                error('BIDSDataHandler:LoadFailed', 'Failed to load data: %s', ME.message);
            end
        end
        
        function events = load_events(obj, subject_id, session_id, modality)
            % LOAD_EVENTS Load task events from TSV file
            
            data_dir = fullfile(obj.data_root, subject_id, session_id, modality);
            event_files = dir(fullfile(data_dir, '*events.tsv'));
            
            if isempty(event_files)
                warning('BIDSDataHandler:NoEvents', 'No events file found for %s %s', subject_id, session_id);
                events = table();
                return;
            end
            
            event_file = fullfile(data_dir, event_files(1).name);
            
            try
                events = readtable(event_file, 'FileType', 'text', 'Delimiter', '\t');
                fprintf('  Events: %d trials loaded\n', height(events));
            catch ME
                warning('BIDSDataHandler:EventLoadFailed', 'Failed to load events: %s', ME.message);
                events = table();
            end
        end
        
        function chan_info = get_channel_info(obj, subject_id, session_id, modality)
            % GET_CHANNEL_INFO Load channel information from TSV
            
            data_dir = fullfile(obj.data_root, subject_id, session_id, modality);
            chan_files = dir(fullfile(data_dir, '*channels.tsv'));
            
            if isempty(chan_files)
                chan_info = table();
                return;
            end
            
            chan_file = fullfile(chan_files(1).folder, chan_files(1).name);
            
            try
                chan_info = readtable(chan_file, 'FileType', 'text', 'Delimiter', '\t');
            catch ME
                warning('BIDSDataHandler:ChannelInfoFailed', 'Failed to load channel info: %s', ME.message);
                chan_info = table();
            end
        end
        
        function modality = detect_modality(obj, subject_id, session_id)
            % DETECT_MODALITY Automatically detect if data is EEG or iEEG
            
            ieeg_dir = fullfile(obj.data_root, subject_id, session_id, 'ieeg');
            eeg_dir = fullfile(obj.data_root, subject_id, session_id, 'eeg');
            
            if exist(ieeg_dir, 'dir')
                modality = 'ieeg';
            elseif exist(eeg_dir, 'dir')
                modality = 'eeg';
            else
                error('BIDSDataHandler:ModalityNotFound', ...
                    'No eeg or ieeg directory found for %s %s', subject_id, session_id);
            end
        end
        
        function info = get_dataset_info(obj)
            % GET_DATASET_INFO Return summary of dataset
            
            if isempty(obj.subjects)
                obj.discover_subjects();
            end
            
            info.n_subjects = length(obj.subjects);
            info.subjects = obj.subjects;
            
            % Count total sessions
            total_sessions = 0;
            session_fields = fieldnames(obj.sessions);
            for i = 1:length(session_fields)
                total_sessions = total_sessions + length(obj.sessions.(session_fields{i}));
            end
            info.n_sessions = total_sessions;
            
            % Get first subject info as example
            if info.n_subjects > 0
                safe_subj_name = strrep(obj.subjects{1}, '-', '_');
                example_data = obj.load_subject_data(obj.subjects{1}, ...
                    obj.sessions.(safe_subj_name){1}, 'chunk', [0, 1]);
                info.example.channels = length(example_data.channels);
                info.example.srate = example_data.srate;
            end
        end
        
        function trials = segment_trials(~, data, trial_window)
            % SEGMENT_TRIALS Segment continuous data into trials
            %
            % Inputs:
            %   data - Output from load_subject_data
            %   trial_window - [pre, post] time around events (seconds)
            
            if isempty(data.events)
                error('BIDSDataHandler:NoEvents', 'No events available for segmentation');
            end
            
            n_trials = height(data.events);
            trials = cell(n_trials, 1);
            
            pre_samples = round(trial_window(1) * data.srate);
            post_samples = round(trial_window(2) * data.srate);
            
            for i = 1:n_trials
                % Get event onset in samples
                onset_sample = data.events.begSample(i);
                
                % Extract window
                idx_start = max(1, onset_sample - pre_samples);
                idx_end = min(size(data.signal, 2), onset_sample + post_samples);
                
                trials{i}.signal = data.signal(:, idx_start:idx_end);
                trials{i}.time = ((idx_start:idx_end) - onset_sample) / data.srate;
                trials{i}.event_info = data.events(i, :);
            end
            
            fprintf('  Segmented %d trials\n', n_trials);
        end
    end
end