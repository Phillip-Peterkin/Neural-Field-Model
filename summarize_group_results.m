function group_results = summarize_group_results(config)
% SUMMARIZE_GROUP_RESULTS (robust)
% Collects per-subject outputs and computes safe group means.

R = dir(fullfile(config.paths.results,'sub-*'));
R = R([R.isdir]);

N = numel(R);
slopes = []; alphaP = []; thetaP = []; gammaP = [];
wpli_theta = []; coh_low = [];

for i = 1:N
    sid = R(i).name;
    sdir = fullfile(R(i).folder, sid);

    % ---- spectral ----
    f = fullfile(sdir, 'spectral.mat');
    try
        if exist(f,'file')
            S = load(f);
            if isfield(S,'data'), S = S.data; end
            if isstruct(S) && isfield(S,'aperiodic') && isfield(S.aperiodic,'slope')
                slopes(end+1,1) = double(S.aperiodic.slope); %#ok<AGROW>
            end
            if isfield(S,'bands') && isstruct(S.bands)
                thetaP(end+1,1) = toscalar(getfield_safe(S.bands,'theta')); %#ok<AGROW>
                alphaP(end+1,1) = toscalar(getfield_safe(S.bands,'alpha')); %#ok<AGROW>
                gammaP(end+1,1) = toscalar(getfield_safe(S.bands,'gamma')); %#ok<AGROW>
            end
        end
    catch
        % skip this subject's spectral
    end

    % ---- connectivity ----
    f = fullfile(sdir, 'connectivity.mat');
    try
        if exist(f,'file')
            C = load(f);
            if isfield(C,'data'), C = C.data; end
            if isstruct(C)
                if isfield(C,'bands') && isfield(C.bands,'theta') && isfield(C.bands.theta,'wpli_mean')
                    wpli_theta(end+1,1) = double(C.bands.theta.wpli_mean); %#ok<AGROW>
                end
                if isfield(C,'freq') && ~isempty(C.freq) && isfield(C,'coh') && ~isempty(C.coh)
                    % ensure 3D
                    M = C.coh;
                    if ndims(M) == 2, M = reshape(M, size(M,1), size(M,2), 1); end
                    idx = C.freq >= 1 & C.freq <= 40;
                    if any(idx)
                        coh_low(end+1,1) = mean(M(:,:,idx), [1 2 3], 'omitnan'); %#ok<AGROW>
                    end
                end
            end
        end
    catch
        % skip this subject's connectivity
    end
end

group_results = struct();
group_results.n_subjects          = N;
group_results.slope_mean          = mean(slopes,      'omitnan');
group_results.theta_power_mean    = mean(thetaP,      'omitnan');
group_results.alpha_power_mean    = mean(alphaP,      'omitnan');
group_results.gamma_power_mean    = mean(gammaP,      'omitnan');
group_results.theta_wpli_mean     = mean(wpli_theta,  'omitnan');
group_results.lowfreq_coh_mean    = mean(coh_low,     'omitnan');

end

function v = getfield_safe(S, name)
if isstruct(S) && isfield(S,name)
    v = S.(name);
else
    v = NaN;
end
end

function x = toscalar(v)
% Accept struct with .power or a numeric
try
    if isstruct(v) && isfield(v,'power')
        x = double(v.power);
    else
        x = double(v);
    end
    if isempty(x), x = NaN; end
catch
    x = NaN;
end
end
