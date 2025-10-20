function create_output_directories(config)
dirs = {config.paths.preprocessed, config.paths.spectral, ...
        config.paths.connectivity, config.paths.pac, ...
        config.paths.erp, config.paths.figures, ...
        config.paths.results, config.paths.logs, config.paths.qc};
for i = 1:length(dirs)
    if ~exist(dirs{i}, 'dir'), mkdir(dirs{i}); end
end
end

function subjects = discover_subjects(data_path)
sub_dirs = dir(fullfile(data_path, 'sub-*'));
sub_dirs = sub_dirs([sub_dirs.isdir]);
subjects = cell(length(sub_dirs), 1);
for i = 1:length(sub_dirs)
    subjects{i} = strrep(sub_dirs(i).name, 'sub-', '');
end
end

function [h, crit_p, adj_ci_cvrg, adj_p] = fdr_bh(pvals, q, method, report)
if nargin < 2, q = 0.05; end
[pvals_sorted, sort_ids] = sort(pvals);
s = length(pvals);
adj_p_sorted = pvals_sorted .* s ./ (1:s)';
for i = s-1:-1:1
    if adj_p_sorted(i) > adj_p_sorted(i+1)
        adj_p_sorted(i) = adj_p_sorted(i+1);
    end
end
adj_p = zeros(size(pvals));
adj_p(sort_ids) = adj_p_sorted;
rej = pvals_sorted < q .* (1:s)' / s;
if sum(rej) > 0
    crit_p = pvals_sorted(find(rej, 1, 'last'));
else
    crit_p = 0;
end
h = pvals <= crit_p;
adj_ci_cvrg = 1 - q;
end


% FDR_BH - Benjamini-Hochberg FDR correction
function [h, crit_p, adj_ci_cvrg, adj_p] = fdr_bh(pvals, q, method, report)
if nargin < 2, q = 0.05; end
if nargin < 3, method = 'pdep'; end
if nargin < 4, report = false; end
s = length(pvals);
if s == 0
    h = []; crit_p = []; adj_ci_cvrg = []; adj_p = [];
    return;
end
[pvals_sorted, sort_ids] = sort(pvals);
if strcmpi(method, 'pdep')
    adj_p_sorted = pvals_sorted .* s ./ (1:s)';
else
    c_s = sum(1 ./ (1:s));
    adj_p_sorted = pvals_sorted .* s .* c_s ./ (1:s)';
end
for i = s-1:-1:1
    if adj_p_sorted(i) > adj_p_sorted(i+1)
        adj_p_sorted(i) = adj_p_sorted(i+1);
    end
end
adj_p_sorted(adj_p_sorted > 1) = 1;
adj_p = zeros(size(pvals));
adj_p(sort_ids) = adj_p_sorted;
rej = pvals_sorted < q .* (1:s)' / s;
if sum(rej) > 0
    max_rej_id = find(rej, 1, 'last');
    crit_p = pvals_sorted(max_rej_id);
else
    crit_p = 0;
end
h = pvals <= crit_p;
adj_ci_cvrg = 1 - q;
end


% FDR_BH - Benjamini-Hochberg FDR correction
function [h, crit_p, adj_ci_cvrg, adj_p] = fdr_bh(pvals, q, method, report)
if nargin < 2, q = 0.05; end
if nargin < 3, method = 'pdep'; end
if nargin < 4, report = false; end
s = length(pvals);
if s == 0
    h = []; crit_p = []; adj_ci_cvrg = []; adj_p = [];
    return;
end
[pvals_sorted, sort_ids] = sort(pvals);
if strcmpi(method, 'pdep')
    adj_p_sorted = pvals_sorted .* s ./ (1:s)';
else
    c_s = sum(1 ./ (1:s));
    adj_p_sorted = pvals_sorted .* s .* c_s ./ (1:s)';
end
for i = s-1:-1:1
    if adj_p_sorted(i) > adj_p_sorted(i+1)
        adj_p_sorted(i) = adj_p_sorted(i+1);
    end
end
adj_p_sorted(adj_p_sorted > 1) = 1;
adj_p = zeros(size(pvals));
adj_p(sort_ids) = adj_p_sorted;
rej = pvals_sorted < q .* (1:s)' / s;
if sum(rej) > 0
    max_rej_id = find(rej, 1, 'last');
    crit_p = pvals_sorted(max_rej_id);
else
    crit_p = 0;
end
h = pvals <= crit_p;
adj_ci_cvrg = 1 - q;
end


function [h, crit_p, adj_ci_cvrg, adj_p] = fdr_bh(pvals, q, method, report)
if nargin < 2, q = 0.05; end
s = length(pvals);
[pvals_sorted, sort_ids] = sort(pvals);
adj_p_sorted = pvals_sorted .* s ./ (1:s)';
for i = s-1:-1:1, if adj_p_sorted(i) > adj_p_sorted(i+1), adj_p_sorted(i) = adj_p_sorted(i+1); end; end
adj_p = zeros(size(pvals)); adj_p(sort_ids) = adj_p_sorted;
rej = pvals_sorted < q .* (1:s)' / s;
if sum(rej) > 0, crit_p = pvals_sorted(find(rej, 1, 'last')); else, crit_p = 0; end
h = pvals <= crit_p; adj_ci_cvrg = 1 - q;
end
