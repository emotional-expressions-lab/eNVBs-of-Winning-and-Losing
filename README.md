# Facial-emotion measures of Olympic and Paralympic athletes across match timepoints

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.XXXXXXX.svg)](https://doi.org/10.5281/zenodo.XXXXXXX)
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

A permanent, versioned copy of this repository is archived on Zenodo at
https://doi.org/10.5281/zenodo.XXXXXXX. Please cite the Zenodo DOI rather than the
GitHub URL, which is the working copy and may change.

## Repository structure

```
.
├── README.md                              This file
├── LICENSE                                MIT (code) + CC BY 4.0 (data/docs)
├── CITATION.cff                           Citation metadata
├── renv.lock                              Exact R package versions for reproducibility
├── requirements.txt                       Package list (summary of renv.lock)
├── .gitignore
├── scripts/
│   ├── technical_validation.R             Reproduces all validation tables from the data
│   └── frame_retention_per_participant.R  Frame yield per analysed participant
├── data/
│   ├── Pre_Analysed_Participants.xlsx
│   ├── Mid_Analysed_Participants.xlsx
│   ├── Result_Analysed_Participants.xlsx
│   ├── Post_Analysed_Participants.xlsx
│   └── (aggregator outputs *_PROCESSED_v9_PY.xlsx, for the frame-yield script)
├── results/                               Output written by the scripts (created on run)
│   ├── univariate_results.csv
│   ├── manova_results.csv
│   ├── frame_retention_per_participant.csv
│   └── frame_retention_summary.csv
└── docs/
    ├── data_dictionary.md                 Column-by-column description of the data
    ├── preprocessing.md                   How the data was produced (pipeline)
    ├── CHANGELOG.md                        Version history of the released dataset
    └── REGENERATE_RENV.md                  How to finalize renv.lock before release
```

## Data records

Each `*_Analysed_Participants.xlsx` file holds one competition timepoint and
contains two sheets, `Study1_Winners` and `Study2_Losers`. Each row is one
athlete-event; columns give participant identifiers, group memberships, the nine
FaceReader affect channels (seven basic emotions plus valence and arousal), and
the twenty combined Action Units. Full column definitions are in
[`docs/data_dictionary.md`](docs/data_dictionary.md).

## Reproducing the technical validation

The analysis runs in R (>= 4.2). To reproduce every table in the Technical
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

If you prefer not to use `renv`, install the packages listed in
[`requirements.txt`](requirements.txt) manually; the script depends only on CRAN
packages.

To generate the frame-retention report, place the aggregator outputs
(`*_PROCESSED_v9_PY.xlsx`) in `data/` alongside the analysis-ready files, then:

```r
setwd("scripts")
source("frame_retention_per_participant.R")
```

This writes `frame_retention_per_participant.csv` and
`frame_retention_summary.csv` to `results/`.

## What the code does

Within each timepoint and study, four two-group contrasts are tested:

| Contrast | Subsample | Grouping |
|----------|-----------|----------|
| High vs Low Power Distance | Blind athletes | PD |
| High vs Low Power Distance | Sighted athletes | PD |
| Sighted vs Blind | High-PD athletes | Vision |
| Sighted vs Blind | Low-PD athletes | Vision |

Each contrast is tested across the nine affect channels and, separately, the
twenty Action Units, reporting Welch's t-test, Cohen's d, Hedges' g, a Bayesian
t-test, Levene's and Shapiro-Wilk assumption checks, and Benjamini-Hochberg
FDR-adjusted p-values. For the affect channels, a parametric MANOVA (Pillai's
trace) and a robust MANOVA (modified ANOVA-type statistic with a bootstrap
p-value) are additionally computed.

Data completeness (the number of FaceReader-analysed frames per athlete-event, and
the number retained as valid after excluding face-detection and model-fit
failures) is reported by `scripts/frame_retention_per_participant.R`. It covers
only the final analysed sample: the set of participants is taken from the
analysis-ready files, and frame counts are joined from the aggregator output on
`Participant_Name_Full`. It writes a per-participant table and a per timepoint x
study summary.

## License

Data and documentation are released under CC BY 4.0. The analysis code in
`scripts/` is released under the MIT License; see [`LICENSE`](LICENSE).

## Contact

Saumya Mehta: s.mehta@dshs-koeln.de

