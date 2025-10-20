%% UTILITY FUNCTIONS
% Helper functions for data management, BIDS operations, and file handling

function create_output_directories(config)
% CREATE_OUTPUT_DIRECTORIES - Create all output directory structure

fprintf('Creating output directories...\n');

dirs = fieldnames(config.paths);
for i = 1:length(dirs)
    if ~strcmp(dirs{i}, 'root') && ~strcmp(dirs{i}, 'data') && ~strcmp(dirs{i}, 'fieldtrip')
        dir_path = config.paths.(dirs{i});
        if ~exist(dir_path, 'dir')
            mkdir(dir_path);
            fprintf('  Created: %s\n', dir_path);
        end
    end
end

fprintf('Directory structure ready\n');

end

%% BIDS FUNCTIONS
function subjects = discover_subjects(data_path)
% DISCOVER_SUBJECTS - Find all subjects in BIDS dataset

fprintf('Discovering subjects in: %s\n', data_path);

% Find all sub-* directories
sub_dirs = dir(fullfile(data_path, 'sub-*'));
sub_dirs = sub_dirs([sub_dirs.isdir]);

subjects = cell(length(sub_dirs), 1);
for i = 1:length(sub_dirs)
    % Extract subject ID (remove 'sub-' prefix)
    subjects{i} = strrep(sub_dirs(i).name, 'sub-', '');
end

fprintf('Found %d subjects: %s\n', length(subjects), strjoin(subjects, ', '));

end

function metadata = load_bids_metadata(data_path, subject_id)
% LOAD_BIDS_METADATA - Load all BIDS metadata for a subject

fprintf('Loading metadata for subject %s...\n', subject_id);

metadata = struct();
metadata.subject = subject_id;

% Subject directory
sub_dir = fullfile(data_path, sprintf('sub-%s', subject_id), 'eeg');

if ~exist(sub_dir, 'dir')
    error('Subject directory not found: %s', sub_dir);
end

% Load JSON sidecar files
json_files = dir(fullfile(sub_dir, '*.json'));
for i = 1:length(json_files)
    try
        json_data = jsondecode(fileread(fullfile(sub_dir, json_files(i).name)));
        [~, fname, ~] = fileparts(json_files(i).name);
        metadata.json.(fname) = json_data;
    catch ME
        warning('Could not read JSON file: %s', json_files(i).name);
    end
end

% Load TSV files
tsv_files = dir(fullfile(sub_dir, '*.tsv'));
for i = 1:length(tsv_files)
    try
        tsv_data = readtable(fullfile(sub_dir, tsv_files(i).name), 'FileType', 'text');
        [~, fname, ~] = fileparts(tsv_files(i).name);
        metadata.tsv.(fname) = tsv_data;
    catch ME
        warning('Could not read TSV file: %s', tsv_files(i).name);
    end
end

% Load electrodes file if present
electrodes_file = fullfile(sub_dir, sprintf('sub-%s_electrodes.tsv', subject_id));
if exist(electrodes_file, 'file')
    metadata.electrodes = readtable(electrodes_file, 'FileType', 'text');
    fprintf('  Loaded electrode positions\n');
end

% Load coordsystem file
coordsys_file = fullfile(sub_dir, sprintf('sub-%s_coordsystem.json', subject_id));
if exist(coordsys_file, 'file')
    metadata.coordsystem = jsondecode(fileread(coordsys_file));
    fprintf('  Loaded coordinate system info\n');
end

fprintf('Metadata loaded\n');

end

%% QUALITY CONTROL
function qc_results = perform_quality_checks(metadata, config)
% PERFORM_QUALITY_CHECKS - Run QC checks on subject data

fprintf('Running quality control checks...\n');

qc_results = struct();
qc_results.checks_passed = [];
qc_results.checks_failed = [];
qc_results.warnings = {};
qc_results.pass_qc = true;

% Check 1: Sampling rate
if isfield(metadata.json, 'eeg') && isfield(metadata.json.eeg, 'SamplingFrequency')
    srate = metadata.json.eeg.SamplingFrequency;
    
    if srate >= config.qc.expected_srate(1) && srate <= config.qc.expected_srate(2)
        qc_results.checks_passed{end+1} = sprintf('Sampling rate OK: %.1f Hz', srate);
    else
        qc_results.checks_failed{end+1} = sprintf('Sampling rate out of range: %.1f Hz', srate);
        qc_results.warnings{end+1} = 'Unusual sampling rate';
    end
    
    qc_results.sampling_rate = srate;
end

% Check 2: Channel count
if isfield(metadata.tsv, 'channels')
    num_channels = height(metadata.tsv.channels);
    
    if num_channels >= config.qc.min_channels
        qc_results.checks_passed{end+1} = sprintf('Channel count OK: %d', num_channels);
    else
        qc_results.checks_failed{end+1} = sprintf('Too few channels: %d', num_channels);
        qc_results.pass_qc = false;
    end
    
    qc_results.num_channels = num_channels;
    
    % Check for bad channels
    if ismember('status', metadata.tsv.channels.Properties.VariableNames)
        bad_channels = sum(strcmp(metadata.tsv.channels.status, 'bad'));
        qc_results.num_bad_channels = bad_channels;
        
        if bad_channels / num_channels > 0.2
            qc_results.warnings{end+1} = sprintf('High proportion of bad channels: %.1f%%', ...
                100 * bad_channels / num_channels);
        end
    end
end

% Check 3: Events/trials
if isfield(metadata.tsv, 'events')
    num_events = height(metadata.tsv.events);
    
    if num_events >= config.qc.min_trials
        qc_results.checks_passed{end+1} = sprintf('Event count OK: %d', num_events);
    else
        qc_results.warnings{end+1} = sprintf('Low trial count: %d', num_events);
    end
    
    qc_results.num_events = num_events;
end

% Check 4: Recording duration
if isfield(metadata.tsv, 'events') && ismember('duration', metadata.tsv.events.Properties.VariableNames)
    total_duration = sum(metadata.tsv.events.duration);
    qc_results.recording_duration = total_duration;
    
    if total_duration < 60 % Less than 1 minute
        qc_results.warnings{end+1} = 'Very short recording duration';
    end
end

% Summary
qc_results.num_checks_passed = length(qc_results.checks_passed);
qc_results.num_checks_failed = length(qc_results.checks_failed);
qc_results.num_warnings = length(qc_results.warnings);

if qc_results.num_checks_failed > 0
    qc_results.pass_qc = false;
end

fprintf('QC complete: %d passed, %d failed, %d warnings\n', ...
    qc_results.num_checks_passed, qc_results.num_checks_failed, qc_results.num_warnings);

end

function save_qc_report(qc_results, subject_id, config)
% SAVE_QC_REPORT - Save quality control report

report_file = fullfile(config.paths.qc, sprintf('sub-%s_qc_report.txt', subject_id));

fid = fopen(report_file, 'w');

fprintf(fid, '=== QUALITY CONTROL REPORT ===\n');
fprintf(fid, 'Subject: %s\n', subject_id);
fprintf(fid, 'Date: %s\n\n', datestr(now));

fprintf(fid, 'OVERALL STATUS: %s\n\n', ternary(qc_results.pass_qc, 'PASS', 'FAIL'));

fprintf(fid, 'CHECKS PASSED (%d):\n', qc_results.num_checks_passed);
for i = 1:length(qc_results.checks_passed)
    fprintf(fid, '  ✓ %s\n', qc_results.checks_passed{i});
end

fprintf(fid, '\nCHECKS FAILED (%d):\n', qc_results.num_checks_failed);
for i = 1:length(qc_results.checks_failed)
    fprintf(fid, '  ✗ %s\n', qc_results.checks_failed{i});
end

fprintf(fid, '\nWARNINGS (%d):\n', qc_results.num_warnings);
for i = 1:length(qc_results.warnings)
    fprintf(fid, '  ⚠ %s\n', qc_results.warnings{i});
end

fprintf(fid, '\n=== END REPORT ===\n');

fclose(fid);

fprintf('QC report saved: %s\n', report_file);

end

%% STATISTICAL HELPERS
function [h, crit_p, adj_ci_cvrg, adj_p] = fdr_bh(pvals, q, method, report)
% FDR_BH - Benjamini-Hochberg FDR procedure
%
% Usage: [h, crit_p, adj_ci_cvrg, adj_p] = fdr_bh(pvals, q, method, report)
%
% Inputs:
%   pvals  - Vector of p-values
%   q      - FDR level (default: 0.05)
%   method - 'pdep' (positive dependence) or 'dep' (general dependence)
%   report - Boolean, print report (default: false)

if nargin < 2, q = 0.05; end
if nargin < 3, method = 'pdep'; end
if nargin < 4, report = false; end

s = length(pvals);

if s == 0
    h = [];
    crit_p = [];
    adj_ci_cvrg = [];
    adj_p = [];
    return;
end

% Sort p-values
[pvals_sorted, sort_ids] = sort(pvals);

% Compute adjusted p-values
if strcmpi(method, 'pdep')
    % Positive dependence (standard BH)
    adj_p_sorted = pvals_sorted .* s ./ (1:s)';
elseif strcmpi(method, 'dep')
    % General dependence (more conservative)
    c_s = sum(1 ./ (1:s));
    adj_p_sorted = pvals_sorted .* s .* c_s ./ (1:s)';
end

% Ensure monotonicity
for i = s-1:-1:1
    if adj_p_sorted(i) > adj_p_sorted(i+1)
        adj_p_sorted(i) = adj_p_sorted(i+1);
    end
end

% Cap at 1
adj_p_sorted(adj_p_sorted > 1) = 1;

% Unsort
adj_p = zeros(size(pvals));
adj_p(sort_ids) = adj_p_sorted;

% Find critical p-value
rej = pvals_sorted < q .* (1:s)' / s;

if sum(rej) > 0
    max_rej_id = find(rej, 1, 'last');
    crit_p = pvals_sorted(max_rej_id);
else
    crit_p = 0;
end

h = pvals <= crit_p;
adj_ci_cvrg = 1 - q;

if report
    fprintf('FDR Correction (q = %.3f, method = %s)\n', q, method);
    fprintf('  %d/%d hypotheses rejected\n', sum(h), s);
    fprintf('  Critical p-value: %.6f\n', crit_p);
end

end

%% DATA AGGREGATION
function group_results = aggregate_subject_results(spectral_results, connectivity_results, ...
    pac_results, erp_results, subjects)
% AGGREGATE_SUBJECT_RESULTS - Combine results across subjects

fprintf('Aggregating results across subjects...\n');

group_results = struct();

% Spectral results
group_results.spectral = aggregate_spectral(spectral_results, subjects);

% Connectivity results
group_results.connectivity = aggregate_connectivity(connectivity_results, subjects);

% PAC results
group_results.pac = aggregate_pac(pac_results, subjects);

% ERP results
group_results.erp = aggregate_erp(erp_results, subjects);

fprintf('Aggregation complete\n');

end

function spectral_group = aggregate_spectral(spectral_results, subjects)
% Aggregate spectral results

spectral_group = struct();
spectral_group.subjects = subjects;

% Initialize arrays
num_subjects = length(subjects);

% Collect aperiodic exponents
exponents = [];
for s = 1:num_subjects
    if isfield(spectral_results, subjects{s}) && ...
       isfield(spectral_results.(subjects{s}), 'fooof')
        exponents = [exponents; spectral_results.(subjects{s}).fooof.exponent];
    end
end

spectral_group.exponent_mean = mean(exponents, 1);
spectral_group.exponent_std = std(exponents, 0, 1);
spectral_group.exponent_sem = spectral_group.exponent_std / sqrt(size(exponents, 1));

% Collect band powers
bands = {'delta', 'theta', 'alpha', 'beta', 'gamma_low', 'gamma_high'};
for b = 1:length(bands)
    band_name = bands{b};
    band_powers = [];
    
    for s = 1:num_subjects
        if isfield(spectral_results, subjects{s}) && ...
           isfield(spectral_results.(subjects{s}).psd, 'band_power')
            band_powers = [band_powers; spectral_results.(subjects{s}).psd.band_power.(band_name)'];
        end
    end
    
    spectral_group.band_power.(band_name).mean = mean(band_powers, 1);
    spectral_group.band_power.(band_name).std = std(band_powers, 0, 1);
    spectral_group.band_power.(band_name).sem = std(band_powers, 0, 1) / sqrt(size(band_powers, 1));
end

end

function connectivity_group = aggregate_connectivity(connectivity_results, subjects)
% Aggregate connectivity results

connectivity_group = struct();
connectivity_group.subjects = subjects;

% Aggregate Granger causality
theta_gc_all = [];

for s = 1:length(subjects)
    if isfield(connectivity_results, subjects{s}) && ...
       isfield(connectivity_results.(subjects{s}), 'granger')
        theta_gc_all = cat(3, theta_gc_all, connectivity_results.(subjects{s}).granger.theta_gc);
    end
end

if ~isempty(theta_gc_all)
    connectivity_group.granger.theta_mean = mean(theta_gc_all, 3);
    connectivity_group.granger.theta_std = std(theta_gc_all, 0, 3);
end

end

function pac_group = aggregate_pac(pac_results, subjects)
% Aggregate PAC results

pac_group = struct();
pac_group.subjects = subjects;

% Collect MI values
mi_all = [];

for s = 1:length(subjects)
    if isfield(pac_results, subjects{s}) && ...
       isfield(pac_results.(subjects{s}), 'tort')
        mi_all = [mi_all; pac_results.(subjects{s}).tort.theta_gamma_mi];
    end
end

if ~isempty(mi_all)
    pac_group.mi_mean = mean(mi_all, 1);
    pac_group.mi_std = std(mi_all, 0, 1);
    pac_group.mi_sem = pac_group.mi_std / sqrt(size(mi_all, 1));
end

end

function erp_group = aggregate_erp(erp_results, subjects)
% Aggregate ERP results

erp_group = struct();
erp_group.subjects = subjects;

% Collect N2 and P3b latencies
n2_latencies = [];
p3b_latencies = [];

for s = 1:length(subjects)
    if isfield(erp_results, subjects{s})
        if isfield(erp_results.(subjects{s}), 'n2_latency')
            n2_latencies = [n2_latencies; erp_results.(subjects{s}).n2_latency.latency];
        end
        if isfield(erp_results.(subjects{s}), 'p3b_latency')
            p3b_latencies = [p3b_latencies; erp_results.(subjects{s}).p3b_latency.latency];
        end
    end
end

if ~isempty(n2_latencies)
    erp_group.n2.latency_mean = mean(n2_latencies);
    erp_group.n2.latency_std = std(n2_latencies);
    erp_group.n2.latency_sem = std(n2_latencies) / sqrt(length(n2_latencies));
end

if ~isempty(p3b_latencies)
    erp_group.p3b.latency_mean = mean(p3b_latencies);
    erp_group.p3b.latency_std = std(p3b_latencies);
    erp_group.p3b.latency_sem = std(p3b_latencies) / sqrt(length(p3b_latencies));
end

end

%% GROUP STATISTICS
function stats = run_group_statistics(group_data, cfg_stats)
% RUN_GROUP_STATISTICS - Run statistical tests on group-level data

fprintf('Running group-level statistics...\n');

stats = struct();

% Add statistical tests as needed based on specific hypotheses

fprintf('Group statistics complete\n');

end

%% MISCELLANEOUS HELPERS
function result = ternary(condition, if_true, if_false)
% TERNARY - Ternary operator for cleaner conditional assignments

if condition
    result = if_true;
else
    result = if_false;
end

end

function validate_data_structure(data, required_fields)
% VALIDATE_DATA_STRUCTURE - Check that data has required fields

for i = 1:length(required_fields)
    if ~isfield(data, required_fields{i})
        error('Missing required field: %s', required_fields{i});
    end
end

end

function timestamp_str = get_timestamp()
% GET_TIMESTAMP - Get formatted timestamp for filenames

timestamp_str = datestr(now, 'yyyymmdd_HHMMSS');

end

function save_results_safely(filename, varargin)
% SAVE_RESULTS_SAFELY - Save with error handling and compression

try
    save(filename, varargin{:}, '-v7.3');
    fprintf('Saved: %s\n', filename);
catch ME
    warning('Failed to save %s: %s', filename, ME.message);
end

end