function phase_conn = compute_phase_connectivity(data, cfg_conn)
% Compute phase connectivity (PLV, wPLI)
fprintf('Computing phase-based connectivity...\n');
phase_conn = struct();
num_bands = size(cfg_conn.foi, 1);
for band_idx = 1:num_bands
    freq_band = cfg_conn.foi(band_idx, :);
    band_name = sprintf('band_%d_%d_Hz', round(freq_band(1)), round(freq_band(2)));
    fprintf('  Processing %s...\n', band_name);
    plv_results = compute_plv(data, freq_band);
    wpli_results = compute_wpli(data, freq_band);
    phase_conn.(band_name).plv = plv_results;
    phase_conn.(band_name).wpli = wpli_results;
end
phase_conn.label = data.label;
fprintf('Phase connectivity computed\n');
end

function plv_results = compute_plv(data, freq_band)
cfg = [];
cfg.bpfilter = 'yes';
cfg.bpfreq = freq_band;
cfg.hilbert = 'yes';
data_filt = ft_preprocessing(cfg, data);
n_ch = length(data.label);
plv_matrix = eye(n_ch);
for i = 1:n_ch
    for j = i+1:n_ch
        phase_diff = [];
        for trial = 1:length(data_filt.trial)
            phi1 = angle(data_filt.trial{trial}(i,:));
            phi2 = angle(data_filt.trial{trial}(j,:));
            phase_diff = [phase_diff, phi1 - phi2];
        end
        plv_matrix(i,j) = abs(mean(exp(1i * phase_diff)));
        plv_matrix(j,i) = plv_matrix(i,j);
    end
end
plv_results.plv = plv_matrix;
plv_results.label = data.label;
end

function wpli_results = compute_wpli(data, freq_band)
cfg = [];
cfg.method = 'mtmfft';
cfg.taper = 'hanning';
cfg.output = 'fourier';
cfg.foi = mean(freq_band);
cfg.keeptrials = 'yes';
freq = ft_freqanalysis(cfg, data);
cfg = [];
cfg.method = 'wpli_debiased';
wpli_data = ft_connectivityanalysis(cfg, freq);
wpli_results.wpli = wpli_data.wpli_debiasedspctrm;
wpli_results.label = wpli_data.label;
end
