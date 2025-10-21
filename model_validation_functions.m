function out = model_validation_functions(results, cfg)
% MODEL_VALIDATION_FUNCTIONS
% Stage 7: Hypothesis checks tying empirical metrics to the Harmonic Field Theory.
% Robust, self-contained, and safe for batch runs.
%
% INPUT
%   results : struct with fields (some may be empty)
%       .spec  : output of spectral_analysis_functions
%       .conn  : output of connectivity_analysis_functions
%       .pac   : output of pac_analysis_functions
%   cfg     : global config; uses cfg.validation.* if present
%
% OUTPUT
%   out : struct
%       .status    : 'ok' | 'skip' | 'fail'
%       .tests     : table [name, metric, value, threshold, pass]
%       .details   : struct with intermediate values
%       .notes     : string
%
% Tests implemented (conservative defaults):
%   T1 1/f slope vs gamma power correlation (expect negative): r < -0.2
%   T2 Theta→Gamma PAC present: mean MI above null threshold (z>2)
%   T3 Theta-band wPLI > floor (sustained coupling): wPLI_mean > 0.05
%   T4 Coherence not trivially high (volume conduction check): coh_mean < 0.8
%
% All thresholds are configurable under cfg.validation.*

% --------- Defaults ---------
out = default_out();

try
    if nargin < 1 || ~isstruct(results)
        out.status = 'skip';
        out.notes = "Missing results struct";
        return
    end
    if nargin < 2 || ~isstruct(cfg), cfg = struct(); end
    if ~isfield(cfg,'validation') || ~isstruct(cfg.validation)
        cfg.validation = struct();
    end

    v = cfg.validation;
    v.slope_gamma_r_thresh = getfield_or(v,'slope_gamma_r_thresh', -0.2);
    v.pac_z_thresh         = getfield_or(v,'pac_z_thresh', 2.0);
    v.wpli_floor           = getfield_or(v,'wpli_floor', 0.05);
    v.coh_ceiling          = getfield_or(v,'coh_ceiling', 0.80);
    v.min_channels         = getfield_or(v,'min_channels', 3);

    tests = [];
    details = struct();

    %% T1: 1/f slope vs gamma power correlation
    t1_name = "T1: slope–gamma correlation (expect negative)";
    t1_metric = "Pearson r";
    t1_value = NaN; t1_pass = false; t1_thr = v.slope_gamma_r_thresh;
    if isfield(results,'spec') && isstruct(results.spec) && ~isempty(results.spec)
        per = results.spec.per_channel;
        if istable(per) && width(per) >= 5 && height(per) >= v.min_channels
            slope = asvec(per.slope);
            gamma = asvec(per.gamma_power);
            mask = isfinite(slope) & isfinite(gamma);
            if nnz(mask) >= v.min_channels
                r = corr(slope(mask), gamma(mask), 'type','Pearson');
                t1_value = r;
                t1_pass = r <= t1_thr;
            end
        end
    end
    tests = add_row(tests, t1_name, t1_metric, t1_value, t1_thr, t1_pass);

    %% T2: Theta→Gamma PAC z-score above null
    t2_name = "T2: theta→gamma PAC present";
    t2_metric = "mean z(MI)"; t2_value = NaN; t2_thr = v.pac_z_thresh; t2_pass = false;
    if isfield(results,'pac') && isstruct(results.pac) && ~isempty(results.pac)
        % Extract theta X gamma cells from grid if present
        G = results.pac.grid;  % table with phase_band and amp_band
        if ~isempty(G) && istable(G) && ~isempty(results.pac.tort_mi)
            % crude null: channel-wise z-scoring across grid to highlight peaks
            MI = results.pac.tort_mi; % chan x grid
            if ~isempty(MI)
                mu = mean(MI,2,'omitnan');
                sd = std(MI,0,2,'omitnan');
                Z = (MI - mu) ./ max(sd, eps);
                % pick grid rows matching typical theta (4–7) and gamma (30–80)
                sel = band_selector(G.phase_band,[4 7]) & band_selector(G.amp_band,[30 80]);
                if any(sel)
                    zvals = Z(:, sel);
                    t2_value = mean(zvals(:),'omitnan');
                    t2_pass = t2_value >= t2_thr;
                end
                details.pac_mean_z = t2_value;
            end
        end
    end
    tests = add_row(tests, t2_name, t2_metric, t2_value, t2_thr, t2_pass);

    %% T3: Theta-band wPLI floor (nontrivial phase coupling)
    t3_name = "T3: theta-band wPLI above floor";
    t3_metric = "mean wPLI (theta)"; t3_value = NaN; t3_thr = v.wpli_floor; t3_pass = false;
    if isfield(results,'conn') && isstruct(results.conn) && ~isempty(results.conn) && ~isempty(results.conn.freq)
        [idxTheta, ~] = pick_band_idx(results.conn.freq, [4 7]);
        if any(idxTheta) && ~isempty(results.conn.wpli)
            W = results.conn.wpli(:,:,idxTheta);
            t3_value = mean(W,[1 2 3],'omitnan');
            t3_pass = t3_value >= t3_thr;
        end
    end
    tests = add_row(tests, t3_name, t3_metric, t3_value, t3_thr, t3_pass);

    %% T4: Coherence ceiling (avoid trivial volume conduction)
    t4_name = "T4: coherence below ceiling";
    t4_metric = "mean coherence (1–40 Hz)"; t4_value = NaN; t4_thr = v.coh_ceiling; t4_pass = false;
    if isfield(results,'conn') && isstruct(results.conn) && ~isempty(results.conn.coh)
        [idxLow, ~] = pick_band_idx(results.conn.freq, [1 40]);
        if any(idxLow)
            C = results.conn.coh(:,:,idxLow);
            t4_value = mean(C,[1 2 3],'omitnan');
            t4_pass = t4_value <= t4_thr;
        end
    end
    tests = add_row(tests, t4_name, t4_metric, t4_value, t4_thr, t4_pass);

    % ---- Package ----
    out.tests  = tests;
    out.details = details;
    out.status = 'ok';
    out.notes  = "Validation computed";

catch ME
    out.status = 'fail';
    out.notes = string(ME.message);
    warning('%s', ME.message);
end
end

%% ================= Helpers =================
function out = default_out()
out = struct('status','skip','tests',table(),'details',struct(),'notes',"");
end

function v = getfield_or(s, name, defaultVal)
if isstruct(s) && isfield(s,name) && ~isempty(s.(name))
    v = s.(name);
else
    v = defaultVal;
end
end

function v = asvec(x)
if istable(x); x = table2array(x); end
v = x(:);
end

function tf = band_selector(strBands, rng)
% strBands: table column of strings like "4-7"
try
    if iscellstr(strBands) %#ok<ISCLSTR>
        strBands = string(strBands);
    end
    parts = split(strBands, "-");
    lo = str2double(parts(:,1)); hi = str2double(parts(:,2));
    tf = (lo >= rng(1)) & (hi <= rng(2));
catch
    tf = false(size(strBands));
end
end

function [idx, ff] = pick_band_idx(f, band)
lo = band(1); hi = band(2);
idx = f >= lo & f <= hi; %#ok<NASGU>
ff  = f(idx);
end

function T = add_row(T, name, metric, value, threshold, pass)
row = table(string(name), string(metric), double(value), double(threshold), logical(pass), ...
            'VariableNames', {'name','metric','value','threshold','pass'});
if isempty(T)
    T = row; else, T = [T; row]; %#ok<AGROW>
end
end
