function group_results = aggregate_group_results(results, subjects, config)
% AGGREGATE_GROUP_RESULTS
% Combine individual subject results into group statistics

fprintf('Computing group-level statistics...\n');

group_results = struct();
group_results.n_subjects = length(subjects);
group_results.subjects_included = {};
group_results.subjects_failed = {};

% Filter successful results with all required fields
valid_results = {};
for i = 1:length(results)
    if ~isempty(results{i}) && isfield(results{i}, 'status') && ...
            strcmp(results{i}.status, 'complete') && ...
            isfield(results{i}, 'spectral') && ...
            isfield(results{i}, 'connectivity') && ...
            isfield(results{i}, 'pac')
        valid_results{end+1} = results{i}; %#ok<AGROW>
        group_results.subjects_included{end+1} = subjects{i}; %#ok<AGROW>
    else
        group_results.subjects_failed{end+1} = subjects{i}; %#ok<AGROW>
    end
end

n_valid = length(valid_results);

if n_valid == 0
    warning('GroupAnalysis:NoValidResults', 'No valid subject results for group analysis');
    return;
end

fprintf('  Valid subjects: %d/%d\n', n_valid, length(subjects));

%% Spectral Statistics
fprintf('  → Spectral features...\n');
group_results.spectral = struct();

% Aggregate power spectra
all_spectra = cellfun(@(x) x.spectral.power_spectrum, valid_results, 'UniformOutput', false);
group_results.spectral.mean_spectrum = mean(cat(3, all_spectra{:}), 3);
group_results.spectral.std_spectrum = std(cat(3, all_spectra{:}), 0, 3);

% Aggregate aperiodic slopes
slopes = cellfun(@(x) x.spectral.aperiodic_slope, valid_results);
group_results.spectral.aperiodic_slope_mean = mean(slopes);
group_results.spectral.aperiodic_slope_std = std(slopes);

%% Connectivity Statistics
fprintf('  → Connectivity matrices...\n');
group_results.connectivity = struct();

% Average connectivity matrices per band
bands = fieldnames(valid_results{1}.connectivity.plv_by_band);
for b = 1:length(bands)
    band = bands{b};
    all_plv = cellfun(@(x) x.connectivity.plv_by_band.(band), valid_results, 'UniformOutput', false);
    group_results.connectivity.mean_plv.(band) = mean(cat(3, all_plv{:}), 3);
end

%% PAC Statistics
fprintf('  → Phase-amplitude coupling...\n');
group_results.pac = struct();

pac_values = cellfun(@(x) mean(x.pac.modulation_index(:)), valid_results);
group_results.pac.mean_MI = mean(pac_values);
group_results.pac.std_MI = std(pac_values);

%% Access Detection Statistics
fprintf('  → Access windows...\n');
group_results.access = struct();

n_access_events = cellfun(@(x) x.access.n_events, valid_results);
group_results.access.mean_events_per_subject = mean(n_access_events);
group_results.access.std_events = std(n_access_events);

%% Energy Budget Statistics
fprintf('  → Energy consumption...\n');
group_results.energy = struct();

mean_power = cellfun(@(x) x.energy.total_power, valid_results);
group_results.energy.mean_power_across_subjects = mean(mean_power);
group_results.energy.std_power = std(mean_power);

%% Decoder Performance
fprintf('  → Decoding performance...\n');
group_results.decoder = struct();

setsize_acc = cellfun(@(x) x.decoder.setsize.accuracy, valid_results);
correct_acc = cellfun(@(x) x.decoder.correct.accuracy, valid_results);
match_acc = cellfun(@(x) x.decoder.match.accuracy, valid_results);

group_results.decoder.setsize_accuracy = mean(setsize_acc);
group_results.decoder.correct_accuracy = mean(correct_acc);
group_results.decoder.match_accuracy = mean(match_acc);

fprintf('  ✓ Group analysis complete (%d/%d subjects)\n', n_valid, group_results.n_subjects);

end