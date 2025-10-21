function varargout = hft_utils(fn, varargin)
% HFT_UTILS  Small utilities for the pipeline. Call as: hft_utils('name', args...)
switch lower(fn)
    case 'sanitizeband', [varargout{1}] = sanitizeBand(varargin{:});
    case 'getvar',      [varargout{1}] = getVar(varargin{:});
    case 'nanmean',     [varargout{1}] = nanMean(varargin{:});
    case 'addorreplace',[varargout{1}] = addOrReplace(varargin{:});
    case 'normtovec',   [varargout{1}] = normToVec(varargin{:});
    otherwise, error('Unknown hft_utils fn: %s', fn);
end
end

% ---------- helpers ----------
function b = sanitizeBand(b, fs, fallback)
% Ensure 1x2 numeric, sorted, inside (0, Nyq). Clip and fix order.
if nargin<3 || isempty(fallback), fallback = [4 7]; end
if ~isnumeric(b) || numel(b)<2, b = fallback; end
b = b(:).';
b = b(1:2);
b = sort(b);
nyq = max(1, fs/2);
epsv = 1e-6;
b(1) = max(epsv, min(b(1), nyq - 2*epsv));
b(2) = max(b(1)+epsv, min(b(2), nyq - epsv));
end

function v = getVar(T, candidates)
% Case‑insensitive table variable finder with synonyms
v = [];
if istable(T)
    names = string(T.Properties.VariableNames);
    for c = string(candidates(:).')
        hit = find(strcmpi(names, c), 1);
        if isempty(hit)
            % allow partial match like "AperiodicSlope"
            hit = find(contains(lower(names), lower(c)), 1);
        end
        if ~isempty(hit)
            v = T.(names(hit));
            return
        end
    end
end
end

function m = nanMean(x, dims)
% Safe mean that never errors on 'omitnan' options
if nargin<2 || isempty(dims), m = mean(x, 'omitnan'); return; end
m = mean(x, dims, 'omitnan');
end

function T = addOrReplace(T, name, col)
% Add a numeric column to table or replace existing
name = string(name);
if ~istable(T), T = table(); end
col = double(col);
if any(strcmpi(T.Properties.VariableNames, name))
    T.(name) = col;
else
    T = addvars(T, col, 'NewVariableNames', name);
end
end

function v = normToVec(x)
% Force row vector double
v = double(x(:).');
end
