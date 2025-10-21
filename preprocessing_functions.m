function data_pre = preprocessing_functions(cfg, data_raw)
% PREPROCESSING_FUNCTIONS
% High-level EEG/iEEG preprocessing routine for HFT pipeline.
% This function standardizes and cleans electrophysiological data for further analyses.
% Designed for reproducibility, modularity, and FieldTrip/EEGLAB compatibility.

%% ==============================
%  Stage 2: Preprocessing Overview
%  ==============================
fprintf('\n[Stage 2] Starting preprocessing...\n');

try
    %% Step 1. Verify Input Structure
    if isempty(data_raw) || ~isfield(data_raw, 'trial')
        error('Invalid input: data_raw missing expected structure fields.');
    end
    fprintf('Input data verified.\n');

    %% Step 2. Standardize Channel Layout
    cfg_layout = [];
    cfg_layout.layout = cfg.preprocessing.layout;
    cfg_layout.channel = 'all';
    try
        ft_layoutplot(cfg_layout);
        close all;
    catch
        warning('Unable to visualize channel layout, continuing without plot.');
    end

    %% Step 3. Re-reference Data (if required)
    if isfield(cfg.preprocessing, 'reref') && cfg.preprocessing.reref
        cfg_ref = [];
        cfg_ref.reref = 'yes';
        cfg_ref.refchannel = cfg.preprocessing.refchannel;
        data_ref = ft_preprocessing(cfg_ref, data_raw);
    else
        data_ref = data_raw;
    end
    fprintf('Re-referencing complete.\n');

    %% Step 4. Filtering (High-pass, Low-pass, Notch)
    cfg_filt = [];
    cfg_filt.hpfilter = 'yes';
    cfg_filt.hpfreq = cfg.preprocessing.highpass;
    cfg_filt.lpfilter = 'yes';
    cfg_filt.lpfreq = cfg.preprocessing.lowpass;
    cfg_filt.bsfilter = 'yes';
    cfg_filt.bsfreq = cfg.preprocessing.notch;

    data_filt = ft_preprocessing(cfg_filt, data_ref);
    fprintf('Filtering complete.\n');

    %% Step 5. Artifact Rejection and Detrending
    cfg_clean = [];
    cfg_clean.demean = 'yes';
    cfg_clean.detrend = 'yes';
    cfg_clean.artfctdef.reject = 'partial';
    cfg_clean.artfctdef.zvalue.channel = 'all';
    cfg_clean.artfctdef.zvalue.cutoff = cfg.preprocessing.z_cutoff;

    try
        [cfg_clean, artifact] = ft_artifact_zvalue(cfg_clean, data_filt);
        data_clean = ft_rejectartifact(cfg_clean, data_filt);
        fprintf('Artifact rejection complete: %d segments removed.\n', size(artifact,1));
    catch ME
        warning('%s', ME.message);
        warning('Artifact rejection failed; proceeding with filtered data.');
        data_clean = data_filt;
    end

    %% Step 6. Resampling
    cfg_resamp = [];
    cfg_resamp.resamplefs = cfg.preprocessing.resample_rate;
    cfg_resamp.detrend = 'no';
    data_resamp = ft_resampledata(cfg_resamp, data_clean);
    fprintf('Data resampled to %.1f Hz.\n', cfg.preprocessing.resample_rate);

    %% Step 7. Channel Inspection and Repair
    bad_chans = detect_bad_channels(data_resamp);
    if ~isempty(bad_chans)
        cfg_interp = [];
        cfg_interp.method = 'spline';
        cfg_interp.badchannel = bad_chans;
        data_interp = ft_channelrepair(cfg_interp, data_resamp);
        fprintf('Interpolated %d bad channels.\n', numel(bad_chans));
    else
        data_interp = data_resamp;
    end

    %% Step 8. Normalize Trial Lengths
    cfg_trim = [];
    cfg_trim.length = cfg.preprocessing.trial_length;
    cfg_trim.overlap = cfg.preprocessing.trial_overlap;
    data_pre = ft_redefinetrial(cfg_trim, data_interp);
    fprintf('Trials redefined to %.2f s with %.2f s overlap.\n', ...
            cfg.preprocessing.trial_length, cfg.preprocessing.trial_overlap);

    %% Step 9. Final Consistency Check
    if isempty(data_pre.trial) || isempty(data_pre.time)
        error('Preprocessing failed: output structure empty or malformed.');
    end

    fprintf('Preprocessing successful for subject.\n');

catch ME
    warning('%s', ME.message);
    warning('Preprocessing stage failed. Returning empty structure.');
    data_pre = struct();
end

end

%% ==============================
% Helper Function: Detect Bad Channels
% ==============================
function bad_chans = detect_bad_channels(data)
try
    chan_var = cellfun(@(x) var(x(:)), data.trial);
    mean_var = mean(chan_var);
    std_var = std(chan_var);
    bad_idx = find(chan_var > mean_var + 3*std_var);
    bad_chans = data.label(bad_idx);
catch
    bad_chans = {};
end
end
