# Changelog

All notable changes to this dataset are documented here. Versions follow the
Zenodo release tags.

## [1.1.0] — 2026-07-20

Adds the full processing pipeline and supporting documentation.

- Added the Python pipeline scripts that produce the analysis-ready files from
  raw FaceReader output: `extract_frx_mapping.py`, `relabel_raw_export.py`,
  `inject_v6_results.py`, `faceReader_aggregator.py`, `make_analysis_ready.py`.
- Added a combined notebook (`FaceReader_Pipeline.ipynb`) running the Python
  stages end to end from a single configuration cell.
- Added the aggregator output files (`*_PROCESSED_v9_PY.xlsx`) used by the
  frame-retention report.
- Expanded documentation: `docs/preprocessing.md` now documents each pipeline
  step, and `docs/data_dictionary.md` documents the aggregator output sheets and
  clarifies the `Blindness Status` column.
- Verified the current data files are exactly reproducible from the pipeline
  scripts (cell-for-cell identical outputs).
- Removed the placeholder `docs/REGENERATE_RENV.md`; `renv.lock` is finalized.

## [1.0.0] — 2026-01-01

Initial public release accompanying the Scientific Data Descriptor.

- Four timepoint files (Pre, Mid, Result, Post), each with Study 1 (Winners) and
  Study 2 (Losers) sheets.
- Nine FaceReader affect channels and twenty combined Action Units per
  athlete-event.
- Technical-validation script (`scripts/technical_validation.R`) reproducing all
  reported validation tables.
- `renv.lock` capturing the exact package environment.
