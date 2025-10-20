% EXAMPLE_SINGLE_SUBJECT_SESSION - Complete analysis with session support
clearvars; close all; clc;

fprintf('\n=== SINGLE SUBJECT-SESSION ANALYSIS ===\n\n');

% Setup
addpath('C:\MATLAB\fieldtrip'); ft_defaults;
addpath(genpath('C:\Neural Network Sim'));
config = initialize_analysis_config();

% Discover subjects and sessions
[subjects, sessions] = discover_subjects_sessions(config.paths.data);
sub_names = fieldnames(subjects);

if isempty(sub_names)
    error('No subjects found in: %s', config.paths.data);
end

% Select first subject and session
subject_id = strrep(sub_names{1}, 'sub_', '');
session_id = sessions.(sub_names{1}){1};
fprintf('Analyzing: sub-%s, ses-%s\n\n', subject_id, session_id);

% Load data
tic;
data_raw = load_raw_data(config.paths.data, subject_id, session_id, config);
fprintf('✓ Data loaded (%.1f s)\n', toc);

% Preprocessing
fprintf('\nPreprocessing...\n');
data_filtered = apply_filtering(data_raw, config.preprocessing);
fprintf('✓ Filtering complete\n');

% Spectral analysis
fprintf('\nSpectral analysis...\n');
psd_results = compute_psd_multitaper(data_filtered, config.spectral);
fooof_results = fit_aperiodic_slope(psd_results, config.spectral);
fprintf('✓ Spectral analysis complete\n');

% Results
fprintf('\n=== RESULTS ===\n');
fprintf('Subject: %s, Session: %s\n', subject_id, session_id);
fprintf('1/f exponent: %.3f ± %.3f\n', mean(fooof_results.exponent), std(fooof_results.exponent));
fprintf('Alpha power: %.2f μV²\n', mean(psd_results.band_power.alpha));
fprintf('Theta power: %.2f μV²\n', mean(psd_results.band_power.theta));

% Save results
output_file = fullfile(config.paths.results, sprintf('sub-%s_ses-%s_results.mat', subject_id, session_id));
save(output_file, 'psd_results', 'fooof_results', '-v7.3');
fprintf('\n✓ Results saved: %s\n', output_file);
