# Preprocessing pipeline

This document describes how the analysis-ready data files were produced from the
raw Noldus FaceReader exports. It is provided so that the derivation of every
value in the dataset is transparent. The pipeline is a sequence
of Python scripts (preprocessing and aggregation) followed by the R analysis;
the analysis-ready files in `data/` are produced from the aggregator output.

## Overview

Raw FaceReader output is frame-level: for each analysed video, every frame
carries an intensity value per emotion category and per Action Unit, or an error
token (like a face-detection or model-fit failure) where no valid reading
was obtained. Multi-event athletes share a single serial number, so events that
belong to the same athlete but different competitions must be separated before
any averaging. The pipeline resolves event identity, attaches the verified
competition result, pools valid frames to one value per athlete-event, and emits
the study-split, analysis-ready files. It uses a master athlete list where all this information is stored.

## Pipeline steps

The steps run per timepoint (Pre, Mid, Result, Post).

1. **`extract_frx_mapping.py` — extract event mapping from the FaceReader project.**
   Reads the FaceReader `.frx` project archive and records,
   for every (Participant, Analysis) pair, the source video's folder name and
   filename. For mapping, only the folder name and filename are used, no other information is needed.

2. **`relabel_raw_export.py` — relabel the raw frame-level export.**
   Athletes whose Analyses came from folders that share serial numbers but have differing event codes have their `Participant Name` replaced, on each
   frame-level row, with the actual source folder name for that row's Analysis.
   This helps distinguish athlete with the same serial number (same athlete) who appear in multiple competition, and allows to treat them independently. 
   Single-event athletes are left untouched. A cross-check audit file is written
   alongside the relabelled export, flagging any athlete where the number of
   labels produced doesn't match the number of distinct events expected.

4. **`inject_v6_results.py` — inject the verified competition result and apply exclusions.**
   The authoritative Win/Loss result for each event is written onto every row,
   keyed on serial *and* event (not serial alone, since a multi-event athlete
   can win one competition and lose another). The result is sourced from a
   previously verified, aggregated reference dataset in which Win/Loss had
   already been checked against the competition video filenames — filename
   evidence takes precedence over folder names or the master athlete list
   wherever they disagree. Rows with no verified result (the excluded non-blind
   para-sport athletes, and a small number of rows with no valid `.frx`
   analyses) are dropped here, before aggregation, so they never enter the
   aggregator. The step fails rather than writing a silent blank if any
   retained row ends up without a result.

5. **`faceReader_aggregator.py` — aggregate to one value per athlete-event.**
   Frames are grouped strictly by the full `Participant Name` label produced in
   step 2, so multi-event athletes stay split.
   Values matching a fixed set of error tokens (`fit_failed`,
   `find_failed`, `no_face`, `missing`, `n/a`, `na`, `error`, `invalid`,
   `none`, and blank) are treated as missing and excluded before averaging. The
   pooled value for each channel is the mean over the remaining valid frames,
   pooled across all of that athlete-event's Analyses. The aggregator also
   records, per athlete-event, the total frame count, valid frame count, and
   validity percentage. The Win/Loss result is taken from the per-row
   `Result` column injected in step 3 where present or falls back to the master list by serial number.
   Other metadata (name, nationality, PD, gender, competition) is taken from the
   master list by serial number. Output is three sheets
   (`Pooled_By_Participant`, `Analysis_Quality`, `Verification`) written as
   `<Timepoint>_PROCESSED_v9_PY.xlsx`.

7. **`make_analysis_ready.py` — produce the analysis-ready files.**
   The pooled data is split by study and result into the two sheets
   (`Study1_Winners`, `Study2_Losers`) and reduced to one value per channel with
   the identifier and grouping columns. This is the output shipped in `data/`.

8. **Analysis and downstream documentation.**
   `scripts/technical_validation.R` runs the group comparisons on the
   analysis-ready files. Athlete-level attributes (such as blindness status) are
   joined by full participant name, which is the stable key across pipeline
   versions — not by serial number, which is not guaranteed unique per athlete
   once multi-event splitting is applied.

## Notes on key design decisions

- **Full participant label, not serial number, is the grouping key.** Serial
  numbers are shared by multi-event athletes, so grouping by serial would collapse
  distinct events. Grouping by the full event label keeps them separate.

- **Result is taken from the competition video file names.** Video file names are
  the most reliable source of Win/Loss and take precedence over folder names or
  the master list where they disagree.

- **Matching is drive-letter- and path-independent.** Source footage lives
  across several external hard disks that mount under different drive letters
  on different machines. Every join in the pipeline uses folder name and
  filename only, never the full absolute path.

- **Zero-padded serials are normalized before matching.** Spreadsheet
  round-trips (save/reopen in Excel) silently convert zero-padded text serials
  such as `"0099"` to the plain number `99`. Every join point strips leading
  zeros before comparing keys, so this doesn't cause silent match failures.

- **Valid frames only.** Error-token frames are excluded from the pooled mean, so
  each value reflects only frames where FaceReader obtained a valid reading. The
  proportion of valid frames per athlete-event is reported as part of the
  technical validation.

- **Exclusions happen once, at injection.** The non-blind para-sport athletes and
  dropped rows are removed before aggregation, so the analysis-ready files already
  contain only the analysed sample.

## FaceReader configuration

FaceReader version: 10.
No pre-existing ethnicity- or origin-specific models or filters were applied, so
that the analysis configuration was uniform across all participants.
Action Units retained: the 20 combined (bilateral) channels; left/right duplicates
are excluded as redundant (they correlate near unity with the combined channel).
