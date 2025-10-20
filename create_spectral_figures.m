%% VISUALIZATION FUNCTIONS
% Publication-quality figures for all analyses

function create_spectral_figures(spectral_data, stats, config)
% CREATE_SPECTRAL_FIGURES - Generate spectral analysis visualizations

fprintf('Creating spectral figures...\n');

fig_dir = fullfile(config.paths.figures, 'spectral');
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

% 1. Power spectral density with 1/f fit
plot_psd_with_fooof(spectral_data, fig_dir, config);

% 2. Aperiodic exponent distribution
plot_exponent_distribution(spectral_data, fig_dir, config);

% 3. Band power comparison
plot_band_powers(spectral_data, fig_dir, config);

% 4. Time-frequency representation
if isfield(spectral_data, 'tf_avg')
    plot_time_frequency(spectral_data, fig_dir, config);
end

fprintf('Spectral figures complete\n');

end

function plot_psd_with_fooof(spectral_data, fig_dir, config)
% Plot power spectral density with aperiodic fit overlay

fig = figure('Position', [100, 100, 1200, 800], 'Visible', 'off');

% Select representative channels
channels_to_plot = {'Fz', 'Cz', 'Pz', 'Oz'};

for idx = 1:length(channels_to_plot)
    subplot(2, 2, idx);
    
    % Find channel
    ch_idx = find(strcmp(spectral_data.label, channels_to_plot{idx}), 1);
    
    if ~isempty(ch_idx)
        % Plot observed PSD
        freq = spectral_data.freq;
        power = spectral_data.psd_mean(ch_idx, :);
        
        loglog(freq, power, 'k-', 'LineWidth', 1.5, 'DisplayName', 'Observed');
        hold on;
        
        % Plot aperiodic fit
        if isfield(spectral_data, 'aperiodic_fit')
            aperiodic = spectral_data.aperiodic_fit(ch_idx, :);
            loglog(freq, aperiodic, 'r--', 'LineWidth', 2, 'DisplayName', 'Aperiodic fit');
        end
        
        % Plot full model fit
        if isfield(spectral_data, 'full_fit')
            full_fit = spectral_data.full_fit(ch_idx, :);
            loglog(freq, full_fit, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Full model');
        end
        
        % Formatting
        xlabel('Frequency (Hz)', 'FontSize', 12);
        ylabel('Power (μV²/Hz)', 'FontSize', 12);
        title(sprintf('%s (Exponent: %.3f)', channels_to_plot{idx}, ...
            spectral_data.exponent_mean(ch_idx)), 'FontSize', 14);
        legend('Location', 'southwest');
        grid on;
        set(gca, 'FontSize', 10);
    end
end

sgtitle('Power Spectral Density with 1/f Fit', 'FontSize', 16, 'FontWeight', 'bold');

% Save
saveas(fig, fullfile(fig_dir, 'psd_with_fooof.png'));
saveas(fig, fullfile(fig_dir, 'psd_with_fooof.fig'));
close(fig);

end

function plot_exponent_distribution(spectral_data, fig_dir, config)
% Plot distribution of aperiodic exponents across channels

fig = figure('Position', [100, 100, 800, 600], 'Visible', 'off');

exponents = spectral_data.exponent_mean;

% Histogram
histogram(exponents, 20, 'FaceColor', [0.3 0.5 0.8], 'EdgeColor', 'k', 'FaceAlpha', 0.7);
hold on;

% Add mean line
mean_exp = mean(exponents);
xline(mean_exp, 'r--', 'LineWidth', 2, 'Label', sprintf('Mean: %.3f', mean_exp));

% Formatting
xlabel('Aperiodic Exponent', 'FontSize', 14);
ylabel('Count', 'FontSize', 14);
title('Distribution of 1/f Exponents', 'FontSize', 16, 'FontWeight', 'bold');
grid on;
set(gca, 'FontSize', 12);

% Save
saveas(fig, fullfile(fig_dir, 'exponent_distribution.png'));
close(fig);

end

function plot_band_powers(spectral_data, fig_dir, config)
% Bar plot of band powers

fig = figure('Position', [100, 100, 1000, 600], 'Visible', 'off');

bands = {'delta', 'theta', 'alpha', 'beta', 'gamma_low', 'gamma_high'};
band_labels = {'δ (1-4)', 'θ (4-8)', 'α (8-13)', 'β (13-30)', 'γ-low (30-50)', 'γ-high (50-80)'};

mean_powers = zeros(1, length(bands));
sem_powers = zeros(1, length(bands));

for b = 1:length(bands)
    if isfield(spectral_data.band_power, bands{b})
        mean_powers(b) = mean(spectral_data.band_power.(bands{b}).mean);
        sem_powers(b) = mean(spectral_data.band_power.(bands{b}).sem);
    end
end

% Bar plot with error bars
bar(1:length(bands), mean_powers, 'FaceColor', [0.4 0.6 0.9], 'EdgeColor', 'k');
hold on;
errorbar(1:length(bands), mean_powers, sem_powers, 'k', 'LineStyle', 'none', 'LineWidth', 1.5);

% Formatting
set(gca, 'XTick', 1:length(bands), 'XTickLabel', band_labels, 'FontSize', 12);
ylabel('Power (μV²)', 'FontSize', 14);
title('Band-Limited Power Across Frequency Bands', 'FontSize', 16, 'FontWeight', 'bold');
grid on;

% Save
saveas(fig, fullfile(fig_dir, 'band_powers.png'));
close(fig);

end

function plot_time_frequency(spectral_data, fig_dir, config)
% Time-frequency representation

fig = figure('Position', [100, 100, 1200, 400], 'Visible', 'off');

% Select channel (Cz)
ch_idx = find(strcmp(spectral_data.label, 'Cz'), 1);

if ~isempty(ch_idx) && isfield(spectral_data, 'tf_avg')
    % Plot
    imagesc(spectral_data.time, spectral_data.freq, ...
        squeeze(spectral_data.tf_avg(ch_idx, :, :)));
    set(gca, 'YDir', 'normal');
    
    % Colormap and colorbar
    colormap(config.viz.color_scheme);
    cb = colorbar;
    ylabel(cb, 'Power (dB)', 'FontSize', 12);
    
    % Formatting
    xlabel('Time (s)', 'FontSize', 14);
    ylabel('Frequency (Hz)', 'FontSize', 14);
    title('Time-Frequency Representation - Cz', 'FontSize', 16, 'FontWeight', 'bold');
    
    % Add event markers
    xline(0, 'w--', 'LineWidth', 2, 'Label', 'Stimulus');
    
    set(gca, 'FontSize', 12);
    
    % Save
    saveas(fig, fullfile(fig_dir, 'time_frequency_cz.png'));
end

close(fig);

end

%% CONNECTIVITY FIGURES
function create_connectivity_figures(connectivity_data, stats, config)
% CREATE_CONNECTIVITY_FIGURES - Generate connectivity visualizations

fprintf('Creating connectivity figures...\n');

fig_dir = fullfile(config.paths.figures, 'connectivity');
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

% 1. Connectivity matrix (PLV)
plot_connectivity_matrix(connectivity_data, 'plv', fig_dir, config);

% 2. Granger causality network
if isfield(connectivity_data, 'granger')
    plot_granger_network(connectivity_data.granger, fig_dir, config);
end

% 3. Circular graph of strong connections
plot_circular_connectivity(connectivity_data, fig_dir, config);

fprintf('Connectivity figures complete\n');

end

function plot_connectivity_matrix(conn_data, method, fig_dir, config)
% Plot connectivity as matrix

fig = figure('Position', [100, 100, 800, 700], 'Visible', 'off');

if isfield(conn_data, method)
    matrix = conn_data.(method).mean;
    
    % Plot
    imagesc(matrix);
    colormap('hot');
    cb = colorbar;
    ylabel(cb, upper(method), 'FontSize', 12);
    
    % Formatting
    axis square;
    set(gca, 'XTick', 1:length(conn_data.label), 'XTickLabel', conn_data.label, ...
        'YTick', 1:length(conn_data.label), 'YTickLabel', conn_data.label);
    xtickangle(45);
    title(sprintf('%s Connectivity Matrix', upper(method)), 'FontSize', 16, 'FontWeight', 'bold');
    set(gca, 'FontSize', 10);
    
    % Save
    saveas(fig, fullfile(fig_dir, sprintf('connectivity_matrix_%s.png', method)));
end

close(fig);

end

function plot_granger_network(granger_data, fig_dir, config)
% Plot Granger causality as directed network

fig = figure('Position', [100, 100, 1000, 800], 'Visible', 'off');

% Theta band Granger causality
if isfield(granger_data, 'theta_mean')
    gc_matrix = granger_data.theta_mean;
    
    % Threshold for visualization
    threshold = quantile(gc_matrix(:), 0.75); % Top 25%
    gc_thresh = gc_matrix;
    gc_thresh(gc_matrix < threshold) = 0;
    
    % Create directed graph
    G = digraph(gc_thresh, granger_data.label);
    
    % Plot
    h = plot(G, 'Layout', 'force', 'EdgeColor', [0.3 0.3 0.3], ...
        'LineWidth', 2, 'ArrowSize', 15, 'NodeColor', [0.4 0.6 0.9], ...
        'MarkerSize', 10);
    
    % Edge weights as line width
    h.EdgeAlpha = 0.7;
    
    title('Theta-Band Granger Causality Network', 'FontSize', 16, 'FontWeight', 'bold');
    set(gca, 'XTick', [], 'YTick', []);
    
    % Save
    saveas(fig, fullfile(fig_dir, 'granger_network_theta.png'));
end

close(fig);

end

function plot_circular_connectivity(conn_data, fig_dir, config)
% Circular graph of connectivity

fig = figure('Position', [100, 100, 800, 800], 'Visible', 'off');

% Use PLV if available
if isfield(conn_data, 'plv')
    matrix = conn_data.plv.mean;
    labels = conn_data.label;
    
    % Threshold
    threshold = quantile(matrix(:), 0.9); % Top 10%
    
    % Create circular layout
    n = length(labels);
    theta = linspace(0, 2*pi, n+1);
    theta = theta(1:end-1);
    
    x = cos(theta);
    y = sin(theta);
    
    % Plot nodes
    scatter(x, y, 200, 'filled', 'MarkerFaceColor', [0.4 0.6 0.9], ...
        'MarkerEdgeColor', 'k', 'LineWidth', 1.5);
    hold on;
    
    % Plot connections
    for i = 1:n
        for j = i+1:n
            if matrix(i,j) > threshold
                plot([x(i) x(j)], [y(i) y(j)], 'k-', 'LineWidth', ...
                    2*matrix(i,j), 'Color', [0.3 0.3 0.3 0.3]);
            end
        end
    end
    
    % Add labels
    for i = 1:n
        text(x(i)*1.15, y(i)*1.15, labels{i}, 'HorizontalAlignment', 'center', ...
            'FontSize', 10, 'FontWeight', 'bold');
    end
    
    axis equal;
    axis off;
    title('Strong Connectivity Patterns (PLV > 90th percentile)', ...
        'FontSize', 16, 'FontWeight', 'bold');
    
    % Save
    saveas(fig, fullfile(fig_dir, 'circular_connectivity.png'));
end

close(fig);

end

%% PAC FIGURES
function create_pac_figures(pac_data, stats, config)
% CREATE_PAC_FIGURES - Generate PAC visualizations

fprintf('Creating PAC figures...\n');

fig_dir = fullfile(config.paths.figures, 'pac');
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

% 1. Comodulogram (average across channels)
plot_comodulogram_average(pac_data, fig_dir, config);

% 2. PAC distribution across channels
plot_pac_distribution(pac_data, stats, fig_dir, config);

% 3. Time-resolved PAC
if isfield(pac_data, 'time_resolved')
    plot_time_resolved_pac(pac_data, fig_dir, config);
end

fprintf('PAC figures complete\n');

end

function plot_comodulogram_average(pac_data, fig_dir, config)
% Average comodulogram across channels

fig = figure('Position', [100, 100, 900, 700], 'Visible', 'off');

if isfield(pac_data, 'mi_matrix_avg')
    % Plot
    imagesc(pac_data.amp_freqs, pac_data.phase_freqs, pac_data.mi_matrix_avg);
    set(gca, 'YDir', 'normal');
    
    % Colormap
    colormap('jet');
    cb = colorbar;
    ylabel(cb, 'Modulation Index', 'FontSize', 12);
    
    % Mark theta-gamma box
    hold on;
    rectangle('Position', [30, 4, 50, 4], 'EdgeColor', 'w', ...
        'LineWidth', 3, 'LineStyle', '--');
    
    % Formatting
    xlabel('Amplitude Frequency (Hz)', 'FontSize', 14);
    ylabel('Phase Frequency (Hz)', 'FontSize', 14);
    title('Theta-Gamma Phase-Amplitude Coupling', 'FontSize', 16, 'FontWeight', 'bold');
    set(gca, 'FontSize', 12);
    
    % Save
    saveas(fig, fullfile(fig_dir, 'comodulogram_average.png'));
end

close(fig);

end

function plot_pac_distribution(pac_data, stats, fig_dir, config)
% Distribution of PAC values with significance

fig = figure('Position', [100, 100, 1000, 600], 'Visible', 'off');

if isfield(pac_data, 'mi_mean') && isfield(stats, 'significant')
    mi_values = pac_data.mi_mean;
    significant = stats.significant;
    
    % Sort by MI value
    [mi_sorted, sort_idx] = sort(mi_values, 'descend');
    labels_sorted = pac_data.label(sort_idx);
    sig_sorted = significant(sort_idx);
    
    % Plot top 20 channels
    n_plot = min(20, length(mi_sorted));
    
    % Bar plot
    bar_colors = repmat([0.7 0.7 0.7], n_plot, 1);
    bar_colors(sig_sorted(1:n_plot), :) = repmat([0.9 0.3 0.3], sum(sig_sorted(1:n_plot)), 1);
    
    b = bar(1:n_plot, mi_sorted(1:n_plot), 'FaceColor', 'flat');
    b.CData = bar_colors;
    
    % Formatting
    set(gca, 'XTick', 1:n_plot, 'XTickLabel', labels_sorted(1:n_plot), 'FontSize', 10);
    xtickangle(45);
    ylabel('Modulation Index', 'FontSize', 14);
    title('Theta-Gamma PAC Strength (Top 20 Channels)', 'FontSize', 16, 'FontWeight', 'bold');
    legend({'Non-significant', 'Significant'}, 'Location', 'northeast');
    grid on;
    
    % Save
    saveas(fig, fullfile(fig_dir, 'pac_distribution.png'));
end

close(fig);

end

function plot_time_resolved_pac(pac_data, fig_dir, config)
% Time course of PAC

fig = figure('Position', [100, 100, 1200, 600], 'Visible', 'off');

% Average across selected channels
channel_idx = select_representative_channels(pac_data.label, {'Fz', 'Cz', 'Pz'});

if ~isempty(channel_idx)
    pac_time = mean(pac_data.time_resolved.mi_time(channel_idx, :), 1);
    time = pac_data.time_resolved.time_centers;
    
    % Plot
    plot(time, pac_time, 'LineWidth', 2, 'Color', [0.2 0.4 0.8]);
    hold on;
    
    % Add event markers
    xline(0, 'r--', 'LineWidth', 2, 'Label', 'Stimulus');
    
    % Formatting
    xlabel('Time (s)', 'FontSize', 14);
    ylabel('Modulation Index', 'FontSize', 14);
    title('Time-Resolved Theta-Gamma PAC', 'FontSize', 16, 'FontWeight', 'bold');
    grid on;
    set(gca, 'FontSize', 12);
    
    % Save
    saveas(fig, fullfile(fig_dir, 'pac_time_resolved.png'));
end

close(fig);

end

%% ERP FIGURES
function create_erp_figures(erp_data, stats, config)
% CREATE_ERP_FIGURES - Generate ERP visualizations

fprintf('Creating ERP figures...\n');

fig_dir = fullfile(config.paths.figures, 'erp');
if ~exist(fig_dir, 'dir'), mkdir(fig_dir); end

% 1. Grand average ERPs
plot_grand_average_erp(erp_data, fig_dir, config);

% 2. N2 and P3b components
plot_erp_components(erp_data, fig_dir, config);

% 3. Topographic maps at peak latencies
plot_erp_topographies(erp_data, fig_dir, config);

fprintf('ERP figures complete\n');

end

function plot_grand_average_erp(erp_data, fig_dir, config)
% Grand average ERP waveforms

fig = figure('Position', [100, 100, 1200, 800], 'Visible', 'off');

conditions = fieldnames(erp_data);
colors = lines(length(conditions));

% Plot key channels
channels = {'Fz', 'Cz', 'Pz'};

for idx = 1:length(channels)
    subplot(2, 2, idx);
    
    ch_idx = find(strcmp(erp_data.(conditions{1}).label, channels{idx}), 1);
    
    if ~isempty(ch_idx)
        for c = 1:length(conditions)
            cond = conditions{c};
            
            time = erp_data.(cond).time * 1000; % Convert to ms
            voltage = erp_data.(cond).avg(ch_idx, :);
            sem = erp_data.(cond).sem(ch_idx, :);
            
            % Plot with shaded error
            plot(time, voltage, 'Color', colors(c,:), 'LineWidth', 2, ...
                'DisplayName', cond);
            hold on;
            
            fill([time, fliplr(time)], ...
                [voltage + sem, fliplr(voltage - sem)], ...
                colors(c,:), 'FaceAlpha', 0.2, 'EdgeColor', 'none', ...
                'HandleVisibility', 'off');
        end
        
        % Formatting
        xline(0, 'k--', 'LineWidth', 1.5);
        yline(0, 'k-', 'LineWidth', 0.5);
        xlabel('Time (ms)', 'FontSize', 12);
        ylabel('Amplitude (μV)', 'FontSize', 12);
        title(channels{idx}, 'FontSize', 14);
        legend('Location', 'best');
        grid on;
        set(gca, 'FontSize', 10);
    end
end

sgtitle('Grand Average ERPs', 'FontSize', 16, 'FontWeight', 'bold');

% Save
saveas(fig, fullfile(fig_dir, 'grand_average_erp.png'));
close(fig);

end

function plot_erp_components(erp_data, fig_dir, config)
% Highlight N2 and P3b components

fig = figure('Position', [100, 100, 1200, 500], 'Visible', 'off');

% N2 component
subplot(1, 2, 1);
if isfield(erp_data, 'n2')
    plot(erp_data.n2.time, erp_data.n2.trace, 'b-', 'LineWidth', 2);
    hold on;
    
    % Mark peak
    plot(erp_data.n2.latency, erp_data.n2.amplitude, 'ro', ...
        'MarkerSize', 10, 'LineWidth', 2);
    
    % Shade N2 window
    patch([erp_data.n2.onset, erp_data.n2.offset, erp_data.n2.offset, erp_data.n2.onset], ...
        [min(erp_data.n2.trace), min(erp_data.n2.trace), max(erp_data.n2.trace), max(erp_data.n2.trace)], ...
        'r', 'FaceAlpha', 0.1, 'EdgeColor', 'none');
    
    xlabel('Time (ms)', 'FontSize', 14);
    ylabel('Amplitude (μV)', 'FontSize', 14);
    title(sprintf('N2 Component (Latency: %.0f ms)', erp_data.n2.latency), ...
        'FontSize', 14, 'FontWeight', 'bold');
    grid on;
end

% P3b component
subplot(1, 2, 2);
if isfield(erp_data, 'p3b')
    plot(erp_data.p3b.time, erp_data.p3b.trace, 'b-', 'LineWidth', 2);
    hold on;
    
    % Mark peak
    plot(erp_data.p3b.latency, erp_data.p3b.amplitude, 'ro', ...
        'MarkerSize', 10, 'LineWidth', 2);
    
    xlabel('Time (ms)', 'FontSize', 14);
    ylabel('Amplitude (μV)', 'FontSize', 14);
    title(sprintf('P3b Component (Latency: %.0f ms)', erp_data.p3b.latency), ...
        'FontSize', 14, 'FontWeight', 'bold');
    grid on;
end

% Save
saveas(fig, fullfile(fig_dir, 'erp_components.png'));
close(fig);

end

function plot_erp_topographies(erp_data, fig_dir, config)
% Topographic maps at key latencies

% This would require electrode position information
% Placeholder for future implementation

fprintf('  Topographic plotting requires electrode positions\n');

end

%% HELPER FUNCTIONS
function idx = select_representative_channels(all_labels, preferred)
% Select representative channels from list

idx = [];
for i = 1:length(preferred)
    ch_idx = find(strcmp(all_labels, preferred{i}), 1);
    if ~isempty(ch_idx)
        idx = [idx, ch_idx];
    end
end

end