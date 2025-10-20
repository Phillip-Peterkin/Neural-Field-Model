%% SPECTRAL ANALYSIS FUNCTIONS
% Power spectral density, aperiodic (1/f) fitting, and time-frequency analysis

function psd_results = compute_psd_multitaper(data, cfg_spectral)
% COMPUTE_PSD_MULTITAPER - Compute power spectral density using multitapers
%
% Uses Slepian tapers (DPSS) for optimal spectral estimation with minimal
% bias and variance trade-off

fprintf('Computing power spectral density...\n');

% Configure multitaper analysis
cfg = [];
cfg.method = cfg_spectral.psd.method;
cfg.taper = cfg_spectral.psd.taper;
cfg.foi = cfg_spectral.psd.foi;
cfg.tapsmofrq = cfg_spectral.psd.tapsmofrq;
cfg.pad = cfg_spectral.psd.pad;
cfg.keeptrials = 'no'; % Average across trials
cfg.output = 'pow';

% Compute PSD
freq = ft_freqanalysis(cfg, data);

% Also compute per-trial for variability estimates
cfg.keeptrials = 'yes';
freq_trials = ft_freqanalysis(cfg, data);

% Extract results
psd_results = struct();
psd_results.freq = freq.freq;
psd_results.powspctrm = freq.powspctrm; % [channels x frequencies]
psd_results.powspctrm_trials = freq_trials.powspctrm; % [trials x channels x frequencies]
psd_results.label = freq.label;
psd_results.dimord = freq.dimord;

% Compute confidence intervals via bootstrapping
psd_results.ci_lower = squeeze(prctile(freq_trials.powspctrm, 2.5, 1));
psd_results.ci_upper = squeeze(prctile(freq_trials.powspctrm, 97.5, 1));

% Compute band-limited power
bands = fieldnames(cfg_spectral.bands);
for b = 1:length(bands)
    band_name = bands{b};
    band_range = cfg_spectral.bands.(band_name);
    
    freq_idx = psd_results.freq >= band_range(1) & psd_results.freq <= band_range(2);
    psd_results.band_power.(band_name) = mean(psd_results.powspctrm(:, freq_idx), 2);
end

fprintf('PSD computed for %d channels, %d frequencies\n', ...
    length(psd_results.label), length(psd_results.freq));

end

%% APERIODIC SLOPE FITTING (FOOOF-LIKE)
function fooof_results = fit_aperiodic_slope(psd_results, cfg_spectral)
% FIT_APERIODIC_SLOPE - Parameterize power spectra into aperiodic and periodic components
%
% Implements a MATLAB version of the FOOOF algorithm:
% Donoghue et al. (2020) "Parameterizing neural power spectra into periodic
% and aperiodic components" Nature Neuroscience
%
% Model: log(Power) = offset - log(freq)^exponent + sum(Gaussians)

fprintf('Fitting aperiodic slope (FOOOF method)...\n');

freq_range = cfg_spectral.fooof.freq_range;
freq = psd_results.freq;
freq_idx = freq >= freq_range(1) & freq <= freq_range(2);
freq_fit = freq(freq_idx);

num_channels = size(psd_results.powspctrm, 1);
fooof_results = struct();

% Initialize output arrays
fooof_results.offset = zeros(num_channels, 1);
fooof_results.exponent = zeros(num_channels, 1);
fooof_results.r_squared = zeros(num_channels, 1);
fooof_results.peaks = cell(num_channels, 1);
fooof_results.aperiodic_fit = zeros(num_channels, length(freq_fit));
fooof_results.full_fit = zeros(num_channels, length(freq_fit));

for ch = 1:num_channels
    % Get power spectrum for this channel
    power = psd_results.powspctrm(ch, freq_idx);
    
    % Convert to log space
    log_freq = log10(freq_fit);
    log_power = log10(power);
    
    % Initial robust fit of aperiodic component (without peaks)
    [aperiodic_params, ap_fit] = fit_aperiodic_component(log_freq, log_power, cfg_spectral);
    
    % Remove aperiodic component
    flattened_spectrum = log_power - ap_fit;
    
    % Detect peaks in flattened spectrum
    peaks = detect_spectral_peaks(freq_fit, flattened_spectrum, cfg_spectral);
    
    % Re-fit with peaks
    if ~isempty(peaks)
        [final_params, final_fit] = fit_full_model(log_freq, log_power, ...
            aperiodic_params, peaks, cfg_spectral);
    else
        final_params = aperiodic_params;
        final_fit = ap_fit;
    end
    
    % Store results
    fooof_results.offset(ch) = final_params.offset;
    fooof_results.exponent(ch) = final_params.exponent;
    fooof_results.peaks{ch} = peaks;
    fooof_results.aperiodic_fit(ch, :) = 10.^ap_fit; % Convert back to linear
    fooof_results.full_fit(ch, :) = 10.^final_fit;
    
    % Compute R-squared
    ss_res = sum((log_power - final_fit).^2);
    ss_tot = sum((log_power - mean(log_power)).^2);
    fooof_results.r_squared(ch) = 1 - ss_res/ss_tot;
end

fooof_results.freq = freq_fit;
fooof_results.label = psd_results.label;

fprintf('Aperiodic fitting complete. Mean exponent: %.3f ± %.3f\n', ...
    mean(fooof_results.exponent), std(fooof_results.exponent));

end

function [params, fit] = fit_aperiodic_component(log_freq, log_power, cfg)
% Fit 1/f^exponent model to log-power spectrum
% Model: log(P) = offset - exponent * log(f)

% Use robust fitting to reduce influence of peaks
robust_weights = ones(size(log_power));

for iter = 1:5 % Iterative robust fit
    % Linear regression in log-log space
    X = [ones(size(log_freq(:))), log_freq(:)];
    w = diag(robust_weights);
    beta = (X' * w * X) \ (X' * w * log_power(:));
    
    params.offset = beta(1);
    params.exponent = -beta(2); % Note: negative because we subtract in model
    
    fit = beta(1) + beta(2) * log_freq(:);
    
    % Update weights (downweight outliers above the line = peaks)
    residuals = log_power(:) - fit;
    mad_res = mad(residuals(residuals < 0), 1); % Only consider points below fit
    robust_weights = exp(-abs(residuals) / (3 * mad_res));
    robust_weights(residuals > 0) = robust_weights(residuals > 0) .* 0.1; % Heavily downweight peaks
end

fit = fit(:)';
end

function peaks = detect_spectral_peaks(freq, flattened_spectrum, cfg)
% Detect peaks in flattened (aperiodic-removed) spectrum

% Smooth spectrum
window = gausswin(7); window = window / sum(window);
smoothed = conv(flattened_spectrum, window, 'same');

% Find local maxima above threshold
[pks, locs] = findpeaks(smoothed, 'MinPeakHeight', cfg.fooof.min_peak_height, ...
    'MinPeakProminence', cfg.fooof.peak_threshold * std(smoothed));

if length(pks) > cfg.fooof.max_peaks
    [~, idx] = sort(pks, 'descend');
    locs = locs(idx(1:cfg.fooof.max_peaks));
    pks = pks(idx(1:cfg.fooof.max_peaks));
end

% Estimate peak parameters
peaks = struct('frequency', {}, 'power', {}, 'width', {});

for i = 1:length(pks)
    % Estimate width at half-maximum
    peak_freq = freq(locs(i));
    peak_power = pks(i);
    
    % Find points at half-maximum
    half_max = peak_power / 2;
    left_idx = find(smoothed(1:locs(i)) < half_max, 1, 'last');
    right_idx = locs(i) + find(smoothed(locs(i):end) < half_max, 1, 'first') - 1;
    
    if ~isempty(left_idx) && ~isempty(right_idx)
        width = freq(right_idx) - freq(left_idx);
    else
        width = 2; % Default width
    end
    
    % Check width limits
    if width >= cfg.fooof.peak_width_limits(1) && width <= cfg.fooof.peak_width_limits(2)
        peaks(end+1).frequency = peak_freq;
        peaks(end).power = peak_power;
        peaks(end).width = width;
    end
end

end

function [params, fit] = fit_full_model(log_freq, log_power, aperiodic_params, peaks, cfg)
% Fit full model: aperiodic + Gaussian peaks

if isempty(peaks)
    params = aperiodic_params;
    fit = aperiodic_params.offset - aperiodic_params.exponent * log_freq;
    return;
end

% Initial parameters: [offset, exponent, peak1_freq, peak1_amp, peak1_width, ...]
num_peaks = length(peaks);
x0 = [aperiodic_params.offset, aperiodic_params.exponent];

for i = 1:num_peaks
    x0 = [x0, log10(peaks(i).frequency), peaks(i).power, peaks(i).width];
end

% Bounds
lb = [aperiodic_params.offset-2, 0]; % offset, exponent
ub = [aperiodic_params.offset+2, 4];

for i = 1:num_peaks
    lb = [lb, log10(cfg.fooof.freq_range(1)), 0, cfg.fooof.peak_width_limits(1)];
    ub = [ub, log10(cfg.fooof.freq_range(2)), max(log_power), cfg.fooof.peak_width_limits(2)];
end

% Fit using nonlinear least squares
options = optimoptions('lsqnonlin', 'Display', 'off', 'MaxIterations', 1000);

model_fun = @(x) full_model(x, log_freq, num_peaks);

try
    x_fit = lsqnonlin(@(x) log_power - model_fun(x), x0, lb, ub, options);
    
    params.offset = x_fit(1);
    params.exponent = x_fit(2);
    
    for i = 1:num_peaks
        idx = 2 + (i-1)*3 + 1;
        peaks(i).frequency = 10^x_fit(idx);
        peaks(i).power = x_fit(idx+1);
        peaks(i).width = x_fit(idx+2);
    end
    
    fit = model_fun(x_fit);
    params.peaks = peaks;
    
catch
    % If fitting fails, return initial aperiodic fit
    params = aperiodic_params;
    fit = aperiodic_params.offset - aperiodic_params.exponent * log_freq;
end

end

function y = full_model(x, log_freq, num_peaks)
% Full spectral model: aperiodic + Gaussian peaks

% Aperiodic component
y = x(1) - x(2) * log_freq;

% Add Gaussian peaks
for i = 1:num_peaks
    idx = 2 + (i-1)*3 + 1;
    center = x(idx);
    amplitude = x(idx+1);
    width = x(idx+2);
    
    % Gaussian peak
    y = y + amplitude * exp(-0.5 * ((log_freq - center) / (width / 2.355)).^2);
end

end

%% TIME-FREQUENCY ANALYSIS
function tf_results = compute_time_frequency(data, cfg_spectral)
% COMPUTE_TIME_FREQUENCY - Compute time-frequency representation
%
% Uses multitaper convolution with adaptive time windows (more cycles at
% higher frequencies for optimal time-frequency resolution)

fprintf('Computing time-frequency analysis...\n');

cfg = [];
cfg.method = cfg_spectral.tf.method;
cfg.foi = cfg_spectral.tf.foi;
cfg.t_ftimwin = cfg_spectral.tf.t_ftimwin;
cfg.taper = cfg_spectral.tf.taper;
cfg.toi = cfg_spectral.tf.toi;
cfg.keeptrials = 'yes';
cfg.output = 'pow';
cfg.pad = 'nextpow2';

% Compute TFR
tfr = ft_freqanalysis(cfg, data);

% Baseline correction (relative change)
cfg = [];
cfg.baseline = [-0.5 -0.1];
cfg.baselinetype = 'relchange';
tfr_bl = ft_freqbaseline(cfg, tfr);

% Store results
tf_results = struct();
tf_results.time = tfr_bl.time;
tf_results.freq = tfr_bl.freq;
tf_results.powspctrm = tfr_bl.powspctrm; % [trials x channels x freq x time]
tf_results.label = tfr_bl.label;

% Average across trials
tf_results.powspctrm_avg = squeeze(mean(tfr_bl.powspctrm, 1));

% Compute intertrial coherence (phase consistency)
cfg = [];
cfg.method = cfg_spectral.tf.method;
cfg.foi = cfg_spectral.tf.foi;
cfg.t_ftimwin = cfg_spectral.tf.t_ftimwin;
cfg.taper = cfg_spectral.tf.taper;
cfg.toi = cfg_spectral.tf.toi;
cfg.output = 'fourier'; % Get complex Fourier coefficients
cfg.keeptrials = 'yes';
cfg.pad = 'nextpow2';

tfr_fourier = ft_freqanalysis(cfg, data);

% Compute ITC (inter-trial phase coherence)
fourier = tfr_fourier.fourierspctrm; % [trials x channels x freq x time]
itc = abs(mean(fourier ./ abs(fourier), 1)); % Phase-locking value
tf_results.itc = squeeze(itc);

fprintf('Time-frequency analysis complete: %d freqs × %d time points\n', ...
    length(tf_results.freq), length(tf_results.time));

end

%% BAND-LIMITED POWER TIME SERIES
function band_power = extract_band_power_timeseries(data, freq_band, cfg_spectral)
% EXTRACT_BAND_POWER_TIMESERIES - Extract amplitude envelope in a frequency band
%
% Uses Hilbert transform to get instantaneous amplitude

fprintf('Extracting %d-%d Hz band power...\n', freq_band(1), freq_band(2));

% Bandpass filter
cfg = [];
cfg.bpfilter = 'yes';
cfg.bpfreq = freq_band;
cfg.bpfiltord = 4;
cfg.bpfilttype = 'but';
cfg.hilbert = 'yes'; % Apply Hilbert transform

data_filtered = ft_preprocessing(cfg, data);

% Get amplitude envelope
band_power = struct();
band_power.time = data_filtered.time;
band_power.label = data_filtered.label;

for trial = 1:length(data_filtered.trial)
    % Amplitude is absolute value of analytic signal
    band_power.amplitude{trial} = abs(data_filtered.trial{trial});
    
    % Instantaneous phase
    band_power.phase{trial} = angle(data_filtered.trial{trial});
end

end

%% SPECTRAL COHERENCE
function coherence = compute_spectral_coherence(data, cfg_spectral)
% COMPUTE_SPECTRAL_COHERENCE - Compute magnitude-squared coherence between channels

fprintf('Computing spectral coherence...\n');

cfg = [];
cfg.method = 'mtmfft';
cfg.taper = 'dpss';
cfg.output = 'powandcsd'; % Power and cross-spectral density
cfg.tapsmofrq = 2;
cfg.foi = cfg_spectral.psd.foi;
cfg.keeptrials = 'no';
cfg.channelcmb = 'all'; % All channel combinations

freq = ft_freqanalysis(cfg, data);

% Compute coherence
cfg = [];
cfg.method = 'coh'; % Coherence
coherence_data = ft_connectivityanalysis(cfg, freq);

coherence = struct();
coherence.freq = coherence_data.freq;
coherence.labelcmb = coherence_data.labelcmb;
coherence.cohspctrm = coherence_data.cohspctrm; % [channel_pairs x frequencies]

fprintf('Coherence computed for %d channel pairs\n', size(coherence.cohspctrm, 1));

end