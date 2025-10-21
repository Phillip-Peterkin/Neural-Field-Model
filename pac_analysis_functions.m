function out = pac_analysis_functions(data_pre, cfg)
arguments
    data_pre (1,1) struct
    cfg struct = struct()
end

out = default_out();
if ~isstruct(data_pre) || isempty(data_pre.trial), out.status="skip"; return, end

fs = data_pre.fsample;
pb = hft_utils('sanitizeband', getf(cfg,'pac.phase_bands',[4 7]), fs, [4 7]);
ab = hft_utils('sanitizeband', getf(cfg,'pac.amp_bands',[50 80]), fs, [50 80]);
nb = getf(cfg,'pac.nbins',18);
nSurr = getf(cfg,'pac.n_surr',100);

X = double(data_pre.trial{1}); % [chan x time]

% Use MATLAB bandpass for stable filters, fall back to butter if needed
try
    ph = angle(hilbert(bandpass(X.', pb, fs, 'Steepness',0.95, 'ImpulseResponse','iir')).');
    ga = abs(hilbert( bandpass(X.', ab, fs, 'Steepness',0.95, 'ImpulseResponse','iir')).');
catch
    [b1,a1] = butter(4, pb/(fs/2), 'bandpass');
    [b2,a2] = butter(4, ab/(fs/2), 'bandpass');
    ph = angle(hilbert(filtfilt(b1,a1,X.').'));
    ga = abs(  hilbert(filtfilt(b2,a2,X.').'));
end

MI = zeros(size(X,1),1); Z = zeros(size(X,1),1);
for ch=1:size(X,1)
    MI(ch) = tort_mi(ph(ch,:), ga(ch,:), nb);
    % light surrogates by shifts
    s = zeros(nSurr,1);
    for k=1:nSurr
        sh = randi(size(ga,2)-1);
        s(k) = tort_mi(ph(ch,:), circshift(ga(ch,:), sh, 2), nb);
    end
    Z(ch) = (MI(ch) - mean(s,'omitnan')) / max(std(s,0,'omitnan'), eps);
end

out.status  = "ok";
out.phase_band = pb; out.amp_band = ab;
out.tort_mi = MI; out.mi_z = Z; out.mean_z = mean(Z,'omitnan');

end

% --- helpers ---
function mi = tort_mi(phase, amp, nb)
edges = linspace(-pi,pi,nb+1);
[~,bin] = histc(phase, edges); bin(bin==0) = 1;
meanA = accumarray(bin(:), amp(:), [nb 1], @mean, 0);
P = meanA / sum(meanA + eps);
H = -sum(P .* log(P + eps));
mi = (log(nb) - H) / log(nb);
end

function v = getf(cfg, field, d)
if isstruct(cfg) && isfield(cfg,field) && ~isempty(cfg.(field)), v = cfg.(field); else, v = d; end
end

function out = default_out()
out = struct('status',"skip",'notes',"",'phase_band',[],'amp_band',[],'tort_mi',[],'mi_z',[],'mean_z',NaN);
end
