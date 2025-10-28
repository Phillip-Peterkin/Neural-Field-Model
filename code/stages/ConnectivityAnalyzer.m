classdef ConnectivityAnalyzer < handle
    % CONNECTIVITYANALYZER - Bulletproof connectivity analysis
    
    properties
        config
    end
    
    methods
        function obj = ConnectivityAnalyzer(config)
            obj.config = config;
        end
        
        function results = analyze(obj, data)
            % ANALYZE - Safe connectivity computation
            
            cfg = obj.config.connectivity;
            n_channels = size(data.signal, 1);
            
            results = struct();
            results.plv_by_band = struct();
            results.wpli_by_band = struct();
            
            % Get band list
            bands = cfg.bands;
            if ~iscell(bands)
                bands = {bands};
            end
            
            % Process each band
            for b = 1:length(bands)
                band_name = bands{b};
                
                try
                    % Get frequency range
                    if isfield(obj.config.spectral.bands, band_name)
                        band_range = obj.config.spectral.bands.(band_name);
                    else
                        warning('ConnectivityAnalyzer:BandNotFound', 'Band %s not found, skipping', band_name);
                        continue;
                    end
                    
                    % Filter to band
                    filtered = obj.filter_band(data.signal, data.srate, band_range);
                    
                    % Compute Hilbert transform
                    analytic_signal = hilbert(filtered')';
                    phase = angle(analytic_signal);
                    
                    % Compute PLV matrix
                    plv_matrix = zeros(n_channels, n_channels);
                    
                    for ch1 = 1:n_channels
                        for ch2 = (ch1+1):n_channels
                            phase_diff = phase(ch1, :) - phase(ch2, :);
                            plv_val = abs(mean(exp(1i * phase_diff)));
                            plv_matrix(ch1, ch2) = plv_val;
                            plv_matrix(ch2, ch1) = plv_val;
                        end
                    end
                    
                    % Store results
                    results.plv_by_band.(band_name) = plv_matrix;
                    
                    % Compute wPLI
                    results.wpli_by_band.(band_name) = obj.compute_wpli(analytic_signal);
                    
                catch ME
                    warning('ConnectivityAnalyzer:BandFailed', 'Band %s failed: %s', band_name, ME.message);
                    results.plv_by_band.(band_name) = zeros(n_channels, n_channels);
                    results.wpli_by_band.(band_name) = zeros(n_channels, n_channels);
                end
            end
            
            % Compute mean across bands
            if ~isempty(fieldnames(results.plv_by_band))
                band_names = fieldnames(results.plv_by_band);
                all_plv = zeros([size(results.plv_by_band.(band_names{1})), length(band_names)]);
                for b = 1:length(band_names)
                    all_plv(:,:,b) = results.plv_by_band.(band_names{b});
                end
                results.mean_plv = mean(all_plv, 3);
            else
                results.mean_plv = zeros(n_channels, n_channels);
            end
        end
        
        function filtered = filter_band(~, signal, srate, band_range)
            % FILTER_BAND - Safe bandpass filtering
            
            try
                order = 4;
                [b, a] = butter(order, band_range / (srate/2), 'bandpass');
                
                n_channels = size(signal, 1);
                filtered = zeros(size(signal));
                
                for ch = 1:n_channels
                    filtered(ch, :) = filtfilt(b, a, signal(ch, :));
                end
            catch
                % If filtering fails, return unfiltered
                warning('ConnectivityAnalyzer:FilterFailed', 'Filtering failed, returning unfiltered signal');
                filtered = signal;
            end
        end
        
        function wpli = compute_wpli(~, analytic_signal)
            % COMPUTE_WPLI - Weighted phase lag index
            
            n_channels = size(analytic_signal, 1);
            wpli = zeros(n_channels, n_channels);
            
            for ch1 = 1:n_channels
                for ch2 = (ch1+1):n_channels
                    cross_spectrum = analytic_signal(ch1, :) .* conj(analytic_signal(ch2, :));
                    imaginary_part = imag(cross_spectrum);
                    
                    wpli_val = abs(mean(imaginary_part)) / mean(abs(imaginary_part));
                    wpli(ch1, ch2) = wpli_val;
                    wpli(ch2, ch1) = wpli_val;
                end
            end
        end
    end
end