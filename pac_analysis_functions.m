function out = pac_analysis_functions(data_pre, cfg)
arguments
    data_pre (1,1) struct
    cfg struct = struct()
end
out = struct('status',"skip",'notes',"",'phase_band',[],'amp_band',[],'tort_mi',[],'mi_z',[],'mean_z',NaN);

if ~isstruct(data_pre) || isempty(data_pre.trial), return, end
fs = data_pre.fsample;

pb = hft_utils('sanitizeband', getf(cfg,'pac.phase_bands',[4 7]),  fs, [4 7]);
ab = hft_utils('sanitizeband', getf(cfg,'pac.amp_bands',  [50 80]), fs, [50 80]);
nb = getf(cfg,'pac.nbins',18);
nS = getf(cfg,'pac.n_surr',100);

X = double(data_pre.trial{1});   % chan x time

% Preferred: bandpass(), fallback to butter
try
    P = angle(hilbert(bandpass(X.', pb, fs, 'Steepness',0.95,'ImpulseResponse','iir')).');
    A = abs(  hilbert(bandpass(X.', ab, fs, 'Steepness',0.95,'ImpulseResponse','iir')).');
catch
    [b1,a1] = butter(4, pb/(fs/2), 'bandpass');
    [b2,a2] = butter(4, ab/(fs/2), 'bandpass');
    P = angle(hilbert(filtfilt(b1,a1,X.').'));
    A = abs(  hilbert(filtfilt(b2,a2,X.').'));
end

MI = zeros(size(X,1),1); Z = zeros(size(X,1),1);
edges = linspace(-pi,pi,nb+1);
for ch = 1:size(X,1)
    % Tort MI
    [~,bin] = histcounts(P(ch,:), edges);
    bin(bin==0) = 1;
    mu = accumarray(bin(:), A(ch,:).', [nb 1], @mean, 0);
    Pbins = mu / sum(mu + eps);
    H = -sum(Pbins .* log(Pbins + eps));
    MI(ch) = (log(nb) - H)/log(nb);

    % Surrogates by circular shifts
    s = zeros(nS,1);
    for k=1:nS
        sh = randi(size(A,2)-1);
        [~,b2] = histcounts(P(ch,:), edges);
        b2(b2==0) = 1;
        mu2 = accumarray(b2(:), circshift(A(ch,:), sh, 2).', [nb 1], @mean, 0);
        p2 = mu2 / sum(mu2 + eps);
        H2 = -sum(p2 .* log(p2 + eps));
        s(k) = (log(nb) - H2)/log(nb);
    end
    Z(ch) = (MI(ch) - mean(s,'omitnan')) / max(std(s,0,'omitnan'), eps);
end

out.status = "ok";
out.phase_band = pb;
out.amp_band   = ab;
out.tort_mi    = MI;
out.mi_z       = Z;
out.mean_z     = mean(Z,'omitnan');
end

function v = getf(cfg, field, d)
if isstruct(cfg) && isfield(cfg,field) && ~isempty(cfg.(field)), v = cfg.(field); else, v = d; end
end
