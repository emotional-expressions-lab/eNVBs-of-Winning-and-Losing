# Frame retention per analysed participant.
#
# Reports, for every athlete-event that enters the statistical analysis, how many
# FaceReader frames were analysed and how many were retained as valid (i.e. not a
# face-detection or model-fit failure). This documents the completeness and
# quality of the automated coding underlying each pooled value.
#
# Scope: only the final analysed sample. The set of analysed participants is taken
# directly from the analysis-ready files (which are already restricted to valid
# vision and the correct result, with disabled athletes and dropped rows removed),
# so athletes with no analysis, disabled athletes, and dropped rows are excluded
# by construction. Frame counts are drawn from the aggregator output, joined on
# Participant_Name_Full (the stable key; Sr_No is not used for joining).
#
# Inputs:
#   ANALYSIS_READY : one file per timepoint, sheets Study1_Winners / Study2_Losers
#                    (defines who is analysed).
#   AGGREGATOR_OUT : one file per timepoint, sheet 'Pooled_By_Participant'
#                    (supplies Total_Frames, Valid_Frames, Invalid_Frames, Valid_Pct).
# Output:
#   frame_retention_per_participant.csv : one row per analysed athlete-event.
#   frame_retention_summary.csv         : per timepoint x study summary.

library(readxl)
library(dplyr)

ANALYSIS_READY <- c(
  Pre    = "../data/Pre_Analysed_Participants.xlsx",
  Mid    = "../data/Mid_Analysed_Participants.xlsx",
  Result = "../data/Result_Analysed_Participants.xlsx",
  Post   = "../data/Post_Analysed_Participants.xlsx"
)
AGGREGATOR_OUT <- c(
  Pre    = "../data/Pre_PROCESSED_v9_PY.xlsx",
  Mid    = "../data/Mid_PROCESSED_v9_PY.xlsx",
  Result = "../data/Result_PROCESSED_v9_PY.xlsx",
  Post   = "../data/Post_PROCESSED_v9_PY.xlsx"
)
OUTPUT_DIR <- "../results"

FRAME_COLS <- c("Total_Frames", "Valid_Frames", "Invalid_Frames", "Valid_Pct")

analysed_roster <- function(file, timepoint) {
  bind_rows(lapply(c(Winners = "Study1_Winners", Losers = "Study2_Losers"),
                   function(sheet) {
    d <- read_excel(file, sheet = sheet)
    data.frame(Timepoint = timepoint,
               Study = if (sheet == "Study1_Winners") "Winners" else "Losers",
               Participant_Name_Full = d$Participant_Name_Full,
               Sr_No = d$Sr_No, Vision = d$Vision, PD = d$PD,
               stringsAsFactors = FALSE)
  }))
}

frame_counts <- function(file) {
  d <- read_excel(file, sheet = "Pooled_By_Participant")
  missing <- setdiff(c("Participant_Name_Full", FRAME_COLS), names(d))
  if (length(missing) > 0)
    stop("Aggregator file missing expected columns: ", paste(missing, collapse = ", "),
         "\n  in: ", file)
  d[, c("Participant_Name_Full", FRAME_COLS)]
}

rows <- list()
for (tp in names(ANALYSIS_READY)) {
  ar <- ANALYSIS_READY[[tp]]; ag <- AGGREGATOR_OUT[[tp]]
  if (!file.exists(ar) || !file.exists(ag)) {
    message("SKIP ", tp, " (input not found)"); next
  }
  roster  <- analysed_roster(ar, tp)
  counts  <- frame_counts(ag)
  merged  <- left_join(roster, counts, by = "Participant_Name_Full")

  unmatched <- sum(is.na(merged$Valid_Frames))
  if (unmatched > 0)
    message(tp, ": ", unmatched,
            " analysed participant(s) had no frame record in the aggregator output.")
  rows[[length(rows) + 1]] <- merged
}

per_participant <- bind_rows(rows)
dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)
write.csv(per_participant,
          file.path(OUTPUT_DIR, "frame_retention_per_participant.csv"),
          row.names = FALSE)

summary_tbl <- per_participant %>%
  group_by(Timepoint, Study) %>%
  summarise(
    n_participants   = n(),
    n_with_frames    = sum(!is.na(Valid_Frames)),
    total_frames_sum = sum(Total_Frames, na.rm = TRUE),
    valid_frames_sum = sum(Valid_Frames, na.rm = TRUE),
    valid_pct_mean   = round(mean(Valid_Pct, na.rm = TRUE), 1),
    valid_pct_sd     = round(sd(Valid_Pct, na.rm = TRUE), 1),
    valid_pct_min    = round(min(Valid_Pct, na.rm = TRUE), 1),
    valid_frames_min = min(Valid_Frames, na.rm = TRUE),
    valid_frames_med = median(Valid_Frames, na.rm = TRUE),
    .groups = "drop")

write.csv(summary_tbl,
          file.path(OUTPUT_DIR, "frame_retention_summary.csv"), row.names = FALSE)

print(summary_tbl)
sessionInfo()
