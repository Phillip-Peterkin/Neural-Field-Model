%% PHASE-AMPLITUDE COUPLING (PAC) ANALYSIS FUNCTIONS
% Theta-gamma coupling using multiple methods with rigorous statistical testing

function pac_tort = compute_pac_tort(data, cfg_pac)
% COMPUTE_PAC_TORT - Compute PAC using Tort's Modulation Index method
%
% Reference: Tort et al. (2010) "Measuring phase-amplitude coupling 
% between neuronal oscillations of different frequencies"
% Journal of Neurophysiology
%
% This is the gold-standard method cited in the paper

fprintf('Computing PAC using Tort''s Modulation Index...\n');

num_channels = length(data.label);
phase_freqs = cfg_pac.phase_freqs;
amp_freqs = cfg_pac.amp_freqs;
num_phase_bins = cfg_pac.num_phase_bins;

% Initialize output
pac_tort = struct();
pac_tort.modulation_index = zeros(num_channels, length(phase_freqs), length(amp_freqs));
pac_tort.phase_freqs = phase_freqs;
pac_tort.amp_freqs = amp_freqs;
pac_tort.label = data.label;

% Extract phase and amplitude for each frequency
fprintf('  Extracting phases and amplitudes...\n');

for ch = 1:num_channels
    if mod(ch, 10) == 0
        fprintf('    Channel %d/%d\n', ch, num_channels);
    end
    
    for ph_idx = 1:length(phase_freqs)
        % Get phase of low-frequency oscillation (theta)
        phase_band = [max(1, phase_freqs(ph_idx) - 0.5), phase_freqs(ph_idx) + 0.5];
        phase_signal = extract_phase_signal(data, ch, phase_band);
        
        for amp_idx = 1:length(amp_freqs)
            % Get amplitude of high-frequency oscillation (gamma)
            amp_band = [max(1, amp_freqs(amp_idx) - 1), amp_freqs(amp_idx) + 1];
            amp_signal = extract_amplitude_signal(data, ch, amp_band);
            
            % Compute Modulation Index
            mi = compute_modulation_index(phase_signal, amp_signal, num_phase_bins);
            pac_tort.modulation_index(ch, ph_idx, amp_idx) = mi;
        end
    end
end

% Average across frequency pairs in theta-gamma range
theta_idx = phase_freqs >= 4 & phase_freqs <= 8;
gamma_idx = amp_freqs >= 30 & amp_freqs <= 80;

pac_tort.theta_gamma_mi = squeeze(mean(mean(...
    pac_tort.modulation_index(:, theta_idx, gamma_idx), 2), 3));

fprintf('Tort PAC computed for %d channels\n', num_channels);

end

function phase_signal = extract_phase_signal(data, channel, freq_band)
% Extract phase using bandpass + Hilbert transform

% Concatenate all trials
all_data = [];
for trial = 1:length(data.trial)
    all_data = [all_data, data.trial{trial}(channel, :)];
end

% Bandpass filter
nyquist = data.fsample / 2;
[b, a] = butter(4, freq_band / nyquist, 'bandpass');
filtered = filtfilt(b, a, all_data);

% Hilbert transform to get phase
analytic = hilbert(filtered);
phase_signal = angle(analytic);

end

function amp_signal = extract_amplitude_signal(data, channel, freq_band)
% Extract amplitude envelope using bandpass + Hilbert transform

% Concatenate all trials
all_data = [];
for trial = 1:length(data.trial)
    all_data = [all_data, data.trial{trial}(channel, :)];
end

% Bandpass filter
nyquist = data.fsample / 2;
[b, a] = butter(4, freq_band / nyquist, 'bandpass');
filtered = filtfilt(b, a, all_data);

% Hilbert transform to get amplitude envelope
analytic = hilbert(filtered);
amp_signal = abs(analytic);

end

function mi = compute_modulation_index(phase_signal, amp_signal, num_bins)
% Compute Tort's Modulation Index
%
% MI quantifies how much the amplitude distribution deviates from uniform
% across phase bins. Higher MI = stronger phase-amplitude coupling

% Ensure same length
min_len = min(length(phase_signal), length(amp_signal));
phase_signal = phase_signal(1:min_len);
amp_signal = amp_signal(1:min_len);

% Bin phases
phase_bins = linspace(-pi, pi, num_bins + 1);
mean_amp_per_bin = zeros(1, num_bins);

for bin = 1:num_bins
    in_bin = phase_signal >= phase_bins(bin) & phase_signal < phase_bins(bin + 1);
    if sum(in_bin) > 0
        mean_amp_per_bin(bin) = mean(amp_signal(in_bin));
    end
end

% Normalize to create probability distribution
p = mean_amp_per_bin / sum(mean_amp_per_bin + eps);

% Compute Kullback-Leibler divergence from uniform distribution
q = ones(1, num_bins) / num_bins; % Uniform distribution

% KL divergence
kl = sum(p .* log((p + eps) ./ (q + eps)));

% Normalize by maximum possible KL (log of number of bins)
mi = kl / log(num_bins);

end

%% MODULATION INDEX METHOD
function pac_mi = compute_pac_modulation_index(data, cfg_pac)
% COMPUTE_PAC_MODULATION_INDEX - Alternative MI calculation
%
% Computes PAC as correlation between phase and amplitude envelope

fprintf('Computing PAC using MI method...\n');

num_channels = length(data.label);
phase_freqs = cfg_pac.phase_freqs;
amp_freqs = cfg_pac.amp_freqs;

pac_mi = struct();
pac_mi.mi_values = zeros(num_channels, length(phase_freqs), length(amp_freqs));
pac_mi.phase_freqs = phase_freqs;
pac_mi.amp_freqs = amp_freqs;
pac_mi.label = data.label;

for ch = 1:num_channels
    for ph_idx = 1:length(phase_freqs)
        phase_band = [max(1, phase_freqs(ph_idx) - 0.5), phase_freqs(ph_idx) + 0.5];
        phase_signal = extract_phase_signal(data, ch, phase_band);
        
        for amp_idx = 1:length(amp_freqs)
            amp_band = [max(1, amp_freqs(amp_idx) - 1), amp_freqs(amp_idx) + 1];
            amp_signal = extract_amplitude_signal(data, ch, amp_band);
            
            % Compute complex-valued mean: <A(t) * exp(i*φ(t))>
            min_len = min(length(phase_signal), length(amp_signal));
            z = amp_signal(1:min_len) .* exp(1i * phase_signal(1:min_len));
            pac_mi.mi_values(ch, ph_idx, amp_idx) = abs(mean(z));
        end
    end
end

% Average in theta-gamma range
theta_idx = phase_freqs >= 4 & phase_freqs <= 8;
gamma_idx = amp_freqs >= 30 & amp_freqs <= 80;

pac_mi.theta_gamma_mi = squeeze(mean(mean(...
    pac_mi.mi_values(:, theta_idx, gamma_idx), 2), 3));

fprintf('MI PAC computed\n');

end

%% PLV-BASED PAC
function pac_plv = compute_pac_plv_method(data, cfg_pac)
% COMPUTE_PAC_PLV_METHOD - PAC using phase-locking value approach
%
% Computes PLV between phase of slow oscillation and phase of 
% amplitude envelope of fast oscillation

fprintf('Computing PAC using PLV method...\n');

num_channels = length(data.label);
phase_freqs = cfg_pac.phase_freqs;
amp_freqs = cfg_pac.amp_freqs;

pac_plv = struct();
pac_plv.plv_values = zeros(num_channels, length(phase_freqs), length(amp_freqs));
pac_plv.phase_freqs = phase_freqs;
pac_plv.amp_freqs = amp_freqs;
pac_plv.label = data.label;

for ch = 1:num_channels
    for ph_idx = 1:length(phase_freqs)
        phase_band = [max(1, phase_freqs(ph_idx) - 0.5), phase_freqs(ph_idx) + 0.5];
        phase_slow = extract_phase_signal(data, ch, phase_band);
        
        for amp_idx = 1:length(amp_freqs)
            amp_band = [max(1, amp_freqs(amp_idx) - 1), amp_freqs(amp_idx) + 1];
            amp_signal = extract_amplitude_signal(data, ch, amp_band);
            
            % Get phase of amplitude envelope
            amp_analytic = hilbert(amp_signal - mean(amp_signal));
            phase_amp_envelope = angle(amp_analytic);
            
            % Compute PLV between slow phase and amplitude envelope phase
            min_len = min(length(phase_slow), length(phase_amp_envelope));
            phase_diff = phase_slow(1:min_len) - phase_amp_envelope(1:min_len);
            
            pac_plv.plv_values(ch, ph_idx, amp_idx) = abs(mean(exp(1i * phase_diff)));
        end
    end
end

% Average in theta-gamma range
theta_idx = phase_freqs >= 4 & phase_freqs <= 8;
gamma_idx = amp_freqs >= 30 & amp_freqs <= 80;

pac_plv.theta_gamma_plv = squeeze(mean(mean(...
    pac_plv.plv_values(:, theta_idx, gamma_idx), 2), 3));

fprintf('PLV PAC computed\n');

end

%% SURROGATE TESTING
function pac_surrogates = generate_pac_surrogates(data, cfg_pac)
% GENERATE_PAC_SURROGATES - Create surrogate data for statistical testing
%
% Methods:
%   1. Phase shuffling - randomly shuffle phase time series
%   2. Time shifting - shift amplitude relative to phase by random lag
%
% Surrogates destroy true PAC while preserving marginal distributions

fprintf('Generating PAC surrogates (%d iterations)...\n', cfg_pac.surrogate.num_surrogates);

num_surrogates = cfg_pac.surrogate.num_surrogates;
num_channels = length(data.label);

% Use Tort method for surrogates
phase_freqs = cfg_pac.phase_freqs;
amp_freqs = cfg_pac.amp_freqs;
num_phase_bins = cfg_pac.num_phase_bins;

% Storage for null distribution
pac_surrogates = struct();
pac_surrogates.null_distribution = zeros(num_channels, num_surrogates);

% Focus on theta-gamma for efficiency
theta_freq = 6; % Center of theta band
gamma_freq = 60; % Center of gamma band

for ch = 1:num_channels
    if mod(ch, 10) == 0
        fprintf('  Channel %d/%d\n', ch, num_channels);
    end
    
    % Get phase and amplitude
    phase_band = [theta_freq - 0.5, theta_freq + 0.5];
    amp_band = [gamma_freq - 5, gamma_freq + 5];
    
    phase_signal = extract_phase_signal(data, ch, phase_band);
    amp_signal = extract_amplitude_signal(data, ch, amp_band);
    
    % Generate surrogates
    for surr = 1:num_surrogates
        if strcmp(cfg_pac.surrogate.method, 'phase_shuffle')
            % Randomly shuffle phase within bins
            phase_shuffled = phase_shuffle_surrogate(phase_signal, num_phase_bins);
            mi_surr = compute_modulation_index(phase_shuffled, amp_signal, num_phase_bins);
            
        elseif strcmp(cfg_pac.surrogate.method, 'time_shift')
            % Random time shift
            shift = randi([100, length(amp_signal) - 100]);
            amp_shifted = circshift(amp_signal, shift);
            mi_surr = compute_modulation_index(phase_signal, amp_shifted, num_phase_bins);
        end
        
        pac_surrogates.null_distribution(ch, surr) = mi_surr;
    end
end

pac_surrogates.label = data.label;
pac_surrogates.method = cfg_pac.surrogate.method;
pac_surrogates.num_surrogates = num_surrogates;

fprintf('Surrogate generation complete\n');

end

function phase_shuffled = phase_shuffle_surrogate(phase_signal, num_bins)
% Shuffle phase values within each bin to destroy PAC while preserving distribution

phase_bins = linspace(-pi, pi, num_bins + 1);
phase_shuffled = phase_signal;

for bin = 1:num_bins
    in_bin = find(phase_signal >= phase_bins(bin) & phase_signal < phase_bins(bin + 1));
    
    if ~isempty(in_bin)
        % Randomly permute indices within this bin
        shuffled_indices = in_bin(randperm(length(in_bin)));
        phase_shuffled(in_bin) = phase_signal(shuffled_indices);
    end
end

end

%% STATISTICAL TESTING
function pac_stats = test_pac_significance(pac_observed, pac_surrogates, cfg_stats)
% TEST_PAC_SIGNIFICANCE - Test statistical significance of PAC values
%
% Compares observed PAC to null distribution from surrogates

fprintf('Testing PAC significance...\n');

num_channels = size(pac_observed.modulation_index, 1);

pac_stats = struct();
pac_stats.observed = pac_observed.theta_gamma_mi;
pac_stats.null_mean = mean(pac_surrogates.null_distribution, 2);
pac_stats.null_std = std(pac_surrogates.null_distribution, 0, 2);

% Z-scores
pac_stats.z_scores = (pac_stats.observed - pac_stats.null_mean) ./ ...
                     (pac_stats.null_std + eps);

% P-values (one-tailed: observed > null)
pac_stats.p_values = zeros(num_channels, 1);

for ch = 1:num_channels
    null_dist = pac_surrogates.null_distribution(ch, :);
    pac_stats.p_values(ch) = mean(null_dist >= pac_stats.observed(ch));
end

% FDR correction
[~, ~, ~, pac_stats.p_values_fdr] = fdr_bh(pac_stats.p_values, cfg_stats.alpha, 'pdep');

% Significant channels
pac_stats.significant = pac_stats.p_values_fdr < cfg_stats.alpha;

fprintf('PAC significant in %d/%d channels (FDR < %.3f)\n', ...
    sum(pac_stats.significant), num_channels, cfg_stats.alpha);

end

%% TIME-RESOLVED PAC
function pac_time = compute_time_resolved_pac(data, cfg_pac)
% COMPUTE_TIME_RESOLVED_PAC - Compute PAC in sliding windows
%
% Reveals dynamics of PAC across task epochs

fprintf('Computing time-resolved PAC...\n');

window_length = cfg_pac.time_window; % seconds
window_overlap = cfg_pac.time_overlap; % seconds
window_samples = round(window_length * data.fsample);
overlap_samples = round(window_overlap * data.fsample);
step_samples = window_samples - overlap_samples;

% Get time vector
time_vec = data.time{1};
num_windows = floor((length(time_vec) - window_samples) / step_samples) + 1;

num_channels = length(data.label);
theta_freq = 6; % Center frequency
gamma_freq = 60;

% Initialize output
pac_time = struct();
pac_time.mi_time = zeros(num_channels, num_windows);
pac_time.time_centers = zeros(1, num_windows);
pac_time.label = data.label;

for ch = 1:num_channels
    for win = 1:num_windows
        % Define window
        win_start = 1 + (win - 1) * step_samples;
        win_end = win_start + window_samples - 1;
        
        if win_end > length(time_vec)
            break;
        end
        
        pac_time.time_centers(win) = mean(time_vec([win_start, win_end]));
        
        % Extract window data
        data_win = data;
        for trial = 1:length(data.trial)
            data_win.trial{trial} = data.trial{trial}(:, win_start:win_end);
            data_win.time{trial} = data.time{trial}(win_start:win_end);
        end
        
        % Compute PAC for this window
        phase_band = [theta_freq - 0.5, theta_freq + 0.5];
        amp_band = [gamma_freq - 5, gamma_freq + 5];
        
        phase_signal = extract_phase_signal(data_win, ch, phase_band);
        amp_signal = extract_amplitude_signal(data_win, ch, amp_band);
        
        pac_time.mi_time(ch, win) = compute_modulation_index(phase_signal, amp_signal, 18);
    end
end

fprintf('Time-resolved PAC computed: %d time windows\n', num_windows);

end

%% COMODULOGRAM
function comodulogram = compute_comodulogram(data, channel_idx, cfg_pac)
% COMPUTE_COMODULOGRAM - Full PAC comodulogram for visualization
%
% Creates a 2D map of PAC across all phase-amplitude frequency pairs

fprintf('Computing comodulogram for channel %s...\n', data.label{channel_idx});

phase_freqs = cfg_pac.phase_freqs;
amp_freqs = cfg_pac.amp_freqs;
num_phase_bins = cfg_pac.num_phase_bins;

comodulogram = struct();
comodulogram.mi_matrix = zeros(length(phase_freqs), length(amp_freqs));
comodulogram.phase_freqs = phase_freqs;
comodulogram.amp_freqs = amp_freqs;
comodulogram.channel = data.label{channel_idx};

for ph_idx = 1:length(phase_freqs)
    fprintf('  Phase frequency %d/%d\n', ph_idx, length(phase_freqs));
    
    phase_band = [max(1, phase_freqs(ph_idx) - 0.5), phase_freqs(ph_idx) + 0.5];
    phase_signal = extract_phase_signal(data, channel_idx, phase_band);
    
    for amp_idx = 1:length(amp_freqs)
        amp_band = [max(1, amp_freqs(amp_idx) - 1), amp_freqs(amp_idx) + 1];
        amp_signal = extract_amplitude_signal(data, channel_idx, amp_band);
        
        comodulogram.mi_matrix(ph_idx, amp_idx) = ...
            compute_modulation_index(phase_signal, amp_signal, num_phase_bins);
    end
end

fprintf('Comodulogram computed\n');

end

%% VISUALIZATION HELPER
function plot_comodulogram(comodulogram, output_path)
% Plot and save comodulogram figure

figure('Position', [100, 100, 800, 600]);

imagesc(comodulogram.amp_freqs, comodulogram.phase_freqs, comodulogram.mi_matrix);
set(gca, 'YDir', 'normal');
colormap('jet');
colorbar;

xlabel('Amplitude Frequency (Hz)', 'FontSize', 14);
ylabel('Phase Frequency (Hz)', 'FontSize', 14);
title(sprintf('PAC Comodulogram - %s', comodulogram.channel), 'FontSize', 16);

% Mark theta-gamma region
hold on;
rectangle('Position', [30, 4, 50, 4], 'EdgeColor', 'w', 'LineWidth', 2, 'LineStyle', '--');
hold off;

if nargin > 1
    saveas(gcf, output_path, 'png');
    close(gcf);
end

end