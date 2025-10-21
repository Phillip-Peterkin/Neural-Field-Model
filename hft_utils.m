function varargout = hft_utils(fn, varargin)
% HFT_UTILS  Small utilities used across the pipeline.
switch lower(fn)
    case 'sanitizeband', [varargout{1}] = sanitizeBand(varargin{:});
    case 'getvar',      [varargout{1}] = getVar(varargin{:});
    case 'nanmean',     [varargout{1}] = nanMean(varargin{:});
    case 'addorreplace',[varargout{1}] = addOrReplace(varargin{:});
otherwise, error('hft_utils:badCall','Unknown fn: %s', fn);
end
end

% ---------- helpers ----------
function b = sanitizeBand(b, fs, fallback)
if nargin<3 || isempty(fallback), fallback = [4 7]; end
if ~isnumeric(b) || numel(b)<2, b = fallback; end
b = sort(double(b(:).'));
nyq = max(1, fs/2); epsv = 1e-6;
b(1) = max(epsv, min(b(1), nyq - 2*epsv));
b(2) = max(b(1)+epsv, min(b(2), nyq - epsv));
end

function v = getVar(T, candidates)
v = [];
if istable(T)
    names = string(T.Properties.VariableNames);
    for c = string(candidates(:).')
        hit = find(strcmpi(names,c),1);
        if isempty(hit), hit = find(contains(lower(names),lower(c)),1); end
        if ~isempty(hit), v = T.(names(hit)); return, end
    end
end
end

function m = nanMean(x, dim)
if nargin<2 || isempty(dim), m = mean(x,'omitnan'); else, m = mean(x,dim,'omitnan'); end
end

function T = addOrReplace(T, name, col)
name = string(name); col = double(col);
if ~istable(T), T = table(); end
if any(strcmpi(T.Properties.VariableNames, name))
    T.(name) = col;
else
    T = addvars(T, col, 'NewVariableNames', name);
end
end
