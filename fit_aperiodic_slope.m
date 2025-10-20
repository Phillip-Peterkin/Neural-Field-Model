function fooof_results = fit_aperiodic_slope(psd_results, cfg_spectral)
% Fit 1/f aperiodic slope (FOOOF method)
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
