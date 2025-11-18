# EEG-Pre-Processing
# EEG Data Processing Pipeline

## Overview
This repository provides a modular EEG preprocessing pipeline, including:
- **Automatic channel verification and replacement** for datasets with one additional incorrect channel.
- **Bad-channel detection** and removal.
- **Epoch rejection** based on artifact percentage.
- **Power Spectral Density (PSD)** estimation with integration over canonical EEG frequency bands.

---

## 1. Channel Removal & Correction
Some datasets contain **30 signals**, where:
- **Channels 1–29** are EEG  
- **Channel 30** is an **event marker**  
- **One EEG channel among 1–28 is incorrect/extra**

The script:
1. Identifies the extra channel by detecting which one does *not* match typical EEG statistical behavior.
2. Replaces that extra channel with the data from **channel 28** to maintain consistent structure.

---

## 2. EEGPreprocessing (Bad Channel Detection, Artifact Detection and Correction)
Bad channels are identified using:
- Variance thresholding  
- Flat-line detection  
- Correlation with surrounding channels  
- Amplitude deviation detection  

Detected bad channels are removed before downstream processing.

Datasets are rejected if:
- **More than 10%** of EEG channels are bad  
- **More than 20%** of epochs are rejected due to artifacts  

---

## 3. Power Spectral Density (PSD)
PSD is computed using **Welch’s method** and integrated across standard EEG frequency bands



---

## 5. Repository Structure
