function group_results = summarize_group_results(config)
% SUMMARIZE_GROUP_RESULTS  Memory-safe group aggregation.
% - Loads ONLY the variables needed, using matfile when possible
% - Reduces subject outputs to scalars immediately to avoid big arrays
% - Handles shape mismatches and missing fields
%
% Expected layout:
%   <config.paths.results>/sub-*/spectral.mat
%   <config.paths.results>/sub-*/connectivity.mat
%
% Tunables (can be overridden in config.group):
G = struct();
G.freq_max_hz        = getfield_or(config,'group.freq_max_hz',40);   % limit for low-frequency coherence
G.freq_block_size    = getfield_or(config,'group.freq_block_size',512); % chunk size for 3-D matrices
G.coh_stat           = getfield_or(config,'group.coh_stat','mean');  % 'mean' or 'median'
G.verbose            = getfield_or(config,'group.verbose',true);

subs = dir(fullfile(config.paths.results,'sub-*')); subs = subs([subs.isdir]);
N = numel(subs);

    % Running stats (sum & count) so we never keep large vectors in memory
    rs = initRunningStats();
    
    for i = 1:N
        sid = subs(i).name; sdir = fullfile(subs(i).folder, sid);
        if G.verbose, fprintf('[group] %s\n', sid); end

    % slope
    if isfield(S,'aperiodic') && isfield(S.aperiodic,'slope')
        rs = rs_add(rs,'slope', double(S.aperiodic.slope));
    elseif isfield(S,'per_channel') && istable(S.per_channel)
        svec = hft_utils('getvar', S.per_channel, {'slope','aperiodic_slope','exponent','ap_slope'});
        if ~isempty(svec), rs = rs_add(rs,'slope', mean(double(svec),'omitnan')); end
    end
    
    % band powers
    if isfield(S,'per_channel') && istable(S.per_channel)
        tv = hft_utils('getvar', S.per_channel, {'theta_power','theta'});
        av = hft_utils('getvar', S.per_channel, {'alpha_power','alpha'});
        gv = hft_utils('getvar', S.per_channel, {'gamma_power','gamma'});
        if ~isempty(tv), rs = rs_add(rs,'theta_power', mean(double(tv),'omitnan')); end
        if ~isempty(av), rs = rs_add(rs,'alpha_power', mean(double(av),'omitnan')); end
        if ~isempty(gv), rs = rs_add(rs,'gamma_power', mean(double(gv),'omitnan')); end
    end

    %% -------- connectivity --------
    cp = fullfile(sdir,'connectivity.mat');
    if exist(cp,'file')
        try
            C = safeLoad(cp, {'data','bands','freq','coh'});
            if isfield(C,'data') && isstruct(C.data), C = C.data; end

            % Example band-level scalar (wPLI in theta)
            if isfield(C,'bands') && isfield(C.bands,'theta') && isfield(C.bands.theta,'wpli_mean')
                rs = rs_add(rs,'theta_wpli', double(C.bands.theta.wpli_mean));
            end

            % Coherence 3-D: chan x chan x freq. Compute low-frequency mean safely.
            if isfield(C,'freq') && ~isempty(C.freq) && isfield(C,'coh') && ~isempty(C.coh)
                f = double(C.freq(:));
                flo = (f >= 1 & f <= G.freq_max_hz);
                if any(flo)
                    M = C.coh; % could be big
                    if ndims(M) == 2, M = reshape(M, size(M,1), size(M,2), 1); end
                    % Chunk along frequency to cap memory
                    idx = find(flo);
                    block = G.freq_block_size;
                    acc = 0; nacc = 0;
                    for k = 1:block:numel(idx)
                        sl = idx(k:min(k+block-1, numel(idx)));
                        slice = M(:,:,sl);
                        acc  = acc + sum(slice(:),'omitnan');
                        nacc = nacc + nnz(~isnan(slice));
                        clear slice; % free early
                    end
                    if nacc > 0
                        rs = rs_add(rs,'coh_lowfreq', acc / nacc);
                    end
                    clear M; % free memory per subject
                end
            end
        catch ME
            warnME('connectivity', cp, ME);
        end
    end

    % Proactive memory relief in long loops
    drawnow limitrate; %#ok<DRAWNOW>
end

% ---- finalize ----
Gout = struct();
Gout.n_subjects       = N;
Gout.slope_mean       = rs_mean(rs,'slope');
Gout.theta_power_mean = rs_mean(rs,'theta_power');
Gout.alpha_power_mean = rs_mean(rs,'alpha_power');
Gout.gamma_power_mean = rs_mean(rs,'gamma_power');
Gout.theta_wpli_mean  = rs_mean(rs,'theta_wpli');
Gout.lowfreq_coh_mean = rs_mean(rs,'coh_lowfreq');

group_results = Gout;
end

%% ================= helpers =================
function S = safeLoad(path, vars)
% Try matfile for partial load, fallback to load
try
    m = matfile(path);
    S = struct();
    for i = 1:numel(vars)
        v = vars{i};
        try
            S.(v) = m.(v);
        catch
            % variable not present, skip
        end
    end
    % if nothing loaded, fallback to load minimal
    if isempty(fieldnames(S))
        S = load(path);
    end
catch
    S = load(path);
end
end

function warnME(stage, file, ME)
warning('%s: %s -> %s', stage, file, ME.message);
end

function x = toScalarSafe(bands, name)
try
    if ~isfield(bands, name), x = NaN; return; end
    v = bands.(name);
    if isstruct(v) && isfield(v,'power')
        x = double(v.power); return
    end
    if isnumeric(v)
        if isempty(v), x = NaN; else, x = double(v(1)); end
        return
    end
    x = NaN;
catch
    x = NaN;
end
end

function rs = initRunningStats()
rs = struct();
end

function rs = rs_add(rs, key, val)
if ~isfield(rs,key)
    rs.(key) = struct('sum',0,'n',0);
end
if ~isnan(val)
    rs.(key).sum = rs.(key).sum + double(val);
    rs.(key).n   = rs.(key).n   + 1;
end
end

function m = rs_mean(rs, key)
if isfield(rs,key) && rs.(key).n > 0
    m = rs.(key).sum / rs.(key).n;
else
    m = NaN;
end
end

function val = getfield_or(S, dotted, defaultVal)
try
    parts = split(string(dotted), '.');
    for i = 1:numel(parts)
        f = strtrim(parts{i});
        if isstruct(S) && isfield(S,f)
            S = S.(f);
        else
            val = defaultVal; return
        end
    end
    if isempty(S), val = defaultVal; else, val = S; end
catch
    val = defaultVal;
end
end
