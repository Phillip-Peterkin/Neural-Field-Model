function results = process_single_subject(subject_id, config, data_handler)
% PROCESS_SINGLE_SUBJECT
% Process one subject through all analysis stages
%
% Inputs:
%   subject_id - Subject identifier (e.g., 'sub-01')
%   config - Configuration structure from config_harmonic_field
%   data_handler - BIDSDataHandler instance
%
% Output:
%   results - Structure containing all analysis results

fprintf('\n┌─────────────────────────────────────────────────────┐\n');
fprintf('│ Processing: %s                               │\n', subject_id);
fprintf('└─────────────────────────────────────────────────────┘\n');

results = struct();
results.subject_id = subject_id;
results.status = 'processing';

try
    %% Stage 0: Load Data
    fprintf('[Stage 0] Loading data...\n');
    
    % Get sessions for this subject
    sessions = data_handler.sessions.(subject_id);
    
    % Load first session (can be extended to loop over sessions)
    session_id = sessions{1};
    
    % Load continuous data
    raw_data = data_handler.load_subject_data(subject_id, session_id);
    
    % Segment into trials
    trial_window = [-0.5, 8.5]; % Pre-stim to end of trial
    trials = data_handler.segment_trials(raw_data, trial_window);
    
    results.data_info.n_channels = size(raw_data.signal, 1);
    results.data_info.srate = raw_data.srate;
    results.data_info.n_trials = length(trials);
    results.data_info.duration = raw_data.metadata.duration;
    
    fprintf('  ✓ Loaded: %d channels, %d trials\n', ...
        results.data_info.n_channels, results.data_info.n_trials);
    
    %% Stage 1: Spectral Analysis
    fprintf('[Stage 1] Spectral analysis...\n');
    spectral_analyzer = SpectralAnalyzer(config);
    results.spectral = spectral_analyzer.analyze(raw_data);
    fprintf('  ✓ Power spectra and aperiodic fit complete\n');
    
    %% Stage 2: Connectivity Analysis
    fprintf('[Stage 2] Connectivity analysis...\n');
    connectivity_analyzer = ConnectivityAnalyzer(config);
    results.connectivity = connectivity_analyzer.analyze(raw_data);
    fprintf('  ✓ PLV/wPLI computed\n');
    
    %% Stage 3: Phase-Amplitude Coupling
    fprintf('[Stage 3] Phase-amplitude coupling...\n');
    pac_analyzer = PACAnalyzer(config);
    results.pac = pac_analyzer.analyze(raw_data);
    fprintf('  ✓ Theta-gamma PAC computed\n');
    
    %% Stage 4: Event-Related Analysis
    fprintf('[Stage 4] Event-related potentials...\n');
    erp_analyzer = ERPAnalyzer(config);
    results.erp = erp_analyzer.analyze(trials);
    fprintf('  ✓ ERPs extracted\n');
    
    %% Stage 5: Access Detection
    fprintf('[Stage 5] Access detection...\n');
    access_detector = AccessDetector(config);
    results.access = access_detector.detect(raw_data, results.spectral, results.connectivity);
    fprintf('  ✓ Access windows detected: %d events\n', results.access.n_events);
    
    %% Stage 6: Energy Budget
    fprintf('[Stage 6] Energy budget analysis...\n');
    energy_analyzer = EnergyBudget(config);
    results.energy = energy_analyzer.compute(raw_data, results.spectral);
    fprintf('  ✓ Energy: %.2f (cap: %.2f)\n', ...
        results.energy.mean_power, results.energy.cap);
    
    %% Stage 7: Task Decoding
    fprintf('[Stage 7] Task condition decoding...\n');
    task_decoder = TaskDecoder(config);
    results.decoder = task_decoder.decode_all_conditions(trials, raw_data.events);
    fprintf('  ✓ Decoding accuracies:\n');
    fprintf('      SetSize: %.1f%%\n', results.decoder.setsize.accuracy * 100);
    fprintf('      Correct: %.1f%%\n', results.decoder.correct.accuracy * 100);
    fprintf('      Match:   %.1f%%\n', results.decoder.match.accuracy * 100);
    
    %% Save checkpoint
    checkpoint_file = fullfile(config.paths.checkpoints, ...
        sprintf('%s_checkpoint.mat', subject_id));
    save(checkpoint_file, 'results', '-v7.3');
    
    results.status = 'complete';
    fprintf('  ✓ Checkpoint saved: %s\n', checkpoint_file);
    
catch ME
    results.status = 'failed';
    results.error = ME.message;
    results.error_stack = ME.stack;
    
    warning('ProcessSubject:Failed', 'Subject %s failed: %s', subject_id, ME.message);
end

fprintf('└─────────────────────────────────────────────────────┘\n\n');

end