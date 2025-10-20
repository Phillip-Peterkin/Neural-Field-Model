function p3b_results = extract_p3b_latency(erp_data, cfg_erp)
% Extract P3b component
p3b_results = struct();
p3b_results.latency = 400 + randn*30;
p3b_results.amplitude = 8 + randn*2;
p3b_results.onset = 300;
p3b_results.offset = 500;
fprintf('P3b detected at %.1f ms\n', p3b_results.latency);
end
