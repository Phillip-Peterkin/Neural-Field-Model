%% AUTOMATED INSTALLER - Creates all analysis pipeline files
% This script will create all 14 required .m files automatically
% 
% INSTRUCTIONS:
% 1. Copy this entire script
% 2. Save as: create_all_files.m in C:\Neural Network Sim\
% 3. Run it: create_all_files
% 4. Then run: test_installation

function create_all_files()

clearvars; close all; clc;

fprintf('\n');
fprintf('================================================================\n');
fprintf('  AUTOMATED INSTALLER FOR NEURAL ANALYSIS PIPELINE\n');
fprintf('================================================================\n');
fprintf('\n');

%% Setup
base_dir = 'C:\Neural Network Sim';

% Create directory if it doesn't exist
if ~exist(base_dir, 'dir')
    mkdir(base_dir);
    fprintf('Created directory: %s\n', base_dir);
end

cd(base_dir);

fprintf('Installing to: %s\n\n', base_dir);
fprintf('This will create 14 analysis files...\n\n');

%% File counter
files_created = 0;
files_failed = 0;

%% Create minimal working versions
% These are simplified versions that will work for testing
% The full versions are in the artifacts

fprintf('Creating files:\n');
fprintf('---------------\n');

%% 1. initialize_analysis_config.m
try
    create_config_file(base_dir);
    files_created = files_created + 1;
    fprintf('✓ [1/14] initialize_analysis_config.m\n');
catch
    files_failed = files_failed + 1;
    fprintf('✗ [1/14] initialize_analysis_config.m FAILED\n');
end

%% 2. utility_functions.m
try
    create_utility_functions(base_dir);
    files_created = files_created + 1;
    fprintf('✓ [2/14] utility_functions.m\n');
catch
    files_failed = files_failed + 1;
    fprintf('✗ [2/14] utility_functions.m FAILED\n');
end

%% 3. preprocessing_functions.m
try
    create_preprocessing_functions(base_dir);
    files_created = files_created + 1;
    fprintf('✓ [3/14] preprocessing_functions.m\n');
catch
    files_failed = files_failed + 1;
    fprintf('✗ [3/14] preprocessing_functions.m FAILED\n');
end

%% 4. spectral_analysis_functions.m  
try
    create_spectral_functions(base_dir);
    files_created = files_created + 1;
    fprintf('✓ [4/14] spectral_analysis_functions.m\n');
catch
    files_failed = files_failed + 1;
    fprintf('✗ [4/14] spectral_analysis_functions.m FAILED\n');
end

%% 5. connectivity_analysis_functions.m
try
    create_connectivity_functions(base_dir);
    files_created = files_created + 1;
    fprintf('✓ [5/14] connectivity_analysis_functions.m\n');
catch
    files_failed = files_failed + 1;
    fprintf('✗ [5/14] connectivity_analysis_functions.m FAILED\n');
end

%% 6. pac_analysis_functions.m
try
    create_pac_functions(base_dir);
    files_created = files_created + 1;
    fprintf('✓ [6/14] pac_analysis_functions.m\n');
catch
    files_failed = files_failed + 1;
    fprintf('✗ [6/14] pac_analysis_functions.m FAILED\n');
end

%% 7. erp_analysis_functions.m
try
    create_erp_functions(base_dir);
    files_created = files_created + 1;
    fprintf('✓ [7/14] erp_analysis_functions.m\n');
catch
    files_failed = files_failed + 1;
    fprintf('✗ [7/14] erp_analysis_functions.m FAILED\n');
end

%% 8-14. Create remaining placeholder files
remaining_files = {
    'visualization_functions.m'
    'generate_analysis_report.m'
    'model_validation_functions.m'
    'run_complete_analysis.m'
    'example_single_subject_analysis.m'
    'setup_paths.m'
    'fix_my_paths.m'
};

for i = 1:length(remaining_files)
    try
        create_placeholder_file(base_dir, remaining_files{i});
        files_created = files_created + 1;
        fprintf('✓ [%d/14] %s\n', 7+i, remaining_files{i});
    catch
        files_failed = files_failed + 1;
        fprintf('✗ [%d/14] %s FAILED\n', 7+i, remaining_files{i});
    end
end

%% Summary
fprintf('\n');
fprintf('================================================================\n');
fprintf('  INSTALLATION SUMMARY\n');
fprintf('================================================================\n');
fprintf('\n');
fprintf('Files created: %d/14\n', files_created);
fprintf('Files failed: %d/14\n', files_failed);
fprintf('\n');

if files_created == 14
    fprintf('✓ ALL FILES CREATED SUCCESSFULLY\n\n');
    fprintf('Next steps:\n');
    fprintf('1. Run: addpath(''C:\\MATLAB\\fieldtrip''); ft_defaults;\n');
    fprintf('2. Run: addpath(genpath(''C:\\Neural Network Sim''));\n');
    fprintf('3. Run: test_installation\n\n');
else
    fprintf('⚠ SOME FILES FAILED TO CREATE\n');
    fprintf('Please check error messages above\n\n');
end

end

%% HELPER FUNCTIONS TO CREATE EACH FILE

function create_config_file(base_dir)
fid = fopen(fullfile(base_dir, 'initialize_analysis_config.m'), 'w');
fprintf(fid, 'function config = initialize_analysis_config()\n');
fprintf(fid, '%% Configuration for neural analysis pipeline\n\n');
fprintf(fid, 'config.paths.root = ''C:\\Neural Network Sim'';\n');
fprintf(fid, 'config.paths.data = ''C:\\openneuro\\ds004752'';\n');
fprintf(fid, 'config.paths.fieldtrip = ''C:\\MATLAB\\fieldtrip'';\n');
fprintf(fid, 'config.paths.output = fullfile(config.paths.root, ''analysis_output'');\n');
fprintf(fid, 'config.paths.preprocessed = fullfile(config.paths.output, ''preprocessed'');\n');
fprintf(fid, 'config.paths.spectral = fullfile(config.paths.output, ''spectral'');\n');
fprintf(fid, 'config.paths.connectivity = fullfile(config.paths.output, ''connectivity'');\n');
fprintf(fid, 'config.paths.pac = fullfile(config.paths.output, ''pac'');\n');
fprintf(fid, 'config.paths.erp = fullfile(config.paths.output, ''erp'');\n');
fprintf(fid, 'config.paths.group = fullfile(config.paths.output, ''group'');\n');
fprintf(fid, 'config.paths.figures = fullfile(config.paths.output, ''figures'');\n');
fprintf(fid, 'config.paths.results = fullfile(config.paths.output, ''results'');\n');
fprintf(fid, 'config.paths.logs = fullfile(config.paths.output, ''logs'');\n');
fprintf(fid, 'config.paths.qc = fullfile(config.paths.output, ''quality_control'');\n\n');
fprintf(fid, '%% Spectral parameters\n');
fprintf(fid, 'config.spectral.psd.method = ''mtmfft'';\n');
fprintf(fid, 'config.spectral.psd.taper = ''dpss'';\n');
fprintf(fid, 'config.spectral.psd.tapsmofrq = 2;\n');
fprintf(fid, 'config.spectral.psd.foi = 1:0.5:120;\n');
fprintf(fid, 'config.spectral.psd.pad = ''nextpow2'';\n');
fprintf(fid, 'config.spectral.fooof.freq_range = [1 50];\n');
fprintf(fid, 'config.spectral.fooof.peak_width_limits = [0.5 12];\n');
fprintf(fid, 'config.spectral.bands.theta = [4 8];\n');
fprintf(fid, 'config.spectral.bands.alpha = [8 13];\n\n');
fprintf(fid, '%% PAC parameters\n');
fprintf(fid, 'config.pac.phase_freqs = 4:0.5:8;\n');
fprintf(fid, 'config.pac.amp_freqs = 30:2:120;\n');
fprintf(fid, 'config.pac.num_phase_bins = 18;\n');
fprintf(fid, 'config.pac.surrogate.num_surrogates = 200;\n');
fprintf(fid, 'config.pac.surrogate.method = ''phase_shuffle'';\n\n');
fprintf(fid, '%% Connectivity parameters\n');
fprintf(fid, 'config.connectivity.foi = [4 8; 30 50; 50 80];\n\n');
fprintf(fid, '%% Statistics\n');
fprintf(fid, 'config.stats.alpha = 0.05;\n');
fprintf(fid, 'config.stats.fdr_method = ''bh'';\n\n');
fprintf(fid, '%% Visualization\n');
fprintf(fid, 'config.viz.color_scheme = ''viridis'';\n\n');
fprintf(fid, '%% Version info\n');
fprintf(fid, 'config.version = ''1.0.0'';\n');
fprintf(fid, 'config.date = datestr(now, ''yyyy-mm-dd'');\n');
fprintf(fid, 'config.random_seed = 42;\n');
fprintf(fid, 'rng(config.random_seed);\n\n');
fprintf(fid, 'config.compute.parallel = false;\n');
fprintf(fid, 'end\n');
fclose(fid);
end

function create_utility_functions(base_dir)
fid = fopen(fullfile(base_dir, 'utility_functions.m'), 'w');
fprintf(fid, 'function create_output_directories(config)\n');
fprintf(fid, 'dirs = {config.paths.preprocessed, config.paths.spectral, ...\n');
fprintf(fid, '        config.paths.connectivity, config.paths.pac, ...\n');
fprintf(fid, '        config.paths.erp, config.paths.figures, ...\n');
fprintf(fid, '        config.paths.results, config.paths.logs, config.paths.qc};\n');
fprintf(fid, 'for i = 1:length(dirs)\n');
fprintf(fid, '    if ~exist(dirs{i}, ''dir''), mkdir(dirs{i}); end\n');
fprintf(fid, 'end\n');
fprintf(fid, 'end\n\n');
fprintf(fid, 'function subjects = discover_subjects(data_path)\n');
fprintf(fid, 'sub_dirs = dir(fullfile(data_path, ''sub-*''));\n');
fprintf(fid, 'sub_dirs = sub_dirs([sub_dirs.isdir]);\n');
fprintf(fid, 'subjects = cell(length(sub_dirs), 1);\n');
fprintf(fid, 'for i = 1:length(sub_dirs)\n');
fprintf(fid, '    subjects{i} = strrep(sub_dirs(i).name, ''sub-'', '''');\n');
fprintf(fid, 'end\n');
fprintf(fid, 'end\n\n');
fprintf(fid, 'function [h, crit_p, adj_ci_cvrg, adj_p] = fdr_bh(pvals, q, method, report)\n');
fprintf(fid, 'if nargin < 2, q = 0.05; end\n');
fprintf(fid, '[pvals_sorted, sort_ids] = sort(pvals);\n');
fprintf(fid, 's = length(pvals);\n');
fprintf(fid, 'adj_p_sorted = pvals_sorted .* s ./ (1:s)'';\n');
fprintf(fid, 'for i = s-1:-1:1\n');
fprintf(fid, '    if adj_p_sorted(i) > adj_p_sorted(i+1)\n');
fprintf(fid, '        adj_p_sorted(i) = adj_p_sorted(i+1);\n');
fprintf(fid, '    end\n');
fprintf(fid, 'end\n');
fprintf(fid, 'adj_p = zeros(size(pvals));\n');
fprintf(fid, 'adj_p(sort_ids) = adj_p_sorted;\n');
fprintf(fid, 'rej = pvals_sorted < q .* (1:s)'' / s;\n');
fprintf(fid, 'if sum(rej) > 0\n');
fprintf(fid, '    crit_p = pvals_sorted(find(rej, 1, ''last''));\n');
fprintf(fid, 'else\n');
fprintf(fid, '    crit_p = 0;\n');
fprintf(fid, 'end\n');
fprintf(fid, 'h = pvals <= crit_p;\n');
fprintf(fid, 'adj_ci_cvrg = 1 - q;\n');
fprintf(fid, 'end\n');
fclose(fid);
end

function create_preprocessing_functions(base_dir)
fid = fopen(fullfile(base_dir, 'preprocessing_functions.m'), 'w');
fprintf(fid, 'function data_out = load_raw_data(data_path, subject_id, config)\n');
fprintf(fid, 'data_out = struct(); %% Placeholder\n');
fprintf(fid, 'end\n\n');
fprintf(fid, 'function data_filtered = apply_filtering(data, cfg_preproc)\n');
fprintf(fid, 'data_filtered = data; %% Placeholder\n');
fprintf(fid, 'end\n');
fclose(fid);
end

function create_spectral_functions(base_dir)
fid = fopen(fullfile(base_dir, 'spectral_analysis_functions.m'), 'w');
fprintf(fid, 'function psd_results = compute_psd_multitaper(data, cfg_spectral)\n');
fprintf(fid, 'cfg = [];\n');
fprintf(fid, 'cfg.method = cfg_spectral.psd.method;\n');
fprintf(fid, 'cfg.taper = cfg_spectral.psd.taper;\n');
fprintf(fid, 'cfg.foi = cfg_spectral.psd.foi;\n');
fprintf(fid, 'cfg.tapsmofrq = cfg_spectral.psd.tapsmofrq;\n');
fprintf(fid, 'cfg.keeptrials = ''no'';\n');
fprintf(fid, 'cfg.output = ''pow'';\n');
fprintf(fid, 'freq = ft_freqanalysis(cfg, data);\n');
fprintf(fid, 'psd_results.freq = freq.freq;\n');
fprintf(fid, 'psd_results.powspctrm = freq.powspctrm;\n');
fprintf(fid, 'psd_results.label = freq.label;\n');
fprintf(fid, 'psd_results.band_power.theta = mean(freq.powspctrm(:, freq.freq >= 4 & freq.freq <= 8), 2);\n');
fprintf(fid, 'psd_results.band_power.alpha = mean(freq.powspctrm(:, freq.freq >= 8 & freq.freq <= 13), 2);\n');
fprintf(fid, 'end\n\n');
fprintf(fid, 'function fooof_results = fit_aperiodic_slope(psd_results, cfg_spectral)\n');
fprintf(fid, 'fooof_results.exponent = ones(size(psd_results.powspctrm, 1), 1); %% Placeholder\n');
fprintf(fid, 'end\n');
fclose(fid);
end

function create_connectivity_functions(base_dir)
fid = fopen(fullfile(base_dir, 'connectivity_analysis_functions.m'), 'w');
fprintf(fid, 'function phase_conn = compute_phase_connectivity(data, cfg_conn)\n');
fprintf(fid, 'phase_conn = struct(); %% Placeholder\n');
fprintf(fid, 'end\n\n');
fprintf(fid, 'function granger_results = compute_granger_causality(data, cfg_conn)\n');
fprintf(fid, 'granger_results = struct(); %% Placeholder\n');
fprintf(fid, 'end\n');
fclose(fid);
end

function create_pac_functions(base_dir)
fid = fopen(fullfile(base_dir, 'pac_analysis_functions.m'), 'w');
fprintf(fid, 'function pac_tort = compute_pac_tort(data, cfg_pac)\n');
fprintf(fid, 'pac_tort.theta_gamma_mi = rand(length(data.label), 1) * 0.01; %% Placeholder\n');
fprintf(fid, 'pac_tort.label = data.label;\n');
fprintf(fid, 'end\n');
fclose(fid);
end

function create_erp_functions(base_dir)
fid = fopen(fullfile(base_dir, 'erp_analysis_functions.m'), 'w');
fprintf(fid, 'function erp_data = compute_condition_erp(data, condition, cfg_erp)\n');
fprintf(fid, 'erp_data = struct(); %% Placeholder\n');
fprintf(fid, 'end\n\n');
fprintf(fid, 'function n2_results = extract_n2_latency(erp_data, cfg_erp)\n');
fprintf(fid, 'n2_results.latency = 250; %% Placeholder\n');
fprintf(fid, 'end\n\n');
fprintf(fid, 'function p3b_results = extract_p3b_latency(erp_data, cfg_erp)\n');
fprintf(fid, 'p3b_results.latency = 400; %% Placeholder\n');
fprintf(fid, 'end\n');
fclose(fid);
end

function create_placeholder_file(base_dir, filename)
fid = fopen(fullfile(base_dir, filename), 'w');
fprintf(fid, '%% %s\n', upper(strrep(filename, '.m', '')));
fprintf(fid, '%% This is a placeholder file\n');
fprintf(fid, '%% Full implementation available in artifacts\n\n');
fprintf(fid, 'function varargout = %s(varargin)\n', strrep(filename, '.m', ''));
fprintf(fid, 'fprintf(''This is a placeholder function\\n'');\n');
fprintf(fid, 'fprintf(''Full implementation available in the artifacts\\n'');\n');
fprintf(fid, 'end\n');
fclose(fid);
end