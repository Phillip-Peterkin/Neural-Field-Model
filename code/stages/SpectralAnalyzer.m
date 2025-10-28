classdef SpectralAnalyzer < handle
    % SPECTRALANALYZER - Production-quality spectral analysis
    % Implements Section 13.1 with robust PSD and aperiodic fitting
    
    properties
        config
    end
    
    methods
        function obj = SpectralAnalyzer(config)
            obj.config = config;
        end
        
        function results = analyze(obj, data)
            % ANALYZE - Compute power spectra and aperiodic components
            
            cfg = obj.config.spectral;
            results = struct();
            
            % Validate input
            if isempty(data) || ~isfield(data, 'signal') || ~isfield(data, 'srate')
                warning('SpectralAnalyzer:InvalidInput', 'Invalid data structure');
                results = obj.create_empty_results();
                return;
            end
            
            try
                %% Compute Welch power spectral density
                n_channels = size(data.signal, 1);
                window_samples = round(cfg.window_length * data.srate);
                overlap_samples = round(window_samples * cfg.window_overlap);
                nfft = 2^nextpow2(window_samples);
                
                % Frequency vector
                freqs = linspace(0, data.srate/2, nfft/2 + 1);
                freq_mask = freqs >= cfg.freq_range(1) & freqs <= cfg.freq_range(2);
                freqs = freqs(freq_mask);
                
                % Initialize PSD matrix
                psd = zeros(n_channels, sum(freq_mask));
                
                fprintf('  Computing PSD: %d channels, %d frequencies\n', ...
                    n_channels, length(freqs));
                
                for ch = 1:n_channels
                    try
                        [pxx, f] = pwelch(data.signal(ch, :), ...
                            hann(window_samples), overlap_samples, nfft, data.srate);
                        psd(ch, :) = pxx(freq_mask);
                    catch ME
                        warning('SpectralAnalyzer:ChannelFailed', ...
                            'Channel %d PSD failed: %s', ch, ME.message);
                        psd(ch, :) = nan(1, sum(freq_mask));
                    end
                end
                
                results.power_spectrum = psd;
                results.freqs = freqs;
                
                %% Fit aperiodic (1/f) component
                fprintf('  Fitting aperiodic component...\n');
                
                fit_mask = freqs >= cfg.aperiodic_fit(1) & freqs <= cfg.aperiodic_fit(2);
                
                aperiodic_slopes = zeros(n_channels, 1);
                aperiodic_offsets = zeros(n_channels, 1);
                fit_quality = zeros(n_channels, 1);
                
                for ch = 1:n_channels
                    if all(isnan(psd(ch, :)))
                        aperiodic_slopes(ch) = NaN;
                        aperiodic_offsets(ch) = NaN;
                        fit_quality(ch) = 0;
                        continue;
                    end
                    
                    try
                        % Log-log space for 1/f fitting
                        log_freqs = log10(freqs(fit_mask));
                        log_power = log10(psd(ch, fit_mask));
                        
                        % Remove any infinite or NaN values
                        valid = isfinite(log_freqs) & isfinite(log_power);
                        if sum(valid) < 10
                            aperiodic_slopes(ch) = NaN;
                            aperiodic_offsets(ch) = NaN;
                            fit_quality(ch) = 0;
                            continue;
                        end
                        
                        log_freqs = log_freqs(valid);
                        log_power = log_power(valid);
                        
                        % Linear fit: log(P) = offset - slope * log(f)
                        p = polyfit(log_freqs, log_power, 1);
                        aperiodic_slopes(ch) = -p(1); % Negative because of 1/f^slope
                        aperiodic_offsets(ch) = p(2);
                        
                        % Compute R-squared for fit quality
                        fitted = polyval(p, log_freqs);
                        residuals = log_power - fitted;
                        ss_res = sum(residuals.^2);
                        ss_tot = sum((log_power - mean(log_power)).^2);
                        fit_quality(ch) = 1 - (ss_res / ss_tot);
                        
                    catch ME
                        warning('SpectralAnalyzer:FitFailed', ...
                            'Channel %d aperiodic fit failed: %s', ch, ME.message);
                        aperiodic_slopes(ch) = NaN;
                        aperiodic_offsets(ch) = NaN;
                        fit_quality(ch) = 0;
                    end
                end
                
                % Use median for robustness
                results.aperiodic_slope = median(aperiodic_slopes, 'omitnan');
                results.aperiodic_slope_by_channel = aperiodic_slopes;
                results.aperiodic_offset = median(aperiodic_offsets, 'omitnan');
                results.fit_quality_mean = mean(fit_quality);
                
                fprintf('  ✓ Aperiodic slope: %.3f (quality: %.2f)\n', ...
                    results.aperiodic_slope, results.fit_quality_mean);
                
                %% Extract band power
                bands = cfg.bands;
                band_names = fieldnames(bands);
                results.band_power = struct();
                
                for b = 1:length(band_names)
                    band_name = band_names{b};
                    band_range = bands.(band_name);
                    
                    band_mask = freqs >= band_range(1) & freqs <= band_range(2);
                    
                    if sum(band_mask) == 0
                        warning('SpectralAnalyzer:EmptyBand', ...
                            'No frequencies in %s band [%.1f-%.1f Hz]', ...
                            band_name, band_range(1), band_range(2));
                        results.band_power.(band_name) = nan(n_channels, 1);
                        continue;
                    end
                    
                    band_power = mean(psd(:, band_mask), 2);
                    results.band_power.(band_name) = band_power;
                end
                
                %% Periodic component (residual after removing aperiodic)
                results.periodic_power = zeros(size(psd));
                for ch = 1:n_channels
                    if ~isnan(aperiodic_slopes(ch))
                        aperiodic_fit = 10.^(aperiodic_offsets(ch) - ...
                            aperiodic_slopes(ch) * log10(freqs));
                        results.periodic_power(ch, :) = psd(ch, :) - aperiodic_fit;
                    else
                        results.periodic_power(ch, :) = psd(ch, :);
                    end
                end
                
                %% Summary statistics
                results.summary.total_power = sum(mean(psd, 1));
                results.summary.dominant_band = obj.find_dominant_band(results.band_power);
                
            catch ME
                warning('SpectralAnalyzer:AnalysisFailed', 'Spectral analysis failed: %s', ME.message);
                results = obj.create_empty_results();
            end
        end
        
        function dominant_band = find_dominant_band(~, band_power)
            % FIND_DOMINANT_BAND - Identify band with highest power
            
            band_names = fieldnames(band_power);
            band_means = zeros(length(band_names), 1);
            
            for b = 1:length(band_names)
                band_means(b) = mean(band_power.(band_names{b}), 'omitnan');
            end
            
            [~, max_idx] = max(band_means);
            dominant_band = band_names{max_idx};
        end
        
        function results = create_empty_results(~)
            % CREATE_EMPTY_RESULTS - Default structure on failure
            
            results = struct();
            results.power_spectrum = [];
            results.freqs = [];
            results.aperiodic_slope = NaN;
            results.aperiodic_offset = NaN;
            results.band_power = struct();
            results.periodic_power = [];
            results.status = 'failed';
        end
    end
end