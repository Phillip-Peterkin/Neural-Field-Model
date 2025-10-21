function out = spectral_analysis_functions(data_pre, cfg)
% Stage 3 spectra and 1/f slope, memory‑safe and table‑robust.

arguments
    data_pre (1,1) struct
    cfg struct = struct()
end

out = default_out();

% Guard
if ~isstruct(data_pre) || ~isfield(data_pre,'trial') || isempty(data_pre.trial)
    out.status = "skip"; out.notes = "empty input"; return
end

% Params
fs   = data_pre.fsample;
foi  = getf(cfg,'spectral.foi', 1:1:150);
win  = getf(cfg,'spectral.win_sec', 1.0);   % shorter to reduce RAM
over = getf(cfg,'spectral.overlap', 0.0);
fitb = getf(cfg,'spectral.fit_band', [2 40]);
theta = getf(cfg,'spectral.theta',[4 7]);
alpha = getf(cfg,'spectral.alpha',[8 12]);
beta  = getf(cfg,'spectral.beta', [13 30]);
gamma = getf(cfg,'spectral.gamma',[30 80]);

% Chunk the data into windows to bound memory
try
    dcfg = struct('length', win, 'overlap', over);
    data_small = ft_redefinetrial(dcfg, data_pre);
catch ME
    warning('%s', ME.message);
    data_small = data_pre; % fallback
end

% Frequency analysis with average across trials inside FieldTrip
c = [];
c.method      = 'mtmfft';
c.taper       = 'hanning';
c.output      = 'pow';
c.foi         = foi;
c.keeptrials  = 'no';           % average inside to save memory
c.pad         = 'maxperlen';    % avoid huge zero‑padding
F = ft_freqanalysis(c, data_small);

% Ensure consistent shape: [chan x freq]
if ndims(F.powspctrm) == 3
    P = squeeze(hft_utils('nanmean', F.powspctrm, 1));
else
    P = F.powspctrm;
end
f = F.freq(:);

% Per‑channel table with auto growth
nch = numel(F.label);
per = table();
per = hft_utils('addorreplace', per, 'theta_power', nan(nch,1));
per = hft_utils('addorreplace', per, 'alpha_power', nan(nch,1));
per = hft_utils('addorreplace', per, 'beta_power',  nan(nch,1));
per = hft_utils('addorreplace', per, 'gamma_power', nan(nch,1));
per = hft_utils('addorreplace', per, 'slope',       nan(nch,1));  % always create 'slope'

% Fit slope and bands
fb = f>=fitb(1) & f<=fitb(2);
logf = log10(f(fb));
for ch = 1:nch
    psd = double(P(ch,:)).';
    per.theta_power(ch) = bandpow(f, psd, theta);
    per.alpha_power(ch) = bandpow(f, psd, alpha);
    per.beta_power(ch)  = bandpow(f, psd, beta);
    per.gamma_power(ch) = bandpow(f, psd, gamma);

    y = log10(psd(fb));
    m = isfinite(logf) & isfinite(y);
    if nnz(m) >= 10
        b = [logf(m) ones(nnz(m),1)] \ y(m);
        per.slope(ch) = b(1);
    end
end

out.status = "ok";
out.freq   = f;
out.pow    = P;
out.per_channel = per;
out.aperiodic.slope_mean = mean(per.slope, 'omitnan');

end

% ------- helpers -------
function p = bandpow(f, psd, band)
b = hft_utils('sanitizeband', band, max(f)*2, [4 7]); % fs not needed here; just clamp union
idx = f>=b(1) & f<=b(2);
if any(idx), p = trapz(f(idx), psd(idx)); else, p = NaN; end
end

function v = getf(cfg, dotted, d)
try
    parts = split(string(dotted),'.'); S = cfg;
    for i=1:numel(parts), f = strtrim(parts{i}); if isfield(S,f), S = S.(f); else, v=d; return; end, end
    if isempty(S), v=d; else, v=S; end
catch, v=d; end
end

function out = default_out()
out = struct('status',"skip",'notes',"",'freq',[],'pow',[],'per_channel',table(),'aperiodic',struct());
end
