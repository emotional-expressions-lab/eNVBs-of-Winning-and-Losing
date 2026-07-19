# Preprocessing pipeline

This document describes how the analysis-ready data files were produced from the
raw Noldus FaceReader exports. It is provided so that the derivation of every
value in the dataset is transparent and reproducible. The pipeline is a sequence
of Python scripts followed by the R analysis; the analysis-ready files in `data/`
are the output of the `make_analysis_ready` step.

## Overview

Raw FaceReader output is frame-level: for each analysed video, every frame
carries an intensity value per emotion channel and per Action Unit, or an error
token (for example a face-detection or model-fit failure) where no valid reading
was obtained. Multi-event athletes share a single serial number, so events that
belong to the same athlete but different competitions must be separated before
any averaging. The pipeline resolves event identity, attaches the verified
competition result, pools valid frames to one value per athlete-event, and emits
the study-split, analysis-ready files.

## Pipeline steps

The steps run per timepoint (Pre, Mid, Result, Post).

1. **Extract event mapping from the FaceReader project.**
   The `.frx` project file is parsed to recover, for each analysed video, the
   full event label (including the competition suffix that distinguishes events
   sharing a serial number). This produces a mapping used to relabel the raw
   export.

2. **Relabel the raw frame-level export.**
   The raw detailed FaceReader Excel export is relabelled using the mapping from
   step 1, so that every frame carries its full participant-event label. This is
   what allows multi-event athletes to be kept as separate participants downstream.

3. **Inject the verified competition result and apply exclusions.**
   The authoritative Win/Loss result for each event, derived from the competition
   video file names, is written onto every row. Athletes outside the analysed
   sample (non-blind para-sport competitors) and a small number of dropped rows
   are removed at this step, so they never enter aggregation.

4. **Aggregate to one value per athlete-event.**
   Frames are grouped strictly by the full participant-event label. Error tokens
   are treated as missing; the pooled value for each channel is the mean over the
   valid (non-missing) frames. The aggregator also records, per athlete-event, the
   total number of frames, the number of valid frames, and the resulting validity
   percentage. These frame counts are used by
   `scripts/frame_retention_per_participant.R` for the completeness report.

5. **Produce the analysis-ready files.**
   The pooled data is split by study and result into the two sheets
   (`Study1_Winners`, `Study2_Losers`) and reduced to one value per channel with
   the identifier and grouping columns. This is the output shipped in `data/`.

6. **Analysis and downstream documentation.**
   `scripts/technical_validation.R` runs the group comparisons on the
   analysis-ready files. Athlete-level attributes (such as blindness status) are
   joined by full participant name, which is the stable key across pipeline
   versions.

## Notes on key design decisions

- **Full participant label, not serial number, is the grouping key.** Serial
  numbers are shared by multi-event athletes, so grouping by serial would collapse
  distinct events. Grouping by the full event label keeps them separate.

- **Result is taken from the competition video file names.** Video file names are
  the most reliable source of Win/Loss and take precedence over folder names or
  the master list where they disagree.

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
