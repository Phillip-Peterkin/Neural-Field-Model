function out = pac_analysis_functions(data_pre, cfg)
% PAC_ANALYSIS_FUNCTIONS
% Stage 5: Phase–Amplitude Coupling (PAC) metrics.
% Computes Tort Modulation Index (MI) and Canolty MI over user bands.
%
% INPUTS
%   data_pre : FieldTrip raw-like struct from preprocessing
%   cfg      : global config; uses cfg.pac.* if present
%
% OUTPUT
%   out : struct
%       .status      : 'ok' | 'skip' | 'fail'
%       .fs          : sampling rate (Hz)
%       .grid        : table of (phase_band, amp_band)
%       .tort_mi     : channels x grid double
%       .canolty_mi  : channels x grid double
%       .diagnostics : struct with parameters
%
% Notes
% - Uses FieldTrip ft_preprocessing for bandpasses.
% - Robust to empty inputs; returns safe defaults.
% - Bands are inclusive [lo hi] (Hz). Grid may include multiple pairs.

% ---- Defaults ----
out = default_out();

try
    if nargin < 1 || isempty(data_pre) || ~isfield(data_pre,'trial') || isempty(data_pre.trial)
        out.status = 'skip';
        out.diagnostics.notes = 'Empty or malformed input data';
        return
    end
    if nargin < 2 || ~isstruct(cfg), cfg = struct(); end
    if ~isfield(cfg,'pac') || ~isstruct(cfg.pac), cfg.pac = struct(); end

    p = cfg.pac;
    p.phase_bands = getfield_or(p,'phase_bands', [4 7; 8 12]);   % theta, alpha
    p.amp_bands   = getfield_or(p,'amp_bands',   [30 55; 65 90]); % low/high gamma
    p.nbins       = getfield_or(p,'nbins',       18);             % Tort histogram bins
    p.min_duration_sec = getfield_or(p,'min_duration_sec', 20);   % require enough data

    fs = infer_fs(data_pre);
    assert(isfinite(fs) && fs > 0, 'Invalid sampling rate');
    out.fs = fs;

    % Check duration
    T = total_duration(data_pre);
    if T < p.min_duration_sec
        out.status = 'skip';
        out.diagnostics.notes = sprintf('Recording too short for PAC (%.1fs < %.1fs).', T, p.min_duration_sec);
        return
    end

    % Build grid of band pairs
    [grid, pairs] = make_band_grid(p.phase_bands, p.amp_bands);
    out.grid = grid;

    nchan = numel(data_pre.label);
    ngrid = size(grid,1);
    tort  = nan(nchan, ngrid);
    cano  = nan(nchan, ngrid);

    % Precompute concatenated data per channel for speed
    [X, tlen] = concatenate_trials(data_pre); %#ok<ASGLU>

    % Compute PAC per pair
    for g = 1:ngrid
        phb = pairs(g).phase_band;  % [lo hi]
        amb = pairs(g).amp_band;    % [lo hi]

        % Phase: bandpass low, take angle of Hilbert
        cfgp = [];
        cfgp.bpfilter = 'yes'; cfgp.bpfreq = phb; cfgp.bpfilttype = 'but';
        cfgp.hilbert  = 'angle';
        P = ft_preprocessing(cfgp, data_pre); % same structure, trials x chan time

        % Amplitude: bandpass high, take abs(Hilbert)
        cfga = [];
        cfga.bpfilter = 'yes'; cfga.bpfreq = amb; cfga.bpfilttype = 'but';
        cfga.hilbert  = 'abs';
        A = ft_preprocessing(cfga, data_pre);

        % Concatenate trials to vectors for each channel and compute metrics
        for c = 1:nchan
            ph = concat_channel(P, c);
            am = concat_channel(A, c);
            if numel(ph) ~= numel(am) || numel(ph) < p.nbins*10
                continue
            end
            tort(c,g) = tort_mi(ph, am, p.nbins);
            cano(c,g) = canolty_mi(ph, am);
        end
    end

    out.tort_mi    = tort;
    out.canolty_mi = cano;
    out.status     = 'ok';
    out.diagnostics = struct('nbins', p.nbins, 'min_duration_sec', p.min_duration_sec, 'notes', "");

catch ME
    out.status = 'fail';
    out.diagnostics.notes = ME.message;
    warning('%s', ME.message);
end
end

%% ===== Helpers =====
function out = default_out()
out = struct('status','skip','fs',NaN,'grid',table(), ...
             'tort_mi',[],'canolty_mi',[], ...
             'diagnostics',struct('nbins',NaN,'min_duration_sec',NaN,'notes',''));
end

function v = getfield_or(s, name, defaultVal)
if isstruct(s) && isfield(s,name) && ~isempty(s.(name))
    v = s.(name);
else
    v = defaultVal;
end
end

function fs = infer_fs(data)
try
    if isfield(data,'fsample') && ~isempty(data.fsample)
        fs = double(data.fsample);
        return
    end
    if isfield(data,'time') && ~isempty(data.time) && iscell(data.time)
        dt = median(diff(data.time{1}));
        fs = 1/dt;
    else
        fs = NaN;
    end
catch
    fs = NaN;
end
end

function T = total_duration(data)
T = 0;
try
    if isfield(data,'time') && iscell(data.time)
        for k = 1:numel(data.time)
            tk = data.time{k};
            if ~isempty(tk)
                T = T + (tk(end) - tk(1));
            end
        end
    end
catch
    T = 0;
end
end

function [grid, pairs] = make_band_grid(phase_bands, amp_bands)
% Build all pairings of rows
np = size(phase_bands,1); na = size(amp_bands,1);
rows = np*na;
phase_low  = nan(rows,1); phase_high = nan(rows,1);
amp_low    = nan(rows,1); amp_high   = nan(rows,1);
pairs(rows) = struct('phase_band',[NaN NaN],'amp_band',[NaN NaN]);
idx = 0;
for i = 1:np
    for j = 1:na
        idx = idx + 1;
        phase_low(idx)  = phase_bands(i,1);
        phase_high(idx) = phase_bands(i,2);
        amp_low(idx)    = amp_bands(j,1);
        amp_high(idx)   = amp_bands(j,2);
        pairs(idx).phase_band = phase_bands(i,:);
        pairs(idx).amp_band   = amp_bands(j,:);
    end
end
phase_band = strcat(string(phase_low),"-",string(phase_high));
amp_band   = strcat(string(amp_low),"-",string(amp_high));
grid = table(phase_band, amp_band);
end

function [X, N] = concatenate_trials(data)
% Returns channels x time matrix
N = 0; X = [];
try
    nchan = numel(data.label);
    % total length
    T = 0;
    for k = 1:numel(data.time)
        T = T + numel(data.time{k});
    end
    X = zeros(nchan, T);
    pos = 1;
    for k = 1:numel(data.trial)
        seg = data.trial{k};
        L = size(seg,2);
        X(:, pos:pos+L-1) = seg;
        pos = pos + L;
    end
    N = T;
catch
    X = [];
    N = 0;
end
end

function v = concat_channel(D, c)
% D is FT raw-like with .trial cell array
try
    total = 0;
    for k = 1:numel(D.trial)
        total = total + size(D.trial{k},2);
    end
    v = zeros(1,total);
    pos = 1;
    for k = 1:numel(D.trial)
        seg = D.trial{k}(c,:);
        L = numel(seg);
        v(pos:pos+L-1) = seg;
        pos = pos + L;
    end
catch
    v = [];
end
end

function mi = tort_mi(phase, amp, nbins)
% Tort et al. 2010 MI.
% phase: radians in [-pi, pi] ideally; amp: >=0
% Steps: histogram amplitude by phase bins, normalize, KL-divergence to uniform.
if isempty(phase) || isempty(amp) || numel(phase)~=numel(amp)
    mi = NaN; return
end
% ensure column
phase = phase(:)'; amp = amp(:)';
% wrap phase to [-pi, pi]
phase = angle(exp(1j*phase));
% bins
edges = linspace(-pi, pi, nbins+1);
P = zeros(1, nbins);
for b = 1:nbins
    idx = phase >= edges(b) & phase < edges(b+1);
    if any(idx)
        P(b) = mean(amp(idx));
    else
        P(b) = 0;
    end
end
if sum(P) == 0
    mi = NaN; return
end
P = P / sum(P); % normalize
U = ones(1, nbins) / nbins; % uniform
% KL divergence to uniform, normalized
kl = sum(P .* log((P + eps) ./ U));
mi = kl / log(nbins);
end

function mi = canolty_mi(phase, amp)
% Canolty et al. 2006 MI: |mean(amp * exp(i*phase))|
if isempty(phase) || isempty(amp) || numel(phase)~=numel(amp)
    mi = NaN; return
end
phase = phase(:)'; amp = amp(:)';
mi = abs(mean(amp .* exp(1j*phase)));
end
