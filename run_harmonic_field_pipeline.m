function run_harmonic_field_pipeline(varargin)
% RUN_HARMONIC_FIELD_PIPELINE
% Master controller for Harmonic Field Theory analysis pipeline
% 
% Usage:
%   run_harmonic_field_pipeline()                    % Process all subjects
%   run_harmonic_field_pipeline('subject', 'sub-01') % Single subject
%   run_harmonic_field_pipeline('resume', true)      % Resume from checkpoint
%
% Author: Phillip Peterkin - Harmonic Field Theory
% Date: 2025

%% Parse inputs
p = inputParser;
addParameter(p, 'subject', 'all', @ischar);
addParameter(p, 'session', 'all', @ischar);
addParameter(p, 'resume', false, @islogical);
addParameter(p, 'test_mode', false, @islogical); % Quick test on 1 subject
parse(p, varargin{:});
opts = p.Results;

%% Initialize
clc;
fprintf('\n╔════════════════════════════════════════════════════════════════╗\n');
fprintf('║         HARMONIC FIELD THEORY ANALYSIS PIPELINE               ║\n');
fprintf('║  Energy, Coherence, and Content: Neural Access Prerequisites  ║\n');
fprintf('╚════════════════════════════════════════════════════════════════╝\n\n');

% Start timer
tic;
pipeline_start = datetime('now');

% Initialize logging
log_file = fullfile('logs', sprintf('pipeline_%s.log', ...
    char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))));
diary(log_file);

try
    %% Step 1: Load Configuration
    fprintf('[1/9] Loading configuration...\n');
    config = config_harmonic_field();
    config.pipeline.start_time = pipeline_start;
    config.pipeline.log_file = log_file;
    fprintf('      ✓ Configuration loaded\n\n');
    
    %% Step 2: Initialize Data Handler
    fprintf('[2/9] Initializing BIDS data handler...\n');
    data_handler = BIDSDataHandler(config.paths.data_root);
    
    % Discover subjects
    if strcmp(opts.subject, 'all')
        subjects = data_handler.discover_subjects();
        if opts.test_mode
            subjects = subjects(1); % Test mode: only first subject
            fprintf('      ⚠ TEST MODE: Processing only %s\n', subjects{1});
        end
    else
        subjects = {opts.subject};
    end
    
    fprintf('      ✓ Found %d subject(s): %s\n\n', ...
        length(subjects), strjoin(subjects, ', '));
    
    %% Step 3: Initialize Parallel Pool
    fprintf('[3/9] Setting up parallel processing...\n');
    pool = setup_parallel_pool(config.compute.num_workers);
    if ~isempty(pool)
        fprintf('      ✓ Parallel pool: %d workers\n\n', pool.NumWorkers);
    else
        fprintf('      ⚠ Running in serial mode\n\n');
    end
    
    %% Step 4: Check for Resume
    if opts.resume
        fprintf('[4/9] Checking for checkpoints...\n');
        checkpoint = load_checkpoint(config);
        if ~isempty(checkpoint)
            fprintf('      ✓ Resuming from %s\n\n', checkpoint.timestamp);
            % Filter subjects already processed
            subjects = setdiff(subjects, checkpoint.completed_subjects);
        else
            fprintf('      ⚠ No checkpoint found, starting fresh\n\n');
        end
    else
        fprintf('[4/9] Starting fresh analysis\n\n');
    end
    
    %% Step 5: Subject-Level Processing
    fprintf('[5/9] Processing subjects...\n');
    fprintf('═══════════════════════════════════════════════════════════════\n\n');
    
    n_subjects = length(subjects);
    results = cell(n_subjects, 1);
    
    parfor (subj_idx = 1:n_subjects, config.compute.num_workers)
        try
            subj_id = subjects{subj_idx};
            fprintf('  → Subject %d/%d: %s\n', subj_idx, n_subjects, subj_id);
            
            % Process single subject
            results{subj_idx} = process_single_subject(subj_id, config, data_handler);
            
            fprintf('  ✓ Subject %s completed\n\n', subj_id);
            
        catch ME
            warning('HarmonicField:SubjectProcessing', 'Subject %s failed: %s', ...
                subjects{subj_idx}, ME.message);
            results{subj_idx} = [];
            log_error(config, subjects{subj_idx}, ME);
        end
    end
    
    fprintf('═══════════════════════════════════════════════════════════════\n\n');
    
    %% Step 6: Group-Level Analysis
    fprintf('[6/9] Running group-level analysis...\n');
    group_results = aggregate_group_results(results, subjects, config);
    fprintf('      ✓ Group statistics computed\n\n');
    
    %% Step 7: Cross-Validation
    fprintf('[7/9] Running cross-validation...\n');
    validation = run_cross_validation(results, subjects, config);
    fprintf('      ✓ Out-of-sample accuracy: %.2f%%\n\n', ...
        validation.accuracy * 100);
    
    %% Step 8: Generate Figures
    fprintf('[8/9] Generating figures...\n');
    visualization_engine = VisualizationEngine(config);
    visualization_engine.generate_all_figures(results, group_results, validation);
    fprintf('      ✓ All figures saved\n\n');
    
    %% Step 9: Final Report
    fprintf('[9/9] Generating final report...\n');
    report = generate_final_report(config, results, group_results, validation);
    report_file = fullfile(config.paths.results, ...
        sprintf('final_report_%s.json', char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))));
    save_json(report_file, report);
    fprintf('      ✓ Report saved: %s\n\n', report_file);
    
    %% Success
    total_time = toc;
    fprintf('╔════════════════════════════════════════════════════════════════╗\n');
    fprintf('║                    PIPELINE COMPLETED                          ║\n');
    fprintf('╠════════════════════════════════════════════════════════════════╣\n');
    fprintf('║  Total time: %.1f minutes                                    ║\n', total_time/60);
    fprintf('║  Subjects processed: %d/%d                                    ║\n', ...
        sum(~cellfun(@isempty, results)), n_subjects);
    fprintf('║  Report: %s\n', report_file);
    fprintf('╚════════════════════════════════════════════════════════════════╝\n\n');
    
catch ME
    fprintf('\n❌ PIPELINE FAILED\n');
    fprintf('Error: %s\n', ME.message);
    fprintf('Stack trace:\n');
    disp(getReport(ME, 'extended'));
    
    % Save crash report
    crash_file = fullfile('logs', sprintf('crash_%s.mat', ...
        char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'))));
    save(crash_file, 'ME', 'config', 'subjects');
    fprintf('\nCrash dump saved: %s\n', crash_file);
    
    rethrow(ME);
end

diary off;

end

%% ========================================================================
%  HELPER FUNCTIONS
%  ========================================================================

function pool = setup_parallel_pool(num_workers)
% Setup parallel pool with error handling
try
    current_pool = gcp('nocreate');
    if isempty(current_pool)
        pool = parpool('local', num_workers);
    else
        pool = current_pool;
        if pool.NumWorkers ~= num_workers
            delete(pool);
            pool = parpool('local', num_workers);
        end
    end
catch ME
    warning('HarmonicField:ParallelPool', 'Failed to create parallel pool: %s', ME.message);
    pool = [];
end
end

function checkpoint = load_checkpoint(config)
% Load most recent checkpoint
checkpoint_dir = fullfile(config.paths.results, 'checkpoints');
files = dir(fullfile(checkpoint_dir, 'checkpoint_*.mat'));
if isempty(files)
    checkpoint = [];
    return;
end
[~, idx] = max([files.datenum]);
checkpoint = load(fullfile(checkpoint_dir, files(idx).name));
end

function log_error(config, subject_id, ME)
% Log error to file
error_file = fullfile(config.paths.logs, sprintf('error_%s.txt', subject_id));
fid = fopen(error_file, 'w');
if fid ~= -1
    fprintf(fid, 'Subject: %s\n', subject_id);
    fprintf(fid, 'Time: %s\n', char(datetime('now')));
    fprintf(fid, 'Error: %s\n\n', ME.message);
    fprintf(fid, '%s\n', getReport(ME, 'extended'));
    fclose(fid);
end
end

function save_json(filename, data)
% Save struct as JSON
json_str = jsonencode(data);
fid = fopen(filename, 'w');
if fid ~= -1
    fprintf(fid, '%s', json_str);
    fclose(fid);
end
end