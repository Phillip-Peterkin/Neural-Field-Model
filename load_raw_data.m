function data_out = load_raw_data(data_path, subject_id, session_id, config)
% LOAD_RAW_DATA  Robust BIDS EEG iEEG loader with smart ID handling,
% modality preference, and FieldTrip first with EEGLAB fallback.

%% 0) Normalize IDs
sub_id = normalize_id(subject_id);      % '01' from 'sub_01' or '01'
ses_id = normalize_id(session_id);      % '' if none or '01' from 'ses-01'

%% 1) Resolve BIDS path
if isempty(ses_id)
    sub_dir = fullfile(data_path, ['sub-' sub_id]);
else
    sub_dir = fullfile(data_path, ['sub-' sub_id], ['ses-' ses_id]);
end
assert(exist(sub_dir,'dir') == 7, 'Session folder not found: %s', sub_dir);
fprintf('Resolved session path: %s\n', sub_dir);

ieeg_dir = fullfile(sub_dir, 'ieeg');
eeg_dir  = fullfile(sub_dir, 'eeg');

%% 2) Build candidate list in priority order
prio = { ...
    fullfile(ieeg_dir, '*_ieeg.vhdr'),  fullfile(ieeg_dir, '*.vhdr'), ...
    fullfile(ieeg_dir, '*_ieeg.edf'),   fullfile(ieeg_dir, '*.edf'), ...
    fullfile(eeg_dir,  '*_eeg.vhdr'),   fullfile(eeg_dir,  '*.vhdr'), ...
    fullfile(eeg_dir,  '*_eeg.edf'),    fullfile(eeg_dir,  '*.edf'), ...
    fullfile(sub_dir,  '*.set') };

cand = list_first_existing(prio);
if isempty(cand)
    error('No candidate recordings found under %s', sub_dir);
end

% Stable sort and prefer run-01
[~,ix] = sort({cand.name});
cand = cand(ix);
idx = 1:numel(cand);
r1  = find(contains({cand.name}, 'run-01', 'IgnoreCase', true), 1);
if ~isempty(r1)
    idx = [r1, setdiff(idx, r1, 'stable')];
    cand = cand(idx);
end

%% 3) Import: FieldTrip first, then EEGLAB, try next file if needed
lastErr = [];
chosen = '';
used = '';
for c = 1:numel(cand)
    f = fullfile(cand(c).folder, cand(c).name);
    try
        cfg = struct('dataset', f, 'continuous', 'yes');
        if endsWith(f,'.vhdr','IgnoreCase',true)
            cfg.dataformat = 'brainvision_eeg';
        elseif endsWith(f,'.edf','IgnoreCase',true)
            cfg.dataformat = 'edf';
        elseif endsWith(f,'.set','IgnoreCase',true)
            cfg.dataformat = 'eeglab_set';
        else
            continue
        end
        fprintf('Trying FieldTrip on %s\n', f);
        data_out = ft_preprocessing(cfg);
        chosen = f; used = 'FieldTrip';
        break
    catch ME
        fprintf('FieldTrip failed on %s: %s\n', f, ME.message);
        lastErr = ME;
        % EEGLAB fallback
        try
            EEG = [];
            if endsWith(f,'.vhdr','IgnoreCase',true)
                [p,n,e] = fileparts(f);
                EEG = pop_loadbv(p, [n e], [], []);
            elseif endsWith(f,'.edf','IgnoreCase',true)
                EEG = pop_biosig(f, [], 'importevent','off', 'importannot','off');
            elseif endsWith(f,'.set','IgnoreCase',true)
                EEG = pop_loadset('filename', f);
            end
            if ~isempty(EEG)
                data_out = eeglab2fieldtrip(EEG, 'preprocessing', 'none');
                chosen = f; used = 'EEGLAB';
                break
            end
        catch ME2
            fprintf('EEGLAB failed on %s: %s\n', f, ME2.message);
            lastErr = ME2;
        end
    end
end

if isempty(chosen)
    error('All import attempts failed. Last error: %s', lastErr.message);
end

%% 4) Load sidecars from the chosen folder
parent_dir = fileparts(chosen);
evf = dir(fullfile(parent_dir, '*_events.tsv'));
chf = dir(fullfile(parent_dir, '*_channels.tsv'));

if ~isempty(evf)
    try
        data_out.events = readtable(fullfile(evf(1).folder, evf(1).name), ...
                                    'FileType','text', 'Delimiter','\t');
        fprintf('Loaded %d events\n', height(data_out.events));
    catch ME
        warning('Could not read events file: %s', ME.message);
    end
end

if ~isempty(chf)
    try
        data_out.channel_info = readtable(fullfile(chf(1).folder, chf(1).name), ...
                                          'FileType','text', 'Delimiter','\t');
        fprintf('Loaded channel table with %d rows\n', height(data_out.channel_info));
    catch ME
        warning('Could not read channels file: %s', ME.message);
    end
end

%% 5) Annotate and report
data_out.subject = ['sub-' sub_id];
data_out.session = ternary(isempty(ses_id), '', ['ses-' ses_id]);
fprintf('Loaded %d channels at %.1f Hz using %s\n', numel(data_out.label), data_out.fsample, used);
end

%% ===== Helpers =====
function id = normalize_id(x)
if isempty(x) || strcmpi(x,'none'), id = ''; return; end
x = string(x);
x = regexprep(x, '^\s+|\s+$', '');
x = regexprep(x, '(?i)^(sub|ses)[-_]?', '');
if all(isstrprop(x,'digit')) && strlength(x) < 2
    x = compose('%02d', str2double(x));
end
id = char(x);
end

function out = list_first_existing(patterns)
out = struct('name',{},'folder',{},'date',{},'bytes',{},'isdir',{},'datenum',{});
for i = 1:numel(patterns)
    d = dir(patterns{i});
    if ~isempty(d)
        bad = endsWith({d.name}, {'.crswap','.tmp','.part'}, 'IgnoreCase', true);
        d = d(~bad);
        out = [out; d]; %#ok<AGROW>
    end
end
end

function y = ternary(cond, a, b)
if cond, y = a; else, y = b; end
end
