eeglab_path = "C:\Users\MaSoOM\Documents\MATLAB\eeglab2024";
addpath(eeglab_path);
eeglab nogui;

%% === QUALITY CONTROL THRESHOLDS ===
QC_THRESHOLDS.max_bad_channels_percent = 10;  % Max 10% bad channels
QC_THRESHOLDS.max_data_rejected_percent = 20; % Max 20% data rejected

%% === FOR REPRODUCIBLE RESULTS ===
rng(42); % Set random seed for consistent ICA results across runs

%%
eegData1 = readmatrix('C:\Users\MaSoOM\Documents\MATLAB\Processing\base.txt');

save_dir = fullfile(userpath, 'my_data');
if ~exist(save_dir, 'dir')
    mkdir(save_dir);
end

save(fullfile(save_dir, 'eeg_database.mat'), 'eegData1')


%% Import and Setup
file_path = "C:\Users\MaSoOM\Documents\MATLAB\my_data\eeg_database.mat";
set_name = 'Baseabdollahi';
EEG = pop_importdata('dataformat','matlab','nbchan',0,'data',file_path,'srate',1000,'pnts',0,'xmin',0);
EEG = pop_chanevent(EEG,29);
EEG = pop_chanedit(EEG, 'lookup','C:\Users\MaSoOM\Documents\MATLAB\eeglab2024\plugins\dipfit\standard_BESA\standard-10-5-cap385.elp','load',{'C:\Users\MaSoOM\Documents\MATLAB\Processing\chn.loc','filetype','loc'});

% Store original info
original_channels = EEG.nbchan;
original_samples = EEG.pnts;

% Filter [1-30 Hz]
EEG = pop_eegfiltnew(EEG, 'locutoff',1,'hicutoff',30,'plotfreqz',0);

%% Visualize Channel Locations
figure;
topoplot([], EEG.chanlocs, 'style', 'blank', 'electrodes', 'labels');
title('EEG Electrode Channel Locations');

%% Average Reference
EEG_temp = pop_reref(EEG, []);

%% Bad Channel Detection with Iterative Refinement
bad_channels = [];
removed_channels = [];
while 1
    EEG_channsremoved = pop_clean_rawdata(EEG_temp, 'FlatlineCriterion',5,'ChannelCriterion',0.80,'LineNoiseCriterion',4,'Highpass','off','BurstCriterion','off','WindowCriterion','off','BurstRejection','off','Distance','Euclidian');
    if (isfield(EEG_channsremoved.etc, 'clean_channel_mask'))
        removed_channels = find(EEG_channsremoved.etc.clean_channel_mask==0);
    end
    previous_bad = bad_channels;
    bad_channels = union(bad_channels, removed_channels);
    if (isequal(bad_channels, previous_bad))
        break;
    end
    
    EEG_interpolated = eeg_interp(EEG, bad_channels, 'spherical');
    interpolated_mean = mean(EEG_interpolated.data);
    EEG_temp.data = EEG.data - interpolated_mean;
end

EEG_temp = eeg_interp(EEG, bad_channels, 'spherical');
reference_signal = mean(EEG_temp.data);
EEG.data = EEG.data - reference_signal;

EEG_channsremoved = pop_clean_rawdata(EEG, 'FlatlineCriterion',5,'ChannelCriterion',0.80,'LineNoiseCriterion',4,'Highpass','off','BurstCriterion','off','WindowCriterion','off','BurstRejection','off','Distance','Euclidian');
bad_channels = [];
if (isfield(EEG_channsremoved.etc, 'clean_channel_mask'))
    bad_channels = find(EEG_channsremoved.etc.clean_channel_mask==0);
end

%% === QC CHECK 1: Bad Channels ===
n_bad_channels = length(bad_channels);
bad_channels_percent = (n_bad_channels / original_channels) * 100;

fprintf('\n=== QUALITY CHECK 1: Bad Channels ===\n');
fprintf('Bad channels: %d out of %d (%.2f%%)\n', n_bad_channels, original_channels, bad_channels_percent);

if bad_channels_percent > QC_THRESHOLDS.max_bad_channels_percent
    warning('FAILED: %.2f%% channels interpolated (threshold: %.1f%%)', bad_channels_percent, QC_THRESHOLDS.max_bad_channels_percent);
    fprintf('*** This participant should be EXCLUDED from analysis ***\n');
    qc_pass_channels = false;
else
    fprintf('✓ PASSED: Bad channels within acceptable range\n');
    qc_pass_channels = true;
end

%% ASR Artifact Rejection
samples_before_asr = size(EEG_channsremoved.data, 2);

EEG_asr = pop_clean_rawdata(EEG_channsremoved, 'FlatlineCriterion','off','ChannelCriterion','off','LineNoiseCriterion','off','Highpass','off','BurstCriterion',10,'WindowCriterion','off','BurstRejection','off','Distance','Euclidian');

%% === QC CHECK 2: Data Rejection ===
samples_after_asr = size(EEG_asr.data, 2);
samples_rejected = samples_before_asr - samples_after_asr;
data_rejected_percent = (samples_rejected / samples_before_asr) * 100;

fprintf('\n=== QUALITY CHECK 2: Data Rejection ===\n');
fprintf('Samples rejected: %d out of %d (%.2f%%)\n', samples_rejected, samples_before_asr, data_rejected_percent);

if data_rejected_percent > QC_THRESHOLDS.max_data_rejected_percent
    warning('FAILED: %.2f%% data rejected (threshold: %.1f%%)', data_rejected_percent, QC_THRESHOLDS.max_data_rejected_percent);
    fprintf('*** This participant should be EXCLUDED from analysis ***\n');
    qc_pass_rejection = false;
else
    fprintf('✓ PASSED: Data rejection within acceptable range\n');
    qc_pass_rejection = true;
end

EEG_interpolated = eeg_interp(EEG_asr, EEG.chanlocs, 'spherical');
EEG = pop_reref(EEG_interpolated, []);

%% ICA Decomposition
fprintf('\n=== Running ICA (this may take several minutes) ===\n');
EEG = pop_runica(EEG, 'icatype', 'runica', 'extended', 1, 'interrupt', 'on');

%% ICLabel Classification
EEG = iclabel(EEG);
n_component = size(EEG.etc.ic_classification.ICLabel.classifications,1);

ic_classifications = EEG.etc.ic_classification.ICLabel.classifications;
[~,I] = max(ic_classifications, [], 2);

% Find brain and artifact components
brainIdx = find(ic_classifications(:,1) >= 0.7);
artifactIdx = find(ic_classifications(:,1) < 0.7);

fprintf('\n=== ICA Component Classification ===\n');
fprintf('Total components: %d\n', n_component);
fprintf('Brain components (≥70%% prob): %d\n', length(brainIdx));
fprintf('Artifact components (<70%% prob): %d\n', length(artifactIdx));

%% === VISUALIZE BRAIN COMPONENTS ===
if ~isempty(brainIdx)
    figure('Name', 'Brain Components (KEPT)', 'NumberTitle', 'off', 'Position', [100 100 1200 800]);
    n_brain = length(brainIdx);
    n_cols = ceil(sqrt(n_brain));
    n_rows = ceil(n_brain / n_cols);
    
    for i = 1:length(brainIdx)
        subplot(n_rows, n_cols, i);
        topoplot(EEG.icawinv(:, brainIdx(i)), EEG.chanlocs, 'electrodes', 'off');
        title(sprintf('IC%d: Brain %.1f%%', brainIdx(i), ic_classifications(brainIdx(i), 1)*100), 'FontSize', 10);
    end
    sgtitle('Brain Components (Will be KEPT)', 'FontSize', 14, 'FontWeight', 'bold', 'Color', 'green');
end

%% === VISUALIZE ARTIFACT COMPONENTS ===
if ~isempty(artifactIdx)
    figure('Name', 'Artifact Components (REMOVED)', 'NumberTitle', 'off', 'Position', [150 50 1200 800]);
    n_artifact = length(artifactIdx);
    n_cols = ceil(sqrt(n_artifact));
    n_rows = ceil(n_artifact / n_cols);
    
    component_labels = {'Brain', 'Muscle', 'Eye', 'Heart', 'Line', 'Chan', 'Other'};
    
    for i = 1:length(artifactIdx)
        subplot(n_rows, n_cols, i);
        topoplot(EEG.icawinv(:, artifactIdx(i)), EEG.chanlocs, 'electrodes', 'off');
        
        [max_prob, comp_type] = max(ic_classifications(artifactIdx(i), :));
        type_label = component_labels{comp_type};
        
        title(sprintf('IC%d: %s %.1f%%', artifactIdx(i), type_label, max_prob*100), 'FontSize', 10);
    end
    sgtitle('Artifact Components (Will be REMOVED)', 'FontSize', 14, 'FontWeight', 'bold', 'Color', 'red');
end



%% Remove Artifact Components
EEG = pop_subcomp(EEG, artifactIdx, 0);
final_corrected = EEG.data;

%% === FINAL QUALITY CONTROL SUMMARY ===
fprintf('\n========================================\n');
fprintf('   FINAL QUALITY CONTROL SUMMARY\n');
fprintf('========================================\n');
fprintf('Participant: %s\n', set_name);
fprintf('----------------------------------------\n');
fprintf('Bad channels: %.2f%% - %s\n', bad_channels_percent, ...
    iif(qc_pass_channels, 'PASS', 'FAIL'));
fprintf('Data rejected: %.2f%% - %s\n', data_rejected_percent, ...
    iif(qc_pass_rejection, 'PASS', 'FAIL'));
fprintf('Brain components kept: %d\n', length(brainIdx));
fprintf('Artifact components removed: %d\n', length(artifactIdx));
fprintf('----------------------------------------\n');

overall_pass = qc_pass_channels && qc_pass_rejection;

if overall_pass
    fprintf('✓✓✓ OVERALL: DATA QUALITY ACCEPTABLE ✓✓✓\n');
    fprintf('>>> INCLUDE this participant in analysis\n');
else
    fprintf('✗✗✗ OVERALL: DATA QUALITY INSUFFICIENT ✗✗✗\n');
    fprintf('>>> EXCLUDE this participant from analysis\n');
end
fprintf('========================================\n\n');

%% Save Results
save(fullfile(save_dir, [set_name, '_corrected']), "final_corrected");

% Save QC Report
QC_REPORT.participant = set_name;
QC_REPORT.date_processed = datestr(now);
QC_REPORT.bad_channels_percent = bad_channels_percent;
QC_REPORT.data_rejected_percent = data_rejected_percent;
QC_REPORT.n_bad_channels = n_bad_channels;
QC_REPORT.n_brain_components = length(brainIdx);
QC_REPORT.n_artifact_components = length(artifactIdx);
QC_REPORT.qc_pass_channels = qc_pass_channels;
QC_REPORT.qc_pass_rejection = qc_pass_rejection;
QC_REPORT.overall_pass = overall_pass;
save(fullfile(save_dir, [set_name, '_QC_report']), "QC_REPORT");

% Save text report
fid = fopen(fullfile(save_dir, [set_name, '_QC_report.txt']), 'w');
fprintf(fid, '=== EEG QUALITY CONTROL REPORT ===\n\n');
fprintf(fid, 'Participant: %s\n', set_name);
fprintf(fid, 'Processing Date: %s\n\n', datestr(now));
fprintf(fid, 'Original Channels: %d\n', original_channels);
fprintf(fid, 'Recording Duration: %.2f seconds\n\n', original_samples/1000);
fprintf(fid, 'Bad Channels: %d (%.2f%%) - %s\n', n_bad_channels, bad_channels_percent, ...
    iif(qc_pass_channels, 'PASS', 'FAIL'));
fprintf(fid, 'Data Rejected: %.2f%% - %s\n', data_rejected_percent, ...
    iif(qc_pass_rejection, 'PASS', 'FAIL'));
fprintf(fid, 'Brain Components: %d\n', length(brainIdx));
fprintf(fid, 'Artifact Components: %d\n\n', length(artifactIdx));
fprintf(fid, 'OVERALL STATUS: %s\n', iif(overall_pass, 'INCLUDE', 'EXCLUDE'));
fclose(fid);

fprintf('\n✓ Results saved to: %s\n', save_dir);
fprintf('  - Corrected data: %s_corrected.mat\n', set_name);
fprintf('  - QC report: %s_QC_report.mat\n', set_name);
fprintf('  - QC text: %s_QC_report.txt\n\n', set_name);

%% Helper Function
function result = iif(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end

end

