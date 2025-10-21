function data_out = preprocessing_functions(data_raw, cfg)
% PREPROCESSING_FUNCTIONS
% Robust preprocessing for EEG/iEEG using FieldTrip.
% Accepts FieldTrip-like input or raw EEGLAB EEG and repairs missing fields.
%
% Signature: data_out = preprocessing_functions(data_raw, cfg)

% ---------- Validate or coerce input ----------
coerced = false;
if ~isstruct(data_raw)
    warning('%s','Invalid input: data_raw is not a struct.');
    data_out = struct();
    return
end

% Detect FieldTrip-like
isFT = isfield(data_raw,'trial') && iscell(data_raw.trial) && isfield(data_raw,'label');
% Detect EEGLAB EEG
isEEG = isfield(data_raw,'data') && isnumeric(data_raw.data) && isfield(data_raw,'srate');

if ~isFT && isEEG
    % EEGLAB EEG -> FieldTrip raw
    tmp = struct();
    tmp.trial   = {double(data_raw.data)};
    tmp.time    = { (0:size(data_raw.data,2)-1) / max(data_raw.srate,eps) };
    tmp.fsample = double(data_raw.srate);
    if isfield(data_raw,'chanlocs') && ~isempty(data_raw.chanlocs)
        lbl = {data_raw.chanlocs.labels};
        if isempty(lbl) || all(cellfun(@isempty,lbl))
            lbl = arrayfun(@(k)sprintf('ch%d',k), 1:size(data_raw.data,1), 'uni',0);
        end
        tmp.label = lbl(:)';
    else
        tmp.label = arrayfun(@(k)sprintf('ch%d',k), 1:size(data_raw.data,1), 'uni',0);
    end
    data_raw = tmp; clear tmp; coerced = true;
end

% After coercion, verify minimal fields
if ~isfield(data_raw,'trial') || isempty(data_raw.trial) || ~iscell(data_raw.trial) || ~isfield(data_raw,'label')
    warning('%s', 'Invalid input: data_raw missing expected structure fields.');
    data_out = struct();
    return
end

if coerced
    fprintf('[preprocessing] Coerced EEGLAB EEG to FieldTrip format. Channels: %d\n', numel(data_raw.label));
end

% ---------- Ensure fsample and time ----------
if ~isfield(data_raw,'fsample') || isempty(data_raw.fsample)
    data_raw.fsample = infer_fsample(data_raw);
end

if ~isfield(data_raw,'time') || isempty(data_raw.time) || numel(data_raw.time) ~= numel(data_raw.trial)
    data_raw.time = cell(size(data_raw.trial));
    for k = 1:numel(data_raw.trial)
        n = size(data_raw.trial{k},2);
        data_raw.time{k} = (0:n-1)/max(eps, data_raw.fsample);
    end
end

% ---------- Pull preprocessing params ----------
p = struct();
p.highpass      = getfield_or(cfg,'preprocessing.highpass',      1.0);
% use safe defaults for the rest
p.lowpass       = getfield_or(cfg,'preprocessing.lowpass',       200.0);
p.notch         = getfield_or(cfg,'preprocessing.notch',         [60 120 180]);
p.resample_rate = getfield_or(cfg,'preprocessing.resample_rate',  500);
p.detrend       = tf(getfield_or(cfg,'preprocessing.detrend',     true));
p.demean        = tf(getfield_or(cfg,'preprocessing.demean',      true));
p.reref         = tf(getfield_or(cfg,'preprocessing.reref',       false));
p.refchannel    = getfield_or(cfg,'preprocessing.refchannel',     'all');

% ---------- Pipeline ----------
try
    % 1) Optional re-reference
    c = [];
    if p.reref
        c.reref      = 'yes';
        c.refchannel = p.refchannel;
        data_raw = ft_preprocessing(c, data_raw);
    end

    % 2) Detrend / Demean
    c = [];
    if p.detrend, c.detrend = 'yes'; else, c.detrend = 'no'; end
    if p.demean
        c.demean  = 'yes';
        c.baselinewindow = [data_raw.time{1}(1) min(0, data_raw.time{1}(end))];
    else
        c.demean  = 'no';
    end
    data1 = ft_preprocessing(c, data_raw);

    % 3) HP/LP filters
    c = [];
    if ~isempty(p.highpass) && p.highpass > 0
        c.hpfilter = 'yes'; c.hpfreq = p.highpass;
    end
    if ~isempty(p.lowpass) && p.lowpass > 0
        c.lpfilter = 'yes'; c.lpfreq = p.lowpass;
    end
    if ~isempty(fieldnames(c))
        data1 = ft_preprocessing(c, data1);
    end

    % 4) Notch
    if ~isempty(p.notch)
        c = [];
        c.dftfilter = 'yes'; c.dftfreq = p.notch;
        data1 = ft_preprocessing(c, data1);
    end

    % 5) Resample
    if ~isempty(p.resample_rate) && isnumeric(p.resample_rate) && p.resample_rate > 0
        c = []; c.resamplefs = p.resample_rate; c.detrend = 'no';
        data1 = ft_resampledata(c, data1);
    end

    data_out = data1;
catch ME
    warning('%s', ME.message);
    data_out = struct();
end
end

% ================= Helpers ==================
function fs = infer_fsample(d)
try
    if isfield(d,'time') && ~isempty(d.time) && ~isempty(d.time{1})
        dt = diff(d.time{1}); fs = 1/median(dt(~isnan(dt) & isfinite(dt)));
        if ~isfinite(fs) || fs <= 0, fs = 1000; end
    elseif isfield(d,'hdr') && isfield(d.hdr,'Fs') && ~isempty(d.hdr.Fs)
        fs = double(d.hdr.Fs);
    else
        fs = 1000;
    end
catch
    fs = 1000;
end
end

function val = getfield_or(cfg, dotted, defaultVal)
try
    parts = split(string(dotted), '.'); S = cfg;
    for i = 1:numel(parts)
        name = strtrim(parts{i});
        if isstruct(S) && isfield(S, name)
            S = S.(name);
        else
            val = defaultVal; return
        end
    end
    if isempty(S), val = defaultVal; else, val = S; end
catch
    val = defaultVal;
end
end

function t = tf(x)
if islogical(x), t = x; elseif isnumeric(x), t = x ~= 0; else, t = false; end
end
