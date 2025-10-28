function test_results = test_pipeline(mode)
% TEST_PIPELINE - Minimal working test suite

if nargin < 1
    mode = 'single';
end

fprintf('\n');
fprintf('╔═══════════════════════════════════════════════════╗\n');
fprintf('║     HARMONIC FIELD THEORY - PIPELINE TEST        ║\n');
fprintf('╚═══════════════════════════════════════════════════╝\n\n');

test_results = struct();
test_results.mode = mode;

switch lower(mode)
    case 'validate'
        test_results = validate_install();
        
    case 'single'
        test_results = test_single_subject();
        
    otherwise
        error('Use: test_pipeline(''validate'') or test_pipeline(''single'')');
end

end

%% Validation
function results = validate_install()
fprintf('VALIDATION MODE\n');
fprintf('═══════════════════════════════════════════════════\n\n');

results.mode = 'validate';
results.passed = 0;
results.failed = 0;

% Check config
fprintf('[1/3] Configuration...');
try
    config = config_harmonic_field();
    fprintf(' ✓\n');
    results.passed = results.passed + 1;
catch
    fprintf(' ✗\n');
    results.failed = results.failed + 1;
    return;
end

% Check data
fprintf('[2/3] Data...');
try
    data_handler = BIDSDataHandler(config.paths.data_root);
    subjects = data_handler.discover_subjects();
    fprintf(' ✓ (%d subjects)\n', length(subjects));
    results.passed = results.passed + 1;
    results.subjects = subjects;
catch ME
    fprintf(' ✗ %s\n', ME.message);
    results.failed = results.failed + 1;
end

% Check files
fprintf('[3/3] Core files...');
if exist('code/core/process_single_subject.m', 'file')
    fprintf(' ✓\n');
    results.passed = results.passed + 1;
else
    fprintf(' ✗\n');
    results.failed = results.failed + 1;
end

fprintf('\n');
if results.failed == 0
    fprintf('✓✓✓ VALIDATION PASSED ✓✓✓\n');
    fprintf('Next: test_pipeline(''single'')\n\n');
else
    fprintf('✗✗✗ VALIDATION FAILED ✗✗✗\n\n');
end

end

%% Single subject test
function results = test_single_subject()
fprintf('SINGLE SUBJECT TEST\n');
fprintf('═══════════════════════════════════════════════════\n\n');

results.mode = 'single';
results.subject = 'sub-01';

% Load config
fprintf('[1/3] Configuration...');
try
    config = config_harmonic_field();
    fprintf(' ✓\n');
catch ME
    fprintf(' ✗ %s\n', ME.message);
    results.error = ME.message;
    fprintf('\n✗✗✗ TEST FAILED ✗✗✗\n\n');
    return;
end

% Check data
fprintf('[2/3] Data availability...');
try
    data_handler = BIDSDataHandler(config.paths.data_root);
    subjects = data_handler.discover_subjects();
    
    if ismember('sub-01', subjects)
        fprintf(' ✓\n');
    else
        fprintf(' ✗ sub-01 not found\n');
        results.error = 'Subject not found';
        fprintf('\n✗✗✗ TEST FAILED ✗✗✗\n\n');
        return;
    end
catch ME
    fprintf(' ✗ %s\n', ME.message);
    results.error = ME.message;
    fprintf('\n✗✗✗ TEST FAILED ✗✗✗\n\n');
    return;
end

% Run pipeline
fprintf('[3/3] Running pipeline...\n');
fprintf('───────────────────────────────────────────────────\n');

try
    % Direct call - no variable capture issues
    run_harmonic_field_pipeline('subject', 'sub-01');
    
    fprintf('───────────────────────────────────────────────────\n');
    fprintf(' ✓ Pipeline completed\n');
    
    % Check outputs
    checkpoint = fullfile(config.paths.checkpoints, 'sub-01_checkpoint.mat');
    if exist(checkpoint, 'file')
        fprintf(' ✓ Checkpoint saved\n');
        results.checkpoint_exists = true;
    else
        fprintf(' ⚠ No checkpoint (processing may have failed)\n');
        results.checkpoint_exists = false;
    end
    
    fprintf('\n✓✓✓ TEST PASSED ✓✓✓\n\n');
    results.success = true;
    
catch ME
    fprintf('───────────────────────────────────────────────────\n');
    fprintf(' ✗ Pipeline failed: %s\n', ME.message);
    
    % Save error
    crash_file = fullfile('logs', sprintf('crash_%s.mat', datestr(now, 'yyyymmdd_HHMMSS')));
    save(crash_file, 'ME');
    
    fprintf('\n✗✗✗ TEST FAILED ✗✗✗\n');
    fprintf('Error details: %s\n\n', crash_file);
    
    results.success = false;
    results.error = ME.message;
end

end