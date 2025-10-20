function pac_tort = compute_pac_tort(data, cfg_pac)
pac_tort.theta_gamma_mi = rand(length(data.label), 1) * 0.01; % Placeholder
pac_tort.label = data.label;
end
