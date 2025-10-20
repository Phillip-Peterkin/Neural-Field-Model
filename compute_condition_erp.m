%% EVENT-RELATED POTENTIAL (ERP) AND ERSP ANALYSIS FUNCTIONS
% N2, P3b component detection and event-related spectral perturbations

function erp_data = compute_condition_erp(data, condition, cfg_erp)
% COMPUTE_CONDITION_ERP - Compute ERPs for specific task condition
%
% Conditions: 'encoding', 'maintenance', 'retrieval'

fprintf('Computing ERPs for %s condition...\n', condition);

% Filter events for condition
if isfield(data, 'events')
    events = data.events;
    condition_idx = strcmp(events.trial_type, condition);
    
    if sum(condition_idx) == 0
        warning('No trials found for condition: %s', condition);
        erp_data = [];
        return;
    end
    
    fprintf('  Found %d %s trials\n', sum(condition_idx), condition);
else
    % Use all trials if no event information
    warning('No event information, using all trials');
end

% Apply ERP-specific filtering (lower cutoff than preprocessing)
cfg = [];
cfg.lpfilter = 'yes';
cfg.lpfreq = cfg_erp.filter.lp;
cfg.lpfiltord = 4;
cfg.hpfilter = 'yes';
cfg.hpfreq = cfg_erp.filter.hp;
cfg.hpfiltord = 2;

data_filtered = ft_preprocessing(cfg, data);

% Baseline correction
cfg = [];
cfg.demean = 'yes';
cfg.baselinewindow = cfg_erp.baseline;
data_bl = ft_preprocessing(cfg, data_filtered);

% Compute average ERP
cfg = [];
cfg.keeptrials = 'no';
erp_avg = ft_timelockanalysis(cfg, data_bl);

% Also keep trial-level data for variability estimates
cfg.keeptrials = 'yes';
erp_trials = ft_timelockanalysis(cfg, data_bl);

% Package results
erp_data = struct();
erp_data.time = erp_avg.time;
erp_data.avg = erp_avg.avg; % [channels x time]
erp_data.label = erp_avg.label;
erp_data.condition = condition;

% Compute standard error
erp_data.sem = squeeze(std(erp_trials.trial, 0, 1)) / sqrt(size(erp_trials.trial, 1));

% Confidence intervals
erp_data.ci_lower = erp_data.avg - 1.96 * erp_data.sem;
erp_data.ci_upper = erp_data.avg + 1.96 * erp_data.sem;

% Store trial-level data
erp_data.trials = erp_trials.trial;

fprintf('ERP computed: %d channels, %.1f ms to %.1f ms\n', ...
    length(erp_data.label), erp_data.time(1)*1000, erp_data.time(end)*1000);

end

%% N2 COMPONENT DETECTION
function n2_results = extract_n2_latency(erp_data, cfg_erp)
% EXTRACT_N2_LATENCY - Detect N2 component (negative deflection 200-350ms)
%
% N2 is associated with conflict monitoring and stimulus evaluation
% Typically maximal at frontocentral electrodes

fprintf('Detecting N2 component...\n');

% Select relevant channels
n2_channels = select_channels_by_pattern(erp_data.label, cfg_erp.n2.channels);

if isempty(n2_channels)
    warning('No N2 channels found, using all channels');
    n2_channels = 1:length(erp_data.label);
end

% Define search window
time_vec = erp_data.time;
window_idx = time_vec >= cfg_erp.n2.window(1) & time_vec <= cfg_erp.n2.window(2);

% Average across N2 channels
n2_trace = mean(erp_data.avg(n2_channels, window_idx), 1);
n2_time = time_vec(window_idx);

% Find most negative peak
[n2_amplitude, peak_idx] = min(n2_trace);
n2_latency = n2_time(peak_idx);

% Find onset (50% of peak amplitude)
onset_threshold = n2_amplitude * 0.5;
onset_idx = find(n2_trace(1:peak_idx) > onset_threshold, 1, 'last');
if ~isempty(onset_idx)
    n2_onset = n2_time(onset_idx);
else
    n2_onset = n2_time(1);
end

% Find offset (return to 50% amplitude)
offset_idx = peak_idx + find(n2_trace(peak_idx:end) > onset_threshold, 1, 'first');
if ~isempty(offset_idx)
    n2_offset = n2_time(offset_idx);
else
    n2_offset = n2_time(end);
end

% Package results
n2_results = struct();
n2_results.latency = n2_latency * 1000; % Convert to ms
n2_results.amplitude = n2_amplitude;
n2_results.onset = n2_onset * 1000;
n2_results.offset = n2_offset * 1000;
n2_results.duration = (n2_offset - n2_onset) * 1000;
n2_results.channels = erp_data.label(n2_channels);
n2_results.trace = n2_trace;
n2_results.time = n2_time * 1000;

fprintf('N2 detected: %.1f ms latency, %.2f μV amplitude\n', ...
    n2_results.latency, n2_results.amplitude);

end

%% P3B COMPONENT DETECTION
function p3b_results = extract_p3b_latency(erp_data, cfg_erp)
% EXTRACT_P3B_LATENCY - Detect P3b component (positive deflection 300-600ms)
%
% P3b is associated with context updating and conscious access
% Typically maximal at centroparietal electrodes

fprintf('Detecting P3b component...\n');

% Select relevant channels
p3b_channels = select_channels_by_pattern(erp_data.label, cfg_erp.p3b.channels);

if isempty(p3b_channels)
    warning('No P3b channels found, using all channels');
    p3b_channels = 1:length(erp_data.label);
end

% Define search window
time_vec = erp_data.time;
window_idx = time_vec >= cfg_erp.p3b.window(1) & time_vec <= cfg_erp.p3b.window(2);

% Average across P3b channels
p3b_trace = mean(erp_data.avg(p3b_channels, window_idx), 1);
p3b_time = time_vec(window_idx);

% Find most positive peak
[p3b_amplitude, peak_idx] = max(p3b_trace);
p3b_latency = p3b_time(peak_idx);

% Find onset (50% of peak amplitude)
onset_threshold = p3b_amplitude * 0.5;
onset_idx = find(p3b_trace(1:peak_idx) < onset_threshold, 1, 'last');
if ~isempty(onset_idx)
    p3b_onset = p3b_time(onset_idx);
else
    p3b_onset = p3b_time(1);
end

% Find offset
offset_idx = peak_idx + find(p3b_trace(peak_idx:end) < onset_threshold, 1, 'first');
if ~isempty(offset_idx)
    p3b_offset = p3b_time(offset_idx);
else
    p3b_offset = p3b_time(end);
end

% Package results
p3b_results = struct();
p3b_results.latency = p3b_latency * 1000; % ms
p3b_results.amplitude = p3b_amplitude;
p3b_results.onset = p3b_onset * 1000;
p3b_results.offset = p3b_offset * 1000;
p3b_results.duration = (p3b_offset - p3b_onset) * 1000;
p3b_results.channels = erp_data.label(p3b_channels);
p3b_results.trace = p3b_trace;
p3b_results.time = p3b_time * 1000;

fprintf('P3b detected: %.1f ms latency, %.2f μV amplitude\n', ...
    p3b_results.latency, p3b_results.amplitude);

end

%% EVENT-RELATED SPECTRAL PERTURBATION (ERSP)
function ersp_results = compute_ersp(data, cfg_erp)
% COMPUTE_ERSP - Compute event-related spectral perturbations
%
% Time-frequency decomposition with baseline correction

fprintf('Computing event-related spectral perturbations...\n');

% Time-frequency analysis
cfg = [];
cfg.method = 'mtmconvol';
cfg.foi = cfg_erp.ersp.foi;
cfg.t_ftimwin = 7 ./ cfg.foi; % 7 cycles
cfg.taper = 'hanning';
cfg.toi = data.time{1};
cfg.keeptrials = 'yes';
cfg.output = 'pow';
cfg.pad = 'nextpow2';

tfr = ft_freqanalysis(cfg, data);

% Baseline correction
cfg = [];
cfg.baseline = cfg_erp.ersp.baseline;
cfg.baselinetype = cfg_erp.ersp.baseline_type; % 'db' for decibel

tfr_bl = ft_freqbaseline(cfg, tfr);

% Package results
ersp_results = struct();
ersp_results.time = tfr_bl.time;
ersp_results.freq = tfr_bl.freq;
ersp_results.powspctrm = tfr_bl.powspctrm; % [trials x channels x freq x time]
ersp_results.label = tfr_bl.label;

% Average across trials
ersp_results.powspctrm_avg = squeeze(mean(tfr_bl.powspctrm, 1));

% Compute ERSP significance using bootstrap
ersp_results.significance = compute_ersp_significance(tfr_bl, cfg_erp);

fprintf('ERSP computed: %d freqs × %d time points\n', ...
    length(ersp_results.freq), length(ersp_results.time));

end

function sig_mask = compute_ersp_significance(tfr_data, cfg_erp)
% Statistical testing for ERSP using bootstrap

fprintf('  Testing ERSP significance...\n');

num_channels = length(tfr_data.label);
num_freqs = length(tfr_data.freq);
num_times = length(tfr_data.time);
num_trials = size(tfr_data.powspctrm, 1);

% Bootstrap baseline distribution
baseline_idx = tfr_data.time >= cfg_erp.ersp.baseline(1) & ...
               tfr_data.time <= cfg_erp.ersp.baseline(2);

sig_mask = false(num_channels, num_freqs, num_times);

for ch = 1:num_channels
    for freq = 1:num_freqs
        % Get baseline distribution across trials
        baseline_power = squeeze(tfr_data.powspctrm(:, ch, freq, baseline_idx));
        baseline_mean = mean(baseline_power(:));
        baseline_std = std(baseline_power(:));
        
        % Test each time point
        for t = 1:num_times
            trial_power = squeeze(tfr_data.powspctrm(:, ch, freq, t));
            
            % T-test against baseline
            [~, p] = ttest(trial_power, baseline_mean);
            
            if p < 0.05 % Uncorrected for visualization
                sig_mask(ch, freq, t) = true;
            end
        end
    end
end

fprintf('  Significance testing complete\n');

end

%% INTER-TRIAL COHERENCE
function itc_results = compute_inter_trial_coherence(data, cfg_erp)
% COMPUTE_INTER_TRIAL_COHERENCE - Phase consistency across trials
%
% High ITC indicates phase-locked activity (evoked response)
% Low ITC indicates non-phase-locked activity (induced response)

fprintf('Computing inter-trial coherence...\n');

% Time-frequency analysis with Fourier output
cfg = [];
cfg.method = 'mtmconvol';
cfg.foi = cfg_erp.ersp.foi;
cfg.t_ftimwin = 7 ./ cfg.foi;
cfg.taper = 'hanning';
cfg.toi = data.time{1};
cfg.keeptrials = 'yes';
cfg.output = 'fourier';
cfg.pad = 'nextpow2';

tfr = ft_freqanalysis(cfg, data);

% Compute ITC: |<exp(i*phase)>|
fourier = tfr.fourierspctrm; % [trials x channels x freq x time]

% Normalize to unit magnitude
fourier_normalized = fourier ./ abs(fourier);

% Average across trials
itc = abs(mean(fourier_normalized, 1));

% Package results
itc_results = struct();
itc_results.time = tfr.time;
itc_results.freq = tfr.freq;
itc_results.itc = squeeze(itc); % [channels x freq x time]
itc_results.label = tfr.label;

fprintf('ITC computed\n');

end

%% SINGLE-TRIAL ANALYSIS
function single_trial = analyze_single_trial_variability(data, cfg_erp)
% ANALYZE_SINGLE_TRIAL_VARIABILITY - Characterize trial-to-trial variability
%
% Analyzes variability in amplitude, latency, and phase

fprintf('Analyzing single-trial variability...\n');

num_trials = length(data.trial);
num_channels = length(data.label);

single_trial = struct();

% Focus on P3b time window
time_vec = data.time{1};
p3b_window = time_vec >= cfg_erp.p3b.window(1) & time_vec <= cfg_erp.p3b.window(2);

% Initialize arrays
peak_amplitudes = zeros(num_trials, num_channels);
peak_latencies = zeros(num_trials, num_channels);

for trial = 1:num_trials
    for ch = 1:num_channels
        trial_data = data.trial{trial}(ch, p3b_window);
        trial_time = time_vec(p3b_window);
        
        % Find peak
        [amp, idx] = max(trial_data);
        peak_amplitudes(trial, ch) = amp;
        peak_latencies(trial, ch) = trial_time(idx);
    end
end

% Compute variability metrics
single_trial.amplitude_mean = mean(peak_amplitudes, 1);
single_trial.amplitude_std = std(peak_amplitudes, 0, 1);
single_trial.amplitude_cv = single_trial.amplitude_std ./ (single_trial.amplitude_mean + eps);

single_trial.latency_mean = mean(peak_latencies, 1);
single_trial.latency_std = std(peak_latencies, 0, 1);

single_trial.label = data.label;

fprintf('Single-trial analysis complete\n');

end

%% DIFFERENCE WAVES
function difference_wave = compute_difference_wave(erp1, erp2, condition1, condition2)
% COMPUTE_DIFFERENCE_WAVE - Compute difference between two conditions
%
% Used to isolate specific cognitive processes

fprintf('Computing difference wave: %s - %s\n', condition1, condition2);

difference_wave = struct();
difference_wave.time = erp1.time;
difference_wave.label = erp1.label;
difference_wave.diff = erp1.avg - erp2.avg;

% Propagate error (assuming independence)
difference_wave.sem = sqrt(erp1.sem.^2 + erp2.sem.^2);
difference_wave.ci_lower = difference_wave.diff - 1.96 * difference_wave.sem;
difference_wave.ci_upper = difference_wave.diff + 1.96 * difference_wave.sem;

difference_wave.condition1 = condition1;
difference_wave.condition2 = condition2;

% Statistical testing: permutation test
difference_wave.stats = permutation_test_difference(erp1.trials, erp2.trials);

fprintf('Difference wave computed\n');

end

function stats = permutation_test_difference(trials1, trials2)
% Permutation test for difference between conditions

num_permutations = 1000;
num_channels = size(trials1, 2);
num_timepoints = size(trials1, 3);

% Observed difference
observed_diff = squeeze(mean(trials1, 1) - mean(trials2, 1));

% Permutation distribution
null_distribution = zeros(num_channels, num_timepoints, num_permutations);

combined_trials = cat(1, trials1, trials2);
n1 = size(trials1, 1);
n_total = size(combined_trials, 1);

for perm = 1:num_permutations
    % Randomly assign trials to conditions
    perm_idx = randperm(n_total);
    perm_trials1 = combined_trials(perm_idx(1:n1), :, :);
    perm_trials2 = combined_trials(perm_idx(n1+1:end), :, :);
    
    null_distribution(:, :, perm) = squeeze(mean(perm_trials1, 1) - mean(perm_trials2, 1));
end

% Compute p-values
stats.p_values = zeros(num_channels, num_timepoints);

for ch = 1:num_channels
    for t = 1:num_timepoints
        null_vals = squeeze(null_distribution(ch, t, :));
        stats.p_values(ch, t) = 2 * min(mean(null_vals >= observed_diff(ch, t)), ...
                                        mean(null_vals <= observed_diff(ch, t)));
    end
end

% FDR correction across time points
p_vec = stats.p_values(:);
[~, ~, ~, adj_p] = fdr_bh(p_vec, 0.05, 'pdep');
stats.p_values_fdr = reshape(adj_p, size(stats.p_values));

end

%% HELPER FUNCTIONS
function channel_idx = select_channels_by_pattern(all_labels, patterns)
% Select channels matching patterns

channel_idx = [];

for i = 1:length(all_labels)
    for p = 1:length(patterns)
        if ~isempty(regexpi(all_labels{i}, patterns{p}))
            channel_idx = [channel_idx, i];
            break;
        end
    end
end

channel_idx = unique(channel_idx);

end

%% MASS UNIVARIATE ANALYSIS
function cluster_stats = cluster_based_permutation_test(data1, data2, cfg_stats)
% CLUSTER_BASED_PERMUTATION_TEST - FieldTrip cluster-based permutation
%
% Controls family-wise error rate across space and time

fprintf('Running cluster-based permutation test...\n');

% Prepare data structures
timelock1 = struct();
timelock1.label = data1.label;
timelock1.time = data1.time;
timelock1.trial = data1.trials;
timelock1.dimord = 'rpt_chan_time';

timelock2 = struct();
timelock2.label = data2.label;
timelock2.time = data2.time;
timelock2.trial = data2.trials;
timelock2.dimord = 'rpt_chan_time';

% Configure cluster statistics
cfg = [];
cfg.method = 'montecarlo';
cfg.statistic = 'depsamplesT'; % Dependent samples t-test
cfg.correctm = 'cluster';
cfg.clusteralpha = cfg_stats.cluster.clusteralpha;
cfg.clusterstatistic = 'maxsum';
cfg.minnbchan = cfg_stats.cluster.minnbchan;
cfg.tail = cfg_stats.cluster.tail;
cfg.clustertail = cfg_stats.cluster.tail;
cfg.alpha = cfg_stats.alpha;
cfg.numrandomization = cfg_stats.permutation.num;

% Design matrix
n_subjects = size(timelock1.trial, 1);
cfg.design = [ones(1, n_subjects) 2*ones(1, n_subjects); 1:n_subjects 1:n_subjects];
cfg.uvar = 2; % Unit variable (subjects)
cfg.ivar = 1; % Independent variable (condition)

% Run cluster test
cluster_stats = ft_timelockstatistics(cfg, timelock1, timelock2);

fprintf('Cluster-based permutation test complete\n');
fprintf('Found %d significant clusters\n', length(find([cluster_stats.posclusters.prob] < cfg_stats.alpha)));

end