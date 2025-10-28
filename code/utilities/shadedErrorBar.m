function varargout = shadedErrorBar(x, y, errBar, varargin)
% SHADEDERRORBAR Plot line with shaded error region
% Simplified version for visualization
%
% Usage:
%   shadedErrorBar(x, y, errBar)
%   shadedErrorBar(x, y, errBar, 'lineProps', '-r')

% Parse inputs
params = inputParser;
params.addParameter('lineProps', '-k', @(x) ischar(x) || iscell(x));
params.addParameter('transparent', true, @islogical);
params.addParameter('patchSaturation', 0.2, @isnumeric);
params.parse(varargin{:});

lineProps = params.Results.lineProps;

% Ensure row vectors
if ~isrow(x), x = x'; end
if ~isrow(y), y = y'; end

% Handle error bar format
if isnumeric(errBar)
    if isrow(errBar)
        errBar = [errBar; errBar];
    end
    yP = y + errBar(1,:);
    yM = y - errBar(2,:);
elseif isstruct(errBar)
    yP = errBar.upper;
    yM = errBar.lower;
end

% Remove NaN values
valid = ~isnan(y) & ~isnan(yP) & ~isnan(yM);
x = x(valid);
y = y(valid);
yP = yP(valid);
yM = yM(valid);

% Plot shaded region
holdStatus = ishold;
if ~holdStatus, hold on; end

% Create patch
H.patch = patch([x, fliplr(x)], [yP, fliplr(yM)], [0.8, 0.8, 1], ...
    'EdgeColor', 'none', 'FaceAlpha', params.Results.patchSaturation);

% Plot main line
if ischar(lineProps)
    H.mainLine = plot(x, y, lineProps, 'LineWidth', 2);
else
    H.mainLine = plot(x, y, lineProps{:});
end

% Restore hold state
if ~holdStatus, hold off; end

% Output
if nargout > 0
    varargout{1} = H;
end

end