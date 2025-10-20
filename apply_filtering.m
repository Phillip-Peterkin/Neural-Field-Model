function data_filtered = apply_filtering(data, preproc_cfg)
% APPLY_FILTERING - Apply filtering and preprocessing to EEG/iEEG data
%
% This function applies bandpass filtering, notch filtering, detrending,
% and demeaning to raw data. It resamples FIRST to avoid filter instability.
%
% Usage:
%   data_filtered = apply_filtering(data, preproc_cfg)
%
% Inputs:
%   data        - Raw data structure (FieldTrip format)
%   preproc_cfg - Preprocessing configuration structure with fields:
%                 .highpass       - High-pass cutoff (Hz)
%                 .lowpass        - Low-pass cutoff (Hz)
%                 .notch          - Notch filter frequencies (Hz)
%                 .order          - Filter order
%                 .detrend        - Boolean, remove linear trend
%                 .demean         - Boolean, remove DC offset
%                 .resample_freq  - Target sampling rate (Hz)
%
% Outputs:
%   data_filtered - Filtered data structure

fprintf('Applying preprocessing pipeline...\n');

%% STEP 1: RESAMPLE FIRST (critical for filter stability)
if ~isempty(preproc_cfg.resample_freq) && preproc_cfg.resample_freq ~= data.fsample
    fprintf('  1. Resampling: %.1f Hz -> %d Hz...', data.fsample, preproc_cfg.resample_freq);
    
    cfg = [];
    cfg.resamplefs = preproc_cfg.resample_freq;
    cfg.detrend = 'no';  % We'll do this later
    cfg.demean = 'no';   % We'll do this later
    
    try
        data = ft_resampledata(cfg, data);
        fprintf(' ✓ (%.1f s)\n', toc);
    catch ME
        warning('Resampling failed: %s. Continuing without resampling.', E.message);
    end
else
    fprintf('  1. Resampling: skipped (already at target rate)\n');
end

%% STEP 2: DETREND (remove slow drifts before filtering)
if preproc_cfg.detrend
    fprintf('  2. Detrending...');
    tic;
    
    cfg = [];
    cfg.detrend = 'yes';
    cfg.demean = 'no';  % Do separately
    
    try
        data = ft_preprocessing(cfg, data);
        fprintf(' ✓ (%.1f s)\n', toc);
    catch ME
        warning('Detrending failed: %s', E.message);
        fprintf(' × (failed)\n');
    end
else
    fprintf('  2. Detrending: skipped\n');
end

%% STEP 3: DEMEAN (remove DC offset)
if preproc_cfg.demean
    fprintf('  3. Demeaning...');
    tic;
    
    cfg = [];
    cfg.demean = 'yes';
    cfg.detrend = 'no';
    
    try
        data = ft_preprocessing(cfg, data);
        fprintf(' ✓ (%.1f s)\n', toc);
    catch ME
        warning('Demeaning failed: %s', E.message);
        fprintf(' × (failed)\n');
    end
else
    fprintf('  3. Demeaning: skipped\n');
end

%% STEP 4: BANDPASS FILTER (high-pass + low-pass)
fprintf('  4. Bandpass filtering: %.1f-%.1f Hz (order %d)...', ...
    preproc_cfg.highpass, preproc_cfg.lowpass, preproc_cfg.order);
tic;

cfg = [];
cfg.bpfilter = 'yes';
cfg.bpfreq = [preproc_cfg.highpass preproc_cfg.lowpass];
cfg.bpfiltord = preproc_cfg.order;
cfg.bpfilttype = 'but';  % Butterworth
cfg.bpfiltdir = 'twopass';  % Zero-phase filter
cfg.bpinstabilityfix = 'reduce';  % Automatically reduce order if unstable

try
    data = ft_preprocessing(cfg, data);
    fprintf(' ✓ (%.1f s)\n', toc);
catch ME
    error('Bandpass filtering failed: %s\nTry increasing highpass cutoff or reducing filter order.', ME.message);
end

%% STEP 5: NOTCH FILTER (remove line noise)
if ~isempty(preproc_cfg.notch)
    fprintf('  5. Notch filtering: %s Hz...', mat2str(preproc_cfg.notch));
    tic;
    
    cfg = [];
    cfg.dftfilter = 'yes';
    cfg.dftfreq = preproc_cfg.notch;
    
    try
        data = ft_preprocessing(cfg, data);
        fprintf(' ✓ (%.1f s)\n', toc);
    catch ME
        warning('Notch filtering failed: %s', E.message);
        fprintf(' × (failed)\n');
    end
else
    fprintf('  5. Notch filtering: skipped\n');
end

%% OUTPUT
data_filtered = data;
fprintf('✓ Preprocessing pipeline complete\n\n');

end