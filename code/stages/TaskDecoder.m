classdef TaskDecoder < handle
    % TASKDECODER - Production-quality task classification
    % Handles missing fields, validates data, provides detailed diagnostics
    
    properties
        config
    end
    
    methods
        function obj = TaskDecoder(config)
            obj.config = config;
        end
        
        function results = decode_all_conditions(obj, trials, events)
            % DECODE_ALL_CONDITIONS - Safe multi-condition decoding
            
            results = struct();
            
            % Validate inputs
            if isempty(trials) || isempty(events)
                warning('TaskDecoder:NoData', 'No trials or events provided');
                results = obj.create_empty_results();
                return;
            end
            
            % Check if events table has required columns
            available_columns = events.Properties.VariableNames;
            fprintf('  Available event columns: %s\n', strjoin(available_columns, ', '));
            
            %% Extract features
            try
                features = obj.extract_features(trials);
                fprintf('  ✓ Features extracted: %d trials × %d features\n', size(features));
            catch ME
                warning('TaskDecoder:FeatureExtractionFailed', 'Feature extraction failed: %s', ME.message);
                results = obj.create_empty_results();
                return;
            end
            
            %% Decode SetSize (4 vs 6 vs 8 items)
            if obj.config.decoder.decode_setsize && ismember('SetSize', available_columns)
                try
                    setsize_labels = events.SetSize;
                    results.setsize = obj.decode_condition(features, setsize_labels, 'SetSize');
                    fprintf('  ✓ SetSize decoded: %.1f%% accuracy\n', results.setsize.accuracy * 100);
                catch ME
                    warning('TaskDecoder:SetSizeFailed', 'SetSize decoding failed: %s', ME.message);
                    results.setsize = obj.create_empty_result_struct('SetSize');
                end
            else
                fprintf('  ⊘ SetSize decoding skipped (column not found or disabled)\n');
                results.setsize = obj.create_empty_result_struct('SetSize');
            end
            
            %% Decode Correct vs Error
            if obj.config.decoder.decode_correct && ismember('Correct', available_columns)
                try
                    correct_labels = events.Correct;
                    results.correct = obj.decode_condition(features, correct_labels, 'Correct');
                    fprintf('  ✓ Correct/Error decoded: %.1f%% accuracy\n', results.correct.accuracy * 100);
                catch ME
                    warning('TaskDecoder:CorrectFailed', 'Correct decoding failed: %s', ME.message);
                    results.correct = obj.create_empty_result_struct('Correct');
                end
            else
                fprintf('  ⊘ Correct decoding skipped (column not found or disabled)\n');
                results.correct = obj.create_empty_result_struct('Correct');
            end
            
            %% Decode Match (IN vs OUT)
            if obj.config.decoder.decode_match && ismember('Match', available_columns)
                try
                    % Handle string matching
                    if iscell(events.Match)
                        match_labels = double(strcmp(events.Match, 'IN'));
                    elseif ischar(events.Match) || isstring(events.Match)
                        match_labels = double(events.Match == "IN");
                    else
                        match_labels = events.Match;
                    end
                    results.match = obj.decode_condition(features, match_labels, 'Match');
                    fprintf('  ✓ Match decoded: %.1f%% accuracy\n', results.match.accuracy * 100);
                catch ME
                    warning('TaskDecoder:MatchFailed', 'Match decoding failed: %s', ME.message);
                    results.match = obj.create_empty_result_struct('Match');
                end
            else
                fprintf('  ⊘ Match decoding skipped (column not found or disabled)\n');
                results.match = obj.create_empty_result_struct('Match');
            end
        end
        
        function features = extract_features(obj, trials)
            % EXTRACT_FEATURES - Robust feature extraction from trials
            
            n_trials = length(trials);
            
            if n_trials == 0
                error('TaskDecoder:NoTrials', 'No trials to extract features from');
            end
            
            % Get dimensions from first trial
            n_channels = size(trials{1}.signal, 1);
            srate = 1 / (trials{1}.time(2) - trials{1}.time(1));
            
            % Get time windows
            cfg = obj.config.decoder;
            
            % Use maintenance window (2-6s is critical for working memory)
            maint_idx = trials{1}.time >= cfg.maintenance_window(1) & ...
                trials{1}.time <= cfg.maintenance_window(2);
            
            % Extract band power during maintenance
            bands = fieldnames(obj.config.spectral.bands);
            n_bands = length(bands);
            
            % Feature matrix: [trials × (channels × bands)]
            n_features = n_channels * n_bands;
            features = zeros(n_trials, n_features);
            
            fprintf('  Extracting features: %d trials × %d channels × %d bands\n', ...
                n_trials, n_channels, n_bands);
            
            for t = 1:n_trials
                if isempty(trials{t}.signal)
                    warning('TaskDecoder:EmptyTrial', 'Trial %d is empty, using zeros', t);
                    continue;
                end
                
                trial_signal = trials{t}.signal(:, maint_idx);
                
                if isempty(trial_signal)
                    warning('TaskDecoder:EmptyMaintenanceWindow', 'Trial %d has no data in maintenance window', t);
                    continue;
                end
                
                feat_idx = 1;
                for b = 1:n_bands
                    band_name = bands{b};
                    band_range = obj.config.spectral.bands.(band_name);
                    
                    % Compute band power for each channel
                    for ch = 1:n_channels
                        try
                            % Use pwelch for power estimation
                            window_length = min(size(trial_signal, 2), round(srate));
                            [pxx, f] = pwelch(trial_signal(ch, :), ...
                                hann(window_length), [], [], srate);
                            
                            % Get band power
                            band_mask = f >= band_range(1) & f <= band_range(2);
                            if sum(band_mask) > 0
                                features(t, feat_idx) = mean(pxx(band_mask));
                            else
                                features(t, feat_idx) = 0;
                            end
                        catch
                            features(t, feat_idx) = 0;
                        end
                        feat_idx = feat_idx + 1;
                    end
                end
            end
            
            % Remove NaN and Inf
            features(isnan(features)) = 0;
            features(isinf(features)) = 0;
            
            % Normalize features (z-score)
            features = zscore(features);
            features(isnan(features)) = 0; % Handle constant features
        end
        
        function result = decode_condition(obj, features, labels, condition_name)
            % DECODE_CONDITION - Cross-validated classification
            
            cfg = obj.config.decoder;
            
            % Convert labels to numeric if needed
            if iscell(labels)
                unique_labels = unique(labels);
                numeric_labels = zeros(length(labels), 1);
                for i = 1:length(unique_labels)
                    numeric_labels(strcmp(labels, unique_labels{i})) = i;
                end
                labels = numeric_labels;
            elseif islogical(labels)
                labels = double(labels);
            end
            
            % Remove trials with missing labels
            valid_idx = ~isnan(labels) & labels > 0;
            features = features(valid_idx, :);
            labels = labels(valid_idx);
            
            if isempty(features) || length(unique(labels)) < 2
                warning('TaskDecoder:InsufficientData', ...
                    'Insufficient data for %s decoding', condition_name);
                result = obj.create_empty_result_struct(condition_name);
                return;
            end
            
            n_trials = size(features, 1);
            
            % Cross-validation
            cv = cvpartition(n_trials, 'KFold', cfg.cv_folds);
            predictions = zeros(n_trials, 1);
            true_labels = labels;
            
            for fold = 1:cfg.cv_folds
                train_idx = training(cv, fold);
                test_idx = test(cv, fold);
                
                if sum(train_idx) == 0 || sum(test_idx) == 0
                    continue;
                end
                
                try
                    % Train linear SVM
                    mdl = fitclinear(features(train_idx, :), labels(train_idx), ...
                        'Learner', 'svm', 'Regularization', 'ridge');
                    
                    % Predict
                    predictions(test_idx) = predict(mdl, features(test_idx, :));
                catch ME
                    warning('TaskDecoder:FoldFailed', 'Fold %d failed: %s', fold, ME.message);
                    continue;
                end
            end
            
            % Compute metrics
            result = struct();
            result.condition_name = condition_name;
            result.accuracy = mean(predictions == true_labels);
            result.predictions = predictions;
            result.true_labels = true_labels;
            result.n_trials = n_trials;
            result.n_classes = length(unique(true_labels));
            
            % Confusion matrix
            try
                result.confusion_matrix = confusionmat(true_labels, predictions);
            catch
                result.confusion_matrix = [];
            end
            
            % Compute mutual information
            result.mutual_information = obj.compute_mutual_information(true_labels, predictions);
            
            % Per-class accuracy
            unique_labels = unique(true_labels);
            result.per_class_accuracy = zeros(length(unique_labels), 1);
            for i = 1:length(unique_labels)
                class_idx = true_labels == unique_labels(i);
                if sum(class_idx) > 0
                    result.per_class_accuracy(i) = mean(predictions(class_idx) == true_labels(class_idx));
                end
            end
        end
        
        function MI = compute_mutual_information(~, true_labels, predictions)
            % COMPUTE_MUTUAL_INFORMATION - Information-theoretic metric
            
            try
                unique_true = unique(true_labels);
                unique_pred = unique(predictions);
                
                n_true = length(unique_true);
                n_pred = length(unique_pred);
                n_total = length(true_labels);
                
                % Joint probability
                joint_prob = zeros(n_true, n_pred);
                for i = 1:n_true
                    for j = 1:n_pred
                        joint_prob(i, j) = sum(true_labels == unique_true(i) & ...
                            predictions == unique_pred(j)) / n_total;
                    end
                end
                
                % Marginal probabilities
                p_true = sum(joint_prob, 2);
                p_pred = sum(joint_prob, 1);
                
                % Mutual information
                MI = 0;
                for i = 1:n_true
                    for j = 1:n_pred
                        if joint_prob(i, j) > 0
                            MI = MI + joint_prob(i, j) * log2(joint_prob(i, j) / ...
                                (p_true(i) * p_pred(j)));
                        end
                    end
                end
            catch
                MI = NaN;
            end
        end
        
        function result = create_empty_result_struct(~, condition_name)
            % CREATE_EMPTY_RESULT_STRUCT - Default structure when decoding fails
            
            result = struct();
            result.condition_name = condition_name;
            result.accuracy = NaN;
            result.predictions = [];
            result.true_labels = [];
            result.confusion_matrix = [];
            result.mutual_information = NaN;
            result.n_trials = 0;
            result.n_classes = 0;
            result.per_class_accuracy = [];
            result.status = 'failed';
        end
        
        function results = create_empty_results(obj)
            % CREATE_EMPTY_RESULTS - Complete empty results structure
            
            results = struct();
            results.setsize = obj.create_empty_result_struct('SetSize');
            results.correct = obj.create_empty_result_struct('Correct');
            results.match = obj.create_empty_result_struct('Match');
        end
    end
end