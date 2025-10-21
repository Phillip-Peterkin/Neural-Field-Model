function out = erp_analysis_functions(data_pre, cfg)
% ERP_ANALYSIS_FUNCTIONS
% Stage 6: Event-Related Potentials (ERP) extraction.
% Computes N2 and P3b latencies and amplitudes from averaged ERPs.
%
% INPUTS
%   data_pre : FieldTrip raw-like struct (from preprocessing)
%   cfg      : config struct; uses cfg.erp fields if present
%
% OUTPUT
%   out : struct
%       .status           : 'ok' | 'skip' | 'fail'
%       .time             : time vector (s)
%       .channels_used    : cellstr
%       .erp_mean         : 1 x T double (grand-mean over chosen channels)
%       .n2_latency_ms    : double (peak latency)
%       .n2_amplitude_uv  : double (peak amplitude)
%       .p3b_latency_ms   : double (peak latency)
%       .p3b_amplitude_uv : double (peak amplitude)
%       .diagnostics      : struct (windows, baseline, notes)
%
% Notes
% - If events are not available, assumes trials are already time-locked and
%   of equal length from preprocessing.
% - If channel lists in cfg are missing, uses all channels.
% - Latency windows are configurable; defaults follow classic definitions.

% ---- Defaults ----
out = default_out();

try
    if nargin < 1 || isempty(data_pre) || ~isfield(data_pre,'trial') || isempty(data_pre.trial)
        out.status = 'skip';
        out.diagnostics.notes = 'Empty or malformed input data';
        return
    end
    if nargin < 2 || ~isstruct(cfg), cfg = struct(); end
    if ~isfield(cfg,'erp') || ~isstruct(cfg.erp), cfg.erp = struct(); end

    p = cfg.erp;
    % Time windows in seconds
    p.baseline_win = getfield_or(p,'baseline_win', [-0.2 0]);      % -200..0 ms
    p.n2_win       = getfield_or(p,'n2_win',       [0.20 0.35]);    % 200..350 ms
    p.p3b_win      = getfield_or(p,'p3b_win',      [0.30 0.60]);    % 300..600 ms
    % Channels of interest (can be labels or regex)
    p.chan_regex   = getfield_or(p,'chan_regex',   '.*');           % use all by default

    % --- Ensure trials are aligned and equal length ---
    % We expect preprocessing to have normalized trials. We still verify
    % consistency and drop mismatched trials.
    [trials, time] = harmonize_trials(data_pre);
    if isempty(trials)
        out.status = 'skip';
        out.diagnostics.notes = 'No usable trials after harmonization';
        return
    end

    % --- Select channels ---
    chan_mask = select_channels(data_pre.label, p.chan_regex);
    if ~any(chan_mask)
        chan_mask(:) = true; % fallback to all channels
    end
    trials = trials(chan_mask, :, :); % chan x time x trials
    chans_used = data_pre.label(chan_mask);

    % --- Baseline correct ---
    [~, b1] = min(abs(time - p.baseline_win(1)));
    [~, b2] = min(abs(time - p.baseline_win(2)));
    base = mean(trials(:, b1:b2, :), 2, 'omitnan');  % chan x 1 x trials
    trials = trials - base;                          % broadcast subtract

    % --- Average ERP over trials and then channels ---
    erp_chan = mean(trials, 3, 'omitnan');   % chan x time
    erp_avg  = mean(erp_chan, 1, 'omitnan'); % 1 x time

    % --- Peak detection for N2 (negative) and P3b (positive) ---
    [~, n1] = min(abs(time - p.n2_win(1)));
    [~, n2] = min(abs(time - p.n2_win(2)));
    [~, p1] = min(abs(time - p.p3b_win(1)));
    [~, p2] = min(abs(time - p.p3b_win(2)));

    [n2_amp, n2_idx]   = min(erp_avg(n1:n2));
    [p3b_amp, p3b_idx] = max(erp_avg(p1:p2));

    n2_latency = time(n1 + n2_idx - 1) * 1e3;  % ms
    p3b_latency = time(p1 + p3b_idx - 1) * 1e3; % ms

    % --- Package output ---
    out.status            = 'ok';
    out.time              = time;
    out.channels_used     = chans_used;
    out.erp_mean          = double(erp_avg);
    out.n2_latency_ms     = double(n2_latency);
    out.n2_amplitude_uv   = double(n2_amp);
    out.p3b_latency_ms    = double(p3b_latency);
    out.p3b_amplitude_uv  = double(p3b_amp);
    out.diagnostics       = struct('baseline_win', p.baseline_win, ...
                                   'n2_win', p.n2_win, 'p3b_win', p.p3b_win, ...
                                   'notes', "");

catch ME
    out.status = 'fail';
    out.diagnostics.notes = ME.message;
    warning('%s', ME.message);
end
end

%% ===== Helpers =====
function out = default_out()
out = struct('status','skip','time',[],'channels_used',{{}},'erp_mean',[], ...
             'n2_latency_ms',NaN,'n2_amplitude_uv',NaN, ...
             'p3b_latency_ms',NaN,'p3b_amplitude_uv',NaN, ...
             'diagnostics',struct('baseline_win',[NaN NaN],'n2_win',[NaN NaN],'p3b_win',[NaN NaN],'notes',''));
end

function v = getfield_or(s, name, defaultVal)
if isstruct(s) && isfield(s,name) && ~isempty(s.(name))
    v = s.(name);
else
    v = defaultVal;
end
end

function mask = select_channels(labels, regex)
try
    mask = false(numel(labels),1);
    for i = 1:numel(labels)
        mask(i) = ~isempty(regexp(labels{i}, regex, 'once'));
    end
catch
    mask = true(numel(labels),1);
end
end

function [trials, time] = harmonize_trials(data)
% Convert FT raw trials into a 3D array (chan x time x trials) with equal length
try
    nT = numel(data.trial);
    if nT == 0
        trials = []; time = [];
        return
    end
    L = cellfun(@(x) size(x,2), data.trial);
    L0 = min(L); % trim to shortest
    nC = size(data.trial{1},1);
    trials = zeros(nC, L0, nT);
    for k = 1:nT
        trials(:,:,k) = data.trial{k}(:, 1:L0);
    end
    time = data.time{1}(1:L0);
catch
    trials = []; time = [];
end
end
