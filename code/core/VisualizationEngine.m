classdef VisualizationEngine < handle
    % VISUALIZATIONENGINE
    % Automated figure generation for all analyses
    % Generates Figures 1-6 from manuscript
    
    properties
        config
        fig_path
    end
    
    methods
        function obj = VisualizationEngine(config)
            obj.config = config;
            obj.fig_path = config.paths.figures;
            
            if ~exist(obj.fig_path, 'dir')
                mkdir(obj.fig_path);
            end
        end
        
        function generate_all_figures(obj, results, group_results, validation)
            % GENERATE_ALL_FIGURES Create all manuscript figures
            
            fprintf('Generating figures...\n');
            
            % Figure 2: State Fingerprints (Spectral + PAC)
            obj.plot_spectral_fingerprints(group_results);
            
            % Figure 3: Connectivity Matrices
            obj.plot_connectivity_matrices(group_results);
            
            % Figure 4: Access Detection Example
            obj.plot_access_detection(results);
            
            % Figure 5: Decoder Performance
            obj.plot_decoder_performance(group_results, validation);
            
            % Figure 6: Energy Budget
            obj.plot_energy_budget(group_results);
            
            fprintf('  ✓ All figures saved to: %s\n', obj.fig_path);
        end
        
        function plot_spectral_fingerprints(obj, group_results)
            % Plot power spectra and PAC
            
            figure('Position', [100, 100, 1200, 400]);
            
            % Subplot 1: Power spectrum
            subplot(1, 3, 1);
            freqs = group_results.spectral.mean_spectrum(1, :);
            mean_power = mean(group_results.spectral.mean_spectrum, 1);
            std_power = mean(group_results.spectral.std_spectrum, 1);
            
            shadedErrorBar(freqs, mean_power, std_power, 'lineProps', '-b');
            set(gca, 'YScale', 'log', 'XScale', 'log');
            xlabel('Frequency (Hz)');
            ylabel('Power (log)');
            title('Group Power Spectrum');
            grid on;
            
            % Subplot 2: Band power
            subplot(1, 3, 2);
            bands = {'theta', 'alpha', 'beta', 'gamma_low'};
            band_values = zeros(length(bands), 1);
            for b = 1:length(bands)
                % Would extract from group_results
                band_values(b) = b; % Placeholder
            end
            bar(band_values);
            set(gca, 'XTickLabel', bands);
            ylabel('Normalized Power');
            title('Band Power');
            
            % Subplot 3: PAC
            subplot(1, 3, 3);
            bar([group_results.pac.mean_MI]);
            ylabel('Modulation Index');
            title('Theta-Gamma PAC');
            
            obj.save_figure('spectral_fingerprints');
        end
        
        function plot_connectivity_matrices(obj, group_results)
            % Plot connectivity matrices per band
            
            bands = fieldnames(group_results.connectivity.mean_plv);
            n_bands = length(bands);
            
            figure('Position', [100, 100, 1200, 300]);
            
            for b = 1:n_bands
                subplot(1, n_bands, b);
                imagesc(group_results.connectivity.mean_plv.(bands{b}));
                colorbar;
                title(sprintf('%s PLV', bands{b}));
                axis square;
            end
            
            obj.save_figure('connectivity_matrices');
        end
        
        function plot_access_detection(obj, results)
            % Plot example access detection
            
            % Find first valid result
            valid_results = results(~cellfun(@isempty, results));
            if isempty(valid_results)
                return;
            end
            
            example = valid_results{1};
            
            if ~isfield(example, 'access')
                return;
            end
            
            figure('Position', [100, 100, 1200, 400]);
            
            % Plot coherence timeseries
            subplot(2, 1, 1);
            plot(example.access.coherence_timeseries, 'k', 'LineWidth', 1.5);
            hold on;
            yline(obj.config.access.R_hi, 'r--', 'Entry');
            yline(obj.config.access.R_lo, 'b--', 'Exit');
            ylabel('Coherence');
            title('Access Detection');
            grid on;
            
            % Mark detected windows
            subplot(2, 1, 2);
            windows = example.access.access_windows;
            for w = 1:size(windows, 1)
                rectangle('Position', [windows(w,1), 0, windows(w,2)-windows(w,1), 1], ...
                    'FaceColor', [0.8, 0.8, 1], 'EdgeColor', 'none');
            end
            ylim([0, 1]);
            xlabel('Time (samples)');
            ylabel('Access State');
            title(sprintf('Detected Windows: %d', size(windows, 1)));
            
            obj.save_figure('access_detection_example');
        end
        
        function plot_decoder_performance(obj, group_results, validation)
            % Plot decoder accuracies
            
            figure('Position', [100, 100, 800, 600]);
            
            % Bar plot of accuracies
            subplot(2, 1, 1);
            accuracies = [group_results.decoder.setsize_accuracy, ...
                          group_results.decoder.correct_accuracy, ...
                          group_results.decoder.match_accuracy];
            bar(accuracies);
            hold on;
            yline(1/3, 'r--', 'Chance (3-class)');
            yline(0.5, 'r--', 'Chance (2-class)');
            set(gca, 'XTickLabel', {'SetSize', 'Correct', 'Match'});
            ylabel('Accuracy');
            title('Decoder Performance');
            ylim([0, 1]);
            grid on;
            
            % Cross-validation
            subplot(2, 1, 2);
            if ~isnan(validation.accuracy)
                bar(validation.accuracy);
                ylabel('Accuracy');
                title(sprintf('Cross-Validation: %.1f%%', validation.accuracy * 100));
                ylim([0, 1]);
            end
            
            obj.save_figure('decoder_performance');
        end
        
        function plot_energy_budget(obj, group_results)
            % Plot energy consumption
            
            figure('Position', [100, 100, 600, 400]);
            
            bar([group_results.energy.mean_power_across_subjects]);
            hold on;
            yline(obj.config.energy.P_max_wake, 'r--', 'Budget Cap');
            errorbar(1, group_results.energy.mean_power_across_subjects, ...
                group_results.energy.std_power, 'k', 'LineWidth', 2);
            
            ylabel('Normalized Power');
            title('Energy Budget Compliance');
            set(gca, 'XTickLabel', {'Mean'});
            grid on;
            
            obj.save_figure('energy_budget');
        end
        
        function save_figure(obj, name)
            % Save figure in multiple formats
            
            formats = obj.config.viz.save_format;
            for f = 1:length(formats)
                fmt = formats{f};
                filename = fullfile(obj.fig_path, sprintf('%s.%s', name, fmt));
                
                switch fmt
                    case 'png'
                        print(gcf, filename, '-dpng', sprintf('-r%d', obj.config.viz.dpi));
                    case 'pdf'
                        print(gcf, filename, '-dpdf', '-bestfit');
                    case 'fig'
                        savefig(gcf, filename);
                end
            end
            
            close(gcf);
        end
    end
end