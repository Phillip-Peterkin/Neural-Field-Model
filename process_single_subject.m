function results = process_single_subject(subject_id, config, data_handler)
% PROCESS_SINGLE_SUBJECT - Production-quality processor
% Returns results with guaranteed structure even on failure

fprintf('\n┌─────────────────────────────────────────────────────┐\n');
fprintf('│ Processing: %-40s │\n', subject_id);
fprintf('└─────────────────────────────────────────────────────┘\n');

% Initialize results with COMPLETE structure upfront
results = initialize_results_structure(subject_id);

try
    %% STAGE 0: Data Loading
    fprintf('[Stage 0] Loading data...\n');
    
    % Try to get sessions - handle both hyphenated and underscore field names
    sessions = [];
    if isfield(data_handler.sessions, subject_id)
        % Original name with hyphen
        sessions = data_handler.sessions.(subject_id);
    else
        % Try safe name with underscore
        safe_subj_name = strrep(subject_id, '-', '_');
        if isfield(data_handler.sessions, safe_subj_name)
            sessions = data_handler.sessions.(safe_subj_name);
        else
            error('Cannot find sessions for subject %s', subject_id);
        end
    end
    
    if isempty(sessions)
        error('No sessions found for subject %s', subject_id);
    end
    
    session_id = sessions{1};
    
    %% STAGE 1: Spectral Analysis
    fprintf('[Stage 1] Spectral analysis...\n');
    results.spectral = run_stage_safe(@SpectralAnalyzer, raw_data, config);
    
    %% STAGE 2: Connectivity Analysis  
    fprintf('[Stage 2] Connectivity analysis...\n');
    results.connectivity = run_stage_safe(@ConnectivityAnalyzer, raw_data, config);
    
    %% STAGE 3: Phase-Amplitude Coupling
    fprintf('[Stage 3] Phase-amplitude coupling...\n');
    results.pac = run_stage_safe(@PACAnalyzer, raw_data, config);
    
    %% STAGE 4: Event-Related Potentials
    fprintf('[Stage 4] Event-related analysis...\n');
    results.erp = run_stage_safe(@ERPAnalyzer, trials, config);
    
    %% STAGE 5: Access Detection
    fprintf('[Stage 5] Access detection...\n');
    results.access = run_stage_safe(@AccessDetector, {raw_data, results.spectral, results.connectivity}, config);
    
    %% STAGE 6: Energy Budget
    fprintf('[Stage 6] Energy budget...\n');
    results.energy = run_stage_safe(@EnergyBudget, {raw_data, results.spectral}, config);
    
    %% STAGE 7: Task Decoding
    fprintf('[Stage 7] Task decoding...\n');
    results.decoder = run_stage_safe(@TaskDecoder, {trials, raw_data.events}, config);
    
    %% Save checkpoint
    checkpoint_file = fullfile(config.paths.checkpoints, sprintf('%s_checkpoint.mat', subject_id));
    save(checkpoint_file, 'results', '-v7.3');
    
    results.status = 'complete';
    fprintf('  ✓ Checkpoint saved\n');
    
catch ME
    results.status = 'failed';
    results.error = ME.message;
    results.error_stack = struct('name', {ME.stack.name}, 'line', {ME.stack.line});
    
    fprintf('\n✗✗✗ PROCESSING FAILED ✗✗✗\n');
    fprintf('Error: %s\n', ME.message);
    
    % Save failed result for debugging
    checkpoint_file = fullfile(config.paths.checkpoints, sprintf('%s_FAILED.mat', subject_id));
    save(checkpoint_file, 'results', 'ME', '-v7.3');
end

fprintf('└─────────────────────────────────────────────────────┘\n\n');

end

%% Helper: Initialize complete structure
function results = initialize_results_structure(subject_id)
    results = struct();
    results.subject_id = subject_id;
    results.status = 'processing';
    results.data_info = struct('n_channels', 0, 'srate', 0, 'n_trials', 0, 'duration', 0);
    results.spectral = struct();
    results.connectivity = struct();
    results.pac = struct();
    results.erp = struct();
    results.access = struct();
    results.energy = struct();
    results.decoder = struct();
end

%% Helper: Load data safely
function [raw_data, trials] = load_subject_data_safe(subject_id, data_handler)
    safe_subj_name = strrep(subject_id, '-', '_');
    sessions = data_handler.sessions.(safe_subj_name);
    session_id = sessions{1};
    
    raw_data = data_handler.load_subject_data(subject_id, session_id);
    
    % Segment trials
    trial_window = [-0.5, 8.5];
    trials = data_handler.segment_trials(raw_data, trial_window);
end

%% Helper: Run analysis stage with error handling
function result = run_stage_safe(analyzer_class, data, config)
    try
        if iscell(data)
            % Multiple inputs (e.g., AccessDetector needs raw_data, spectral, connectivity)
            analyzer = analyzer_class(config);
            if isscalar(data)
                result = analyzer.analyze(data{1});
            elseif length(data) == 2
                result = analyzer.compute(data{1}, data{2});
            elseif length(data) == 3
                result = analyzer.detect(data{1}, data{2}, data{3});
            end
        else
            % Single input
            analyzer = analyzer_class(config);
            result = analyzer.analyze(data);
        end
        fprintf('  ✓ Complete\n');
    catch ME
        fprintf('  ✗ FAILED: %s\n', ME.message);
        result = struct('status', 'failed', 'error', ME.message);
    end
end