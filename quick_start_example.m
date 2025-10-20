%% QUICK START EXAMPLE - Single Subject Analysis
% This script demonstrates the complete analysis pipeline on a single subject
% Use this to test the pipeline and understand each step before running
% the full multi-subject analysis
%
% Expected runtime: 10-30 minutes depending on data size

clearvars; close all; clc;

fprintf('\n');
fprintf('=================================================================\n');
fprintf('  QUICK START: SINGLE SUBJECT ANALYSIS EXAMPLE\n');
fprintf('=================================================================\n');
fprintf('\n');

%% STEP 1: SETUP AND INITIALIZATION
fprintf('STEP 1: Setup and Initialization\n');
fprintf('---------------------------------\n');

% Add paths
addpath('C:\MATLAB\fieldtrip');
ft_defaults;
addpath(genpath('C:\Neural Network Sim'));
addpath('C:\openneuro\ds004752');

% Initialize configuration
config = initialize_analysis_config();
fprintf('  ✓ Configuration loaded\n');

% Create output directories
create_output_directories(config);
fprintf('  ✓ Output directories created\n');

% Select a subject to analyze
subjects = discover_subjects(config.paths.data);

if isempty(subjects)
    error('No subjects found. Please check data path: %s', config.paths.data);
end

subject_id = subjects{1}; % Use first subject
fprintf('  ✓ Selected subject: %s\n', subject_id);

%% STEP 2: QUALITY CONTROL
fprintf('\nSTEP 2: Quality Control\n');
fprintf('------------------------\n');

% Load metadata
metadata = load_bids_metadata(config.paths.data, subject_id);
fprintf('  ✓ Metadata loaded\n');

% Run QC checks
qc_results = perform_quality_checks(metadata, config);

if ~qc_results.pass_qc
    warning('Subject failed QC. Continuing for demonstration purposes.');
    fprintf('  ⚠ %d checks failed\n', qc_results.num_checks_failed);
else
    fprintf('  ✓ QC passed: %d checks\n', qc_results.num_checks_passed);
end

% Save QC report
save_qc_report(qc_results, subject_id, config);
fprintf('  ✓ QC report saved\n');

%% STEP 3: DATA LOADING
fprintf('\nSTEP 3: Data Loading\n');
fprintf('--------------------\n');

% Load raw data
tic;
data_raw = load_raw_data(config.paths.data, subject_id, config);
fprintf('  ✓ Raw data loaded (%.1f s)\n', toc);
fprintf('    Channels: %d\n', length(data_raw.label));
fprintf('    Sampling rate: %.1f Hz\n', data_raw.fsample);
fprintf('    Duration: %.1f s\n', ...
    (data_raw.sampleinfo(end) - data_raw.sampleinfo(1)) / data_raw.fsample);

%% STEP 4: PREPROCESSING
fprintf('\nSTEP 4: Preprocessing\n');
fprintf('---------------------\n');

% Filtering
fprintf('  Applying filters...\n');
tic;
data_filtered = apply_filtering(data_raw, config.preprocessing);
fprintf('    ✓ Filtering complete (%.1f s)\n', toc);

% Rereferencing
fprintf('  Applying rereferencing...\n');
tic;
data_reref = apply_rereferencing(data_filtered, config.preprocessing);
fprintf('    ✓ Rereferencing complete (%.1f s)\n', toc);

% Artifact detection
fprintf('  Detecting artifacts...\n');
tic;
data_clean = detect_and_remove_artifacts(data_reref, config.preprocessing);
fprintf('    ✓ Artifact detection complete (%.1f s)\n', toc);

if isfield(data_clean, 'artifacts')
    fprintf('    Artifacts detected: %d segments\n', ...
        size(data_clean.artifacts.bad_segments, 1));
end

% Epoching
fprintf('  Creating epochs...\n');
tic;
data_epochs = create_epochs(data_clean, config.preprocessing);
fprintf('    ✓ Epoching complete (%.1f s)\n', toc);
fprintf('    Total trials: %d\n', length(data_epochs.trial));

% Save preprocessed data
preproc_file = fullfile(config.paths.preprocessed, ...
    sprintf('sub-%s_preprocessed.mat', subject_id));
save(preproc_file, 'data_epochs', '-v7.3');
fprintf('  ✓ Preprocessed data saved\n');

%% STEP 5: SPECTRAL ANALYSIS
fprintf('\nSTEP 5: Spectral Analysis\n');
fprintf('-------------------------\n');

% Power spectral density
fprintf('  Computing PSD...\n');
tic;
psd_results = compute_psd_multitaper(data_epochs, config.spectral);
fprintf('    ✓ PSD computed (%.1f s)\n', toc);

% FOOOF fitting
fprintf('  Fitting aperiodic slope (FOOOF)...\n');
tic;
fooof_results = fit_aperiodic_slope(psd_results, config.spectral);
fprintf('    ✓ FOOOF complete (%.1f s)\n', toc);
fprintf('    Mean exponent: %.3f (range: %.3f - %.3f)\n', ...
    mean(fooof_results.exponent), ...
    min(fooof_results.exponent), ...
    max(fooof_results.exponent));

% Time-frequency analysis
fprintf('  Computing time-frequency representation...\n');
tic;
tf_results = compute_time_frequency(data_epochs, config.spectral);
fprintf('    ✓ TFR computed (%.1f s)\n', toc);

% Save spectral results
spectral_file = fullfile(config.paths.spectral, ...
    sprintf('sub-%s_spectral.mat', subject_id));
save(spectral_file, 'psd_results', 'fooof_results', 'tf_results', '-v7.3');
fprintf('  ✓ Spectral results saved\n');

%% STEP 6: CONNECTIVITY ANALYSIS
fprintf('\nSTEP 6: Connectivity Analysis\n');
fprintf('-----------------------------\n');

% Phase connectivity
fprintf('  Computing phase connectivity (PLV, wPLI)...\n');
tic;
phase_conn = compute_phase_connectivity(data_epochs, config.connectivity);
fprintf('    ✓ Phase connectivity computed (%.1f s)\n', toc);

% Granger causality
fprintf('  Computing Granger causality...\n');
fprintf('    Note: This may take several minutes...\n');
tic;
granger_results = compute_granger_causality(data_epochs, config.connectivity);
fprintf('    ✓ Granger causality computed (%.1f s)\n', toc);

% Save connectivity results
conn_file = fullfile(config.paths.connectivity, ...
    sprintf('sub-%s_connectivity.mat', subject_id));
save(conn_file, 'phase_conn', 'granger_results', '-v7.3');
fprintf('  ✓ Connectivity results saved\n');

%% STEP 7: PHASE-AMPLITUDE COUPLING
fprintf('\nSTEP 7: Phase-Amplitude Coupling\n');
fprintf('--------------------------------\n');

% Reduce surrogates for faster execution in example
config_pac_fast = config.pac;
config_pac_fast.surrogate.num_surrogates = 50; % Reduced from 200

% Tort's modulation index
fprintf('  Computing PAC (Tort method)...\n');
tic;
pac_tort = compute_pac_tort(data_epochs, config_pac_fast);
fprintf('    ✓ PAC computed (%.1f s)\n', toc);
fprintf('    Mean theta-gamma MI: %.4f\n', mean(pac_tort.theta_gamma_mi));

% Surrogate testing
fprintf('  Generating surrogates...\n');
tic;
pac_surrogates = generate_pac_surrogates(data_epochs, config_pac_fast);
fprintf('    ✓ Surrogates generated (%.1f s)\n', toc);

% Statistical testing
fprintf('  Testing significance...\n');
pac_stats = test_pac_significance(pac_tort, pac_surrogates, config.stats);
fprintf('    ✓ %d/%d channels significant (FDR < 0.05)\n', ...
    sum(pac_stats.significant), length(pac_stats.significant));

% Save PAC results
pac_file = fullfile(config.paths.pac, ...
    sprintf('sub-%s_pac.mat', subject_id));
save(pac_file, 'pac_tort', 'pac_surrogates', 'pac_stats', '-v7.3');
fprintf('  ✓ PAC results saved\n');

%% STEP 8: EVENT-RELATED ANALYSIS
fprintf('\nSTEP 8: Event-Related Analysis\n');
fprintf('------------------------------\n');

% Compute ERPs for different conditions
conditions = {'encoding', 'retrieval'};

erp_results = struct();

for c = 1:length(conditions)
    fprintf('  Computing ERP for %s condition...\n', conditions{c});
    tic;
    erp_results.(conditions{c}) = compute_condition_erp(data_epochs, ...
        conditions{c}, config.erp);
    fprintf('    ✓ %s ERP computed (%.1f s)\n', conditions{c}, toc);
end

% Extract components
if isfield(erp_results, 'encoding')
    fprintf('  Extracting N2 component...\n');
    n2_results = extract_n2_latency(erp_results.encoding, config.erp);
    fprintf('    ✓ N2 detected at %.0f ms\n', n2_results.latency);
end

if isfield(erp_results, 'retrieval')
    fprintf('  Extracting P3b component...\n');
    p3b_results = extract_p3b_latency(erp_results.retrieval, config.erp);
    fprintf('    ✓ P3b detected at %.0f ms\n', p3b_results.latency);
end

% Save ERP results
erp_file = fullfile(config.paths.erp, ...
    sprintf('sub-%s_erp.mat', subject_id));
save(erp_file, 'erp_results', 'n2_results', 'p3b_results', '-v7.3');
fprintf('  ✓ ERP results saved\n');

%% STEP 9: VISUALIZATION
fprintf('\nSTEP 9: Visualization\n');
fprintf('--------------------\n');

% Create subject-specific figure directory
fig_dir = fullfile(config.paths.figures, sprintf('sub-%s', subject_id));
if ~exist(fig_dir, 'dir')
    mkdir(fig_dir);
end

% Plot 1: Power spectrum with FOOOF fit
fprintf('  Creating PSD figure...\n');
fig1 = figure('Position', [100, 100, 1000, 600], 'Visible', 'off');

ch_idx = find(strcmp(psd_results.label, 'Cz'), 1);
if isempty(ch_idx), ch_idx = 1; end

loglog(psd_results.freq, psd_results.powspctrm(ch_idx, :), 'k-', 'LineWidth', 1.5);
hold on;
loglog(fooof_results.freq, fooof_results.aperiodic_fit(ch_idx, :), 'r--', 'LineWidth', 2);
loglog(fooof_results.freq, fooof_results.full_fit(ch_idx, :), 'b-', 'LineWidth', 1.5);

xlabel('Frequency (Hz)', 'FontSize', 14);
ylabel('Power (μV²/Hz)', 'FontSize', 14);
title(sprintf('Power Spectrum - %s (Exponent: %.3f)', ...
    psd_results.label{ch_idx}, fooof_results.exponent(ch_idx)), 'FontSize', 16);
legend('Observed', 'Aperiodic fit', 'Full model');
grid on;

saveas(fig1, fullfile(fig_dir, 'psd_fooof.png'));
close(fig1);
fprintf('    ✓ PSD figure saved\n');

% Plot 2: Time-frequency representation
fprintf('  Creating TFR figure...\n');
fig2 = figure('Position', [100, 100, 1200, 400], 'Visible', 'off');

imagesc(tf_results.time, tf_results.freq, tf_results.powspctrm_avg(ch_idx, :, :));
set(gca, 'YDir', 'normal');
colormap('jet');
colorbar;

xlabel('Time (s)', 'FontSize', 14);
ylabel('Frequency (Hz)', 'FontSize', 14);
title(sprintf('Time-Frequency Representation - %s', psd_results.label{ch_idx}), ...
    'FontSize', 16);
xline(0, 'w--', 'LineWidth', 2);

saveas(fig2, fullfile(fig_dir, 'time_frequency.png'));
close(fig2);
fprintf('    ✓ TFR figure saved\n');

% Plot 3: ERP waveforms
if isfield(erp_results, 'encoding') && isfield(erp_results, 'retrieval')
    fprintf('  Creating ERP figure...\n');
    fig3 = figure('Position', [100, 100, 1000, 500], 'Visible', 'off');
    
    plot(erp_results.encoding.time * 1000, erp_results.encoding.avg(ch_idx, :), ...
        'b-', 'LineWidth', 2, 'DisplayName', 'Encoding');
    hold on;
    plot(erp_results.retrieval.time * 1000, erp_results.retrieval.avg(ch_idx, :), ...
        'r-', 'LineWidth', 2, 'DisplayName', 'Retrieval');
    
    xline(0, 'k--', 'LineWidth', 1.5);
    yline(0, 'k-', 'LineWidth', 0.5);
    
    xlabel('Time (ms)', 'FontSize', 14);
    ylabel('Amplitude (μV)', 'FontSize', 14);
    title(sprintf('Event-Related Potentials - %s', psd_results.label{ch_idx}), ...
        'FontSize', 16);
    legend('Location', 'best');
    grid on;
    
    saveas(fig3, fullfile(fig_dir, 'erp_waveforms.png'));
    close(fig3);
    fprintf('    ✓ ERP figure saved\n');
end

%% STEP 10: SUMMARY REPORT
fprintf('\nSTEP 10: Summary Report\n');
fprintf('----------------------\n');

% Create text summary
summary_file = fullfile(config.paths.results, ...
    sprintf('sub-%s_summary.txt', subject_id));

fid = fopen(summary_file, 'w');

fprintf(fid, '=== SINGLE SUBJECT ANALYSIS SUMMARY ===\n\n');
fprintf(fid, 'Subject: %s\n', subject_id);
fprintf(fid, 'Analysis Date: %s\n\n', datestr(now));

fprintf(fid, 'DATA CHARACTERISTICS\n');
fprintf(fid, '-------------------\n');
fprintf(fid, 'Channels: %d\n', length(data_epochs.label));
fprintf(fid, 'Trials: %d\n', length(data_epochs.trial));
fprintf(fid, 'Sampling Rate: %.1f Hz\n\n', data_epochs.fsample);

fprintf(fid, 'SPECTRAL ANALYSIS\n');
fprintf(fid, '----------------\n');
fprintf(fid, 'Mean 1/f Exponent: %.3f ± %.3f\n', ...
    mean(fooof_results.exponent), std(fooof_results.exponent));
fprintf(fid, 'Mean Alpha Power: %.2f μV²\n', ...
    mean(psd_results.band_power.alpha));
fprintf(fid, 'Mean Theta Power: %.2f μV²\n\n', ...
    mean(psd_results.band_power.theta));

fprintf(fid, 'PHASE-AMPLITUDE COUPLING\n');
fprintf(fid, '-----------------------\n');
fprintf(fid, 'Mean Theta-Gamma MI: %.4f\n', mean(pac_tort.theta_gamma_mi));
fprintf(fid, 'Significant Channels: %d/%d\n\n', ...
    sum(pac_stats.significant), length(pac_stats.significant));

if exist('n2_results', 'var')
    fprintf(fid, 'EVENT-RELATED POTENTIALS\n');
    fprintf(fid, '-----------------------\n');
    fprintf(fid, 'N2 Latency: %.0f ms\n', n2_results.latency);
    if exist('p3b_results', 'var')
        fprintf(fid, 'P3b Latency: %.0f ms\n', p3b_results.latency);
    end
    fprintf(fid, '\n');
end

fprintf(fid, 'OUTPUT FILES\n');
fprintf(fid, '-----------\n');
fprintf(fid, 'Preprocessed: %s\n', preproc_file);
fprintf(fid, 'Spectral: %s\n', spectral_file);
fprintf(fid, 'Connectivity: %s\n', conn_file);
fprintf(fid, 'PAC: %s\n', pac_file);
fprintf(fid, 'ERP: %s\n', erp_file);
fprintf(fid, 'Figures: %s\n\n', fig_dir);

fprintf(fid, '=== END SUMMARY ===\n');
fclose(fid);

fprintf('  ✓ Summary report saved: %s\n', summary_file);

%% COMPLETION
fprintf('\n');
fprintf('=================================================================\n');
fprintf('  ANALYSIS COMPLETE\n');
fprintf('=================================================================\n');
fprintf('\n');
fprintf('Results saved to: %s\n', config.paths.output);
fprintf('Figures saved to: %s\n', fig_dir);
fprintf('Summary report: %s\n', summary_file);
fprintf('\n');
fprintf('Next steps:\n');
fprintf('  1. Review the summary report and figures\n');
fprintf('  2. Run full multi-subject analysis: run_complete_analysis\n');
fprintf('  3. Generate comprehensive HTML report\n');
fprintf('\n');
fprintf('For questions or issues, see README.md\n');
fprintf('\n');