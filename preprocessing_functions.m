function [data_pp, events, meta] = preprocessing_functions(cfg, raw)
% PREPROCESSING_FUNCTIONS
% Robust FieldTrip-based preprocessing for BIDS EEG/iEEG recordings.
%
% Inputs
%   cfg : struct with fields (all optional)
%       .resample_hz   default 500
%       .hp_hz         default 1
%       .lp_hz         default 200
%       .notch_hz      default [60 120 180]  % uses dftfilter
%       .remove_eog    default true
%       .remove_ecg    default true
%       .car_eeg       default true          % common average ref for EEG
%       .reref_ieeg    default 'none'        % 'none' | 'commonavg' | channel label cellstr
%   raw : struct from load_raw_data.m with fields:
%       .data          FieldTrip raw struct (label, trial, time, fsample, hdr, cfg)
%       .events        table with at least onset (s) and type
%       .channel_info  table from channels.tsv, must include 'name' and 'type'
%       .subject_id    char
%       .session_id    char
%
% Outputs
%   data_pp : FieldTrip raw struct after preprocessing
%   events  : table, input events resynced to new sampling rate
%   meta    : struct with bookkeeping info

assert(isstruct(raw) && isfield(raw,'data'), 'raw.data missing');
if nargin < 1 || ~isstruct(cfg), cfg = struct; end

% ---- defaults ----
cfg = set_default(cfg, 'resample_hz', 500);
cfg = set_default(cfg, 'hp_hz', 1.0);
cfg = set_default(cfg, 'lp_hz', 200.0);
cfg = set_default(cfg, 'notch_hz', [60 120 180]);
cfg = set_default(cfg, 'remove_eog', true);
cfg = set_default(cfg, 'remove_ecg', true);
cfg = set_default(cfg, 'car_eeg', true);
cfg = set_default(cfg, 'reref_ieeg', 'none'); % or 'commonavg' or cellstr

% ---- toolboxes ----
ensure_fieldtrip();
ft_defaults; %#ok<*NOPRT>  % keep FT on path

% ---- unpack input without polluting FT data ----
data_in  = raw.data;
chan_tbl = coerce_channel_table(raw);
events   = coerce_events_table(raw);

% store metadata only inside cfg.meta to avoid FT warnings
data_in.cfg = ensure_struct(data_in.cfg);
data_in.cfg.meta.subject_id = safe_id(raw, 'subject_id');   % no hyphens as fields
data_in.cfg.meta.session_id = safe_id(raw, 'session_id');
data_in.cfg.meta.channel_info = chan_tbl;
data_in.cfg.meta.original_fsample = data_in.fsample;

% ---- 0) select usable channels and drop obvious non-phys ----
good_mask = true(height(chan_tbl),1);
if any(ismember(chan_tbl.Properties.VariableNames,'status'))
    bad = strcmpi(string(chan_tbl.status), "bad");
    bad(isnan(bad)) = false;
    good_mask = good_mask & ~bad;
end
if cfg.remove_eog && any(strcmpi(chan_tbl.type, 'EOG'))
    good_mask(strcmpi(chan_tbl.type,'EOG')) = false;
end
if cfg.remove_ecg && any(strcmpi(chan_tbl.type, 'ECG'))
    good_mask(strcmpi(chan_tbl.type,'ECG')) = false;
end
good_labels = string(chan_tbl.name(good_mask));
cfg_sel = [];
cfg_sel.channel = cellstr(good_labels);
data_sel = ft_selectdata(cfg_sel, data_in);

% ---- 1) resample FIRST ----
if ~isempty(cfg.resample_hz) && abs(data_sel.fsample - cfg.resample_hz) > 1e-6
    cfg_rs = [];
    cfg_rs.resamplefs = cfg.resample_hz;
    cfg_rs.detrend    = 'no';
    data_rs = ft_resampledata(cfg_rs, data_sel);
else
    data_rs = data_sel;
end

% ---- 2) detrend + demean ----
cfg_pp = [];
cfg_pp.detrend = 'yes';
cfg_pp.demean  = 'yes';
data_pp = ft_preprocessing(cfg_pp, data_rs);

% ---- 3) bandpass ----
if ~isempty(cfg.hp_hz) || ~isempty(cfg.lp_hz)
    cfg_bp = [];
    cfg_bp.bpfilter = 'yes';
    if ~isempty(cfg.hp_hz) && ~isempty(cfg.lp_hz)
        cfg_bp.bpfreq = [cfg.hp_hz cfg.lp_hz];
    elseif ~isempty(cfg.hp_hz)
        cfg_bp.hpfilter = 'yes';
        cfg_bp.hpfreq   = cfg.hp_hz;
        cfg_bp.bpfilter = 'no';
    else
        cfg_bp.lpfilter = 'yes';
        cfg_bp.lpfreq   = cfg.lp_hz;
        cfg_bp.bpfilter = 'no';
    end
    data_pp = ft_preprocessing(cfg_bp, data_pp);
end

% ---- 4) line noise removal with DFT filter ----
if ~isempty(cfg.notch_hz)
    cfg_ln = [];
    cfg_ln.dftfilter = 'yes';
    cfg_ln.dftfreq   = cfg.notch_hz(:)';  % row
    data_pp = ft_preprocessing(cfg_ln, data_pp);
end

% ---- 5) rereference by modality ----
% Use BIDS types if present, else guess from label count
mod_types = lower(string(chan_tbl.type(good_mask)));
is_eeg  = any(mod_types=="eeg");
is_ieeg = any(mod_types=="ieeg") || any(mod_types=="seeg") || any(mod_types=="ecog");

if is_eeg && cfg.car_eeg
    cfg_rr = [];
    cfg_rr.reref      = 'yes';
    cfg_rr.refchannel = data_pp.label; % common average
    data_pp = ft_preprocessing(cfg_rr, data_pp);
end

if is_ieeg && ~strcmpi(cfg.reref_ieeg,'none')
    cfg_rr = [];
    cfg_rr.reref = 'yes';
    if ischar(cfg.reref_ieeg) || isstring(cfg.reref_ieeg)
        if strcmpi(string(cfg.reref_ieeg),'commonavg')
            cfg_rr.refchannel = data_pp.label;
        else
            error('Unknown cfg.reref_ieeg string. Use ''none'' or ''commonavg'' or cellstr of labels.');
        end
    elseif iscellstr(cfg.reref_ieeg) || isstring(cfg.reref_ieeg)
        cfg_rr.refchannel = cellstr(cfg.reref_ieeg);
    else
        error('cfg.reref_ieeg must be ''none'', ''commonavg'', or a list of labels');
    end
    data_pp = ft_preprocessing(cfg_rr, data_pp);
end

% ---- 6) finalize metadata and event resync ----
meta = struct();
meta.subject      = data_in.cfg.meta.subject_id;
meta.session      = data_in.cfg.meta.session_id;
meta.n_channels   = numel(data_pp.label);
meta.fsample      = data_pp.fsample;
meta.pipeline     = struct('resample_hz', cfg.resample_hz, ...
                           'hp_hz', cfg.hp_hz, 'lp_hz', cfg.lp_hz, ...
                           'notch_hz', cfg.notch_hz, ...
                           'car_eeg', cfg.car_eeg, 'reref_ieeg', cfg.reref_ieeg);
meta.kept_labels  = data_pp.label(:);
meta.dropped_labels = setdiff(cellstr(data_in.label), cellstr(meta.kept_labels));

% resync events to new sampling rate, keep columns if present
if ~isempty(events) && any(ismember(events.Properties.VariableNames,'onset'))
    if ~ismember('sample', events.Properties.VariableNames)
        events.sample = zeros(height(events),1);
    end
    events.sample = max(1, round(events.onset .* data_pp.fsample) + 1);
end

% keep channel table in cfg.meta, not at top level
data_pp.cfg.meta = meta;
data_pp.cfg.meta.channel_info = chan_tbl;

end % main

% ========= helpers =========

function ensure_fieldtrip()
    if exist('ft_defaults','file') ~= 2
        error('FieldTrip not found on path. Add it, then rerun.');
    end
end

function s = ensure_struct(s)
    if isempty(s), s = struct; end
end

function v = set_default(s, name, val)
    if ~isfield(s, name) || isempty(s.(name))
        v = val;
    else
        v = s.(name);
    end
    s.(name) = v; %#ok<NASGU> (silence)
end

function t = coerce_channel_table(raw)
    if isfield(raw,'channel_info') && istable(raw.channel_info)
        t = raw.channel_info;
    else
        % minimum scaffold from labels when channels.tsv missing
        lbl = cellstr(raw.data.label(:));
        t = table(lbl, repmat("EEG",numel(lbl),1), 'VariableNames', {'name','type'});
    end
    % standardize colnames
    t.Properties.VariableNames = matlab.lang.makeUniqueStrings(lower(t.Properties.VariableNames));
    if ~ismember('name', t.Properties.VariableNames)
        error('channel_info must include a ''name'' column');
    end
    if ~ismember('type', t.Properties.VariableNames)
        t.type = repmat("EEG",height(t),1);
    else
        t.type = string(t.type);
    end
end

function e = coerce_events_table(raw)
    if isfield(raw,'events') && istable(raw.events)
        e = raw.events;
    else
        e = table(); % empty but valid
    end
end

function sid = safe_id(raw, field)
    sid = '';
    if isfield(raw, field) && ~isempty(raw.(field))
        sid = char(raw.(field));
    end
    % never use this as a struct field name, keep as value only
end
