# Facial-emotion measures of Olympic and Paralympic athletes across match timepoints

[![DOI](https://zenodo.org/badge/1292152281.svg)](https://doi.org/10.5281/zenodo.21446738)
[![License: CC BY 4.0](https://img.shields.io/badge/License-CC%20BY%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by/4.0/)

Data and analysis code accompanying the Data Descriptor:

> Mehta, Saumya; Thies, Noemi; Pallare-Herbeck, Max; Memmert, Daniel; Furley, Philip. Facial-emotion measures of Olympic and Paralympic athletes across
> match timepoints. *Scientific Data* (in submission).

This repository contains the analysis-ready dataset and the technical-validation
code for facial-emotion measurements of Olympic (sighted) and Paralympic
(visually impaired) athletes, captured with Noldus FaceReader across four
competition timepoints (Pre, Mid, Result, Post). Athletes are grouped by vision
status (Sighted / Blind) and cultural Power Distance (High / Low), and split into
Study 1 (Winners) and Study 2 (Losers).

A permanent, versioned copy of this repository is archived on Zenodo at https://doi.org/10.5281/zenodo.21446738
 Please cite the Zenodo DOI rather than the
GitHub URL, which is the working copy and may change.

## Repository structure

```
.
├── README.md                              This file
├── LICENSE                                
├── CITATION.cff                           Citation metadata
├── renv.lock                              Exact R package versions for reproducibility
├── requirements.txt                       Packages list
├── .gitignore
├── scripts/
│   ├── extract_frx_mapping.py             Step 1: event mapping from project files
│   ├── relabel_raw_export.py              Step 2: relabel raw export for multi-event athletes who share serial numbers
│   ├── inject_v6_results.py               Step 3: inject verified Win/Loss, apply exclusions
│   ├── faceReader_aggregator.py           Step 4: pool frames to one value per athlete-event
│   ├── make_analysis_ready.py             Step 5: split into Study1_Winners / Study2_Losers
│   ├── FaceReader_Pipeline.ipynb          Single sequence of steps 1-5, single config cell (Python)
│   ├── technical_validation.R             Reproduces all validation tables from the data
│   └── frame_retention_per_participant.R  Frame yield per analysed participant
├── data/
│   ├── Pre_Analysed_Participants.xlsx
│   ├── Mid_Analysed_Participants.xlsx
│   ├── Result_Analysed_Participants.xlsx
│   ├── Post_Analysed_Participants.xlsx
│   └── (aggregator outputs *_PROCESSED_v9_PY.xlsx, produced by the aggregator)
├── results/                               Output written by the scripts
│   ├── univariate_results.csv
│   ├── manova_results.csv
│   ├── frame_retention_per_participant.csv
│   ├── frame_retention_summary.csv
│   └── FaceReader_Results_StudyWise Outputs/  Descriptive HTML tables per Study x Timepoint
│       (Emotions/AU breakdowns, sample breakdowns, summary appendix, Analysed_Participants_Final.xlsx)
├── FACS/                                  Supplementary manual FACS annotations (see note below)
├── BAPCS/                                 Supplementary manual BAPCS annotations (see note below)
└── docs/
    ├── data_dictionary.md                 Column-by-column description of the data
    ├── preprocessing.md                   How the data was produced and processed
    └── CHANGELOG.md                       Version history of the released dataset
```

## FaceReader study-wise outputs

`results/FaceReader_Results_StudyWise Outputs/` contains descriptive HTML
tables generated per Study (Winners/Losers) x Timepoint (Pre/Mid/Result/Post)
x channel type (Emotions/AU), plus per-study sample-breakdown tables and a
summary appendix (`Appendix_FaceReader_Emotion_Tables.html`). These are
reporting study outputs - all of which are used to validate the dataset based on expected directions of results.

## Supplementary manual annotations (FACS, BAPCS)

`FACS/` and `BAPCS/` contain manual coding annotations carried out independent of 
automated FaceReader pipeline described above: expert-rater Facial Action
Coding System (FACS) annotations and Body Action and Posture Coding System
(BAPCS) gesture codes, with their own descriptive and inferential outputs
(`FACS/Study 1_FACS Descriptives.xlsx`, `FACS/Study 2_FACS Descriptives.xlsx`,
`BAPCS/BAPCS_submitfiles/BAPCS_analysis.R`, and associated results). These are
supplementary reference material reported alongside the FaceReader findings in
the Data Descriptor.

## Data records

Each `*_Analysed_Participants.xlsx` file holds one competition timepoint and
contains two sheets, `Study1_Winners` and `Study2_Losers`. Each row is one
athlete-event; columns give participant identifiers, group memberships, the nine
FaceReader affect channels (seven basic emotions plus valence and arousal), and
the twenty combined Action Units. Full column definitions are in
[`docs/data_dictionary.md`](docs/data_dictionary.md).

## Code availability

All code used to produce and validate this dataset is in `scripts/` and archived
with the dataset on Zenodo. The pipeline from raw FaceReader exports to the
analysis-ready files is documented step by step in
[`docs/preprocessing.md`](docs/preprocessing.md); in brief:

1. `extract_frx_mapping.py` — recovers event identity from the FaceReader `.frx` project file
2. `relabel_raw_export.py` — relabels multi-event athletes in the raw frame-level export
3. `inject_v6_results.py` — injects the verified Win/Loss result, applies sample exclusions
4. `faceReader_aggregator.py` — pools valid frames to one value per athlete-event
5. `make_analysis_ready.py` — splits the pooled data into Study1_Winners / Study2_Losers
6. `technical_validation.R` — reproduces the Technical Validation tables (below)
7. `frame_retention_per_participant.R` — reports data completeness for the analysed sample

Steps 1-5 run in Python; `FaceReader_Pipeline.ipynb` runs all five from a single
configuration cell. Steps 6-7 run in R on the analysis-ready files. The
`*_PROCESSED_v9_PY.xlsx` files in `data/` are the output of step 4.

The raw FaceReader Excel exports and the intermediate per-timepoint reference
files are archived with the Zenodo record rather than in this repository, owing
to their size; the analysis-ready and aggregator output files needed to
reproduce every reported result are included here in `data/`.

## Reproducing the technical validation

The analysis runs in R. To reproduce every table in the Technical
Validation section:

```r
# 1. restore the exact package environment
install.packages("renv")
renv::restore()

# 2. run the validation
setwd("scripts")
source("technical_validation.R")
```

The script reads the four data files, applies the sample exclusions described in
the Data Descriptor, and writes `univariate_results.csv` and
`manova_results.csv` to `results/`. It prints `sessionInfo()` on completion so the
run environment is recorded alongside the output.

All required packages are listed in
[`requirements.txt`](requirements.txt).

To generate the frame-retention report, place the aggregator outputs
(`*_PROCESSED_v9_PY.xlsx`) in `data/` alongside the analysis-ready files, then:

```r
setwd("scripts")
source("frame_retention_per_participant.R")
```

This writes `frame_retention_per_participant.csv` and
`frame_retention_summary.csv` to `results/`.

## What the script does

Within each timepoint and study, four two-group contrasts are tested:

| Contrast | Subsample | Grouping |
|----------|-----------|----------|
| High vs Low Power Distance | Blind athletes | PD |
| High vs Low Power Distance | Sighted athletes | PD |
| Sighted vs Blind | High-PD athletes | Vision |
| Sighted vs Blind | Low-PD athletes | Vision |

Each contrast is tested across the nine emotion score and, separately, the
twenty Action Units, reporting Welch's t-test, Cohen's d, Hedges' g, a Bayesian
t-test, Levene's and Shapiro-Wilk assumption checks, and Benjamini-Hochberg
FDR-adjusted p-values. For the affect channels, a parametric MANOVA (Pillai's
trace) and a robust MANOVA (modified ANOVA-type statistic with a bootstrap
p-value) are additionally computed.

Frame-leel diagnostics (the number of FaceReader-analysed frames per athlete-event, and
the number retained as valid after excluding face-detection and model-fit
failures) are reported by `scripts/frame_retention_per_participant.R`. It covers
only the final analysed sample: the set of participants is taken from the
analysis-ready files, and frame counts are joined from the aggregator output on
`Participant_Name_Full`. It writes a per-participant table and a per timepoint x
study summary.

## License

Data and documentation are released under CC BY 4.0. The analysis code in
`scripts/` is released under the MIT License; see [`LICENSE`](LICENSE).

## Contact

Saumya Mehta: s.mehta@dshs-koeln.de

