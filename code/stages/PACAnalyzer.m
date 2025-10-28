classdef PACAnalyzer < handle
    % PACANALYZER - Production-quality phase-amplitude coupling
    % Implements Section 13.3 with Tort's Modulation Index
    
    properties
        config
    end
    
    methods
        function obj = PACAnalyzer(config)
            obj.config = config;
        end
        
        function results = analyze(obj, data)
            % ANALYZE - Compute theta-gamma PAC using Tort's MI
            
            cfg = obj.config.pac;
            results = struct();
            
            % Validate input
            if isempty(data) || ~isfield(data, 'signal') || ~isfield(data, 'srate')
                warning('PACAnalyzer:InvalidInput', 'Invalid data structure');
                results = obj.create_empty_results();
                return;
            end
            
            n_channels = size(data.signal, 1);
            
            try
                %% Extract phase and amplitude
                fprintf('  Extracting theta phase and gamma amplitude...\n');
                
                % Theta phase (4-7 Hz)
                theta_filtered = obj.filter_band(data.signal, data.srate, cfg.phase_band);
                theta_analytic = hilbert(theta_filtered')';
                theta_phase = angle(theta_analytic);
                
                % Gamma amplitude (50-80 Hz)
                gamma_filtered = obj.filter_band(data.signal, data.srate, cfg.amp_band);
                gamma_analytic = hilbert(gamma_filtered')';
                gamma_amplitude = abs(gamma_analytic);
                
                %% Compute Tort's Modulation Index per channel
                mi_values = zeros(n_channels, 1);
                mi_surrogates = zeros(n_channels, cfg.surrogate_n);
                mi_pvalues = zeros(n_channels, 1);
                
                for ch = 1:n_channels
                    try
                        % Compute MI for real data
                        mi_values(ch) = obj.compute_tort_MI(...
                            theta_phase(ch, :), ...
                            gamma_amplitude(ch, :), ...
                            cfg.n_phase_bins);
                        
                        % Compute surrogate distribution
                        for s = 1:cfg.surrogate_n
                            % Phase shuffle the amplitude
                            shuffled_amp = gamma_amplitude(ch, randperm(length(gamma_amplitude(ch, :))));
                            mi_surrogates(ch, s) = obj.compute_tort_MI(...
                                theta_phase(ch, :), ...
                                shuffled_amp, ...
                                cfg.n_phase_bins);
                        end
                        
                        % Statistical significance
                        mi_pvalues(ch) = sum(mi_surrogates(ch, :) >= mi_values(ch)) / cfg.surrogate_n;
                        
                    catch ME
                        warning('PACAnalyzer:ChannelFailed', ...
                            'Channel %d PAC failed: %s', ch, ME.message);
                        mi_values(ch) = NaN;
                        mi_surrogates(ch, :) = NaN;
                        mi_pvalues(ch) = 1;
                    end
                end
                
                results.modulation_index = mi_values;
                results.mi_surrogates = mi_surrogates;
                results.mi_pvalues = mi_pvalues;
                
                % Z-scores
                mi_means = mean(mi_surrogates, 2, 'omitnan');
                mi_stds = std(mi_surrogates, 0, 2, 'omitnan');
                results.mi_zscore = (mi_values - mi_means) ./ mi_stds;
                
                % Mean across channels
                results.mean_MI = mean(mi_values, 'omitnan');
                results.mean_MI_zscore = mean(results.mi_zscore, 'omitnan');
                results.n_significant = sum(mi_pvalues < 0.05);
                
                fprintf('  ✓ Mean MI: %.4f (z=%.2f, %d/%d channels significant)\n', ...
                    results.mean_MI, results.mean_MI_zscore, ...
                    results.n_significant, n_channels);
                
                %% Phase-amplitude distribution
                results.phase_bins = linspace(-pi, pi, cfg.n_phase_bins + 1);
                results.mean_amp_by_phase = obj.compute_phase_amplitude_distribution(...
                    theta_phase, gamma_amplitude, cfg.n_phase_bins);
                
                %% Comodulogram (optional - frequency-frequency coupling)
                results.comodulogram_computed = false;
                
            catch ME
                warning('PACAnalyzer:AnalysisFailed', 'PAC analysis failed: %s', ME.message);
                results = obj.create_empty_results();
            end
        end
        
        function MI = compute_tort_MI(~, phase, amplitude, n_bins)
            % COMPUTE_TORT_MI - Tort's modulation index
            % MI = (H_max - H) / H_max
            
            % Remove NaN values
            valid = ~isnan(phase) & ~isnan(amplitude);
            phase = phase(valid);
            amplitude = amplitude(valid);
            
            if length(phase) < 100
                MI = NaN;
                return;
            end
            
            % Bin phases
            phase_bins = linspace(-pi, pi, n_bins + 1);
            
            % Mean amplitude per phase bin
            mean_amp_per_bin = zeros(n_bins, 1);
            for b = 1:n_bins
                in_bin = phase >= phase_bins(b) & phase < phase_bins(b+1);
                if sum(in_bin) > 0
                    mean_amp_per_bin(b) = mean(amplitude(in_bin));
                end
            end
            
            % Normalize to probability distribution
            P = mean_amp_per_bin / sum(mean_amp_per_bin);
            P(P == 0) = eps; % Avoid log(0)
            
            % Entropy
            H = -sum(P .* log(P));
            H_max = log(n_bins);
            
            % Modulation index
            MI = (H_max - H) / H_max;
        end
        
        function mean_amp = compute_phase_amplitude_distribution(~, phase, amplitude, n_bins)
            % COMPUTE_PHASE_AMPLITUDE_DISTRIBUTION - Mean amp vs phase
            
            n_channels = size(phase, 1);
            phase_bins = linspace(-pi, pi, n_bins + 1);
            mean_amp = zeros(n_channels, n_bins);
            
            for ch = 1:n_channels
                for b = 1:n_bins
                    in_bin = phase(ch, :) >= phase_bins(b) & phase(ch, :) < phase_bins(b+1);
                    if sum(in_bin) > 0
                        mean_amp(ch, b) = mean(amplitude(ch, in_bin), 'omitnan');
                    end
                end
            end
        end
        
        function filtered = filter_band(~, signal, srate, band_range)
            % FILTER_BAND - Bandpass filter with error handling
            
            try
                order = 4;
                [b, a] = butter(order, band_range / (srate/2), 'bandpass');
                
                n_channels = size(signal, 1);
                filtered = zeros(size(signal));
                
                for ch = 1:n_channels
                    filtered(ch, :) = filtfilt(b, a, signal(ch, :));
                end
            catch
                warning('PACAnalyzer:FilterFailed', 'Filtering failed, returning zeros');
                filtered = zeros(size(signal));
            end
        end
        
        function results = create_empty_results(~)
            % CREATE_EMPTY_RESULTS - Default structure on failure
            
            results = struct();
            results.modulation_index = [];
            results.mi_surrogates = [];
            results.mi_zscore = [];
            results.mi_pvalues = [];
            results.mean_MI = NaN;
            results.mean_MI_zscore = NaN;
            results.status = 'failed';
        end
    end
end