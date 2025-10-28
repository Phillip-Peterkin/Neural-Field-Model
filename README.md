# Harmonic Field Theory Analysis Pipeline

**Energy, Coherence, and Content: Prerequisites for Neural Access to Awareness**

Author: Phillip Peterkin  
Date: October 2025

## Overview

This is a production-level MATLAB pipeline implementing the neural field model described in:
*Peterkin, P. (2025). Energy, Coherence, and Content: Prerequisites for Neural Access to Awareness.*

The pipeline processes intracranial EEG (iEEG) data from verbal working memory tasks and tests the model's predictions about:
- Spectral organization (theta-gamma coupling)
- Access detection (coherence + content thresholds)
- Energy budget constraints
- Task decoding (memory load, accuracy, match/mismatch)

## Installation

### Requirements
- MATLAB R2025b or later
- Toolboxes:
  - Signal Processing Toolbox
  - Statistics and Machine Learning Toolbox
  - Parallel Computing Toolbox
  - Optimization Toolbox
- Optional: EEGLAB, FieldTrip (for enhanced data loading)

### Setup
1. Clone or download this repository to `C:\HarmonicFieldTheory\`
2. Open MATLAB and run:
```matlab
   cd C:\HarmonicFieldTheory
   addpath(genpath('code'))
   savepath
```

## Usage

### Quick Start (Test Mode - 1 Subject)
```matlab
run_harmonic_field_pipeline('test_mode', true)
```

### Full Analysis (All Subjects)
```matlab
run_harmonic_field_pipeline()
```

### Single Subject
```matlab
run_harmonic_field_pipeline('subject', 'sub-01')
```

### Resume from Checkpoint
```matlab
run_harmonic_field_pipeline('resume', true)
```

## Pipeline Stages

1. **Data Loading** - BIDS-compliant dataset discovery
2. **Spectral Analysis** - Power spectra, aperiodic slope (1/f)
3. **Connectivity** - Phase-locking value (PLV), weighted PLI
4. **Phase-Amplitude Coupling** - Theta-gamma coupling (Tort's MI)
5. **Event-Related Analysis** - ERPs, N2, P3b latencies
6. **Access Detection** - Coherence thresholds + content validation
7. **Energy Budget** - Power consumption constraints
8. **Task Decoding** - SetSize, Correct/Error, Match classification
9. **Cross-Validation** - Leave-subject-out validation

## Output

Results are saved to:
- `results/` - MAT files with analysis outputs
- `results/figures/` - Publication-ready figures (PNG, PDF, FIG)
- `results/checkpoints/` - Subject-level checkpoints
- `logs/` - Processing logs and error reports

## Configuration

Edit `config/config_harmonic_field.m` to modify:
- Model parameters (Table 1 from manuscript)
- Access detection thresholds
- Energy budget caps
- Analysis parameters

## Project Structure
```
HarmonicFieldTheory/
├── run_harmonic_field_pipeline.m   (MAIN SCRIPT)
├── code/
│   ├── core/                       (Core processing)
│   ├── stages/                     (Analysis modules)
│   └── utilities/                  (Helper functions)
├── config/                         (Configuration)
├── results/                        (Output data)
└── logs/                           (Processing logs)
```

## Citation

If you use this code, please cite:
```
Peterkin, P. (2025). Energy, Coherence, and Content: Prerequisites for 
Neural Access to Awareness. [Journal Details TBD]
```

## License

MIT License - See LICENSE file for details

## Contact

Phillip Peterkin  
Email: [your_email@domain.com]  
GitHub: [your_github]

## Troubleshooting

**Out of memory errors:**
- Reduce `config.compute.chunk_size`
- Process fewer subjects in parallel
- Increase system RAM

**Parallel pool errors:**
- Set `config.compute.num_workers` to lower value
- Ensure Parallel Computing Toolbox is installed

**Missing functions:**
- Ensure all folders in `code/` are on MATLAB path
- Run `addpath(genpath('C:\HarmonicFieldTheory\code'))`

## Version History

- v1.0 (October 2025) - Initial release