function psd_results = compute_psd_multitaper(data, cfg_spectral)
cfg = [];
cfg.method = cfg_spectral.psd.method;
cfg.taper = cfg_spectral.psd.taper;
cfg.foi = cfg_spectral.psd.foi;
cfg.tapsmofrq = cfg_spectral.psd.tapsmofrq;
cfg.keeptrials = 'no';
cfg.output = 'pow';
freq = ft_freqanalysis(cfg, data);
psd_results.freq = freq.freq;
psd_results.powspctrm = freq.powspctrm;
psd_results.label = freq.label;
psd_results.band_power.theta = mean(freq.powspctrm(:, freq.freq >= 4 & freq.freq <= 8), 2);
psd_results.band_power.alpha = mean(freq.powspctrm(:, freq.freq >= 8 & freq.freq <= 13), 2);
end

function fooof_results = fit_aperiodic_slope(psd_results, cfg_spectral)
fooof_results.exponent = ones(size(psd_results.powspctrm, 1), 1); % Placeholder
end


function fooof_results = fit_aperiodic_slope(psd_results, cfg_spectral)
% Fit 1/f aperiodic slope
num_channels = size(psd_results.powspctrm, 1);
fooof_results.exponent = zeros(num_channels, 1);
fooof_results.offset = zeros(num_channels, 1);
fooof_results.r_squared = zeros(num_channels, 1);
freq_range = cfg_spectral.fooof.freq_range;
freq_idx = psd_results.freq >= freq_range(1) & psd_results.freq <= freq_range(2);
freq_fit = psd_results.freq(freq_idx);
for ch = 1:num_channels
    power = psd_results.powspctrm(ch, freq_idx);
    log_freq = log10(freq_fit);
    log_power = log10(power);
    X = [ones(size(log_freq(:))), log_freq(:)];
    beta = X \ log_power(:);
    fooof_results.offset(ch) = beta(1);
    fooof_results.exponent(ch) = -beta(2);
    predicted = X * beta;
    ss_res = sum((log_power(:) - predicted).^2);
    ss_tot = sum((log_power(:) - mean(log_power(:))).^2);
    fooof_results.r_squared(ch) = 1 - ss_res/ss_tot;
end
fooof_results.freq = freq_fit;
fooof_results.label = psd_results.label;
fprintf('Aperiodic fitting complete. Mean exponent: %.3f\n', mean(fooof_results.exponent));
end


function fooof_results = fit_aperiodic_slope(psd_results, cfg_spectral)
% Fit 1/f aperiodic slope
num_channels = size(psd_results.powspctrm, 1);
fooof_results.exponent = zeros(num_channels, 1);
fooof_results.offset = zeros(num_channels, 1);
fooof_results.r_squared = zeros(num_channels, 1);
freq_range = cfg_spectral.fooof.freq_range;
freq_idx = psd_results.freq >= freq_range(1) & psd_results.freq <= freq_range(2);
freq_fit = psd_results.freq(freq_idx);
for ch = 1:num_channels
    power = psd_results.powspctrm(ch, freq_idx);
    log_freq = log10(freq_fit);
    log_power = log10(power);
    X = [ones(size(log_freq(:))), log_freq(:)];
    beta = X \ log_power(:);
    fooof_results.offset(ch) = beta(1);
    fooof_results.exponent(ch) = -beta(2);
    predicted = X * beta;
    ss_res = sum((log_power(:) - predicted).^2);
    ss_tot = sum((log_power(:) - mean(log_power(:))).^2);
    fooof_results.r_squared(ch) = 1 - ss_res/ss_tot;
end
fooof_results.freq = freq_fit;
fooof_results.label = psd_results.label;
fprintf('Aperiodic fitting complete. Mean exponent: %.3f\n', mean(fooof_results.exponent));
end


function fooof_results = fit_aperiodic_slope(psd_results, cfg_spectral)
num_channels = size(psd_results.powspctrm, 1);
fooof_results.exponent = zeros(num_channels, 1);
freq_range = cfg_spectral.fooof.freq_range;
freq_idx = psd_results.freq >= freq_range(1) & psd_results.freq <= freq_range(2);
for ch = 1:num_channels
    power = psd_results.powspctrm(ch, freq_idx);
    X = [ones(size(log10(psd_results.freq(freq_idx))')) log10(psd_results.freq(freq_idx))'];
    beta = X \ log10(power)';
    fooof_results.exponent(ch) = -beta(2);
end
fooof_results.label = psd_results.label;
end
