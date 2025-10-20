% TEST_DATA_STRUCTURE - Test loading with sessions
clearvars; close all; clc;

fprintf('\n=== TESTING DATA STRUCTURE ===\n\n');

% Discover structure
data_path = 'C:\openneuro\ds004752';
[subjects, sessions] = discover_subjects_sessions(data_path);

% Show structure
sub_names = fieldnames(subjects);
fprintf('\nDataset Structure:\n');
fprintf('------------------\n');
for i = 1:length(sub_names)
    sub_id = strrep(sub_names{i}, 'sub_', '');
    ses_list = sessions.(sub_names{i});
    fprintf('sub-%s: %d sessions (', sub_id, length(ses_list));
    for j = 1:length(ses_list)
        fprintf('%s', ses_list{j});
        if j < length(ses_list), fprintf(', '); end
    end
    fprintf(')\n');
end

% Try loading one subject-session
fprintf('\n=== TESTING DATA LOADING ===\n\n');
try
    config = initialize_analysis_config();
    
    % Get first subject and first session
    first_sub = strrep(sub_names{1}, 'sub_', '');
    first_ses = sessions.(sub_names{1}){1};
    
    fprintf('Attempting to load sub-%s, ses-%s...\n', first_sub, first_ses);
    data = load_raw_data(data_path, first_sub, first_ses, config);
    
    fprintf('\n✓ SUCCESS!\n');
    fprintf('Channels: %d\n', length(data.label));
    fprintf('Sampling rate: %.1f Hz\n', data.fsample);
    if isfield(data, 'events')
        fprintf('Events: %d\n', height(data.events));
    end
catch ME
    fprintf('\n✗ FAILED: %s\n', ME.message);
    fprintf('Stack trace:\n');
    for k = 1:length(ME.stack)
        fprintf('  %s (line %d)\n', ME.stack(k).name, ME.stack(k).line);
    end
end
