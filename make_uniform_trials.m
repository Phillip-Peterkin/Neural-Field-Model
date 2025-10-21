function out = make_uniform_trials(data_in, fs_out, win_sec, overlap)
% MAKE_UNIFORM_TRIALS  Build exact-length windows and attach sampleinfo.
arguments
    data_in (1,1) struct
    fs_out (1,1) double {mustBePositive} = 500
    win_sec (1,1) double {mustBePositive} = 2.0
    overlap (1,1) double {mustBeGreaterThanOrEqual(overlap,0),mustBeLessThan(overlap,1)} = 0.0
end

% 1) Resample (if needed)
if isfield(data_in,'fsample') && abs(data_in.fsample - fs_out) < 1e-6
    res = data_in;
else
    cfg = [];
    cfg.resamplefs = fs_out;
    cfg.detrend    = 'no';
    res = ft_resampledata(cfg, data_in);
end

% 2) Build TRL with exact sample counts
ns   = round(win_sec*fs_out);
step = round((1-overlap)*win_sec*fs_out); step = max(step, 1);
n    = size(res.trial{1}, 2);
starts = 1:step:max(1, n-ns+1);
trl = [starts(:) starts(:)+ns-1 zeros(numel(starts),1)];

% 3) Redefine trials with explicit TRL; FieldTrip will set sampleinfo = trl(:,1:2)
cfg = [];
cfg.trl = trl;
out = ft_redefinetrial(cfg, res);

% 4) Final consistency check
out = ft_checkdata(out, 'datatype','raw', 'feedback','no');
end
