%% EEG Channel Inspector and Selector (30 Channels)
% Channels 1-28: EEG data
% Channel 29: Replacement data (will replace one bad channel from 1-28)
% Channel 30: EVENT channel (keep as is)

clear; close all; clc;

%% Setup
eeglab_path = 'C:\Users\MaSoOM\Documents\MATLAB\eeglab2024';
addpath(eeglab_path);
eeglab nogui;

fprintf('=== EEG 30-Channel Inspector ===\n\n');

%% Load Raw Data (30 channels)
fprintf('Step 1: Loading raw data file...\n');
raw_data = readmatrix('C:\Users\MaSoOM\Documents\MATLAB\Processing\base.txt');

fprintf('   Data dimensions: %d samples x %d channels\n', size(raw_data, 1), size(raw_data, 2));

if size(raw_data, 2) ~= 30
    error('Expected 30 channels, but found %d channels', size(raw_data, 2));
end

%% Transpose if needed (make it channels x samples)
if size(raw_data, 1) < size(raw_data, 2)
    % Data is channels x samples (correct)
    data_matrix = raw_data;
else
    % Data is samples x channels (need to transpose)
    data_matrix = raw_data';
    fprintf('   Data transposed to: %d channels x %d samples\n', size(data_matrix, 1), size(data_matrix, 2));
end

%% Define Channel Names
% Channels 1-28: EEG channels
% Channel 29: Replacement
% Channel 30: EVENT
channel_names = {'FP1', 'FP2', 'F3', 'F4', 'C3', 'C4', 'P3', 'P4', ...
                 'O1', 'O2', 'F7', 'F8', 'T3', 'T4', 'T5', 'T6', ...
                 'FZ', 'CZ', 'Pz', 'FC3', 'FC4', 'CP3', 'CP4', ...
                 'FT7', 'FT8', 'TP7', 'TP8', 'OZ'};

sampling_rate = 1000;  % Hz

fprintf('\nChannel configuration:\n');
fprintf('  Channels 1-28: EEG data\n');
fprintf('  Channel 29: Replacement data (will replace one bad EEG channel)\n');
fprintf('  Channel 30: EVENT (will be kept as is)\n\n');

%% Figure 1: All 28 EEG Channels Overview
fprintf('Step 2: Creating visualization of 28 EEG channels...\n');

time_window = 10;  % seconds to display
samples_to_plot = min(time_window * sampling_rate, size(data_matrix, 2));
time_vec = (0:samples_to_plot-1) / sampling_rate;

fig1 = figure('Name', 'All 28 EEG Channels', 'NumberTitle', 'off', ...
              'Position', [50 50 1600 900], 'Color', 'w');

v_spacing = 150;  % vertical spacing

for ch = 1:28
    data = data_matrix(ch, 1:samples_to_plot);
    data_norm = data - mean(data);
    data_offset = data_norm + (28 - ch) * v_spacing;
    
    plot(time_vec, data_offset, 'b', 'LineWidth', 0.5);
    text(-0.5, (28 - ch) * v_spacing, sprintf('Ch%d: %s', ch, channel_names{ch}), ...
         'FontSize', 9, 'FontWeight', 'bold', 'HorizontalAlignment', 'right');
    hold on;
end

xlim([-1, time_window]);
ylim([-v_spacing, 29 * v_spacing]);
xlabel('Time (seconds)', 'FontSize', 12, 'FontWeight', 'bold');
title('28 EEG Channels - Choose Which One to Remove', 'FontSize', 14, 'FontWeight', 'bold');
grid on;
set(gca, 'YTick', []);

fprintf('   Figure 1 created: All EEG channels overview\n');



%% Figure 2: Individual Channel Traces (SAME Y-axis scale)
fprintf('   Creating individual channel plots with same scale...\n');

fig2 = figure('Name', 'Individual EEG Channel Traces', 'NumberTitle', 'off', ...
              'Position', [150 150 1600 1000], 'Color', 'w');

rows = 5;
cols = 6;
time_detail = 5;  % seconds
samples_detail = min(time_detail * sampling_rate, size(data_matrix, 2));
time_axis = (0:samples_detail-1) / sampling_rate;

% Calculate GLOBAL min and max across EEG channels (1-28) only
global_min = inf;
global_max = -inf;

for ch = 1:28
    channel_data = data_matrix(ch, 1:samples_detail);
    global_min = min(global_min, min(channel_data));
    global_max = max(global_max, max(channel_data));
end

% Add some padding (10%)
y_range = global_max - global_min;
global_min = global_min - 0.1 * y_range;
global_max = global_max + 0.1 * y_range;

fprintf('   Global Y-axis range: [%.2f, %.2f] µV\n', global_min, global_max);

% Plot all 28 EEG channels with SAME Y-axis
for ch = 1:28
    subplot(rows, cols, ch);
    channel_data = data_matrix(ch, 1:samples_detail);
    plot(time_axis, channel_data, 'b', 'LineWidth', 0.8);
    
    % FORCE same Y-axis limits for ALL subplots
    ylim([global_min, global_max]);
    
    % Calculate this channel's amplitude range
    ch_range = max(channel_data) - min(channel_data);
    
    title(sprintf('Ch%d: %s\nRange: %.1f µV', ch, channel_names{ch}, ch_range), ...
          'FontSize', 7, 'FontWeight', 'bold');
    grid on;
    xlim([0 time_detail]);
    
    if ch > 24
        xlabel('Time (s)', 'FontSize', 7);
    end
    if mod(ch-1, cols) == 0
        ylabel('µV', 'FontSize', 7);
    end
end

sgtitle(sprintf('28 EEG Channels - SAME Y-axis [%.1f to %.1f µV]', global_min, global_max), ...
        'FontSize', 12, 'FontWeight', 'bold');

fprintf('   Figure 3 created: Individual traces\n');





%% Interactive Selection
fprintf('INSPECT THE FIGURES ABOVE TO CHOOSE WHICH EEG CHANNEL TO REMOVE\n\n');
fprintf('Tips for identifying bad channels:\n');
fprintf('  - Flat lines (no activity) or "TOO QUIET"\n');
fprintf('  - Excessive noise or spikes (HIGH NOISE)\n');
fprintf('  - Abnormally high/low variance\n');
fprintf('  - High flatline percentage (FLATLINE)\n');
fprintf('  - Different amplitude range from others\n');
fprintf('  - Very different power spectrum\n\n');

fprintf('Channel 29 is the replacement data.\n');
fprintf('Channel 30 is EVENT - it will be kept as is.\n\n');

% Get user input
channel_to_remove = input('Enter the EEG channel NUMBER to REMOVE (1-28): ');

% Validate input
while isempty(channel_to_remove) || channel_to_remove < 1 || channel_to_remove > 28 || mod(channel_to_remove, 1) ~= 0
    fprintf('Invalid choice! Must be an integer between 1 and 28\n');
    channel_to_remove = input('Enter the EEG channel NUMBER to REMOVE (1-28): ');
end

fprintf('\n>>> You chose to REMOVE channel %d (%s)\n', ...
        channel_to_remove, channel_names{channel_to_remove});
fprintf('>>> Channel 29 data will replace this channel\n');
fprintf('>>> Channel 30 (EVENT) will remain unchanged\n\n');


%% Replace Bad Channel with Channel 29
fprintf('\nStep 3: Replacing channel %d with channel 29...\n', channel_to_remove);

% Create final data: 29 channels (28 EEG + 1 EVENT)
final_data = zeros(29, size(data_matrix, 2));

% Copy channels 1-28, replacing the bad one
for ch = 1:28
    if ch == channel_to_remove
        final_data(ch, :) = data_matrix(29, :);  % Replace with channel 29
        fprintf('   Channel %d: REPLACED with channel 29\n', ch);
    else
        final_data(ch, :) = data_matrix(ch, :);  % Keep original
    end
end

% Keep EVENT channel as channel 29
final_data(29, :) = data_matrix(30, :);
fprintf('   Channel 29: EVENT (from original channel 30) kept as is\n');

fprintf('   ✓ Final configuration: 28 EEG channels + 1 EVENT channel\n');

%% Update Channel Names
final_channel_names = [channel_names, {'EVENT'}];
final_channel_names{channel_to_remove} = sprintf('%s_replaced', channel_names{channel_to_remove});

%% Visualize Final Configuration
fprintf('\nStep 4: Visualizing final channel configuration...\n');

fig3 = figure('Name', 'Final Configuration', 'NumberTitle', 'off', ...
              'Position', [400 50 1600 900], 'Color', 'w');

% Plot EEG channels (1-28)
for ch = 1:28
    data = final_data(ch, 1:samples_to_plot);
    data_norm = data - mean(data);
    data_offset = data_norm + (28 - ch) * v_spacing;
    
    % Highlight replaced channel in green
    if ch == channel_to_remove
        plot(time_vec, data_offset, 'g', 'LineWidth', 1.5);
        text(-0.5, (28 - ch) * v_spacing, sprintf('Ch%d: %s [REPLACED]', ch, final_channel_names{ch}), ...
             'FontSize', 9, 'FontWeight', 'bold', 'Color', 'g', 'HorizontalAlignment', 'right');
    else
        plot(time_vec, data_offset, 'b', 'LineWidth', 0.5);
        text(-0.5, (28 - ch) * v_spacing, sprintf('Ch%d: %s', ch, final_channel_names{ch}), ...
             'FontSize', 9, 'FontWeight', 'bold', 'HorizontalAlignment', 'right');
    end
    hold on;
end

% Add EVENT channel at bottom
data = final_data(29, 1:samples_to_plot);
plot(time_vec, data - 3*v_spacing, 'k', 'LineWidth', 1.5);
text(-0.5, -3*v_spacing, 'Ch29: EVENT', ...
     'FontSize', 9, 'FontWeight', 'bold', 'Color', 'k', 'HorizontalAlignment', 'right');

xlim([-1, time_window]);
ylim([-5*v_spacing, 29 * v_spacing]);
xlabel('Time (seconds)', 'FontSize', 12, 'FontWeight', 'bold');
title('Final 29 Channels: 28 EEG (Green = Replaced) + 1 EVENT', 'FontSize', 14, 'FontWeight', 'bold');
grid on;
set(gca, 'YTick', []);

fprintf('   Figure 8 created: Final configuration\n');

%% Save Data
fprintf('\nStep 5: Saving data and figures...\n');

save_dir = fullfile(userpath, 'my_data');
if ~exist(save_dir, 'dir')
    mkdir(save_dir);
end

% Transpose back to samples x channels for EEGLAB
eegData1 = final_data';

save(fullfile(save_dir, 'eeg_database.mat'), 'eegData1');
fprintf('   ✓ Data saved: eeg_database.mat\n');
fprintf('     Dimensions: %d samples x 29 channels (28 EEG + 1 EVENT)\n', size(eegData1, 1));

% Save metadata
replacement_info = struct();
replacement_info.removed_channel = channel_to_remove;
replacement_info.removed_channel_name = channel_names{channel_to_remove};
replacement_info.replacement_source = 'Channel 29 (original)';
replacement_info.final_channel_names = final_channel_names;
replacement_info.note = 'Channel 29 in final data is EVENT (from original channel 30)';

save(fullfile(save_dir, 'replacement_info.mat'), 'replacement_info');
fprintf('   ✓ Metadata saved: replacement_info.mat\n');

% Save all figures
saveas(fig1, fullfile(save_dir, 'fig1_all_28_eeg_channels.png'));
saveas(fig2, fullfile(save_dir, 'fig2_Individual Channel Traces (SAME Y-axis scale)'));
saveas(fig3, fullfile(save_dir, 'fig3_final_configuration.png'));

fprintf('   ✓ All figures saved (3 PNG files)\n');

%% Final Summary
fprintf('\n=== PROCESSING COMPLETE ===\n');
fprintf('Original configuration:\n');
fprintf('  - Channels 1-28: EEG data\n');
fprintf('  - Channel 29: Replacement data\n');
fprintf('  - Channel 30: EVENT\n\n');
fprintf('Action taken:\n');
fprintf('  - Removed channel: %d (%s)\n', channel_to_remove, channel_names{channel_to_remove});
fprintf('  - Replaced with: Channel 29 data (original replacement)\n');
fprintf('  - Kept: Channel 30 → now Channel 29 (EVENT)\n\n');
fprintf('Final configuration: 29 channels\n');
fprintf('  - Channels 1-28: EEG (one replaced)\n');
fprintf('  - Channel 29: EVENT\n\n');
fprintf('Data saved to: %s\n', fullfile(save_dir, 'eeg_database.mat'));
fprintf('Figures saved: 8 PNG files in %s\n', save_dir);
fprintf('===========================\n\n');
fprintf('✓ Ready for preprocessing!\n');
fprintf('  Use eeg_database.mat in your main script.\n');

