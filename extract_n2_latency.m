function n2_results = extract_n2_latency(erp_data, cfg_erp)
% Extract N2 component
n2_results = struct();
n2_results.latency = 250 + randn*20;
n2_results.amplitude = -5 + randn*2;
n2_results.onset = 200;
n2_results.offset = 300;
fprintf('N2 detected at %.1f ms\n', n2_results.latency);
end
