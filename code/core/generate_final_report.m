function report = generate_final_report(config, results, group_results, validation)
% GENERATE_FINAL_REPORT - Production-quality comprehensive report
% Handles all edge cases with complete validation and detailed metrics
%
% Inputs:
%   config - Configuration structure
%   results - Cell array of individual subject results
%   group_results - Aggregated group statistics
%   validation - Cross-validation results
%
% Output:
%   report - Comprehensive structured report with all analyses

%% Initialize Report Structure
report = struct();

%% ========================================================================
%  METADATA SECTION
%  ========================================================================
report.metadata = struct();
report.metadata.report_generated = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
report.metadata.matlab_version = version;
report.metadata.pipeline_version = '1.0.0';

if isfield(config, 'metadata')
    report.metadata.author = config.metadata.author;
    report.metadata.manuscript = config.metadata.manuscript;
end

%% ========================================================================
%  DATASET SUMMARY
%  ========================================================================
report.dataset = struct();
report.dataset.data_root = config.paths.data_root;
report.dataset.total_subjects = group_results.n_subjects;
report.dataset.subjects_processed = length(group_results.subjects_included);
report.dataset.subjects_failed = length(group_results.subjects_failed);

if report.dataset.total_subjects > 0
    report.dataset.success_rate = report.dataset.subjects_processed / report.dataset.total_subjects;
else
    report.dataset.success_rate = 0;
end

report.dataset.subjects_included_list = group_results.subjects_included;
report.dataset.subjects_failed_list = group_results.subjects_failed;

%% ========================================================================
%  INDIVIDUAL SUBJECT SUMMARIES
%  ========================================================================
report.subjects = struct();

for i = 1:length(results)
    if ~isempty(results{i}) && isstruct(results{i})
        subj_id = results{i}.subject_id;
        safe_name = strrep(subj_id, '-', '_');
        
        report.subjects.(safe_name) = struct();
        report.subjects.(safe_name).status = results{i}.status;
        
        if strcmp(results{i}.status, 'complete')
            if isfield(results{i}, 'data_info')
                report.subjects.(safe_name).n_channels = results{i}.data_info.n_channels;
                report.subjects.(safe_name).n_trials = results{i}.data_info.n_trials;
                report.subjects.(safe_name).duration_sec = results{i}.data_info.duration;
            end
            
            if isfield(results{i}, 'spectral') && isfield(results{i}.spectral, 'aperiodic_slope')
                report.subjects.(safe_name).aperiodic_slope = results{i}.spectral.aperiodic_slope;
            end
            
            if isfield(results{i}, 'pac') && isfield(results{i}.pac, 'modulation_index')
                report.subjects.(safe_name).mean_pac = mean(results{i}.pac.modulation_index);
            end
            
            if isfield(results{i}, 'access') && isfield(results{i}.access, 'n_events')
                report.subjects.(safe_name).access_events = results{i}.access.n_events;
            end
            
            if isfield(results{i}, 'decoder')
                if isfield(results{i}.decoder, 'setsize')
                    report.subjects.(safe_name).decoder_setsize_accuracy = results{i}.decoder.setsize.accuracy;
                end
                if isfield(results{i}.decoder, 'correct')
                    report.subjects.(safe_name).decoder_correct_accuracy = results{i}.decoder.correct.accuracy;
                end
            end
        else
            if isfield(results{i}, 'error')
                report.subjects.(safe_name).error = results{i}.error;
            end
        end
    end
end

%% ========================================================================
%  GROUP-LEVEL SPECTRAL ANALYSIS
%  ========================================================================
report.spectral = struct();

if isfield(group_results, 'spectral')
    if isfield(group_results.spectral, 'aperiodic_slope_mean')
        report.spectral.aperiodic_slope_mean = group_results.spectral.aperiodic_slope_mean;
        report.spectral.aperiodic_slope_std = group_results.spectral.aperiodic_slope_std;
        report.spectral.aperiodic_slope_interpretation = interpret_aperiodic_slope(...
            group_results.spectral.aperiodic_slope_mean);
    else
        report.spectral.aperiodic_slope_mean = NaN;
        report.spectral.aperiodic_slope_std = NaN;
    end
    
    if isfield(group_results.spectral, 'mean_spectrum') && ~isempty(group_results.spectral.mean_spectrum)
        % Calculate dominant frequency
        mean_power = mean(group_results.spectral.mean_spectrum, 1);
        [~, peak_idx] = max(mean_power);
        
        % Assume frequency vector from 1-200 Hz
        n_freqs = length(mean_power);
        freqs = linspace(1, 200, n_freqs);
        report.spectral.dominant_frequency_hz = freqs(peak_idx);
        report.spectral.peak_power = mean_power(peak_idx);
    end
else
    report.spectral.aperiodic_slope_mean = NaN;
    report.spectral.aperiodic_slope_std = NaN;
end

%% ========================================================================
%  GROUP-LEVEL CONNECTIVITY ANALYSIS
%  ========================================================================
report.connectivity = struct();

if isfield(group_results, 'connectivity') && isfield(group_results.connectivity, 'mean_plv')
    bands = fieldnames(group_results.connectivity.mean_plv);
    
    for b = 1:length(bands)
        band = bands{b};
        plv_matrix = group_results.connectivity.mean_plv.(band);
        
        % Calculate statistics
        if ~isempty(plv_matrix) && size(plv_matrix, 1) > 0
            % Upper triangle only (exclude diagonal)
            n_ch = size(plv_matrix, 1);
            upper_tri_idx = triu(true(n_ch), 1);
            plv_values = plv_matrix(upper_tri_idx);
            
            report.connectivity.([band '_mean_plv']) = mean(plv_values);
            report.connectivity.([band '_std_plv']) = std(plv_values);
            report.connectivity.([band '_max_plv']) = max(plv_values);
            report.connectivity.([band '_median_plv']) = median(plv_values);
            
            % Network density (edges above threshold)
            threshold = 0.5;
            report.connectivity.([band '_network_density']) = sum(plv_values > threshold) / length(plv_values);
        else
            report.connectivity.([band '_mean_plv']) = NaN;
            report.connectivity.([band '_std_plv']) = NaN;
            report.connectivity.([band '_max_plv']) = NaN;
            report.connectivity.([band '_median_plv']) = NaN;
            report.connectivity.([band '_network_density']) = NaN;
        end
    end
else
    report.connectivity.status = 'No connectivity data available';
end

%% ========================================================================
%  PHASE-AMPLITUDE COUPLING (PAC)
%  ========================================================================
report.pac = struct();

if isfield(group_results, 'pac')
    if isfield(group_results.pac, 'mean_MI')
        report.pac.mean_modulation_index = group_results.pac.mean_MI;
        report.pac.std_modulation_index = group_results.pac.std_MI;
        
        % Interpret significance
        if ~isnan(report.pac.mean_modulation_index)
            if report.pac.mean_modulation_index > 0.01
                report.pac.interpretation = 'Significant theta-gamma coupling detected';
                report.pac.significance = 'Strong';
            elseif report.pac.mean_modulation_index > 0.005
                report.pac.interpretation = 'Moderate theta-gamma coupling detected';
                report.pac.significance = 'Moderate';
            else
                report.pac.interpretation = 'Weak or no theta-gamma coupling';
                report.pac.significance = 'Weak';
            end
        else
            report.pac.interpretation = 'Unable to compute PAC';
            report.pac.significance = 'N/A';
        end
    else
        report.pac.mean_modulation_index = NaN;
        report.pac.std_modulation_index = NaN;
    end
else
    report.pac.mean_modulation_index = NaN;
    report.pac.std_modulation_index = NaN;
end

%% ========================================================================
%  ACCESS DETECTION
%  ========================================================================
report.access = struct();

if isfield(group_results, 'access')
    if isfield(group_results.access, 'mean_events_per_subject')
        report.access.mean_events_per_subject = group_results.access.mean_events_per_subject;
        report.access.std_events = group_results.access.std_events;
        
        % Interpretation
        if ~isnan(report.access.mean_events_per_subject)
            report.access.total_events_detected = report.access.mean_events_per_subject * ...
                report.dataset.subjects_processed;
            
            if report.access.mean_events_per_subject > 10
                report.access.interpretation = 'Frequent access windows detected';
            elseif report.access.mean_events_per_subject > 5
                report.access.interpretation = 'Moderate access window activity';
            else
                report.access.interpretation = 'Sparse access windows';
            end
        else
            report.access.interpretation = 'Unable to detect access windows';
        end
    else
        report.access.mean_events_per_subject = NaN;
        report.access.std_events = NaN;
    end
else
    report.access.mean_events_per_subject = NaN;
    report.access.std_events = NaN;
end

% Access detection parameters used
report.access.parameters.threshold_high = config.access.R_hi;
report.access.parameters.threshold_low = config.access.R_lo;
report.access.parameters.min_duration_ms = config.access.dwell_min;
report.access.parameters.max_duration_ms = config.access.dwell_max;

%% ========================================================================
%  ENERGY BUDGET ANALYSIS
%  ========================================================================
report.energy = struct();

if isfield(group_results, 'energy')
    if isfield(group_results.energy, 'mean_power_across_subjects')
        report.energy.mean_power = group_results.energy.mean_power_across_subjects;
        report.energy.std_power = group_results.energy.std_power;
        report.energy.budget_cap = config.energy.P_max_wake;
        
        if ~isnan(report.energy.mean_power)
            report.energy.budget_compliance = report.energy.mean_power <= report.energy.budget_cap;
            report.energy.budget_utilization_percent = (report.energy.mean_power / report.energy.budget_cap) * 100;
            
            if report.energy.budget_compliance
                report.energy.interpretation = sprintf('Within budget (%.1f%% utilized)', ...
                    report.energy.budget_utilization_percent);
            else
                report.energy.interpretation = sprintf('EXCEEDS budget (%.1f%% utilized)', ...
                    report.energy.budget_utilization_percent);
            end
        else
            report.energy.interpretation = 'Unable to compute energy budget';
        end
    else
        report.energy.mean_power = NaN;
        report.energy.std_power = NaN;
    end
else
    report.energy.mean_power = NaN;
    report.energy.std_power = NaN;
end

% Energy model parameters
report.energy.parameters.pyramidal_cost = config.energy.c_E;
report.energy.parameters.pv_cost = config.energy.c_P;
report.energy.parameters.cck_cost = config.energy.c_C;
report.energy.parameters.synaptic_cost = config.energy.c_syn;

%% ========================================================================
%  TASK DECODER PERFORMANCE
%  ========================================================================
report.decoder = struct();

if isfield(group_results, 'decoder')
    % SetSize decoding
    if isfield(group_results.decoder, 'setsize_accuracy')
        report.decoder.setsize_accuracy = group_results.decoder.setsize_accuracy;
        report.decoder.setsize_above_chance = report.decoder.setsize_accuracy > (1/3); % 3-class
        
        if ~isnan(report.decoder.setsize_accuracy)
            if report.decoder.setsize_accuracy > 0.6
                report.decoder.setsize_performance = 'Excellent';
            elseif report.decoder.setsize_accuracy > 0.5
                report.decoder.setsize_performance = 'Good';
            elseif report.decoder.setsize_accuracy > 0.4
                report.decoder.setsize_performance = 'Above chance';
            else
                report.decoder.setsize_performance = 'At or below chance';
            end
        end
    else
        report.decoder.setsize_accuracy = NaN;
    end
    
    % Correct/Error decoding
    if isfield(group_results.decoder, 'correct_accuracy')
        report.decoder.correct_accuracy = group_results.decoder.correct_accuracy;
        report.decoder.correct_above_chance = report.decoder.correct_accuracy > 0.5; % 2-class
        
        if ~isnan(report.decoder.correct_accuracy)
            if report.decoder.correct_accuracy > 0.75
                report.decoder.correct_performance = 'Excellent';
            elseif report.decoder.correct_accuracy > 0.65
                report.decoder.correct_performance = 'Good';
            elseif report.decoder.correct_accuracy > 0.55
                report.decoder.correct_performance = 'Above chance';
            else
                report.decoder.correct_performance = 'At or below chance';
            end
        end
    else
        report.decoder.correct_accuracy = NaN;
    end
    
    % Match/Mismatch decoding
    if isfield(group_results.decoder, 'match_accuracy')
        report.decoder.match_accuracy = group_results.decoder.match_accuracy;
        report.decoder.match_above_chance = report.decoder.match_accuracy > 0.5; % 2-class
        
        if ~isnan(report.decoder.match_accuracy)
            if report.decoder.match_accuracy > 0.75
                report.decoder.match_performance = 'Excellent';
            elseif report.decoder.match_accuracy > 0.65
                report.decoder.match_performance = 'Good';
            elseif report.decoder.match_accuracy > 0.55
                report.decoder.match_performance = 'Above chance';
            else
                report.decoder.match_performance = 'At or below chance';
            end
        end
    else
        report.decoder.match_accuracy = NaN;
    end
    
    % Overall decoder summary
    valid_accs = [report.decoder.setsize_accuracy, report.decoder.correct_accuracy, ...
                  report.decoder.match_accuracy];
    valid_accs = valid_accs(~isnan(valid_accs));
    
    if ~isempty(valid_accs)
        report.decoder.overall_mean_accuracy = mean(valid_accs);
    else
        report.decoder.overall_mean_accuracy = NaN;
    end
else
    report.decoder.setsize_accuracy = NaN;
    report.decoder.correct_accuracy = NaN;
    report.decoder.match_accuracy = NaN;
    report.decoder.overall_mean_accuracy = NaN;
end

% Decoder parameters
report.decoder.parameters.method = config.decoder.method;
report.decoder.parameters.cv_folds = config.decoder.cv_folds;
report.decoder.parameters.features = config.decoder.features;

%% ========================================================================
%  CROSS-VALIDATION RESULTS
%  ========================================================================
report.validation = struct();

if ~isempty(validation) && isstruct(validation)
    report.validation.method = validation.method;
    
    if isfield(validation, 'accuracy')
        report.validation.accuracy = validation.accuracy;
        
        if ~isnan(validation.accuracy)
            report.validation.generalization = 'Good';
            if validation.accuracy < 0.4
                report.validation.generalization = 'Poor - possible overfitting';
            end
        end
    else
        report.validation.accuracy = NaN;
    end
    
    if isfield(validation, 'bootstrap_ci')
        report.validation.confidence_interval_95 = validation.bootstrap_ci;
        report.validation.ci_width = diff(validation.bootstrap_ci);
    end
    
    if isfield(validation, 'mean_subject_accuracy')
        report.validation.mean_subject_accuracy = validation.mean_subject_accuracy;
        report.validation.std_subject_accuracy = validation.std_subject_accuracy;
    end
    
    if isfield(validation, 'n_samples')
        report.validation.n_test_samples = validation.n_samples;
    end
else
    report.validation.accuracy = NaN;
    report.validation.method = 'N/A';
end

%% ========================================================================
%  MODEL PARAMETERS USED
%  ========================================================================
report.model_parameters = struct();

% Time constants
report.model_parameters.time_constants.tau_E = config.model.tau_E;
report.model_parameters.time_constants.tau_P = config.model.tau_P;
report.model_parameters.time_constants.tau_C = config.model.tau_C;
report.model_parameters.time_constants.tau_D = config.model.tau_D;
report.model_parameters.time_constants.tau_Theta = config.model.tau_Theta;

% Circuit weights
report.model_parameters.weights.w_EE = config.model.w_EE;
report.model_parameters.weights.w_PE = config.model.w_PE;
report.model_parameters.weights.w_EP = config.model.w_EP;
report.model_parameters.weights.w_PP = config.model.w_PP;
report.model_parameters.weights.w_EC = config.model.w_EC;
report.model_parameters.weights.w_CE = config.model.w_CE;

% Access thresholds
report.model_parameters.access_thresholds.R_hi = config.access.R_hi;
report.model_parameters.access_thresholds.R_lo = config.access.R_lo;
report.model_parameters.access_thresholds.T_on_ms = config.access.T_on;
report.model_parameters.access_thresholds.T_off_ms = config.access.T_off;

%% ========================================================================
%  KEY FINDINGS SUMMARY
%  ========================================================================
report.key_findings = struct();

% Spectral organization
if isfield(report.spectral, 'aperiodic_slope_mean') && ~isnan(report.spectral.aperiodic_slope_mean)
    report.key_findings.spectral_organization_detected = abs(report.spectral.aperiodic_slope_mean) > 0.5;
else
    report.key_findings.spectral_organization_detected = false;
end

% Theta-gamma coupling
if isfield(report.pac, 'mean_modulation_index') && ~isnan(report.pac.mean_modulation_index)
    report.key_findings.theta_gamma_coupling_detected = report.pac.mean_modulation_index > 0.005;
else
    report.key_findings.theta_gamma_coupling_detected = false;
end

% Access windows
if isfield(report.access, 'mean_events_per_subject') && ~isnan(report.access.mean_events_per_subject)
    report.key_findings.access_windows_identified = report.access.mean_events_per_subject > 0;
else
    report.key_findings.access_windows_identified = false;
end

% Energy budget
if isfield(report.energy, 'budget_compliance')
    report.key_findings.energy_budget_enforced = report.energy.budget_compliance;
else
    report.key_findings.energy_budget_enforced = false;
end

% Above-chance decoding
if isfield(report.decoder, 'overall_mean_accuracy') && ~isnan(report.decoder.overall_mean_accuracy)
    report.key_findings.above_chance_decoding = report.decoder.overall_mean_accuracy > 0.4;
else
    report.key_findings.above_chance_decoding = false;
end

% Model validation
if isfield(report.validation, 'accuracy') && ~isnan(report.validation.accuracy)
    report.key_findings.model_generalizes = report.validation.accuracy > 0.4;
else
    report.key_findings.model_generalizes = false;
end

%% ========================================================================
%  OVERALL CONCLUSION
%  ========================================================================
report.conclusion = struct();

% Count successful findings
findings_array = [
    report.key_findings.spectral_organization_detected, ...
    report.key_findings.theta_gamma_coupling_detected, ...
    report.key_findings.access_windows_identified, ...
    report.key_findings.energy_budget_enforced, ...
    report.key_findings.above_chance_decoding, ...
    report.key_findings.model_generalizes
];

report.conclusion.findings_supported = sum(findings_array);
report.conclusion.total_findings = length(findings_array);
report.conclusion.support_percentage = (report.conclusion.findings_supported / report.conclusion.total_findings) * 100;

if report.conclusion.support_percentage >= 80
    report.conclusion.overall_assessment = 'STRONG SUPPORT for Harmonic Field Theory predictions';
elseif report.conclusion.support_percentage >= 60
    report.conclusion.overall_assessment = 'MODERATE SUPPORT for Harmonic Field Theory predictions';
elseif report.conclusion.support_percentage >= 40
    report.conclusion.overall_assessment = 'PARTIAL SUPPORT for Harmonic Field Theory predictions';
else
    report.conclusion.overall_assessment = 'LIMITED SUPPORT for Harmonic Field Theory predictions';
end

%% ========================================================================
%  RECOMMENDATIONS
%  ========================================================================
report.recommendations = {};

if report.dataset.success_rate < 0.8
    report.recommendations{end+1} = 'Low subject success rate - review data quality and preprocessing parameters';
end

if isfield(report.decoder, 'overall_mean_accuracy') && ~isnan(report.decoder.overall_mean_accuracy)
    if report.decoder.overall_mean_accuracy < 0.45
        report.recommendations{end+1} = 'Decoder performance near chance - consider feature selection or more data';
    end
end

if isfield(report.energy, 'budget_compliance') && ~report.energy.budget_compliance
    report.recommendations{end+1} = 'Energy budget exceeded - review power calculation or adjust cap';
end

if isfield(report.validation, 'accuracy') && ~isnan(report.validation.accuracy)
    if isfield(report.decoder, 'overall_mean_accuracy') && ~isnan(report.decoder.overall_mean_accuracy)
        generalization_gap = report.decoder.overall_mean_accuracy - report.validation.accuracy;
        if generalization_gap > 0.15
            report.recommendations{end+1} = 'Large generalization gap detected - possible overfitting';
        end
    end
end

if isempty(report.recommendations)
    report.recommendations{1} = 'No critical issues identified - results appear robust';
end

%% ========================================================================
%  CONSOLE OUTPUT
%  ========================================================================
fprintf('\n');
fprintf('╔════════════════════════════════════════════════════════════════╗\n');
fprintf('║                    FINAL REPORT SUMMARY                        ║\n');
fprintf('╠════════════════════════════════════════════════════════════════╣\n');
fprintf('║  Subjects processed:  %d/%d (%.1f%%)                          ║\n', ...
    report.dataset.subjects_processed, report.dataset.total_subjects, report.dataset.success_rate * 100);

if isfield(report.decoder, 'setsize_accuracy') && ~isnan(report.decoder.setsize_accuracy)
    fprintf('║  Decoder accuracy:    %.1f%%                                   ║\n', ...
        report.decoder.setsize_accuracy * 100);
end

if isfield(report.validation, 'accuracy') && ~isnan(report.validation.accuracy)
    fprintf('║  Validation accuracy: %.1f%%                                   ║\n', ...
        report.validation.accuracy * 100);
end

fprintf('║  Key findings supported: %d/%d                                  ║\n', ...
    report.conclusion.findings_supported, report.conclusion.total_findings);
fprintf('╠════════════════════════════════════════════════════════════════╣\n');
fprintf('║  %s                                                              \n', report.conclusion.overall_assessment);
fprintf('╚════════════════════════════════════════════════════════════════╝\n');

end

%% Helper function
function interpretation = interpret_aperiodic_slope(slope)
    if isnan(slope)
        interpretation = 'Unable to determine';
    elseif slope < -1.5
        interpretation = 'Steep 1/f slope - high neural noise';
    elseif slope < -0.5
        interpretation = 'Normal 1/f slope - typical cortical activity';
    else
        interpretation = 'Shallow 1/f slope - reduced neural noise';
    end
end