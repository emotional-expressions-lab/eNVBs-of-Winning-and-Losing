# Data dictionary

Each file (`Pre_`, `Mid_`, `Result_`, `Post_Analysed_Participants.xlsx`)
corresponds to one competition timepoint and contains two sheets:
`Study1_Winners` (athletes who won) and `Study2_Losers` (athletes who lost).
One row is one athlete-event. The timepoint is identified by the file name.

The affect channels and Action Units were produced with Noldus FaceReader 10.
No pre-existing ethnicity- or origin-specific models or filters were applied,
ensuring a uniform analysis configuration across all participants. See the
preprocessing documentation for the full FaceReader configuration.

## Identifier and grouping columns

| Column | Type | Description |
|--------|------|-------------|
| `Study` | text | `Study 1` (Winners sheet) or `Study 2` (Losers sheet). |
| `Timepoint` | text | Competition moment. The value is given by the file name (Pre, Mid, Result, Post); the in-cell field may be blank. |
| `Sr_No` | integer | Serial number, the primary athlete identifier. Athletes competing in more than one event are split per event and share a serial across events. |
| `Participant_Name_Full` | text | Full participant label used as the join key across processing steps. |
| `Name` | text | Athlete name. |
| `Nationality` | text | Athlete nationality. |
| `Gender` | text | `Female` or `Male`. |
| `Competition` | text | Competition name. `Olympic` denotes the sighted sample; all other (Paralympic and para-sport) competitions denote the visually impaired sample. |
| `Vision` | text | `Sighted` (Olympic) or `Blind` (visually impaired). Derived from Competition per the sampling-frame rule. |
| `Blindness Status` | text | Descriptive attribute for the visually impaired sample; `N/A (Sighted)` for the Olympic sample and a placeholder (`Unknown`) for the visually impaired sample in the released files. Not used in any statistic: the analysis groups only by Vision x PD. |
| `PD` | text | Cultural Power Distance group of the athlete's nationality: `High` or `Low`. |
| `Result` | text | `Win` (Study 1 sheet) or `Loss` (Study 2 sheet). Derived from the competition video file names. |

## FaceReader affect channels

One pooled value per athlete-event, averaged across all valid analysed video
frames. The seven basic emotions and neutral are intensity probabilities in
[0, 1]; valence is in [-1, 1]; arousal is in [0, 1].

| Column | Type | Range | Description |
|--------|------|-------|-------------|
| `Neutral` | numeric | 0–1 | Neutral expression intensity. |
| `Happy` | numeric | 0–1 | Happiness intensity. |
| `Sad` | numeric | 0–1 | Sadness intensity. |
| `Angry` | numeric | 0–1 | Anger intensity. |
| `Surprised` | numeric | 0–1 | Surprise intensity. |
| `Scared` | numeric | 0–1 | Fear intensity. |
| `Disgusted` | numeric | 0–1 | Disgust intensity. |
| `Valence` | numeric | -1–1 | Positive minus negative expression (pleasantness). |
| `Arousal` | numeric | 0–1 | Activation / intensity of expression. |

## Action Units

Twenty combined (bilateral) Facial Action Unit activations, one pooled value per
athlete-event in [0, 1]. Left/right channels are excluded; they correlate near
unity with the combined channel and are redundant.

Because the source material is real competition footage rather than controlled
laboratory recordings, recording conditions vary across athlete-events. Automated
AU intensities can be influenced by such conditions: overhead or uneven lighting
can cast shadows that inflate brow-region units (e.g. AU04), and non-frontal head
pose or partial occlusion can attenuate detection. These are known properties of
automated facial coding and are documented here so that users can interpret the
AU channels with appropriate caution. The frame-level face-detection and model-fit
quality that underlies each pooled value is summarised in the Technical Validation
section of the Data Descriptor.

| Column | Action Unit |
|--------|-------------|
| `AU01_InnerBrowRaiser` | AU01 Inner Brow Raiser |
| `AU02_OuterBrowRaiser` | AU02 Outer Brow Raiser |
| `AU04_BrowLowerer` | AU04 Brow Lowerer |
| `AU05_UpperLidRaiser` | AU05 Upper Lid Raiser |
| `AU06_CheekRaiser` | AU06 Cheek Raiser |
| `AU07_LidTightener` | AU07 Lid Tightener |
| `AU09_NoseWrinkler` | AU09 Nose Wrinkler |
| `AU10_UpperLipRaiser` | AU10 Upper Lip Raiser |
| `AU12_LipCornerPuller` | AU12 Lip Corner Puller |
| `AU14_Dimpler` | AU14 Dimpler |
| `AU15_LipCornerDepressor` | AU15 Lip Corner Depressor |
| `AU17_ChinRaiser` | AU17 Chin Raiser |
| `AU18_LipPucker` | AU18 Lip Pucker |
| `AU20_LipStretcher` | AU20 Lip Stretcher |
| `AU23_LipTightener` | AU23 Lip Tightener |
| `AU24_LipPressor` | AU24 Lip Pressor |
| `AU25_LipsPart` | AU25 Lips Part |
| `AU26_JawDrop` | AU26 Jaw Drop |
| `AU27_MouthStretch` | AU27 Mouth Stretch |
| `AU43_EyeClosure` | AU43 Eye Closure |

## Notes on the analysed sample

The released files contain the full sample. The technical-validation script
excludes a fixed list of non-blind para-sport athletes (by serial number) at
read time, so that the `Blind` group comprises only visually impaired athletes;
these rows remain in the data files for completeness and are not removed on disk.
Panel sample sizes may therefore fall a few below the group totals where an
athlete has a missing Power Distance value and drops from a Power Distance
contrast. This is expected and documented in the Data Descriptor.

## Aggregator output files (`*_PROCESSED_v9_PY.xlsx`)

These are the intermediate, un-split aggregated files that the
`*_Analysed_Participants.xlsx` files are derived from. Each has three sheets:

| Sheet | Grain | Key columns |
|---|---|---|
| `Pooled_By_Participant` | one row per athlete-event | identifier/grouping columns as above, plus `<Channel>_AllAnalyses` (pooled mean across all valid frames) and `<Channel>_AllAnalyses_NFrames` (valid frame count behind that mean), for every affect channel and Action Unit including left/right sub-channels |
| `Analysis_Quality` | one row per athlete-event × Analysis Index | `Total_Frames`, `Valid_Frames`, `Invalid_Frames`, `Invalid_Pct`, `Flagged_30pct`, `Flagged_50pct` (yes/no; informational only, nothing is excluded from `Pooled_By_Participant` on this basis) |
| `Verification` | one row per athlete-event | `<Channel>_Sum` and `<Channel>_Count` alongside the mean in `Pooled_By_Participant`, so `Sum / Count` can be checked against `_AllAnalyses` |
