function [data_pre, diag] = preprocessing_functions(data_raw, config)
% PREPROCESSING_FUNCTIONS  Clean raw EEG/iEEG and make uniform trials.
arguments
    data_raw (1,1) struct
    config struct = struct()
end
diag = struct(); data_pre = struct();

if ~isstruct(data_raw) || ~isfield(data_raw,'trial') || isempty(data_raw.trial)
    warning('preproc:empty','Preprocessing skipped, empty input');
    return
end

fs0   = data_raw.fsample;
fsOut = getf(config,'preprocess.target_fs', 500);
hpHz  = getf(config,'preprocess.highpass_hz', 1.0);
lpHz  = min(getf(config,'preprocess.lowpass_hz', 200), max(10, fs0/2 - 5));
notch = getf(config,'preprocess.notch_hz', [60 120 180]);
winS  = getf(config,'preprocess.window_sec', 2.0);
olap  = getf(config,'preprocess.overlap', 0.0);

% Stable IIR, two-pass, memory-light
cfg = [];
cfg.demean      = 'yes';
cfg.detrend     = 'yes';
cfg.hpfilter    = 'yes'; cfg.hpfreq = hpHz; cfg.hpfilttype = 'but'; cfg.hpfiltord = 4; cfg.hpfiltdir = 'twopass';
cfg.lpfilter    = 'yes'; cfg.lpfreq = lpHz; cfg.lpfilttype = 'but'; cfg.lpfiltord = 6; cfg.lpfiltdir = 'twopass';
cfg.dftfilter   = 'yes'; cfg.dftfreq = notch;     % 60 Hz harmonics
x = ft_preprocessing(cfg, data_raw);

% Uniform trials fix sampleinfo issues
data_pre = make_uniform_trials(x, fsOut, winS, olap);

diag.fsample_in  = fs0;
diag.fsample_out = data_pre.fsample;
diag.ntrials     = numel(data_pre.trial);
diag.nsamples    = size(data_pre.trial{1},2);
end

% ---- helper ----
function v = getf(cfg, dotted, d)
try
    parts = split(string(dotted), '.'); S = cfg;
    for i = 1:numel(parts)
        f = strtrim(parts{i});
        if isstruct(S) && isfield(S,f), S = S.(f); else, v = d; return
        end
    end
    if isempty(S), v = d; else, v = S; end
catch, v = d;
end
end
