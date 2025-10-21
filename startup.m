try
    % user paths
    PROJECT_ROOT   = 'C:\Neural Network Sim';
    DATA_ROOT      = 'C:\openneuro\ds004752';
    OUTPUT_ROOT    = fullfile(PROJECT_ROOT, 'analysis_output');

    % toolboxes
    EEGLAB_ROOT    = 'C:\MATLAB\eeglab2025.0.0';
    FIELDTRIP_ROOT = 'C:\MATLAB\fieldtrip';

    % order matters
    addpath(genpath(EEGLAB_ROOT)); eeglab nogui; close all;
    addpath(FIELDTRIP_ROOT); ft_defaults;

    % env hints
    setenv('EEGLAB_PATH', EEGLAB_ROOT);
    setenv('FIELDTRIP_PATH', FIELDTRIP_ROOT);

    % project code
    addpath(PROJECT_ROOT)
    if exist(fullfile(PROJECT_ROOT,'utils'),'dir')
        addpath(genpath(fullfile(PROJECT_ROOT,'utils')));
    end

    % reproducibility
    rng(42, 'twister');

    % light warning hygiene
    warning('off','MATLAB:table:ModifiedAndSavedVarnames')
catch ME
    fprintf(2, 'startup.m failed: %s\n', ME.message);
end
