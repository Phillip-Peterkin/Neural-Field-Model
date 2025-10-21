function out = spectral_analysis_functions(data_pre, cfg)
% SPECTRAL_ANALYSIS_FUNCTIONS
% Stage 3: Power spectrum + 1/f (aperiodic) fit + band powers.
% Robust to empty inputs and safe for batch runs.
%
% INPUTS
%   data_pre : FieldTrip raw-like struct from preprocessing_functions
%   cfg      : global config struct; uses cfg.spectral fields if present
%
% OUTPUT
%   out : struct with fields
%       .status            : 'ok' | 'skip' | 'fail'
%       .fs                : sampling rate (Hz)
%       .freq              : frequency vector (Hz)
%       .psd               : average power spectral density (uV^2/Hz)
%       .aperiodic         : struct with slope, intercept (log-log fit)
%       .bands             : struct with band powers
%       .per_channel       : table with per-channel band powers and slope
%       .diagnostics       : struct (window_sec, method, notes)
%
% NOTE
%   Uses FieldTrip ft_freqanalysis (multitaper). Fits 1/f on log10 power.

% ---- Defaults (robust) ----
out = default_out();

try
    % Validate input
    if nargin < 1 || isempty(data_pre) || ~isfield(data_pre,'trial') || isempty(data_pre.trial)
        out.status = 'skip';
        out.diagnostics.notes = 'Empty or malformed input data';
        return
    end

    if nargin < 2 || ~isstruct(cfg)
        cfg = struct();
    end

    if ~isfield(cfg,'spectral') || ~isstruct(cfg.spectral)
        cfg.spectral = struct();
    end

    % Parameters with sane defaults
    p = cfg.spectral;
    p.foi         = getfield_or(p,'foi',        1:0.5:150);   % frequencies of interest (Hz)
    p.win_sec     = getfield_or(p,'win_sec',    2.0);          % Welch-like window
    p.taper       = getfield_or(p,'taper',      'hanning');    % dpss or hanning
    p.pad         = getfield_or(p,'pad',        'nextpow2');   % FFT padding strategy
    p.fit_band    = getfield_or(p,'fit_band',   [2 40]);       % 1/f fit range
    p.theta_band  = getfield_or(p,'theta',      [4 7]);
    p.alpha_band  = getfield_or(p,'alpha',      [8 12]);
    p.beta_band   = getfield_or(p,'beta',       [13 30]);
    p.gamma_band  = getfield_or(p,'gamma',      [30 80]);
    p.robust_fit  = getfield_or(p,'robust_fit', true);

    % Sampling rate
    if isfield(data_pre,'fsample')
        fs = double(data_pre.fsample);
    else
        fs = infer_fs(data_pre);
    end
    assert(isfinite(fs) && fs > 0, 'Invalid sampling rate');
    out.fs = fs;

    % ---- Frequency analysis via FieldTrip ----
    % Construct cfg for ft_freqanalysis
    cfa = [];
    cfa.method     = 'mtmfft';
    cfa.output     = 'pow';
    cfa.taper      = p.taper;
    cfa.foi        = p.foi;   % explicit vector of frequencies
    cfa.pad        = p.pad;   % 'nextpow2' or numeric seconds

    % Compute spectrum per channel
    freq = ft_freqanalysis(cfa, data_pre);  % freq.freq, freq.powspctrm (chan x freq)

    % Average across trials if present
    P = double(freq.powspctrm);    % channels x freqs
    f = double(freq.freq(:));
    if ~ismatrix(P)
        P = squeeze(mean(P, 1));   % in rare cases method returns trl x chan x freq
    end

    % Guard against empties
    if isempty(P) || isempty(f)
        out.status = 'skip';
        out.diagnostics.notes = 'Empty spectrum from ft_freqanalysis';
        return
    end

    % Average PSD over channels for group summaries (keep per-channel too)
    psd_avg = mean(P, 1, 'omitnan');

    % ---- Aperiodic (1/f) fit on log10 scale ----
    [fit_idx, fit_freqs] = pick_band_idx(f, p.fit_band);
    logF = log10(fit_freqs);
    logP = log10(psd_avg(fit_idx));

    if p.robust_fit
        coeff = robustfit(logF, logP); % logP = a + b*logF; coeff(1)=a, coeff(2)=b
        intercept = coeff(1);
        slope     = coeff(2);
    else
        X = [ones(numel(logF),1) logF(:)];
        B = X \ logP(:);
        intercept = B(1); slope = B(2);
    end

    % ---- Band powers (area under PSD in bands) ----
    bands = struct();
    bands.theta = bandpower_trapz(f, psd_avg, p.theta_band);
    bands.alpha = bandpower_trapz(f, psd_avg, p.alpha_band);
    bands.beta  = bandpower_trapz(f, psd_avg, p.beta_band);
    bands.gamma = bandpower_trapz(f, psd_avg, p.gamma_band);

    % Per-channel metrics table
    per_table = per_channel_metrics(f, P, p);

    % ---- Package output ----
    out.status      = 'ok';
    out.freq        = f;
    out.psd         = psd_avg(:)';
    out.aperiodic   = struct('slope', slope, 'intercept', intercept, 'fit_band', p.fit_band);
    out.bands       = bands;
    out.per_channel = per_table;
    out.diagnostics = struct('window_sec', p.win_sec, 'method', cfa.method, ...
                             'taper', p.taper, 'notes', "");
catch ME
    out.status = 'fail';
    out.diagnostics.notes = ME.message;
    warning('%s', ME.message);
end
end

%% ================= Helpers =================
function out = default_out()
out = struct('status','skip','fs',NaN,'freq',[],'psd',[], ...
             'aperiodic',struct('slope',NaN,'intercept',NaN,'fit_band',[NaN NaN]), ...
             'bands',struct('theta',NaN,'alpha',NaN,'beta',NaN,'gamma',NaN), ...
             'per_channel',table(), ...
             'diagnostics',struct('window_sec',NaN,'method','', 'taper','', 'notes',''));
end

function v = getfield_or(s, name, defaultVal)
if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
    v = s.(name);
else
    v = defaultVal;
end
end

function fs = infer_fs(data)
try
    if isfield(data,'time') && ~isempty(data.time) && iscell(data.time)
        t = data.time{1};
        dt = median(diff(t));
        fs = 1/dt;
    else
        fs = NaN;
    end
catch
    fs = NaN;
end
end

function [idx, ff] = pick_band_idx(f, band)
lo = band(1); hi = band(2);
idx = f >= lo & f <= hi;
ff  = f(idx);
end

function bp = bandpower_trapz(f, psd, band)
[idx, ff] = pick_band_idx(f, band);
if ~any(idx)
    bp = NaN;
else
    bp = trapz(ff, psd(idx));
end
end

function T = per_channel_metrics(f, P, p)
% P: channels x freqs
nch = size(P,1);
sl  = nan(nch,1);
th  = nan(nch,1); al = nan(nch,1); be = nan(nch,1); ga = nan(nch,1);

[fit_idx, fit_freqs] = pick_band_idx(f, p.fit_band);
logF = log10(fit_freqs);

for c = 1:nch
    ps = double(P(c,:));
    logP = log10(ps(fit_idx));
    if any(isfinite(logP)) && numel(logP) == numel(logF)
        % robust linear fit
        cff = robustfit(logF, logP);
        sl(c) = cff(2);
    end
    th(c) = bandpower_trapz(f, ps, p.theta_band);
    al(c) = bandpower_trapz(f, ps, p.alpha_band);
    be(c) = bandpower_trapz(f, ps, p.beta_band);
    ga(c) = bandpower_trapz(f, ps, p.gamma_band);
end

T = table(sl, th, al, be, ga, 'VariableNames', ...
          {'slope','theta_power','alpha_power','beta_power','gamma_power'});
end
