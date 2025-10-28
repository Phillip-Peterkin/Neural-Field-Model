function config = config_harmonic_field()
% CONFIG_HARMONIC_FIELD
% Configuration for Harmonic Field Theory Analysis Pipeline
% All parameters from manuscript Table 1 and model specifications
%
% Reference: Peterkin (2025) - Energy, Coherence, and Content
%
% Output:
%   config - Complete configuration structure

%% ========================================================================
%  PATHS
%  ========================================================================
config.paths.data_root = 'C:\openneuro\ds004752';
config.paths.project_root = 'C:\HarmonicFieldTheory';
config.paths.results = fullfile(config.paths.project_root, 'results');
config.paths.figures = fullfile(config.paths.results, 'figures');
config.paths.checkpoints = fullfile(config.paths.results, 'checkpoints');
config.paths.logs = fullfile(config.paths.project_root, 'logs');

%% ========================================================================
%  COMPUTE RESOURCES (Based on system specs)
%  ========================================================================
config.compute.num_workers = 10;  % Leave 2 cores for system
config.compute.max_memory_gb = 20; % Leave 2GB headroom
config.compute.use_gpu = true;     % Enable if available
config.compute.chunk_size = 60;    % Seconds per chunk for memory efficiency

%% ========================================================================
%  NEURAL FIELD MODEL PARAMETERS (From Table 1)
%  ========================================================================

%% Time Constants (ms)
config.model.tau_E = 12;       % Pyramidal cells
config.model.tau_P = 6;        % Parvalbumin interneurons
config.model.tau_C = 30;       % CCK interneurons
config.model.tau_D = 80;       % Dendritic NMDA
config.model.tau_Theta = 120;  % Theta resonator
config.model.tau_M = 40;       % Matrix thalamus
config.model.tau_K = 25;       % Core thalamus

%% Circuit Weights
config.model.w_EE = 10;        % E → E recurrent
config.model.w_PE = 14;        % E → PV
config.model.w_EP = 12;        % PV → E
config.model.w_PP = 4;         % PV → PV
config.model.w_EC = 6;         % E → CCK
config.model.w_CE = 3;         % CCK → E
config.model.w_CC = 2;         % CCK → CCK
config.model.w_DE = 8;         % Dendritic → E

%% Weight Uncertainty Ranges (for parameter inference)
config.model.w_EE_range = [8, 12];
config.model.w_PE_range = [11, 17];
config.model.w_EP_range = [9, 15];
config.model.w_PP_range = [2, 6];
config.model.w_EC_range = [4, 8];
config.model.w_CE_range = [2, 4];

%% Thalamic Parameters
config.model.alpha_M = 0.5;    % Matrix baseline gain
config.model.beta_M = 0.3;     % Matrix E-coupling
config.model.alpha_K = 0.4;    % Core baseline gain
config.model.beta_K = 0.4;     % Core E-coupling
config.model.w_TRN = 2.0;      % TRN inhibition weight
config.model.gamma_K = 1.0;    % Core → E projection

%% Dendritic NMDA Dynamics
config.model.alpha_NMDA = 0.5; % NMDA activation rate
config.model.beta_BK = 0.3;    % BK potassium rate

%% Gain and Normalization
config.model.g_max = 1.5;      % Maximum gain [1.2, 1.8]
config.model.beta_gain = 2.0;  % Gain slope
config.model.a_M = 0.4;        % Matrix contribution to gain
config.model.a_theta = 0.3;    % Theta phase contribution to gain
config.model.kappa_J = 0.1;    % Divisive normalization strength

%% Conduction Velocities and Delays
config.model.v_cortex = 1.5;      % Cortico-cortical (m/s)
config.model.v_thalamus = 3.0;    % Thalamo-cortical (m/s)
config.model.kappa_delay = 3;     % Gamma kernel order
config.model.d_EM = 20;           % E → Matrix delay (ms)
config.model.d_EK = 15;           % E → Core delay (ms)

%% Noise Parameters
config.model.sigma_E = 0.02;      % Pyramidal noise std
config.model.sigma_P = 0.02;      % PV noise std
config.model.sigma_C = 0.02;      % CCK noise std
config.model.sigma_D = 0.01;      % Dendritic noise std
config.model.sigma_Theta = 0.015; % Theta noise std
config.model.sigma_M = 0.02;      % Matrix noise std
config.model.sigma_K = 0.02;      % Core noise std
config.model.tau_noise = 30;      % Noise correlation time (ms)

%% Neuromodulator Gains (for CCK modulation, Eq 3)
config.model.chi_ACh = 0.5;    % Acetylcholine gain
config.model.chi_NA = 0.4;     % Noradrenaline gain
config.model.k_CB1 = 0.3;      % CB1 receptor suppression

%% ========================================================================
%  ACCESS DETECTION PARAMETERS (Section 9)
%  ========================================================================
config.access.R_hi = 0.55;        % Coherence entry threshold
config.access.R_lo = 0.45;        % Coherence exit threshold
config.access.T_on = 30;          % Entry duration (ms)
config.access.T_off = 20;         % Exit duration (ms)
config.access.dwell_min = 100;    % Minimum access window (ms)
config.access.dwell_max = 300;    % Maximum access window (ms)
config.access.refractory = 60;    % Refractory period (ms)

% Content decoder thresholds (mutual information, bits)
config.access.MI_binary = 0.10;   % 2-class tasks
config.access.MI_4class = 0.20;   % 4-class tasks
config.access.decoder_stability = 0.80; % 80% consistency requirement

%% ========================================================================
%  ENERGY BUDGET PARAMETERS (Section 10)
%  ========================================================================
config.energy.c_E = 1.0;          % Pyramidal spiking cost
config.energy.c_P = 0.8;          % PV spiking cost
config.energy.c_C = 0.6;          % CCK spiking cost
config.energy.c_syn = 0.5;        % Synaptic transmission cost
config.energy.c_gamma = 0.3;      % Gamma coordination cost

% State-specific power caps (relative to wake = 1.0)
config.energy.P_max_wake = 1.0;
config.energy.P_max_task_high = 1.05;  % High cognitive load
config.energy.P_max_task_low = 0.95;   % Low cognitive load

% Lagrange multiplier update
config.energy.eta_P = 0.01;       % Learning rate
config.energy.tolerance = 0.02;   % ±2% tolerance

%% ========================================================================
%  SPECTRAL ANALYSIS PARAMETERS (Stage 1, Section 13.1)
%  ========================================================================
config.spectral.freq_range = [1, 200];     % Analysis range (Hz)
config.spectral.freq_resolution = 0.5;     % Frequency resolution (Hz)
config.spectral.window_length = 4;         % Seconds
config.spectral.window_overlap = 0.5;      % 50% overlap
config.spectral.taper = 'hann';            % Window function
config.spectral.aperiodic_fit = [1, 50];   % Range for 1/f fit (Hz)

% Target bands
config.spectral.bands.delta = [1, 4];
config.spectral.bands.theta = [4, 8];
config.spectral.bands.alpha = [8, 13];
config.spectral.bands.beta = [13, 30];
config.spectral.bands.gamma_low = [30, 50];
config.spectral.bands.gamma_high = [50, 100];

%% ========================================================================
%  CONNECTIVITY ANALYSIS (Stage 2, Section 13.2)
%  ========================================================================
config.connectivity.method = 'imaginary_PLV'; % Reduces volume conduction
config.connectivity.window_length = 4;        % Seconds
config.connectivity.window_overlap = 0.5;
config.connectivity.bands = {'theta', 'alpha', 'beta', 'gamma_low'};
config.connectivity.surrogate_n = 200;        % Number of surrogates
config.connectivity.fdr_q = 0.05;             % False discovery rate

%% ========================================================================
%  PHASE-AMPLITUDE COUPLING (Stage 3, Section 13.3)
%  ========================================================================
config.pac.phase_band = [4, 7];        % Theta phase (Hz)
config.pac.amp_band = [50, 80];        % Gamma amplitude (Hz)
config.pac.n_phase_bins = 18;          % Tort's MI standard
config.pac.method = 'tort_MI';         % Modulation index
config.pac.surrogate_n = 200;
config.pac.window_length = 2;          % Seconds

%% ========================================================================
%  EVENT-RELATED ANALYSIS (Stage 4, Section 13.4)
%  ========================================================================
config.erp.baseline = [-0.2, 0];       % Baseline window (s)
config.erp.epoch = [-0.5, 1.5];        % Epoch window (s)
config.erp.filter_low = 0.1;           % High-pass (Hz)
config.erp.filter_high = 40;           % Low-pass (Hz)
config.erp.resample_rate = 500;        % Downsample to 500 Hz for ERP

% Component windows for validation
config.erp.N2_window = [0.2, 0.35];    % N2 latency range (s)
config.erp.P3b_window = [0.3, 0.6];    % P3b latency range (s)

%% ========================================================================
%  TASK DECODER (Working Memory Specific)
%  ========================================================================
config.decoder.method = 'linear_svm';  % Linear SVM classifier
config.decoder.features = 'power_connectivity'; % Feature set
config.decoder.cv_folds = 5;           % Cross-validation folds
config.decoder.time_window = 0.1;      % Decoder window (s)
config.decoder.time_step = 0.05;       % Sliding window step (s)

% Task-specific conditions
config.decoder.decode_setsize = true;   % 4 vs 6 vs 8 items
config.decoder.decode_correct = true;   % Correct vs error
config.decoder.decode_match = true;     % IN vs OUT probe

% Temporal windows
config.decoder.encoding_window = [0, 2];     % Encoding phase (s)
config.decoder.maintenance_window = [2, 6];  % Maintenance (s)
config.decoder.probe_window = [6, 8];        % Probe/response (s)

%% ========================================================================
%  VALIDATION PARAMETERS (Section 13.6-13.8)
%  ========================================================================
config.validation.method = 'leave_subject_out';
config.validation.n_folds = 5;
config.validation.n_bootstrap = 2000;
config.validation.confidence_level = 0.95;

% Identifiability checks
config.validation.fisher_condition_threshold = 100;  % Max condition number
config.validation.profile_likelihood = true;
config.validation.parameter_pairs = {{'w_PE', 'w_EP'}, ...
                                      {'alpha_M', 'w_TRN'}, ...
                                      {'v_cortex', 'kappa_delay'}};

%% ========================================================================
%  INTEGRATION PARAMETERS
%  ========================================================================
config.integration.dt = 0.5;           % Time step (ms)
config.integration.method = 'heun';    % SDE integration scheme
config.integration.bounds_check = true; % Enforce [0,1] bounds per step

%% ========================================================================
%  VISUALIZATION SETTINGS
%  ========================================================================
config.viz.save_format = {'png', 'pdf', 'fig'};
config.viz.dpi = 300;
config.viz.font_size = 12;
config.viz.line_width = 1.5;
config.viz.color_scheme = 'default';

%% ========================================================================
%  RANDOM SEED (For reproducibility)
%  ========================================================================
config.random_seed = 42;
rng(config.random_seed, 'twister');

%% ========================================================================
%  METADATA
%  ========================================================================
config.metadata.version = '1.0';
config.metadata.author = 'Phillip Peterkin';
config.metadata.manuscript = 'Energy, Coherence, and Content';
config.metadata.date_created = char(datetime('now'));
config.metadata.matlab_version = version;

fprintf('✓ Configuration loaded: %d parameter groups\n', length(fieldnames(config)));

end