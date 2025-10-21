function out = connectivity_analysis_functions(data_pre, cfg)
% CONNECTIVITY_ANALYSIS_FUNCTIONS
% Stage 4: Connectivity metrics using FieldTrip.
% Computes PLV, wPLI, and Coherence per band, plus full-frequency curves.
%
% INPUTS
%   data_pre : FieldTrip raw-like struct (from preprocessing)
%   cfg      : config struct with optional cfg.connectivity fields
%
% OUTPUT
%   out : struct
%       .status        : 'ok' | 'skip' | 'fail'
%       .fs            : Hz
%       .freq          : frequency vector (Hz)
%       .plv, .wpli, .coh : channel x channel x freq matrices (double)
%       .bands         : struct with mean PLV/wPLI/Coherence per band
%       .diagnostics   : struct
%
% Notes
% - Uses ft_freqanalysis (mtmfft, fourier) then ft_connectivityanalysis.
% - Robust to empty inputs and returns safe defaults when needed.

% ---- Defaults ----
out = default_out();

try
    % Basic checks
    if nargin < 1 || isempty(data_pre) || ~isfield(data_pre,'trial') || isempty(data_pre.trial)
        out.status = 'skip';
        out.diagnostics.notes = 'Empty or malformed input data';
        return
    end
    if nargin < 2 || ~isstruct(cfg), cfg = struct(); end
    if ~isfield(cfg,'connectivity') || ~isstruct(cfg.connectivity)
        cfg.connectivity = struct();
    end

    % Parameters
    p = cfg.connectivity;
    p.foi        = getfield_or(p,'foi',       1:1:150);
    p.taper      = getfield_or(p,'taper',     'dpss');  % more stable phase metrics
    p.tapsmofrq  = getfield_or(p,'tapsmofrq', 2);       % DPSS smoothing (Hz)
    p.theta_band = getfield_or(p,'theta',     [4 7]);
    p.alpha_band = getfield_or(p,'alpha',     [8 12]);
    p.beta_band  = getfield_or(p,'beta',      [13 30]);
    p.gamma_band = getfield_or(p,'gamma',     [30 80]);

    % Sampling rate
    fs = infer_fs(data_pre);
    assert(isfinite(fs) && fs > 0, 'Invalid sampling rate');
    out.fs = fs;

    % ---- Spectral transform (complex Fourier) ----
    cfa = [];
    cfa.method     = 'mtmfft';
    cfa.output     = 'fourier';
    cfa.taper      = p.taper;
    cfa.tapsmofrq  = p.tapsmofrq;
    cfa.foi        = p.foi;

    freq = ft_freqanalysis(cfa, data_pre);  % freq.fourierspctrm: trials x chan x freq (or chan x freq)

    % Make sure dims are trials x chan x freq
    F = freq.fourierspctrm;
    if ndims(F) == 2
        % assume chan x freq, add a singleton trial dim
        F = reshape(F, [1, size(F,1), size(F,2)]);
    end
    freq.fourierspctrm = F;

    % ---- Connectivity metrics ----
    % PLV
    cc = [];
    cc.method = 'plv';
    Cplv = ft_connectivityanalysis(cc, freq); % Cplv.plvspctrm: chan x chan x freq

    % wPLI
    cc = [];
    cc.method = 'wpli_debiased';
    Cwpli = ft_connectivityanalysis(cc, freq);

    % Coherence (magnitude-squared)
    cc = [];
    cc.method = 'coh';
    Ccoh = ft_connectivityanalysis(cc, freq);

    f = double(Cplv.freq(:));
    out.freq = f;
    out.plv  = double(Cplv.plvspctrm);
    out.wpli = double(Cwpli.wplispctrm);
    out.coh  = double(Ccoh.cohspctrm);

    % ---- Band summaries ----
    bands = struct();
    bands.theta = summarize_band(out, f, p.theta_band);
    bands.alpha = summarize_band(out, f, p.alpha_band);
    bands.beta  = summarize_band(out, f, p.beta_band);
    bands.gamma = summarize_band(out, f, p.gamma_band);

    out.bands = bands;
    out.status = 'ok';
    out.diagnostics = struct('taper', p.taper, 'tapsmofrq', p.tapsmofrq, 'notes', "");

catch ME
    out.status = 'fail';
    out.diagnostics.notes = ME.message;
    warning('%s', ME.message);
end
end

%% ===== Helpers =====
function out = default_out()
out = struct('status','skip','fs',NaN,'freq',[], ...
             'plv',[], 'wpli',[], 'coh',[], ...
             'bands',struct(), ...
             'diagnostics',struct('taper','', 'tapsmofrq',NaN, 'notes',''));
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

function S = summarize_band(out, f, band)
% Mean connectivity over channel pairs and band frequencies
lo = band(1); hi = band(2);
idx = f >= lo & f <= hi;
S = struct();
try
    if any(idx)
        S.plv_mean  = mean(out.plv(:,:,idx),  [1 2 3], 'omitnan');
        S.wpli_mean = mean(out.wpli(:,:,idx), [1 2 3], 'omitnan');
        S.coh_mean  = mean(out.coh(:,:,idx),  [1 2 3], 'omitnan');
    else
        S.plv_mean = NaN; S.wpli_mean = NaN; S.coh_mean = NaN;
    end
catch
    S.plv_mean = NaN; S.wpli_mean = NaN; S.coh_mean = NaN;
end
end
