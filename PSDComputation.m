
EEG = load('C:\Users\MaSoOM\Documents\MATLAB\my_data\MainAbdolmaleki_preprocessed.mat').final_corrected;
%%
[num_channels, num_samples] = size(EEG);
 
window_size = 1000; %  in samples
step_size =500; % 50% overlap
 
start_indices = 1:step_size:(num_samples - window_size + 1);
stop_indices = start_indices + window_size - 1;
n_windows = length(start_indices);
 
fs = 1000; 
 
% Frequency bands in Hz
bands = struct('delta', [2, 3], 'theta', [4, 7], 'alpha', [8, 12], 'beta', [13, 30]);
 
% Create Hanning window
hanning_window = hann(window_size);
%% Perform FFT, calculate PSD, and compute band power for each channel and each window
 
% Initialize power storage
overlap_size = window_size / 2; 
band_power.delta = zeros(1, num_channels);
band_power.theta = zeros(1, num_channels);
band_power.alpha = zeros(1, num_channels);
band_power.beta = zeros(1, num_channels);

for ch = 1:num_channels
    channel_data = EEG(ch, :);  % Assign each channel's data to channel_data
    
    % Initialize temporary power storage for each window
    delta_psd = zeros(1, n_windows);
    theta_psd = zeros(1, n_windows);
    alpha_psd = zeros(1, n_windows);
    beta_psd = zeros(1, n_windows);

    for win = 1:n_windows 
        % Extract the current window of data
        windowed_signal = channel_data(start_indices(win):stop_indices(win));
        
        % Calculate PSD using Welch's method
        [segment_psd, f] = pwelch(windowed_signal, hanning_window, overlap_size , [], fs);

        % Determine frequency indices and calculate band power for the current window
        delta_idx = find(f >= bands.delta(1) & f <= bands.delta(2));
        theta_idx = find(f >= bands.theta(1) & f <= bands.theta(2));
        alpha_idx = find(f >= bands.alpha(1) & f <= bands.alpha(2));
        beta_idx = find(f >= bands.beta(1) & f <= bands.beta(2));
        
        delta_psd(win) = sum(segment_psd(delta_idx));
        theta_psd(win) = sum(segment_psd(theta_idx));
        alpha_psd(win) = sum(segment_psd(alpha_idx));
        beta_psd(win) = sum(segment_psd(beta_idx));
    end
    
    % Assign median band powers after processing all windows for this channel
    band_power.delta(ch) = median(delta_psd);
    band_power.theta(ch) = median(theta_psd);
    band_power.alpha(ch) = median(alpha_psd);
    band_power.beta(ch) = median(beta_psd);

    disp(['Processed channel: ', num2str(ch)]);
end

% If you want to concatenate band powers, ensure consistent dimensionality
all_band_power = cat(3, band_power.delta, band_power.theta, band_power.alpha, band_power.beta);
%%
save_dir = fullfile(userpath, 'my_data');
save(fullfile(save_dir, 'BaseMedianHosseinnejad'), "all_band_power");