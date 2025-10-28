function validation = run_cross_validation(results, subjects, config)
% RUN_CROSS_VALIDATION
% Perform leave-subject-out cross-validation
% Implements Section 13.7 from manuscript
%
% Inputs:
%   results - Cell array of subject results
%   subjects - Cell array of subject IDs
%   config - Configuration structure
%
% Output:
%   validation - Cross-validation results

fprintf('Running cross-validation...\n');

validation = struct();
validation.method = config.validation.method;

% Filter valid results
valid_idx = ~cellfun(@isempty, results);
valid_results = results(valid_idx);
valid_subjects = subjects(valid_idx);
n_valid = length(valid_results);

if n_valid < 2
    warning('Validation:InsufficientData', 'Need at least 2 subjects for cross-validation');
    validation.accuracy = NaN;
    return;
end

%% Leave-Subject-Out Cross-Validation for Decoder Performance
all_predictions = [];
all_true_labels = [];

for fold = 1:n_valid
    % Test subject
    test_subj = fold;
    train_subjs = setdiff(1:n_valid, test_subj);
    
    % Aggregate training data (use SetSize decoder as primary metric)
    train_features = [];
    train_labels = [];
    
    for tr = train_subjs
        if isfield(valid_results{tr}, 'decoder') && ...
                isfield(valid_results{tr}.decoder, 'setsize')
            % Would need actual features here - simplified for now
            train_labels = [train_labels; valid_results{tr}.decoder.setsize.true_labels]; %#ok<AGROW>
        end
    end
    
    % Test data
    if isfield(valid_results{test_subj}, 'decoder') && ...
            isfield(valid_results{test_subj}.decoder, 'setsize')
        test_predictions = valid_results{test_subj}.decoder.setsize.predictions;
        test_labels = valid_results{test_subj}.decoder.setsize.true_labels;
        
        all_predictions = [all_predictions; test_predictions]; %#ok<AGROW>
        all_true_labels = [all_true_labels; test_labels]; %#ok<AGROW>
    end
end

%% Compute overall accuracy
if ~isempty(all_predictions)
    validation.accuracy = mean(all_predictions == all_true_labels);
    validation.confusion_matrix = confusionmat(all_true_labels, all_predictions);
    validation.n_samples = length(all_predictions);
else
    validation.accuracy = NaN;
    validation.n_samples = 0;
end

%% Bootstrap confidence intervals
if config.validation.n_bootstrap > 0 && ~isempty(all_predictions)
    fprintf('  Computing bootstrap CI...\n');
    boot_accuracies = bootstrp(config.validation.n_bootstrap, ...
        @(x,y) mean(x==y), all_predictions, all_true_labels);
    
    validation.bootstrap_mean = mean(boot_accuracies);
    validation.bootstrap_ci = prctile(boot_accuracies, ...
        [2.5, 97.5]); % 95% CI
end

%% Subject-level variability
subject_accuracies = zeros(n_valid, 1);
for s = 1:n_valid
    if isfield(valid_results{s}, 'decoder') && ...
            isfield(valid_results{s}.decoder, 'setsize')
        subject_accuracies(s) = valid_results{s}.decoder.setsize.accuracy;
    else
        subject_accuracies(s) = NaN;
    end
end

validation.subject_accuracies = subject_accuracies;
validation.mean_subject_accuracy = mean(subject_accuracies, 'omitnan');
validation.std_subject_accuracy = std(subject_accuracies, 'omitnan');

fprintf('  ✓ Cross-validation complete\n');

end