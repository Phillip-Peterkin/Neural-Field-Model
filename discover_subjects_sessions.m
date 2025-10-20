function subjects_info = discover_subjects_sessions(data_path)
% DISCOVER_SUBJECTS_SESSIONS - Find all subjects and sessions in BIDS dataset
%
% Only looks for directories matching BIDS format:
%   sub-01/ses-01/, sub-01/ses-02/, etc.
%
% Returns:
%   subjects_info - Structure with fields like 'sub_01' containing 
%                   cell arrays {'ses-01', 'ses-02', ...}

fprintf('Discovering subjects and sessions in: %s\n', data_path);

subjects_info = struct();

% Find all subject directories (sub-*)
subject_dirs = dir(fullfile(data_path, 'sub-*'));
subject_dirs = subject_dirs([subject_dirs.isdir]);

for i = 1:length(subject_dirs)
    subject_name = subject_dirs(i).name;  % e.g., 'sub-01'
    subject_path = fullfile(data_path, subject_name);
    
    % Find session directories (ses-*) ONLY
    session_dirs = dir(fullfile(subject_path, 'ses-*'));
    session_dirs = session_dirs([session_dirs.isdir]);
    
    if isempty(session_dirs)
        fprintf('  %s: No ses-* directories found, skipping\n', subject_name);
        continue;
    end
    
    % Store session names as they appear (ses-01, ses-02, etc.)
    session_list = cell(length(session_dirs), 1);
    for j = 1:length(session_dirs)
        session_list{j} = session_dirs(j).name;  % Keep full name: 'ses-01'
    end
    
    % Convert 'sub-01' to 'sub_01' for MATLAB struct fieldname
    field_name = strrep(subject_name, '-', '_');
    
    % Store the sessions
    subjects_info.(field_name) = session_list;
    
    % Print summary
    fprintf('  %s: %d sessions (%s)\n', subject_name, length(session_list), ...
        strjoin(session_list, ', '));
end

num_subjects = length(fieldnames(subjects_info));
fprintf('Found %d subjects\n', num_subjects);

if num_subjects == 0
    warning('No subjects found! Check your data path: %s', data_path);
end

end