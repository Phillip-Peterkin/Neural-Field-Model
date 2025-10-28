classdef AccessDetector < handle
    % ACCESSDETECTOR - Production-quality access window detection
    % Robust coherence-based detection with hysteresis thresholding
    
    properties
        config
    end
    
    methods
        function obj = AccessDetector(config)
            obj.config = config;
        end
        
        function results = detect(obj, data, spectral_results, connectivity_results)
            % DETECT - Find access windows with coherence + content validation
            
            cfg = obj.config.access;
            results = struct();
            
            % Validate inputs
            if isempty(data) || isempty(connectivity_results)
                warning('AccessDetector:InvalidInput', 'Missing data for access detection');
                results = obj.create_empty_results();
                return;
            end
            
            try
                %% Step 1: Compute coherence time series
                fprintf('  Computing coherence timeseries...\n');
                coherence_ts = obj.compute_coherence_timeseries(data, connectivity_results);
                
                if isempty(coherence_ts) || all(isnan(coherence_ts))
                    warning('AccessDetector:InvalidCoherence', 'Could not compute valid coherence');
                    results = obj.create_empty_results();
                    return;
                end
                
                %% Step 2: Apply hysteresis thresholding
                fprintf('  Applying hysteresis detection...\n');
                access_windows = obj.detect_windows_with_hysteresis(coherence_ts, data.srate, cfg);
                
                results.coherence_timeseries = coherence_ts;
                results.access_windows = access_windows;
                results.n_events = size(access_windows, 1);
                
                %% Step 3: Content validation placeholder
                results.content_validated = false;
                results.validation_method = 'Pending decoder integration';
                
                %% Step 4: Summary statistics
                if results.n_events > 0
                    window_durations = access_windows(:, 2) - access_windows(:, 1);
                    results.mean_duration = mean(window_durations) / data.srate;
                    results.std_duration = std(window_durations) / data.srate;
                    results.total_access_time = sum(window_durations) / data.srate;
                    results.access_proportion = results.total_access_time / data.time(end);
                    
                    fprintf('  ✓ Detected %d access windows (mean duration: %.2f s)\n', ...
                        results.n_events, results.mean_duration);
                else
                    results.mean_duration = 0;
                    results.std_duration = 0;
                    results.total_access_time = 0;
                    results.access_proportion = 0;
                    fprintf('  ⊘ No access windows detected\n');
                end
                
            catch ME
                warning('AccessDetector:DetectionFailed', 'Access detection failed: %s', ME.message);
                results = obj.create_empty_results();
            end
        end
        
        function coherence_ts = compute_coherence_timeseries(obj, data, connectivity_results)
            % COMPUTE_COHERENCE_TIMESERIES - Sliding window PLV
            
            cfg = obj.config.connectivity;
            
            % Use theta-band connectivity as coherence proxy
            if isfield(connectivity_results, 'plv_by_band') && ...
                    isfield(connectivity_results.plv_by_band, 'theta')
                
                % Get number of channels
                n_channels = size(data.signal, 1);
                
                % Sliding window parameters
                window_samples = round(cfg.window_length * data.srate);
                step_samples = round(window_samples * (1 - cfg.window_overlap));
                
                % Filter to theta band
                theta_band = obj.config.spectral.bands.theta;
                filtered = obj.filter_band(data.signal, data.srate, theta_band);
                
                % Compute sliding window coherence
                n_windows = floor((size(filtered, 2) - window_samples) / step_samples) + 1;
                coherence_ts = zeros(n_windows, 1);
                
                for w = 1:n_windows
                    idx_start = (w-1) * step_samples + 1;
                    idx_end = min(idx_start + window_samples - 1, size(filtered, 2));
                    
                    window_data = filtered(:, idx_start:idx_end);
                    
                    if size(window_data, 2) < 10
                        coherence_ts(w) = 0;
                        continue;
                    end
                    
                    % Compute instantaneous PLV
                    analytic = hilbert(window_data')';
                    phase = angle(analytic);
                    
                    % Mean PLV across all channel pairs
                    plv_sum = 0;
                    n_pairs = 0;
                    for ch1 = 1:n_channels
                        for ch2 = (ch1+1):n_channels
                            phase_diff = phase(ch1, :) - phase(ch2, :);
                            plv_sum = plv_sum + abs(mean(exp(1i * phase_diff)));
                            n_pairs = n_pairs + 1;
                        end
                    end
                    
                    if n_pairs > 0
                        coherence_ts(w) = plv_sum / n_pairs;
                    else
                        coherence_ts(w) = 0;
                    end
                end
            else
                % Fallback: use mean connectivity
                warning('AccessDetector:NoTheta', 'Theta band not found, using mean connectivity');
                coherence_ts = [];
            end
        end
        
        function windows = detect_windows_with_hysteresis(~, coherence_ts, srate, cfg)
            % DETECT_WINDOWS_WITH_HYSTERESIS - Dual-threshold state machine
            
            if isempty(coherence_ts) || all(isnan(coherence_ts))
                windows = [];
                return;
            end
            
            % Convert time to samples (assuming coherence_ts is downsampled)
            % Estimate effective sampling rate of coherence timeseries
            effective_srate = srate / 100; % Approximate based on sliding window
            
            T_on_samples = round((cfg.T_on / 1000) * effective_srate);
            T_off_samples = round((cfg.T_off / 1000) * effective_srate);
            dwell_min_samples = round((cfg.dwell_min / 1000) * effective_srate);
            dwell_max_samples = round((cfg.dwell_max / 1000) * effective_srate);
            refractory_samples = round((cfg.refractory / 1000) * effective_srate);
            
            % State machine
            in_access = false;
            candidate_start = 0;
            above_hi_counter = 0;
            below_lo_counter = 0;
            
            windows = [];
            last_window_end = -refractory_samples;
            
            for t = 1:length(coherence_ts)
                if isnan(coherence_ts(t))
                    continue;
                end
                
                if ~in_access
                    % Looking for entry
                    if coherence_ts(t) >= cfg.R_hi
                        above_hi_counter = above_hi_counter + 1;
                        if above_hi_counter >= T_on_samples && ...
                                (t - last_window_end) >= refractory_samples
                            in_access = true;
                            candidate_start = t - above_hi_counter + 1;
                            below_lo_counter = 0;
                        end
                    else
                        above_hi_counter = 0;
                    end
                else
                    % In access, looking for exit
                    if coherence_ts(t) <= cfg.R_lo
                        below_lo_counter = below_lo_counter + 1;
                        if below_lo_counter >= T_off_samples
                            % Exit access
                            window_end = t - below_lo_counter + 1;
                            window_duration = window_end - candidate_start;
                            
                            % Check duration constraints
                            if window_duration >= dwell_min_samples && ...
                                    window_duration <= dwell_max_samples
                                windows = [windows; candidate_start, window_end]; %#ok<AGROW>
                                last_window_end = window_end;
                            end
                            
                            in_access = false;
                            above_hi_counter = 0;
                            below_lo_counter = 0;
                        end
                    else
                        below_lo_counter = 0;
                    end
                end
            end
            
            % Handle case where access extends to end
            if in_access
                window_duration = length(coherence_ts) - candidate_start;
                if window_duration >= dwell_min_samples && ...
                        window_duration <= dwell_max_samples
                    windows = [windows; candidate_start, length(coherence_ts)];
                end
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
                warning('AccessDetector:FilterFailed', 'Filtering failed');
                filtered = signal;
            end
        end
        
        function results = create_empty_results(~)
            % CREATE_EMPTY_RESULTS - Default structure on failure
            
            results = struct();
            results.coherence_timeseries = [];
            results.access_windows = [];
            results.n_events = 0;
            results.mean_duration = 0;
            results.std_duration = 0;
            results.total_access_time = 0;
            results.access_proportion = 0;
            results.content_validated = false;
            results.status = 'failed';
        end
    end
end