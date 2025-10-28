classdef ERPAnalyzer < handle
    % ERPANALYZER - Production-quality event-related potential analysis
    % Implements Section 13.4 with robust filtering and baseline correction
    
    properties
        config
    end
    
    methods
        function obj = ERPAnalyzer(config)
            obj.config = config;
        end
        
        function results = analyze(obj, trials)
            % ANALYZE - Extract ERPs from segmented trials
            
            cfg = obj.config.erp;
            results = struct();
            
            % Validate input
            if isempty(trials) || ~iscell(trials)
                warning('ERPAnalyzer:InvalidInput', 'No trials provided');
                results = obj.create_empty_results();
                return;
            end
            
            n_trials = length(trials);
            if n_trials == 0
                warning('ERPAnalyzer:NoTrials', 'No trials to analyze');
                results = obj.create_empty_results();
                return;
            end
            
            try
                % Get dimensions from first valid trial
                first_valid = find(~cellfun(@isempty, trials), 1);
                if isempty(first_valid)
                    warning('ERPAnalyzer:AllTrialsEmpty', 'All trials are empty');
                    results = obj.create_empty_results();
                    return;
                end
                
                n_channels = size(trials{first_valid}.signal, 1);
                n_samples = size(trials{first_valid}.signal, 2);
                time = trials{first_valid}.time;
                
                fprintf('  Analyzing %d trials (%d channels, %d samples)\n', ...
                    n_trials, n_channels, n_samples);
                
                %% Concatenate all valid trials
                all_trials = nan(n_channels, n_samples, n_trials);
                valid_trial_idx = false(n_trials, 1);
                
                for t = 1:n_trials
                    if ~isempty(trials{t}) && isfield(trials{t}, 'signal')
                        trial_signal = trials{t}.signal;
                        if size(trial_signal, 1) == n_channels && size(trial_signal, 2) == n_samples
                            all_trials(:, :, t) = trial_signal;
                            valid_trial_idx(t) = true;
                        end
                    end
                end
                
                n_valid = sum(valid_trial_idx);
                fprintf('  Valid trials: %d/%d\n', n_valid, n_trials);
                
                if n_valid < 5
                    warning('ERPAnalyzer:InsufficientTrials', 'Too few valid trials (%d)', n_valid);
                    results = obj.create_empty_results();
                    return;
                end
                
                % Remove invalid trials
                all_trials = all_trials(:, :, valid_trial_idx);
                
                %% Filter for ERP
                srate = 1 / (time(2) - time(1));
                filtered_trials = obj.filter_erp(all_trials, srate);
                
                %% Baseline correction
                baseline_idx = time >= cfg.baseline(1) & time <= cfg.baseline(2);
                
                if sum(baseline_idx) == 0
                    warning('ERPAnalyzer:NoBaseline', 'No samples in baseline window');
                    baseline_mean = zeros(n_channels, 1, n_valid);
                else
                    baseline_mean = mean(filtered_trials(:, baseline_idx, :), 2);
                end
                
                filtered_trials = filtered_trials - baseline_mean;
                
                %% Compute ERP (average across trials)
                results.erp = mean(filtered_trials, 3, 'omitnan');
                results.erp_std = std(filtered_trials, 0, 3, 'omitnan');
                results.erp_sem = results.erp_std / sqrt(n_valid);
                results.time = time;
                results.n_trials = n_valid;
                results.n_channels = n_channels;
                
                %% Extract component latencies
                % Average across channels for component detection
                mean_erp = mean(results.erp, 1);
                
                % N2 component (200-350 ms) - negative deflection
                n2_idx = time >= cfg.N2_window(1) & time <= cfg.N2_window(2);
                if sum(n2_idx) > 0
                    [n2_amp, n2_peak_idx] = min(mean_erp(n2_idx));
                    n2_time_vector = time(n2_idx);
                    results.N2_latency = n2_time_vector(n2_peak_idx);
                    results.N2_amplitude = n2_amp;
                else
                    results.N2_latency = NaN;
                    results.N2_amplitude = NaN;
                end
                
                % P3b component (300-600 ms) - positive deflection
                p3b_idx = time >= cfg.P3b_window(1) & time <= cfg.P3b_window(2);
                if sum(p3b_idx) > 0
                    [p3b_amp, p3b_peak_idx] = max(mean_erp(p3b_idx));
                    p3b_time_vector = time(p3b_idx);
                    results.P3b_latency = p3b_time_vector(p3b_peak_idx);
                    results.P3b_amplitude = p3b_amp;
                else
                    results.P3b_latency = NaN;
                    results.P3b_amplitude = NaN;
                end
                
                fprintf('  ✓ ERP components: N2=%.0fms, P3b=%.0fms\n', ...
                    results.N2_latency*1000, results.P3b_latency*1000);
                
                %% Compute condition-specific ERPs if available
                if ~isempty(trials{first_valid}) && isfield(trials{first_valid}, 'event_info')
                    results.erp_by_condition = obj.compute_conditional_erps(...
                        trials(valid_trial_idx), filtered_trials);
                else
                    results.erp_by_condition = struct();
                end
                
            catch ME
                warning('ERPAnalyzer:AnalysisFailed', 'ERP analysis failed: %s', ME.message);
                results = obj.create_empty_results();
            end
        end
        
        function filtered = filter_erp(obj, trials_3d, srate)
            % FILTER_ERP - Apply bandpass filter for ERP (0.1-40 Hz)
            
            cfg = obj.config.erp;
            
            try
                % Design filter
                order = 4;
                [b, a] = butter(order, [cfg.filter_low, cfg.filter_high] / (srate/2), 'bandpass');
                
                % Filter each channel and trial
                [n_channels, ~, n_trials] = size(trials_3d);
                filtered = zeros(size(trials_3d));
                
                for ch = 1:n_channels
                    for tr = 1:n_trials
                        try
                            filtered(ch, :, tr) = filtfilt(b, a, trials_3d(ch, :, tr));
                        catch
                            filtered(ch, :, tr) = trials_3d(ch, :, tr);
                        end
                    end
                end
            catch
                warning('ERPAnalyzer:FilterFailed', 'ERP filtering failed, using unfiltered');
                filtered = trials_3d;
            end
        end
        
        function conditional_erps = compute_conditional_erps(~, trials, filtered_trials)
            % COMPUTE_CONDITIONAL_ERPS - Separate ERPs by task condition
            
            conditional_erps = struct();
            
            try
                % Extract SetSize if available
                has_setsize = isfield(trials{1}.event_info, 'SetSize');
                if has_setsize
                    setsizes = cellfun(@(x) x.event_info.SetSize, trials);
                    unique_sizes = unique(setsizes);
                    
                    for s = 1:length(unique_sizes)
                        size_val = unique_sizes(s);
                        size_trials = setsizes == size_val;
                        
                        if sum(size_trials) > 0
                            conditional_erps.(sprintf('setsize_%d', size_val)) = ...
                                mean(filtered_trials(:, :, size_trials), 3, 'omitnan');
                        end
                    end
                end
                
                % Correct vs Error
                has_correct = isfield(trials{1}.event_info, 'Correct');
                if has_correct
                    correct = cellfun(@(x) x.event_info.Correct, trials);
                    
                    if sum(correct == 1) > 0
                        conditional_erps.correct = mean(filtered_trials(:, :, correct == 1), 3, 'omitnan');
                    end
                    if sum(correct == 0) > 0
                        conditional_erps.error = mean(filtered_trials(:, :, correct == 0), 3, 'omitnan');
                    end
                end
            catch ME
                warning('ERPAnalyzer:ConditionalFailed', 'Conditional ERP failed: %s', ME.message);
            end
        end
        
        function results = create_empty_results(~)
            % CREATE_EMPTY_RESULTS - Default structure on failure
            
            results = struct();
            results.erp = [];
            results.erp_std = [];
            results.time = [];
            results.n_trials = 0;
            results.N2_latency = NaN;
            results.P3b_latency = NaN;
            results.erp_by_condition = struct();
            results.status = 'failed';
        end
    end
end