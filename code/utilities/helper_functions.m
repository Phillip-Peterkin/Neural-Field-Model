function varargout = helper_functions(function_name, varargin)
% HELPER_FUNCTIONS
% Collection of utility functions for the pipeline
%
% Usage:
%   result = helper_functions('function_name', arg1, arg2, ...)

switch function_name
    case 'check_memory'
        varargout{1} = check_memory_usage(varargin{:});
    case 'downsample_signal'
        varargout{1} = downsample_signal_safe(varargin{:});
    case 'detect_bad_channels'
        varargout{1} = detect_bad_channels(varargin{:});
    otherwise
        error('HelperFunctions:UnknownFunction', 'Unknown function: %s', function_name);
end

end

%% Memory checking
function mem_ok = check_memory_usage(required_gb)
% Check if sufficient memory is available
mem_info = memory;
available_gb = mem_info.MemAvailableAllArrays / 1024^3;
mem_ok = available_gb >= required_gb;

if ~mem_ok
    warning('HelperFunctions:LowMemory', ...
        'Low memory: %.1f GB available, %.1f GB required', ...
        available_gb, required_gb);
end
end

%% Safe downsampling
function downsampled = downsample_signal_safe(signal, factor)
% Downsample with anti-aliasing filter

if factor == 1
    downsampled = signal;
    return;
end

% Apply low-pass filter before downsampling
[b, a] = butter(4, 0.8/factor, 'low');
n_channels = size(signal, 1);
downsampled = zeros(n_channels, ceil(size(signal, 2) / factor));

for ch = 1:n_channels
    filtered = filtfilt(b, a, signal(ch, :));
    downsampled(ch, :) = filtered(1:factor:end);
end
end

%% Bad channel detection
function bad_channels = detect_bad_channels(signal, threshold_std)
% Detect bad channels based on variance

if nargin < 2
    threshold_std = 5; % Default: 5 standard deviations
end

% Compute variance per channel
channel_var = var(signal, 0, 2);

% Detect outliers
mean_var = mean(channel_var);
std_var = std(channel_var);

bad_channels = find(abs(channel_var - mean_var) > threshold_std * std_var);

if ~isempty(bad_channels)
    warning('HelperFunctions:BadChannels', ...
        'Detected %d bad channels: %s', ...
        length(bad_channels), mat2str(bad_channels));
end
end