function config = initialize_analysis_config()
% INITIALIZE_ANALYSIS_CONFIG - Comprehensive configuration for ds004752 analysis
%
% This function creates a complete configuration structure for analyzing
% the ds004752 BIDS dataset (verbal working memory with EEG/iEEG).
% All analysis parameters are centralized here for reproducibility.
%
% Usage:
%   config = initialize_analysis_config();
%
% Returns:
%   config - Complete configuration structure with all analysis parameters

%% METADATA
fprintf('\n=== Initializing Analysis Configuration ===\n');
fprintf('Dataset: ds004752 (Verbal Working Memory)\n');
fprintf('MATLAB Version: %s\n', version);

%% PATH CONFIGURATION
config.paths.root = 'C:\Neural Network Sim';
config.paths.data = 'C:\openneuro\ds004752';
config.paths.fieldtrip = 'C:\Matlab\fieldtrip';

% Output directories
config.paths.output = fullfile(config.paths.root, 'analysis_output');
config.paths.preprocessed = fullfile(config.paths.output, 'preprocessed');
config.paths.spectral = fullfile(config.paths.output, 'spectral');
config.paths.connectivity = fullfile(config.paths.output, 'connectivity');
config.paths.pac = fullfile(config.paths.output, 'pac');
config.paths.erp = fullfile(config.paths.output, 'erp');
config.paths.group = fullfile(config.paths.output, 'group');
config.paths.figures = fullfile(config.paths.output, 'figures');
config.paths.results = fullfile(config.paths.output, 'results');
config.paths.logs = fullfile(config.paths.output, 'logs');
config.paths.qc = fullfile(config.paths.output, 'quality_control');

% Create output directories if they don't exist
dirs_to_create = {
    config.paths.output
    config.paths.preprocessed
    config.paths.spectral
    config.paths.connectivity
    config.paths.pac
    config.paths.erp
    config.paths.group
    config.paths.figures
    config.paths.results
    config.paths.logs
    config.paths.qc
};

for i = 1:length(dirs_to_create)
    if ~exist(dirs_to_create{i}, 'dir')
        mkdir(dirs_to_create{i});
    end
end

%% PREPROCESSING PARAMETERS
% These parameters work with apply_filtering.m function
% The filter will be stable because we resample to 500 Hz FIRST

% Filtering parameters
config.preprocessing.highpass = 1.0;           % High-pass cutoff (Hz)
config.preprocessing.lowpass = 200;            % Low-pass cutoff (Hz)
config.preprocessing.notch = [60 120 180];     % Notch filter frequencies (Hz) - US line noise
config.preprocessing.order = 4;                % Butterworth filter order
config.preprocessing.type = 'but';             % Filter type (Butterworth)

% Detrending and demeaning
config.preprocessing.detrend = true;           % Remove linear trends
config.preprocessing.demean = true;            % Remove DC offset

% Resampling - CRITICAL: This happens FIRST to ensure filter stability
config.preprocessing.resample_freq = 500;      % Downsample to 500 Hz before filtering

% Rereferencing
config.preprocessing.reref.scalp = 'average';  % Scalp EEG reference
config.preprocessing.reref.depth = 'bipolar';  % Depth electrode reference
config.preprocessing.reref.exclude_bad = true; % Exclude bad channels from reference

% Artifact rejection parameters
config.preprocessing.artifact.method = 'automatic';
config.preprocessing.artifact.z_threshold = 4;       % Z-score threshold
config.preprocessing.artifact.freq_threshold = 3;    % High-frequency artifacts
config.preprocessing.artifact.muscle_threshold = 0.6; % Muscle artifact
config.preprocessing.artifact.eye_threshold = 150;    % Eye movements (μV)

% Independent Component Analysis (optional)
config.preprocessing.ica.enable = false;       % Set to true if needed
config.preprocessing.ica.method = 'fastica';
config.preprocessing.ica.num_components = 30;

% Epoching parameters
config.preprocessing.epoch.baseline = [-0.5 0];     % Baseline window (s)
config.preprocessing.epoch.window = [-1 3];         % Epoch window (s)
config.preprocessing.epoch.reject_criteria.amp = 150; % μV threshold

%% SPECTRAL ANALYSIS PARAMETERS
% Power spectral density
config.spectral.psd.method = 'mtmfft';         % Multitaper FFT
config.spectral.psd.taper = 'dpss';            % Discrete prolate spheroidal sequences
config.spectral.psd.tapsmofrq = 2;             % Smoothing frequency (Hz)
config.spectral.psd.foi = 1:0.5:120;           % Frequencies of interest
config.spectral.psd.pad = 'nextpow2';          % Padding
config.spectral.psd.keeptrials = 'no';         % Average across trials

% Time-frequency analysis
config.spectral.tfr.method = 'mtmconvol';      % Method
config.spectral.tfr.foi = 2:2:100;             % Frequencies
config.spectral.tfr.toi = -1:0.05:3;           % Time points (s)
config.spectral.tfr.t_ftimwin = 7./config.spectral.tfr.foi; % Time windows
config.spectral.tfr.tapsmofrq = 0.4 * config.spectral.tfr.foi; % Smoothing

% FOOOF (Fitting Oscillations & One Over F)
config.spectral.fooof.freq_range = [1 50];     % Frequency range for fitting
config.spectral.fooof.peak_width_limits = [0.5 12]; % Peak width constraints
config.spectral.fooof.max_n_peaks = 6;         % Maximum peaks to fit
config.spectral.fooof.min_peak_height = 0.1;   % Minimum peak height
config.spectral.fooof.peak_threshold = 2.0;    % Peak threshold (std)
config.spectral.fooof.aperiodic_mode = 'fixed'; % 'fixed' or 'knee'

% Frequency bands
config.spectral.bands.delta = [1 4];
config.spectral.bands.theta = [4 8];
config.spectral.bands.alpha = [8 13];
config.spectral.bands.beta = [13 30];
config.spectral.bands.gamma_low = [30 50];
config.spectral.bands.gamma_high = [50 80];
config.spectral.bands.gamma_ultra = [80 120];

%% PHASE-AMPLITUDE COUPLING (PAC) PARAMETERS
config.pac.phase_freqs = 4:0.5:8;              % Phase frequencies (theta)
config.pac.amp_freqs = 30:2:120;               % Amplitude frequencies (gamma)
config.pac.method = 'mi_tort';                 % Modulation index (Tort et al.)
config.pac.num_phase_bins = 18;                % Phase bins (20° each)
config.pac.filter_order = 3;                   % Bandpass filter order
config.pac.edge_buffer = 1;                    % Remove edge artifacts (s)

% Surrogate testing
config.pac.surrogate.num_surrogates = 200;     % Number of surrogates
config.pac.surrogate.method = 'phase_shuffle'; % Shuffling method
config.pac.surrogate.alpha = 0.05;             % Significance level

%% CONNECTIVITY ANALYSIS PARAMETERS
% General settings
config.connectivity.method = 'granger';        % 'granger', 'psi', 'plv', 'wpli'
config.connectivity.foi = [4 8; 30 50; 50 80]; % Frequency bands [theta; gamma_low; gamma_high]
config.connectivity.time_window = [0 2];       % Analysis window (s)

% Granger causality
config.connectivity.granger.order = 10;        % Model order (auto if empty)
config.connectivity.granger.method = 'bsmart'; % 'bsmart' or 'biosig'
config.connectivity.granger.conditional = false; % Conditional GC

% Phase synchrony
config.connectivity.plv.window_length = 0.5;   % Window length (s)
config.connectivity.plv.overlap = 0.9;         % Overlap fraction

% Directed connectivity (PSI - Phase Slope Index)
config.connectivity.psi.bandwidth = 2;         % Frequency bandwidth (Hz)
config.connectivity.psi.normalize = true;      % Normalize PSI

%% EVENT-RELATED POTENTIAL (ERP) PARAMETERS
config.erp.baseline = [-200 0];                % Baseline period (ms)
config.erp.components = {                      % Components to analyze
    'N1', [80 120];
    'N2', [200 300];
    'P3a', [250 350];
    'P3b', [300 500];
    'LPP', [400 800]
};

% Peak detection
config.erp.peak_detection.method = 'localmax'; % Method
config.erp.peak_detection.window = 50;         % Search window (ms)

%% STATISTICAL PARAMETERS
config.stats.alpha = 0.05;                     % Significance level
config.stats.fdr_method = 'bh';                % FDR correction (Benjamini-Hochberg)
config.stats.correction = 'cluster';           % 'none', 'fdr', 'bonferroni', 'cluster'

% Cluster-based permutation testing
config.stats.cluster.method = 'montecarlo';
config.stats.cluster.numrandomization = 1000;
config.stats.cluster.alpha = 0.05;
config.stats.cluster.clusteralpha = 0.05;
config.stats.cluster.clustertail = 0;          % Two-tailed

% Effect sizes
config.stats.effect_size = 'cohens_d';         % 'cohens_d', 'hedges_g'

%% MODEL VALIDATION PARAMETERS
config.validation.cross_validation.k_folds = 5;
config.validation.cross_validation.repetitions = 10;
config.validation.cross_validation.stratified = true;

% Metrics to compute
config.validation.metrics = {
    'spectral_slope',
    'theta_gamma_pac',
    'plv_theta',
    'granger_causality',
    'n2_latency',
    'p3b_latency',
    'power_ratio_theta_beta'
};

% Model predictions to test
config.validation.predictions = {
    'theta_increase_encoding',       % Theta increases during encoding
    'gamma_coupling_maintenance',    % Gamma coupling during maintenance
    'granger_hipp_to_cortex',       % Hippocampus → Cortex flow
    'alpha_suppression_retrieval'    % Alpha suppression during retrieval
};

%% COMPUTATION PARAMETERS
config.compute.parallel = true;                % Use parallel processing
config.compute.num_workers = 4;                % Parallel workers
config.compute.memory_limit = 16;              % GB
config.compute.save_intermediate = true;       % Save intermediate results
config.compute.precision = 'double';           % Numerical precision

%% VISUALIZATION PARAMETERS
% Figure settings
config.viz.format = 'png';                     % Output format
config.viz.resolution = 300;                   % DPI
config.viz.color_scheme = 'viridis';           % Color scheme
config.viz.font_size = 12;
config.viz.font_name = 'Arial';
config.viz.line_width = 1.5;

% Figure types to generate
config.viz.generate_individual = true;         % Per-subject figures
config.viz.generate_group = true;              % Group-level figures
config.viz.generate_statistics = true;         % Statistical maps
config.viz.generate_topoplots = true;          % Topographic maps

%% VERSIONING AND REPRODUCIBILITY
config.version = '1.0.1';
config.date = datestr(now, 'yyyy-mm-dd HH:MM:SS');
config.matlab_version = version;

% Get FieldTrip version
try
    ft_defaults;
    ft_ver = ft_version;
    config.fieldtrip_version = ft_ver;
catch
    config.fieldtrip_version = 'unknown';
    warning('Could not determine FieldTrip version');
end

config.random_seed = 42;                       % For reproducibility

% Set random seed for reproducibility
rng(config.random_seed, 'twister');

%% VALIDATION
fprintf('\nValidating configuration...\n');

% Check required paths
if ~exist(config.paths.data, 'dir')
    error('Data directory not found: %s', config.paths.data);
end

if ~exist(config.paths.fieldtrip, 'dir')
    error('FieldTrip directory not found: %s', config.paths.fieldtrip);
end

% Initialize FieldTrip
try
    ft_defaults;
    fprintf('✓ FieldTrip initialized\n');
catch
    warning('Could not initialize FieldTrip. Make sure it is in your path.');
end

%% SUMMARY
fprintf('\n=== Configuration Summary ===\n');
fprintf('Version: %s\n', config.version);
fprintf('Date: %s\n', config.date);
fprintf('MATLAB: %s\n', config.matlab_version);
fprintf('FieldTrip: %s\n', config.fieldtrip_version);
fprintf('Data: %s\n', config.paths.data);
fprintf('Output: %s\n', config.paths.output);
fprintf('Random seed: %d\n', config.random_seed);
fprintf('Parallel processing: %s\n', mat2str(config.compute.parallel));
fprintf('\nPreprocessing Settings:\n');
fprintf('  Resample FIRST: %d Hz (from original rate)\n', config.preprocessing.resample_freq);
fprintf('  Highpass: %.1f Hz\n', config.preprocessing.highpass);
fprintf('  Lowpass: %.1f Hz\n', config.preprocessing.lowpass);
fprintf('  Notch: %s Hz\n', mat2str(config.preprocessing.notch));
fprintf('  Filter order: %d\n', config.preprocessing.order);
fprintf('  Detrend: %s\n', mat2str(config.preprocessing.detrend));
fprintf('  Demean: %s\n', mat2str(config.preprocessing.demean));
fprintf('\n✓ Configuration initialized successfully\n');
fprintf('=====================================\n\n');

end