function out = spectral_analysis_functions(data_pre, cfg)
% SPECTRAL_ANALYSIS_FUNCTIONS  PSD, 1/f slope, band powers.
arguments
    data_pre (1,1) struct
    cfg struct = struct()
end

out = struct('status',"skip",'notes',"",'freq',[],'pow',[],'per_channel',table(),'aperiodic',struct());

if ~isstruct(data_pre) || ~isfield(data_pre,'trial') || isempty(data_pre.trial)
    out.notes = "empty input"; return
end

fs   = data_pre.fsample;
foi  = getf(cfg,'spectral.foi', 1:1:150);
fitb = hft_utils('sanitizeband', getf(cfg,'spectral.fit_band',[2 40]), fs, [2 40]);

% Keep memory small: average trials inside FieldTrip
fcfg = [];
fcfg.method     = 'mtmfft';
fcfg.taper      = 'hanning';
fcfg.output     = 'pow';
fcfg.foi        = foi;
fcfg.keeptrials = 'no';
fcfg.pad        = 'maxperlen';
F = ft_freqanalysis(fcfg, data_pre);

P = F.powspctrm;     % [chan x freq]
f = F.freq(:);       % [freq x 1]
nch = size(P,1);

% Bands
theta = hft_utils('sanitizeband', getf(cfg,'spectral.theta',[4 7]), fs, [4 7]);
alpha = hft_utils('sanitizeband', getf(cfg,'spectral.alpha',[8 12]), fs, [8 12]);
beta  = hft_utils('sanitizeband', getf(cfg,'spectral.beta', [13 30]), fs, [13 30]);
gamma = hft_utils('sanitizeband', getf(cfg,'spectral.gamma',[30 80]), fs, [30 80]);

per = table();
per = hft_utils('addorreplace', per,'theta_power', nan(nch,1));
per = hft_utils('addorreplace', per,'alpha_power', nan(nch,1));
per = hft_utils('addorreplace', per,'beta_power',  nan(nch,1));
per = hft_utils('addorreplace', per,'gamma_power', nan(nch,1));
per = hft_utils('addorreplace', per,'slope',       nan(nch,1));

fb = f>=fitb(1) & f<=fitb(2);
logf = log10(f(fb));
for ch = 1:nch
    psd = double(P(ch,:)).';
    per.theta_power(ch) = trapz(f(f>=theta(1)&f<=theta(2)), psd(f>=theta(1)&f<=theta(2)));
    per.alpha_power(ch) = trapz(f(f>=alpha(1)&f<=alpha(2)), psd(f>=alpha(1)&f<=alpha(2)));
    per.beta_power(ch)  = trapz(f(f>=beta(1) &f<=beta(2)),  psd(f>=beta(1) &f<=beta(2)));
    per.gamma_power(ch) = trapz(f(f>=gamma(1)&f<=gamma(2)), psd(f>=gamma(1)&f<=gamma(2)));

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

function v = getf(cfg, dotted, d)
try
    parts = split(string(dotted),'.'); S = cfg;
    for i=1:numel(parts), f = strtrim(parts{i}); if isfield(S,f), S = S.(f); else, v=d; return; end, end
    if isempty(S), v=d; else, v=S; end
catch, v=d; end
end
