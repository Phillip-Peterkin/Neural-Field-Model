function [h, crit_p, adj_ci_cvrg, adj_p] = fdr_bh(pvals, q, method, report)
% FDR_BH Benjamini-Hochberg FDR correction
if nargin < 2, q = 0.05; end
if nargin < 3, method = 'pdep'; end
if nargin < 4, report = false; end

s = length(pvals);
if s == 0
    h = []; crit_p = []; adj_ci_cvrg = []; adj_p = [];
    return;
end

% Ensure pvals is a column vector
pvals = pvals(:);

[pvals_sorted, sort_ids] = sort(pvals);

if strcmpi(method, 'pdep')
    adj_p_sorted = pvals_sorted .* s ./ (1:s)';
else
    c_s = sum(1 ./ (1:s));
    adj_p_sorted = pvals_sorted .* s .* c_s ./ (1:s)';
end

% Ensure monotonicity
for i = s-1:-1:1
    if adj_p_sorted(i) > adj_p_sorted(i+1)
        adj_p_sorted(i) = adj_p_sorted(i+1);
    end
end

adj_p_sorted(adj_p_sorted > 1) = 1;

% Unsort
adj_p = zeros(size(pvals));
adj_p(sort_ids) = adj_p_sorted;

% Find critical p-value
rej = pvals_sorted < q .* (1:s)' / s;
if sum(rej) > 0
    max_rej_id = find(rej, 1, 'last');
    crit_p = pvals_sorted(max_rej_id);
else
    crit_p = 0;
end

h = pvals <= crit_p;
adj_ci_cvrg = 1 - q;

if report
    fprintf('FDR Correction (q = %.3f)\n', q);
    fprintf('  %d/%d hypotheses rejected\n', sum(h), s);
    fprintf('  Critical p-value: %.6f\n', crit_p);
end
end
