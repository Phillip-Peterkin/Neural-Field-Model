function run_complete_analysis()
% RUN_COMPLETE_ANALYSIS
% Elite production-level EEG/iEEG pipeline controller.
% Designed for reproducibility, parallelization, and model integration.
% Built for the Harmonic Field Theory (Conscious Assembly Alignment Model).

%% ==============================
%  STAGE 0: ENVIRONMENT SETUP
%  ==============================
clc;
fprintf(['\n============================================================\n', ...
         ' HARMONIC FIELD THEORY - COMPLETE ANALYSIS PIPELINE\n', ...
         '============================================================\n']);

try
    ft_defaults; % FieldTrip
    fprintf('FieldTrip initialized.\n');
catch ME
    warning('%s', ME.message);
    warning('FieldTrip not detected on path. Ensure ft_defaults is available.');
end

% Detect EEGLAB
if exist('eeglab.m', 'file')
    eeglab('nogui');
    fprintf('EEGLAB initialized.\n');
else
    warning('EEGLAB not found. Add it to your MATLAB path.');
end

% Initialize configuration
config = initialize_analysis_config();
config.env.start_time = datetime('now');
config.env.git_commit = get_git_commit_hash();
config.env.matlab_version = version;
config.env.fieldtrip_version = ft_version;

rng(config.general.random_seed, 'twister');

% Initialize output folders
make_output_folders(config);

log_file = fullfile(config.paths.logs, ['run_log_', char(datetime('now','Format','yyyyMMdd_HHmmss')), '.txt']);
diary(log_file);

fprintf('Configuration and environment initialized.\n');

%% ==============================
%  STAGE 1: DATA DISCOVERY AND QC
%  ==============================
fprintf('\n[Stage 1] Data discovery and QC...\n');
[pipeline_state, subject_list] = discover_subjects_sessions(config);

fprintf('Discovered %d subjects.\n', numel(subject_list));

%% ==============================
%  STAGE 2: SUBJECT-LEVEL PROCESSING
%  ==============================
num_subjects = numel(subject_list);
configConst = parallel.pool.Constant(config);
parpool('local', config.general.num_workers);

parfor s = 1:num_subjects
    cfg = configConst.Value;
    subj = subject_list{s};
    subj_name = subj.id;
    fprintf('\n[Subject %s] Starting processing...\n', subj_name);

    try
        % ---- Stage 2: Preprocessing ----
        data_raw = load_raw_data(cfg.paths.data, subj_name, subj.sessions{1}, cfg);
        data_pre = preprocessing_functions(cfg.preprocessing, data_raw);
        save_stage_output(cfg, subj_name, 'preprocessed', data_pre);

        % ---- Stage 3: Spectral Analysis ----
        data_spec = spectral_analysis_functions(data_pre, cfg);
        save_stage_output(cfg, subj_name, 'spectral', data_spec);

        % ---- Stage 4: Connectivity ----
        data_conn = connectivity_analysis_functions(data_pre, cfg);
        save_stage_output(cfg, subj_name, 'connectivity', data_conn);

        % ---- Stage 5: PAC ----
        data_pac = pac_analysis_functions(data_pre, cfg);
        save_stage_output(cfg, subj_name, 'pac', data_pac);

        % ---- Stage 6: ERP ----
        data_erp = erp_analysis_functions(data_pre, cfg);
        save_stage_output(cfg, subj_name, 'erp', data_erp);

        % ---- Stage 7: Model Validation ----
        model_results = model_validation_functions(struct('spec', data_spec, 'conn', data_conn, 'pac', data_pac), cfg);
        save_stage_output(cfg, subj_name, 'validation', model_results);

        fprintf('[Subject %s] Completed successfully.\n', subj_name);

    catch ME
        warning('%s', ME.message);
        warning('[Subject %s] Error encountered. Logging...', subj_name);
        log_error(cfg, subj_name, ME);
    end
end

delete(gcp('nocreate'));

%% ==============================
%  STAGE 8: GROUP-LEVEL ANALYSIS
%  ==============================
try
    fprintf('\n[Stage 8] Group-level aggregation...\n');
    group_results = summarize_group_results(config);
    save(fullfile(config.paths.results, 'group_results.mat'), 'group_results', '-v7.3');
    fprintf('Group-level analysis complete.\n');
catch ME
    warning('%s', ME.message);
    warning('Group analysis failed. Check logs for details.');
end

%% ==============================
%  STAGE 9: FINAL REPORTING
%  ==============================
report = generate_final_report(config, pipeline_state);
report_path = fullfile(config.paths.results, ['final_report_', char(datetime('now','Format','yyyyMMdd_HHmmss')), '.json']);
jsonwrite(report_path, report);

fprintf(['\n============================================================\n', ...
         ' Pipeline completed successfully.\n', ...
         ' Report saved to: %s\n', ...
         '============================================================\n'], report_path);

diary off;
end

%% ========================================================================
% Helper Functions
% ========================================================================

function commit = get_git_commit_hash()
try
    [~, commit] = system('git rev-parse HEAD');
    commit = strtrim(commit);
catch ME
    warning('%s', ME.message);
    commit = 'unknown';
end
end

function make_output_folders(config)
folders = fieldnames(config.paths);
for i = 1:numel(folders)
    if ~exist(config.paths.(folders{i}), 'dir')
        mkdir(config.paths.(folders{i}));
    end
end
end

function log_error(config, subj, ME)
log_path = fullfile(config.paths.logs, ['error_log_', subj, '.txt']);
fid = fopen(log_path, 'a');
if fid ~= -1
    fprintf(fid, '[%s] %s\n', char(datetime('now')), ME.message);
    fprintf(fid, '%s\n', getReport(ME, 'extended', 'hyperlinks', 'off'));
    fclose(fid);
else
    warning('Failed to open error log for writing.');
end
end

function save_stage_output(config, subj, stage_name, data)
subj_dir = fullfile(config.paths.results, subj);
if ~exist(subj_dir, 'dir'), mkdir(subj_dir); end
save(fullfile(subj_dir, [stage_name, '.mat']), 'data', '-v7.3');
end

function report = generate_final_report(config, pipeline_state)
report.pipeline_version = '3.1';
report.date_completed = string(datetime('now'));
report.matlab_version = config.env.matlab_version;
report.fieldtrip_version = config.env.fieldtrip_version;
report.git_commit = config.env.git_commit;
report.runtime_minutes = minutes(datetime('now') - config.env.start_time);
report.subjects_processed = numel(fieldnames(pipeline_state));
end
