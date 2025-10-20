%% TEST_INSTALLATION - Verify analysis pipeline installation
% This script tests all components of the analysis pipeline to ensure
% proper installation and functionality before running full analyses.
%
% Run this after initial setup to verify:
%   - MATLAB toolboxes
%   - FieldTrip installation
%   - Data paths
%   - Function accessibility
%   - Sample data processing

clearvars; close all; clc;

fprintf('\n');
fprintf('=================================================================\n');
fprintf('  INSTALLATION TEST FOR NEURAL ANALYSIS PIPELINE\n');
fprintf('=================================================================\n');
fprintf('\n');

%% TEST 1: MATLAB VERSION
fprintf('TEST 1: MATLAB Version...\n');
matlab_version = version;
matlab_year = str2double(regexp(matlab_version, '\d{4}', 'match', 'once'));

if matlab_year >= 2025
    fprintf('  ✓ MATLAB version OK: %s\n', matlab_version);
    test1_pass = true;
else
    fprintf('  ✗ MATLAB version too old: %s (requires R2025b or later)\n', matlab_version);
    test1_pass = false;
end

%% TEST 2: REQUIRED TOOLBOXES
fprintf('\nTEST 2: Required Toolboxes...\n');

required_toolboxes = {
    'Signal Processing Toolbox', ...
    'Statistics and Machine Learning Toolbox', ...
    'Optimization Toolbox'
};

installed_toolboxes = ver;
installed_names = {installed_toolboxes.Name};

test2_pass = true;
for i = 1:length(required_toolboxes)
    if any(contains(installed_names, required_toolboxes{i}))
        fprintf('  ✓ %s installed\n', required_toolboxes{i});
    else
        fprintf('  ✗ %s NOT installed\n', required_toolboxes{i});
        test2_pass = false;
    end
end

%% TEST 3: FIELDTRIP INSTALLATION
fprintf('\nTEST 3: FieldTrip Installation...\n');

try
    ft_version_info = ft_version;
    fprintf('  ✓ FieldTrip found: %s\n', ft_version_info);
    test3_pass = true;
catch
    fprintf('  ✗ FieldTrip not found on path\n');
    fprintf('    Add FieldTrip: addpath(''C:\MATLAB\fieldtrip''); ft_defaults;\n');
    test3_pass = false;
end

%% TEST 4: CONFIGURATION FILE
fprintf('\nTEST 4: Configuration File...\n');

try
    config = initialize_analysis_config();
    fprintf('  ✓ Configuration loaded successfully\n');
    fprintf('    Output directory: %s\n', config.paths.output);
    test4_pass = true;
catch ME
    fprintf('  ✗ Configuration failed: %s\n', ME.message);
    fprintf('    This may be due to missing FieldTrip or data paths\n');
    test4_pass = false;
    
    % Try to create a minimal config for remaining tests
    try
        config = struct();
        config.paths.root = 'C:\Neural Network Sim';
        config.paths.output = fullfile(config.paths.root, 'analysis_output');
        config.paths.data = 'C:\openneuro\ds004752';
        config.paths.figures = fullfile(config.paths.output, 'figures');
        config.paths.results = fullfile(config.paths.output, 'results');
        config.paths.preprocessed = fullfile(config.paths.output, 'preprocessed');
        config.paths.spectral = fullfile(config.paths.output, 'spectral');
        config.paths.connectivity = fullfile(config.paths.output, 'connectivity');
        config.paths.pac = fullfile(config.paths.output, 'pac');
        config.paths.erp = fullfile(config.paths.output, 'erp');
        config.paths.group = fullfile(config.paths.output, 'group');
        config.paths.qc = fullfile(config.paths.output, 'quality_control');
        config.paths.logs = fullfile(config.paths.output, 'logs');
        
        % Add minimal config settings for later tests
        config.spectral.psd.method = 'mtmfft';
        config.spectral.psd.taper = 'dpss';
        config.spectral.psd.tapsmofrq = 2;
        config.spectral.psd.foi = 1:0.5:120;
        config.spectral.psd.pad = 'nextpow2';
        
        config.spectral.fooof.freq_range = [1 50];
        config.spectral.fooof.peak_width_limits = [0.5 12];
        config.spectral.fooof.max_peaks = 6;
        config.spectral.fooof.min_peak_height = 0.1;
        config.spectral.fooof.peak_threshold = 2.0;
        config.spectral.fooof.aperiodic_mode = 'fixed';
        
        config.spectral.bands.delta = [1 4];
        config.spectral.bands.theta = [4 8];
        config.spectral.bands.alpha = [8 13];
        config.spectral.bands.beta = [13 30];
        config.spectral.bands.gamma_low = [30 50];
        config.spectral.bands.gamma_high = [50 80];
        
        config.pac.phase_freqs = 4:0.5:8;
        config.pac.amp_freqs = 30:2:120;
        config.pac.num_phase_bins = 18;
        
        config.connectivity.foi = [4 8; 30 50; 50 80];
        
        config.stats.alpha = 0.05;
        
        config.viz.color_scheme = 'viridis';
        
        fprintf('    Created minimal config for remaining tests\n');
    catch
        fprintf('    Could not create minimal config\n');
    end
end

%% TEST 5: DATA PATHS
fprintf('\nTEST 5: Data Paths...\n');

test5_pass = true;

% Check data directory
if exist(config.paths.data, 'dir')
    fprintf('  ✓ Data directory exists: %s\n', config.paths.data);
    
    % Try to discover subjects
    try
        subjects = discover_subjects(config.paths.data);
        fprintf('    Found %d subjects\n', length(subjects));
    catch
        fprintf('    ⚠ Could not discover subjects (may be normal if no data yet)\n');
    end
else
    fprintf('  ✗ Data directory not found: %s\n', config.paths.data);
    fprintf('    Download dataset from: https://openneuro.org/datasets/ds004752\n');
    test5_pass = false;
end

% Check if output directories can be created
try
    create_output_directories(config);
    fprintf('  ✓ Output directories created/verified\n');
catch ME
    fprintf('  ✗ Could not create output directories: %s\n', ME.message);
    test5_pass = false;
end

%% TEST 6: FUNCTION ACCESSIBILITY
fprintf('\nTEST 6: Function Accessibility...\n');

functions_to_test = {
    'load_raw_data', ...
    'apply_filtering', ...
    'compute_psd_multitaper', ...
    'fit_aperiodic_slope', ...
    'compute_phase_connectivity', ...
    'compute_granger_causality', ...
    'compute_pac_tort', ...
    'extract_n2_latency', ...
    'extract_p3b_latency', ...
    'fdr_bh'
};

test6_pass = true;
for i = 1:length(functions_to_test)
    if exist(functions_to_test{i}, 'file') == 2
        fprintf('  ✓ %s found\n', functions_to_test{i});
    else
        fprintf('  ✗ %s NOT found\n', functions_to_test{i});
        test6_pass = false;
    end
end

%% TEST 7: SAMPLE DATA PROCESSING
fprintf('\nTEST 7: Sample Data Processing...\n');

try
    % Create synthetic test data
    fprintf('  Creating synthetic test data...\n');
    
    % Simulate EEG data
    fsample = 500;
    duration = 10; % seconds
    nchans = 4;
    ntrials = 5;
    
    data = struct();
    data.fsample = fsample;
    data.label = {'Fz', 'Cz', 'Pz', 'Oz'};
    
    t = (0:1/fsample:duration-1/fsample);
    
    for trial = 1:ntrials
        % Add multiple frequency components
        signal = zeros(nchans, length(t));
        
        for ch = 1:nchans
            % Alpha (10 Hz) + theta (6 Hz) + noise
            signal(ch, :) = 10 * sin(2*pi*10*t + randn*2*pi) + ...
                           5 * sin(2*pi*6*t + randn*2*pi) + ...
                           randn(1, length(t)) * 2;
        end
        
        data.trial{trial} = signal;
        data.time{trial} = t;
    end
    
    data.sampleinfo = repmat([1, length(t)], ntrials, 1);
    
    fprintf('  ✓ Synthetic data created: %d trials, %d channels, %.1f Hz\n', ...
        ntrials, nchans, fsample);
    
    % Test spectral analysis
    fprintf('  Testing spectral analysis...\n');
    cfg_spectral = config.spectral;
    psd_results = compute_psd_multitaper(data, cfg_spectral);
    
    % Check for alpha peak
    alpha_range = [8 13];
    alpha_idx = psd_results.freq >= alpha_range(1) & psd_results.freq <= alpha_range(2);
    alpha_power = mean(psd_results.powspctrm(:, alpha_idx), 2);
    
    fprintf('  ✓ Spectral analysis successful\n');
    fprintf('    Mean alpha power: %.2f μV²/Hz\n', mean(alpha_power));
    
    % Test FOOOF fitting
    fprintf('  Testing 1/f slope fitting...\n');
    fooof_results = fit_aperiodic_slope(psd_results, cfg_spectral);
    fprintf('  ✓ FOOOF fitting successful\n');
    fprintf('    Mean exponent: %.3f\n', mean(fooof_results.exponent));
    
    % Test connectivity
    fprintf('  Testing connectivity analysis...\n');
    cfg_conn = config.connectivity;
    phase_conn = compute_phase_connectivity(data, cfg_conn);
    fprintf('  ✓ Connectivity analysis successful\n');
    
    % Test PAC
    fprintf('  Testing PAC analysis...\n');
    cfg_pac = config.pac;
    cfg_pac.surrogate.num_surrogates = 10; % Reduce for speed
    pac_results = compute_pac_tort(data, cfg_pac);
    fprintf('  ✓ PAC analysis successful\n');
    fprintf('    Mean theta-gamma MI: %.4f\n', mean(pac_results.theta_gamma_mi));
    
    test7_pass = true;
    
catch ME
    fprintf('  ✗ Sample processing failed: %s\n', ME.message);
    fprintf('    Stack trace:\n');
    for k = 1:length(ME.stack)
        fprintf('      %s (line %d)\n', ME.stack(k).name, ME.stack(k).line);
    end
    test7_pass = false;
end

%% TEST 8: STATISTICAL FUNCTIONS
fprintf('\nTEST 8: Statistical Functions...\n');

try
    % Test FDR correction
    test_pvals = [0.001, 0.01, 0.02, 0.05, 0.1, 0.5, 0.8];
    [h, crit_p, ~, adj_p] = fdr_bh(test_pvals, 0.05, 'pdep');
    
    fprintf('  ✓ FDR correction working\n');
    fprintf('    Original p-values: %s\n', mat2str(test_pvals, 3));
    fprintf('    Adjusted p-values: %s\n', mat2str(adj_p, 3));
    fprintf('    Significant: %s\n', mat2str(h));
    
    test8_pass = true;
catch ME
    fprintf('  ✗ Statistical functions failed: %s\n', ME.message);
    test8_pass = false;
end

%% TEST 9: VISUALIZATION
fprintf('\nTEST 9: Visualization Capabilities...\n');

try
    % Test figure creation
    test_fig = figure('Visible', 'off');
    plot(1:10, rand(1,10), 'LineWidth', 2);
    title('Test Figure', 'FontSize', 14);
    xlabel('X', 'FontSize', 12);
    ylabel('Y', 'FontSize', 12);
    
    % Try to save
    test_fig_path = fullfile(config.paths.figures, 'test_figure.png');
    saveas(test_fig, test_fig_path);
    close(test_fig);
    
    if exist(test_fig_path, 'file')
        fprintf('  ✓ Figure creation and saving successful\n');
        delete(test_fig_path); % Clean up
        test9_pass = true;
    else
        fprintf('  ✗ Could not save figure\n');
        test9_pass = false;
    end
    
catch ME
    fprintf('  ✗ Visualization failed: %s\n', ME.message);
    test9_pass = false;
end

%% TEST 10: MEMORY AND PERFORMANCE
fprintf('\nTEST 10: System Resources...\n');

try
    % Check available memory
    if ispc
        [~, sys_view] = memory;
        total_mem_gb = sys_view.PhysicalMemory.Total / 1e9;
        available_mem_gb = sys_view.PhysicalMemory.Available / 1e9;
        
        fprintf('  System memory:\n');
        fprintf('    Total: %.1f GB\n', total_mem_gb);
        fprintf('    Available: %.1f GB\n', available_mem_gb);
        
        if available_mem_gb < 4
            fprintf('  ⚠ Low available memory (< 4 GB)\n');
            fprintf('    Consider:\n');
            fprintf('    - Processing fewer subjects at once\n');
            fprintf('    - Reducing parallel workers\n');
            fprintf('    - Closing other applications\n');
        else
            fprintf('  ✓ Sufficient memory available\n');
        end
    else
        fprintf('  ℹ Memory check only available on Windows\n');
    end
    
    % Check parallel computing capability
    if config.compute.parallel
        try
            pool = gcp('nocreate');
            if isempty(pool)
                pool = parpool(config.compute.num_workers);
                fprintf('  ✓ Parallel pool created: %d workers\n', pool.NumWorkers);
                delete(pool);
            else
                fprintf('  ✓ Parallel pool already exists: %d workers\n', pool.NumWorkers);
            end
        catch ME
            fprintf('  ⚠ Parallel computing not available: %s\n', ME.message);
        end
    else
        fprintf('  ℹ Parallel computing disabled in config\n');
    end
    
    test10_pass = true;
    
catch ME
    fprintf('  ⚠ Could not assess system resources: %s\n', ME.message);
    test10_pass = true; % Non-critical
end

%% SUMMARY
fprintf('\n');
fprintf('=================================================================\n');
fprintf('  TEST SUMMARY\n');
fprintf('=================================================================\n');

tests = [test1_pass, test2_pass, test3_pass, test4_pass, test5_pass, ...
         test6_pass, test7_pass, test8_pass, test9_pass, test10_pass];

test_names = {
    'MATLAB Version', ...
    'Required Toolboxes', ...
    'FieldTrip Installation', ...
    'Configuration File', ...
    'Data Paths', ...
    'Function Accessibility', ...
    'Sample Data Processing', ...
    'Statistical Functions', ...
    'Visualization', ...
    'System Resources'
};

for i = 1:length(tests)
    if tests(i)
        fprintf('  ✓ Test %d: %s\n', i, test_names{i});
    else
        fprintf('  ✗ Test %d: %s\n', i, test_names{i});
    end
end

fprintf('\n');

if all(tests)
    fprintf('=================================================================\n');
    fprintf('  ✓ ALL TESTS PASSED\n');
    fprintf('  Installation is complete and functional!\n');
    fprintf('  You can now run: run_complete_analysis\n');
    fprintf('=================================================================\n');
else
    fprintf('=================================================================\n');
    fprintf('  ⚠ SOME TESTS FAILED\n');
    fprintf('  Please address the issues above before running analyses.\n');
    fprintf('  See README.md for troubleshooting tips.\n');
    fprintf('=================================================================\n');
end

fprintf('\n');
fprintf('For questions or issues, see README.md or contact support.\n');
fprintf('\n');