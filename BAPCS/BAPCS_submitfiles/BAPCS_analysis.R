# =============================================================================
# BAPCS: Gesture Analysis by Culture (PD) and Vision
# Winners and Losers treated as two separate studies
# =============================================================================
#
# STUDY 1: Winners (Winning outcome athletes)
# STUDY 2: Losers  (Losing outcome athletes)
#
# Each study has Pre and Result moments, tested:
#   (a) Separately — cross-sectional comparison of groups at each moment
#   (b) Pre vs Result change — Wilcoxon signed-rank on paired athletes
#       (supplementary; only athletes with BOTH moments included)
#
# DESCRIPTIVE TABLE STRUCTURE (one per study):
#   Rows    = Action_cat (11 categories)
#   Columns = HiPD-Sighted | LoPD-Sighted | HiPD-Blind | LoPD-Blind
#             repeated for Pre and Result (8 columns total)
#   Cell    = n_present/n (%) | med intensity
#
# DVs per Action_cat:
#   DV1: presence      (binary, all athletes)       → Chi/Fisher
#   DV2: max_intensity (ordinal 1-3, present only)  → Mann-Whitney / KW
#   DV3: n_moments     (count, all athletes)        → Mann-Whitney / KW
#
# Action_unit tests: presence only (no descriptives)
#
# CORRECTIONS: BH-FDR within each study x moment x DV block
#
# EXPORTS:
#   BAPCS_descriptives_Winners.csv
#   BAPCS_descriptives_Losers.csv
#   BAPCS_tests_Winners.csv
#   BAPCS_tests_Losers.csv
#   BAPCS_tests_PreVsResult_Winners.csv  (supplementary paired)
#   BAPCS_tests_PreVsResult_Losers.csv   (supplementary paired)
#   12 plots: 6 per study (Winners / Losers)
#
# =============================================================================

# install.packages(c("tidyverse","readxl","knitr","dunn.test","ggplot2"))

library(tidyverse)
library(readxl)
library(knitr)
library(dunn.test)
library(ggplot2)

# =============================================================================
# 0. LOAD AND CLEAN
# =============================================================================

df_raw <- read_excel("BAPCS_clean_for_R_FINAL.xlsx")

df <- df_raw %>%
  filter(`filter_$` == 1) %>%
  mutate(
    athlete_id  = as.character(athlete_id),
    moment      = factor(moment,  levels = c("Pre", "Result")),
    outcome     = factor(outcome, levels = c("Winning", "Losing")),
    pd          = factor(pd,      levels = c("High-PD", "Low-PD")),
    vision      = factor(vision,  levels = c("Sighted", "Blind")),
    pd_vision   = factor(paste(pd, vision, sep = " x ")),
    Intensity   = as.integer(Intensity),
    Action_cat  = factor(Action_cat),
    action_unit = factor(action_unit)
  )

all_cats  <- levels(df$Action_cat)   # 11
all_units <- levels(df$action_unit)  # 33

# =============================================================================
# 1. AGGREGATE TO ATHLETE LEVEL
# =============================================================================
# Per participant_name x Action_cat: max intensity
# (collapses repeated frames and cascading intensity into one peak value)
# Then per athlete x moment x Action_cat: max across all their moments + frequency

roster <- df %>%
  distinct(athlete_id, moment, outcome, pd, vision, pd_vision)

# Action_cat
cat_present <- df %>%
  group_by(athlete_id, moment, outcome, pd, vision, pd_vision,
           participant_name, Action_cat) %>%
  summarise(max_int = max(Intensity, na.rm = TRUE), .groups = "drop") %>%
  group_by(athlete_id, moment, outcome, pd, vision, pd_vision, Action_cat) %>%
  summarise(
    max_intensity   = max(max_int),
    n_moments_shown = n(),
    .groups = "drop"
  )

cat_long <- roster %>%
  crossing(Action_cat = all_cats) %>%
  mutate(Action_cat = factor(Action_cat, levels = all_cats)) %>%
  left_join(cat_present,
            by = c("athlete_id","moment","outcome","pd","vision",
                   "pd_vision","Action_cat")) %>%
  mutate(
    present         = as.integer(!is.na(max_intensity)),
    n_moments_shown = replace_na(n_moments_shown, 0L)
  )

# Action_unit (presence only)
unit_present <- df %>%
  distinct(athlete_id, moment, outcome, pd, vision, pd_vision,
           participant_name, action_unit) %>%
  distinct(athlete_id, moment, outcome, pd, vision, pd_vision, action_unit) %>%
  mutate(present = 1L)

unit_long <- roster %>%
  crossing(action_unit = all_units) %>%
  mutate(action_unit = factor(action_unit, levels = all_units)) %>%
  left_join(unit_present,
            by = c("athlete_id","moment","outcome","pd","vision",
                   "pd_vision","action_unit")) %>%
  mutate(present = replace_na(present, 0L))

cat(sprintf("cat_long:  %d rows\n", nrow(cat_long)))
cat(sprintf("unit_long: %d rows\n\n", nrow(unit_long)))

# =============================================================================
# 2. DESCRIPTIVE TABLES
# =============================================================================
# One table per study (Winners / Losers)
# Rows = Action_cat
# Columns = 4 groups x 2 moments = 8 columns
# Cell = n_present/n (%) | med intensity

make_desc_table <- function(study_outcome) {

  # Column order: Pre then Result, within each: HiPD-Sight, LoPD-Sight,
  # HiPD-Blind, LoPD-Blind
  groups <- c("High-PD x Sighted", "Low-PD x Sighted",
              "High-PD x Blind",   "Low-PD x Blind")

  sub <- cat_long %>% filter(outcome == study_outcome)

  # Build one column per group x moment combination
  col_data <- map_dfc(c("Pre","Result"), function(mom) {
    map_dfc(groups, function(grp) {
      pd_val  <- str_split(grp, " x ")[[1]][1]
      vis_val <- str_split(grp, " x ")[[1]][2]
      col_nm  <- paste0(mom, "\n", grp)

      cell_vals <- sub %>%
        filter(moment == mom, pd == pd_val, vision == vis_val) %>%
        group_by(Action_cat) %>%
        summarise(
          n      = n(),
          npres  = sum(present),
          pct    = round(100 * npres / n, 1),
          med_int= round(median(max_intensity, na.rm = TRUE), 1),
          .groups= "drop"
        ) %>%
        mutate(cell = paste0(npres, "/", n, " (", pct, "%)  i=", med_int)) %>%
        arrange(Action_cat) %>%
        pull(cell)

      setNames(tibble(cell_vals), col_nm)
    })
  })

  bind_cols(
    tibble(Action_cat = all_cats),
    col_data
  )
}

cat("=================================================================\n")
cat("  STUDY 1: WINNERS — Descriptive Table\n")
cat("  Cell: n_present/n_athletes (%) | i = median max intensity\n")
cat("=================================================================\n\n")
desc_win <- make_desc_table("Winning")
print(kable(desc_win, format = "simple"), quote = FALSE)

cat("\n\n=================================================================\n")
cat("  STUDY 2: LOSERS — Descriptive Table\n")
cat("  Cell: n_present/n_athletes (%) | i = median max intensity\n")
cat("=================================================================\n\n")
desc_los <- make_desc_table("Losing")
print(kable(desc_los, format = "simple"), quote = FALSE)

# =============================================================================
# 3. STATISTICAL TESTS — Cross-sectional (per moment within each study)
# =============================================================================

safe_test <- function(tbl) {
  if (any(tbl < 5)) fisher.test(tbl, simulate.p.value = TRUE, B = 5000)
  else chisq.test(tbl, correct = FALSE)
}

run_dunn <- function(data, dv, label_col, study_out, mom, results, sig_col) {
  sig_labels <- results %>% filter(!!sym(sig_col) == "*") %>% pull(label)
  if (length(sig_labels) == 0) {
    cat("    None significant after FDR correction.\n\n")
    return(invisible(NULL))
  }
  sub <- data %>%
    filter(outcome == study_out, moment == mom, !is.na(!!sym(dv)))
  for (lbl in sig_labels) {
    d <- sub %>% filter(!!sym(label_col) == lbl)
    cat(sprintf("    %s:\n", lbl))
    dunn.test(d[[dv]], d$pd_vision,
              method = "bonferroni", alpha = 0.05, kw = FALSE, label = TRUE)
    cat("\n")
  }
}

run_cross_sectional <- function(study_outcome, mom) {

  sc <- cat_long  %>% filter(outcome == study_outcome, moment == mom)
  su <- unit_long %>% filter(outcome == study_outcome, moment == mom)

  # Action_cat
  res_cat <- map_dfr(all_cats, function(lbl) {

    d      <- sc %>% filter(Action_cat == lbl)
    d_pres <- d  %>% filter(present == 1)
    n_pres <- nrow(d_pres)

    pct <- d %>% group_by(pd, vision) %>%
      summarise(v = round(100 * mean(present), 1), .groups = "drop") %>%
      mutate(g = paste(pd, vision, sep = "x")) %>%
      select(g, v) %>% deframe()

    med_int <- d_pres %>% group_by(pd, vision) %>%
      summarise(v = round(median(max_intensity, na.rm = TRUE), 1),
                .groups = "drop") %>%
      mutate(g = paste(pd, vision, sep = "x")) %>%
      select(g, v) %>% deframe()

    # DV1 presence
    t1_pd  <- safe_test(table(d$pd,        d$present))
    t1_vis <- safe_test(table(d$vision,    d$present))
    t1_4   <- safe_test(table(d$pd_vision, d$present))

    # DV2 max intensity (present only)
    t2_pd  <- if (n_pres >= 4 && n_distinct(d_pres$pd)       == 2)
      wilcox.test(max_intensity ~ pd,        data = d_pres, exact = FALSE)
    else list(statistic = NA_real_, p.value = NA_real_)
    t2_vis <- if (n_pres >= 4 && n_distinct(d_pres$vision)   == 2)
      wilcox.test(max_intensity ~ vision,    data = d_pres, exact = FALSE)
    else list(statistic = NA_real_, p.value = NA_real_)
    t2_4   <- if (n_pres >= 4 && n_distinct(d_pres$pd_vision) > 1)
      kruskal.test(max_intensity ~ pd_vision, data = d_pres)
    else list(statistic = NA_real_, parameter = NA_real_, p.value = NA_real_)

    # DV3 frequency
    t3_pd  <- wilcox.test(n_moments_shown ~ pd,        data = d, exact = FALSE)
    t3_vis <- wilcox.test(n_moments_shown ~ vision,    data = d, exact = FALSE)
    t3_4   <- kruskal.test(n_moments_shown ~ pd_vision, data = d)

    tibble(
      level = "Action_cat", label = lbl,
      n_athletes = nrow(d), n_present = n_pres,
      pct_HiPD_Sight = pct["High-PDxSighted"],
      pct_HiPD_Blind = pct["High-PDxBlind"],
      pct_LoPD_Sight = pct["Low-PDxSighted"],
      pct_LoPD_Blind = pct["Low-PDxBlind"],
      stat_pres_pd    = round(ifelse("statistic" %in% names(t1_pd),
                                     t1_pd$statistic, NA), 3),
      p_pres_pd       = round(t1_pd$p.value,  4),
      stat_pres_vis   = round(ifelse("statistic" %in% names(t1_vis),
                                     t1_vis$statistic, NA), 3),
      p_pres_vis      = round(t1_vis$p.value, 4),
      stat_pres_4grp  = round(ifelse("statistic" %in% names(t1_4),
                                     t1_4$statistic, NA), 3),
      p_pres_4grp     = round(t1_4$p.value,  4),
      med_int_HiPD_Sight = med_int["High-PDxSighted"],
      med_int_HiPD_Blind = med_int["High-PDxBlind"],
      med_int_LoPD_Sight = med_int["Low-PDxSighted"],
      med_int_LoPD_Blind = med_int["Low-PDxBlind"],
      W_int_pd    = round(t2_pd$statistic,  1),
      p_int_pd    = round(t2_pd$p.value,    4),
      W_int_vis   = round(t2_vis$statistic, 1),
      p_int_vis   = round(t2_vis$p.value,   4),
      H_int_4grp  = round(t2_4$statistic,   3),
      p_int_4grp  = round(t2_4$p.value,     4),
      W_mom_pd    = round(t3_pd$statistic,  1),
      p_mom_pd    = round(t3_pd$p.value,    4),
      W_mom_vis   = round(t3_vis$statistic, 1),
      p_mom_vis   = round(t3_vis$p.value,   4),
      H_mom_4grp  = round(t3_4$statistic,   3),
      p_mom_4grp  = round(t3_4$p.value,     4)
    )
  }) %>%
    mutate(
      p_pres_pd_fdr   = round(p.adjust(p_pres_pd,   method = "BH"), 4),
      p_pres_vis_fdr  = round(p.adjust(p_pres_vis,  method = "BH"), 4),
      p_pres_4grp_fdr = round(p.adjust(p_pres_4grp, method = "BH"), 4),
      p_int_pd_fdr    = round(p.adjust(p_int_pd,    method = "BH"), 4),
      p_int_vis_fdr   = round(p.adjust(p_int_vis,   method = "BH"), 4),
      p_int_4grp_fdr  = round(p.adjust(p_int_4grp,  method = "BH"), 4),
      p_mom_pd_fdr    = round(p.adjust(p_mom_pd,    method = "BH"), 4),
      p_mom_vis_fdr   = round(p.adjust(p_mom_vis,   method = "BH"), 4),
      p_mom_4grp_fdr  = round(p.adjust(p_mom_4grp,  method = "BH"), 4),
      sig_pres_pd     = ifelse(p_pres_pd_fdr   < .05, "*", ""),
      sig_pres_vis    = ifelse(p_pres_vis_fdr  < .05, "*", ""),
      sig_pres_4grp   = ifelse(p_pres_4grp_fdr < .05, "*", ""),
      sig_int_pd      = ifelse(p_int_pd_fdr    < .05, "*", ""),
      sig_int_vis     = ifelse(p_int_vis_fdr   < .05, "*", ""),
      sig_int_4grp    = ifelse(p_int_4grp_fdr  < .05, "*", ""),
      sig_mom_pd      = ifelse(p_mom_pd_fdr    < .05, "*", ""),
      sig_mom_vis     = ifelse(p_mom_vis_fdr   < .05, "*", ""),
      sig_mom_4grp    = ifelse(p_mom_4grp_fdr  < .05, "*", "")
    )

  # Action_unit
  res_unit <- map_dfr(all_units, function(lbl) {
    d    <- su %>% filter(action_unit == lbl)
    n_pr <- sum(d$present)
    pct  <- d %>% group_by(pd, vision) %>%
      summarise(v = round(100 * mean(present), 1), .groups = "drop") %>%
      mutate(g = paste(pd, vision, sep = "x")) %>%
      select(g, v) %>% deframe()
    t_pd  <- safe_test(table(d$pd,        d$present))
    t_vis <- safe_test(table(d$vision,    d$present))
    t_4   <- safe_test(table(d$pd_vision, d$present))
    tibble(
      level = "action_unit", label = lbl,
      n_athletes = nrow(d), n_present = n_pr,
      pct_HiPD_Sight = pct["High-PDxSighted"],
      pct_HiPD_Blind = pct["High-PDxBlind"],
      pct_LoPD_Sight = pct["Low-PDxSighted"],
      pct_LoPD_Blind = pct["Low-PDxBlind"],
      stat_pres_pd   = round(ifelse("statistic" %in% names(t_pd),
                                    t_pd$statistic, NA), 3),
      p_pres_pd      = round(t_pd$p.value,  4),
      stat_pres_vis  = round(ifelse("statistic" %in% names(t_vis),
                                    t_vis$statistic, NA), 3),
      p_pres_vis     = round(t_vis$p.value, 4),
      stat_pres_4grp = round(ifelse("statistic" %in% names(t_4),
                                    t_4$statistic, NA), 3),
      p_pres_4grp    = round(t_4$p.value,  4)
    )
  }) %>%
    mutate(
      p_pres_pd_fdr   = round(p.adjust(p_pres_pd,   method = "BH"), 4),
      p_pres_vis_fdr  = round(p.adjust(p_pres_vis,  method = "BH"), 4),
      p_pres_4grp_fdr = round(p.adjust(p_pres_4grp, method = "BH"), 4),
      sig_pres_pd     = ifelse(p_pres_pd_fdr   < .05, "*", ""),
      sig_pres_vis    = ifelse(p_pres_vis_fdr  < .05, "*", ""),
      sig_pres_4grp   = ifelse(p_pres_4grp_fdr < .05, "*", "")
    )

  list(cat = res_cat, unit = res_unit)
}

# =============================================================================
# 4. PAIRED PRE vs RESULT TESTS (supplementary)
# =============================================================================
# Only athletes with BOTH Pre and Result coded are included.
# Wilcoxon signed-rank on paired presence and max_intensity values.

run_paired <- function(study_outcome) {

  # Athletes with both moments
  both <- cat_long %>%
    filter(outcome == study_outcome) %>%
    group_by(athlete_id) %>%
    filter(n_distinct(moment) == 2) %>%
    ungroup()

  n_paired <- n_distinct(both$athlete_id)
  cat(sprintf("  Paired athletes (%s): %d\n", study_outcome, n_paired))

  map_dfr(all_cats, function(lbl) {

    d <- both %>%
      filter(Action_cat == lbl) %>%
      select(athlete_id, pd, vision, pd_vision, moment, present, max_intensity) %>%
      pivot_wider(names_from = moment,
                  values_from = c(present, max_intensity),
                  names_sep   = "_")

    # Signed-rank: Pre vs Result presence
    t_pres <- wilcox.test(d$present_Pre, d$present_Result,
                          paired = TRUE, exact = FALSE)

    # Signed-rank: Pre vs Result max_intensity (present at either moment)
    d_int <- d %>% filter(!is.na(max_intensity_Pre) | !is.na(max_intensity_Result)) %>%
      mutate(
        max_intensity_Pre    = replace_na(max_intensity_Pre,    0),
        max_intensity_Result = replace_na(max_intensity_Result, 0)
      )
    t_int <- if (nrow(d_int) >= 4)
      wilcox.test(d_int$max_intensity_Pre, d_int$max_intensity_Result,
                  paired = TRUE, exact = FALSE)
    else list(statistic = NA_real_, p.value = NA_real_)

    tibble(
      label           = lbl,
      n_paired        = n_paired,
      pct_Pre         = round(100 * mean(d$present_Pre),    1),
      pct_Result      = round(100 * mean(d$present_Result), 1),
      med_int_Pre     = round(median(d$max_intensity_Pre,    na.rm = TRUE), 1),
      med_int_Result  = round(median(d$max_intensity_Result, na.rm = TRUE), 1),
      V_pres          = round(t_pres$statistic, 1),
      p_pres          = round(t_pres$p.value,   4),
      V_int           = round(t_int$statistic,  1),
      p_int           = round(t_int$p.value,    4)
    )
  }) %>%
    mutate(
      p_pres_fdr = round(p.adjust(p_pres, method = "BH"), 4),
      p_int_fdr  = round(p.adjust(p_int,  method = "BH"), 4),
      sig_pres   = ifelse(p_pres_fdr < .05, "*", ""),
      sig_int    = ifelse(p_int_fdr  < .05, "*", "")
    )
}

# =============================================================================
# 5. RUN ALL TESTS AND PRINT
# =============================================================================

all_cross  <- list()
all_paired <- list()

for (study in c("Winning", "Losing")) {

  study_label <- if (study == "Winning") "STUDY 1: WINNERS" else "STUDY 2: LOSERS"

  cat(strrep("=", 68), "\n")
  cat(sprintf("  %s\n", study_label))
  cat(strrep("=", 68), "\n\n")

  for (mom in c("Pre", "Result")) {

    key <- paste(study, mom, sep = "_")
    res <- run_cross_sectional(study, mom)
    all_cross[[key]] <- bind_rows(res$cat, res$unit)

    cat(strrep("-", 68), "\n")
    cat(sprintf("  %s — %s moment\n", study_label, mom))
    cat(strrep("-", 68), "\n\n")

    # DV1: Presence — Action_cat
    cat("  DV1 PRESENCE — Action categories  (* = BH p < .05)\n\n")
    print(kable(res$cat %>% select(
      label, n_athletes, n_present,
      pct_HiPD_Sight, pct_HiPD_Blind, pct_LoPD_Sight, pct_LoPD_Blind,
      stat_pres_pd, p_pres_pd_fdr, sig_pres_pd,
      stat_pres_vis, p_pres_vis_fdr, sig_pres_vis,
      stat_pres_4grp, p_pres_4grp_fdr, sig_pres_4grp),
      format = "simple", digits = 3), quote = FALSE)
    cat("\n  Dunn post-hoc — 4-group presence:\n")
    run_dunn(cat_long, "present", "Action_cat", study, mom,
             res$cat, "sig_pres_4grp")

    # DV1: Presence — action_unit
    cat("  DV1 PRESENCE — Action units  (* = BH p < .05)\n\n")
    print(kable(res$unit %>% select(
      label, n_present,
      pct_HiPD_Sight, pct_HiPD_Blind, pct_LoPD_Sight, pct_LoPD_Blind,
      stat_pres_pd, p_pres_pd_fdr, sig_pres_pd,
      stat_pres_vis, p_pres_vis_fdr, sig_pres_vis,
      stat_pres_4grp, p_pres_4grp_fdr, sig_pres_4grp),
      format = "simple", digits = 3), quote = FALSE)
    cat("\n  Dunn post-hoc — 4-group unit presence:\n")
    run_dunn(unit_long, "present", "action_unit", study, mom,
             res$unit, "sig_pres_4grp")

    # DV2: Intensity
    cat("  DV2 MAX INTENSITY — present athletes only  (* = BH p < .05)\n\n")
    print(kable(res$cat %>% select(
      label, n_present,
      med_int_HiPD_Sight, med_int_HiPD_Blind,
      med_int_LoPD_Sight, med_int_LoPD_Blind,
      W_int_pd, p_int_pd_fdr, sig_int_pd,
      W_int_vis, p_int_vis_fdr, sig_int_vis,
      H_int_4grp, p_int_4grp_fdr, sig_int_4grp),
      format = "simple", digits = 3), quote = FALSE)
    cat("\n  Dunn post-hoc — 4-group intensity:\n")
    run_dunn(cat_long, "max_intensity", "Action_cat", study, mom,
             res$cat, "sig_int_4grp")

    # DV3: Frequency
    cat("  DV3 FREQUENCY — n video moments  (* = BH p < .05)\n\n")
    print(kable(res$cat %>% select(
      label, W_mom_pd, p_mom_pd_fdr, sig_mom_pd,
      W_mom_vis, p_mom_vis_fdr, sig_mom_vis,
      H_mom_4grp, p_mom_4grp_fdr, sig_mom_4grp),
      format = "simple", digits = 3), quote = FALSE)
    cat("\n  Dunn post-hoc — 4-group frequency:\n")
    run_dunn(cat_long, "n_moments_shown", "Action_cat", study, mom,
             res$cat, "sig_mom_4grp")
    cat("\n")
  }

  # Paired Pre vs Result
  cat(strrep("-", 68), "\n")
  cat(sprintf("  %s — SUPPLEMENTARY: Pre vs Result (paired, signed-rank)\n",
              study_label))
  cat(strrep("-", 68), "\n\n")

  paired_res <- run_paired(study)
  all_paired[[study]] <- paired_res

  print(kable(paired_res %>% select(
    label, n_paired,
    pct_Pre, pct_Result,
    med_int_Pre, med_int_Result,
    V_pres, p_pres_fdr, sig_pres,
    V_int,  p_int_fdr,  sig_int),
    format = "simple", digits = 3), quote = FALSE)
  cat("\n  * = BH-corrected p < .05\n",
      "  V_pres: signed-rank on presence (Pre vs Result)\n",
      "  V_int:  signed-rank on max intensity (Pre vs Result)\n\n")
}

# =============================================================================
# 6. PLOTS — separate files per study
# =============================================================================

theme_bapcs <- function() {
  theme_minimal(base_size = 11) +
    theme(
      plot.title       = element_text(face = "bold", size = 13),
      plot.subtitle    = element_text(size = 10, colour = "grey40"),
      strip.text       = element_text(face = "bold", size = 10),
      axis.text.x      = element_text(angle = 35, hjust = 1, size = 9),
      legend.position  = "bottom",
      legend.title     = element_text(face = "bold"),
      panel.grid.minor = element_blank()
    )
}

grp_cols <- c(
  "High-PD x Sighted" = "#2166ac",
  "Low-PD x Sighted"  = "#74add1",
  "High-PD x Blind"   = "#d73027",
  "Low-PD x Blind"    = "#f4a582"
)

make_plots <- function(study_outcome, study_label, file_prefix) {

  sub_cat <- cat_long %>% filter(outcome == study_outcome)

  plot_data <- sub_cat %>%
    group_by(moment, pd, vision, Action_cat) %>%
    summarise(
      n        = n(),
      pct      = round(100 * sum(present) / n, 1),
      med_int  = round(median(max_intensity, na.rm = TRUE), 1),
      .groups  = "drop"
    ) %>%
    mutate(
      group      = factor(paste(pd, vision, sep = " x "), levels = names(grp_cols)),
      Action_cat = factor(Action_cat, levels = all_cats)
    )

  # P1: Grouped bar — prevalence, faceted by moment
  p1 <- ggplot(plot_data, aes(x = Action_cat, y = pct, fill = group)) +
    geom_col(position = position_dodge(0.75), width = 0.7,
             colour = "white", linewidth = 0.3) +
    facet_wrap(~ moment, ncol = 2) +
    scale_fill_manual(values = grp_cols, name = "PD x Vision") +
    scale_y_continuous(limits = c(0, 100),
                       labels = function(x) paste0(x, "%")) +
    labs(title    = paste(study_label, "— Gesture Prevalence"),
         subtitle = "% athletes showing each gesture at least once",
         x = NULL, y = "% Athletes") +
    theme_bapcs()
  ggsave(paste0(file_prefix, "_plot1_prevalence.pdf"), p1, width = 13, height = 6)
  ggsave(paste0(file_prefix, "_plot1_prevalence.png"), p1, width = 13, height = 6,
         dpi = 150)

  # P2: PD dot-line
  pd_data <- sub_cat %>%
    group_by(moment, pd, Action_cat) %>%
    summarise(pct = round(100 * sum(present) / n(), 1), .groups = "drop") %>%
    mutate(Action_cat = factor(Action_cat, levels = rev(all_cats)))

  p2 <- ggplot(pd_data, aes(x = pct, y = Action_cat, colour = pd,
                             group = Action_cat)) +
    geom_line(colour = "grey75", linewidth = 0.9) +
    geom_point(size = 3.5) +
    facet_wrap(~ moment, ncol = 2) +
    scale_colour_manual(
      values = c("High-PD" = "#2166ac", "Low-PD" = "#d73027"),
      name   = "PD Group") +
    scale_x_continuous(limits = c(0, 100),
                       labels = function(x) paste0(x, "%")) +
    labs(title    = paste(study_label, "— PD Group Differences"),
         subtitle = "Line connects High-PD to Low-PD for the same gesture",
         x = "% Athletes", y = NULL) +
    theme_bapcs() +
    theme(axis.text.x = element_text(angle = 0, hjust = 0.5))
  ggsave(paste0(file_prefix, "_plot2_pd.pdf"), p2, width = 11, height = 7)
  ggsave(paste0(file_prefix, "_plot2_pd.png"), p2, width = 11, height = 7, dpi = 150)

  # P3: Vision dot-line
  vis_data <- sub_cat %>%
    group_by(moment, vision, Action_cat) %>%
    summarise(pct = round(100 * sum(present) / n(), 1), .groups = "drop") %>%
    mutate(Action_cat = factor(Action_cat, levels = rev(all_cats)))

  p3 <- ggplot(vis_data, aes(x = pct, y = Action_cat, colour = vision,
                              group = Action_cat)) +
    geom_line(colour = "grey75", linewidth = 0.9) +
    geom_point(size = 3.5) +
    facet_wrap(~ moment, ncol = 2) +
    scale_colour_manual(
      values = c("Sighted" = "#1a9641", "Blind" = "#d7191c"),
      name   = "Vision") +
    scale_x_continuous(limits = c(0, 100),
                       labels = function(x) paste0(x, "%")) +
    labs(title    = paste(study_label, "— Vision Group Differences"),
         subtitle = "Line connects Sighted to Blind for the same gesture",
         x = "% Athletes", y = NULL) +
    theme_bapcs() +
    theme(axis.text.x = element_text(angle = 0, hjust = 0.5))
  ggsave(paste0(file_prefix, "_plot3_vision.pdf"), p3, width = 11, height = 7)
  ggsave(paste0(file_prefix, "_plot3_vision.png"), p3, width = 11, height = 7,
         dpi = 150)

  # P4: Heatmap
  p4 <- ggplot(plot_data, aes(x = group, y = Action_cat, fill = pct)) +
    geom_tile(colour = "white", linewidth = 0.6) +
    geom_text(aes(label = paste0(pct, "%")),
              size = 3, colour = "white", fontface = "bold") +
    facet_wrap(~ moment, ncol = 2) +
    scale_fill_gradient(low = "#deebf7", high = "#08519c",
                        limits = c(0, 100), name = "% Present") +
    scale_x_discrete(labels = function(x) str_wrap(x, 10)) +
    labs(title = paste(study_label, "— Prevalence Heatmap"),
         x = NULL, y = NULL) +
    theme_bapcs() + theme(panel.grid = element_blank())
  ggsave(paste0(file_prefix, "_plot4_heatmap.pdf"), p4, width = 12, height = 7)
  ggsave(paste0(file_prefix, "_plot4_heatmap.png"), p4, width = 12, height = 7,
         dpi = 150)

  # P5: Intensity boxplot (present athletes only)
  int_data <- sub_cat %>%
    filter(present == 1) %>%
    mutate(
      group      = factor(paste(pd, vision, sep = " x "), levels = names(grp_cols)),
      Action_cat = factor(Action_cat, levels = all_cats)
    )

  p5 <- ggplot(int_data, aes(x = group, y = max_intensity, fill = group)) +
    geom_boxplot(width = 0.6, outlier.size = 0.8, outlier.alpha = 0.5,
                 linewidth = 0.4) +
    facet_grid(Action_cat ~ moment) +
    scale_fill_manual(values = grp_cols) +
    scale_y_continuous(breaks = 1:3,
                       labels = c("1\nLow", "2\nMed", "3\nHigh")) +
    labs(title    = paste(study_label, "— Peak Intensity"),
         subtitle = "Among athletes who showed the gesture",
         x = NULL, y = "Max Intensity") +
    theme_bapcs() +
    theme(axis.text.x  = element_text(angle = 40, hjust = 1, size = 7),
          strip.text.y = element_text(size = 7, angle = 0),
          legend.position = "none")
  ggsave(paste0(file_prefix, "_plot5_intensity.pdf"), p5, width = 10, height = 18)
  ggsave(paste0(file_prefix, "_plot5_intensity.png"), p5, width = 10, height = 18,
         dpi = 120)

  # P6: Pre to Result change arrow
  change_data <- sub_cat %>%
    group_by(moment, Action_cat) %>%
    summarise(pct = round(100 * sum(present) / n(), 1), .groups = "drop") %>%
    pivot_wider(names_from = moment, values_from = pct) %>%
    mutate(
      direction  = ifelse(Result >= Pre, "Increases", "Decreases"),
      Action_cat = factor(Action_cat, levels = rev(all_cats))
    )

  p6 <- ggplot(change_data,
               aes(x = Pre, xend = Result, y = Action_cat, colour = direction)) +
    geom_segment(linewidth = 1.4,
                 arrow = arrow(length = unit(0.2, "cm"), type = "closed")) +
    geom_point(aes(x = Pre),    size = 3, shape = 19) +
    geom_point(aes(x = Result), size = 3, shape = 17) +
    scale_colour_manual(
      values = c("Increases" = "#1a9641", "Decreases" = "#d7191c"),
      name   = NULL) +
    scale_x_continuous(limits = c(0, 100),
                       labels = function(x) paste0(x, "%")) +
    labs(title    = paste(study_label, "— Pre \u2192 Result Change"),
         subtitle = "Circle = Pre, Triangle = Result. Collapsed across PD and Vision.",
         x = "% Athletes", y = NULL) +
    theme_bapcs() +
    theme(axis.text.x = element_text(angle = 0, hjust = 0.5))
  ggsave(paste0(file_prefix, "_plot6_change.pdf"), p6, width = 8, height = 6)
  ggsave(paste0(file_prefix, "_plot6_change.png"), p6, width = 8, height = 6,
         dpi = 150)

  cat(sprintf("  6 plots saved for %s\n", study_label))
}

make_plots("Winning", "Study 1: Winners", "Winners")
make_plots("Losing",  "Study 2: Losers",  "Losers")

# =============================================================================
# 7. EXPORT
# =============================================================================

# Descriptives
write_csv(desc_win, "BAPCS_descriptives_Winners.csv")
write_csv(desc_los, "BAPCS_descriptives_Losers.csv")

# Cross-sectional tests
cross_win <- imap_dfr(
  all_cross[str_detect(names(all_cross), "Winning")],
  function(r, key) r %>% mutate(moment = str_remove(key, "Winning_"))
)
cross_los <- imap_dfr(
  all_cross[str_detect(names(all_cross), "Losing")],
  function(r, key) r %>% mutate(moment = str_remove(key, "Losing_"))
)
write_csv(cross_win, "BAPCS_tests_Winners.csv")
write_csv(cross_los, "BAPCS_tests_Losers.csv")

# Paired tests
write_csv(all_paired[["Winning"]], "BAPCS_tests_PreVsResult_Winners.csv")
write_csv(all_paired[["Losing"]],  "BAPCS_tests_PreVsResult_Losers.csv")

cat("\n=================================================================\n")
cat("  EXPORTS:\n")
cat("    BAPCS_descriptives_Winners.csv\n")
cat("    BAPCS_descriptives_Losers.csv\n")
cat("    BAPCS_tests_Winners.csv\n")
cat("    BAPCS_tests_Losers.csv\n")
cat("    BAPCS_tests_PreVsResult_Winners.csv  (supplementary)\n")
cat("    BAPCS_tests_PreVsResult_Losers.csv   (supplementary)\n")
cat("  PLOTS (PDF + PNG, 6 per study = 12 total):\n")
cat("    Winners_plot1_prevalence  | Losers_plot1_prevalence\n")
cat("    Winners_plot2_pd          | Losers_plot2_pd\n")
cat("    Winners_plot3_vision      | Losers_plot3_vision\n")
cat("    Winners_plot4_heatmap     | Losers_plot4_heatmap\n")
cat("    Winners_plot5_intensity   | Losers_plot5_intensity\n")
cat("    Winners_plot6_change      | Losers_plot6_change\n")
cat("=================================================================\n")
cat("DONE\n")

# =============================================================================
# 8. PRIDE / SHAME COMPOSITE ANALYSIS
#    Based on Tracy & Matsumoto (2008) categorisation
# =============================================================================
#
# PRIDE gestures (7 Action_cat):
#   Head tilt back, Arms raised, Arms out, Fists,
#   Arms on Waist Hips, Chest expanded, Torso out
#
# SHAME gestures (3 Action_cat):
#   Head tilt down, Chest narrowed, Shoulder slumped
#
# Unique Gesture is excluded — not in Tracy & Matsumoto coding scheme
#
# COMPOSITE DVs per athlete x moment:
#   composite_present : did athlete show ≥1 gesture of this emotion? (binary)
#   n_categories      : how many distinct gesture categories of this emotion shown?
#
# TESTS:
#   (A) Cross-sectional — Fisher's exact test (presence composite) and
#       Mann-Whitney U (n_categories count) comparing High-PD vs Low-PD
#       and Sighted vs Blind, at Pre and Result separately.
#       Corrected: Bonferroni across the 4 tests per emotion per study
#       (2 DVs x 2 comparisons = 4 tests), matching student approach.
#
#   (B) Paired Pre→Result — McNemar test within each pd group and vision group
#       (athletes with both moments only).
#       Corrected: Bonferroni across the 2 emotion categories per group.
#
# =============================================================================

pride_cats <- c("Head tilt back", "Arms raised", "Arms out", "Fists",
                "Arms on Waist Hips", "Chest expanded", "Torso out")
shame_cats <- c("Head tilt down", "Chest narrowed", "Shoulder slumped")

cat("\n=================================================================\n")
cat("  SECTION 4: PRIDE / SHAME COMPOSITE ANALYSIS\n")
cat("  Tracy & Matsumoto (2008) categorisation\n")
cat("=================================================================\n\n")

# Build composite dataset
composite <- cat_long %>%
  mutate(
    emotion_group = case_when(
      Action_cat %in% pride_cats ~ "Pride",
      Action_cat %in% shame_cats ~ "Shame",
      TRUE ~ "Unclassified"
    )
  ) %>%
  filter(emotion_group != "Unclassified") %>%
  group_by(athlete_id, moment, outcome, pd, vision, pd_vision, emotion_group) %>%
  summarise(
    composite_present  = as.integer(any(present == 1)),
    n_categories_shown = sum(present),
    .groups = "drop"
  )

# ---- (A) Cross-sectional composite tests ------------------------------------

run_composite_cross <- function(study_outcome, mom, emotion) {

  d <- composite %>%
    filter(outcome == study_outcome, moment == mom, emotion_group == emotion)

  n_ath <- nrow(d) / 2  # approximate (all athletes)

  # Prevalence per group
  pct <- d %>% group_by(pd, vision) %>%
    summarise(v = round(100 * mean(composite_present), 1), .groups = "drop") %>%
    mutate(g = paste(pd, vision, sep = "x")) %>% select(g, v) %>% deframe()

  med_n <- d %>% group_by(pd, vision) %>%
    summarise(v = round(median(n_categories_shown), 2), .groups = "drop") %>%
    mutate(g = paste(pd, vision, sep = "x")) %>% select(g, v) %>% deframe()

  # Fisher exact: presence composite ~ pd (collapsed across vision)
  tbl_pd  <- table(d$pd,     d$composite_present)
  tbl_vis <- table(d$vision, d$composite_present)
  f_pd    <- fisher.test(tbl_pd,  simulate.p.value = TRUE, B = 10000)
  f_vis   <- fisher.test(tbl_vis, simulate.p.value = TRUE, B = 10000)

  # Mann-Whitney: n_categories ~ pd
  mw_pd  <- wilcox.test(n_categories_shown ~ pd,     data = d, exact = FALSE)
  mw_vis <- wilcox.test(n_categories_shown ~ vision, data = d, exact = FALSE)

  # Bonferroni correction across 4 tests (2 DVs x 2 comparisons)
  raw_ps <- c(f_pd$p.value, f_vis$p.value, mw_pd$p.value, mw_vis$p.value)
  adj_ps <- p.adjust(raw_ps, method = "bonferroni")

  tibble(
    emotion        = emotion,
    pct_HiPD_Sight = pct["High-PDxSighted"],
    pct_HiPD_Blind = pct["High-PDxBlind"],
    pct_LoPD_Sight = pct["Low-PDxSighted"],
    pct_LoPD_Blind = pct["Low-PDxBlind"],
    med_n_HiPD_Sight = med_n["High-PDxSighted"],
    med_n_HiPD_Blind = med_n["High-PDxBlind"],
    med_n_LoPD_Sight = med_n["Low-PDxSighted"],
    med_n_LoPD_Blind = med_n["Low-PDxBlind"],
    # presence
    p_pres_pd    = round(f_pd$p.value,  4),
    p_pres_pd_adj= round(adj_ps[1],     4),
    p_pres_vis   = round(f_vis$p.value, 4),
    p_pres_vis_adj=round(adj_ps[2],     4),
    sig_pres_pd  = ifelse(adj_ps[1] < .05, "*", ""),
    sig_pres_vis = ifelse(adj_ps[2] < .05, "*", ""),
    # count
    W_count_pd    = round(mw_pd$statistic,  1),
    p_count_pd    = round(mw_pd$p.value,    4),
    p_count_pd_adj= round(adj_ps[3],        4),
    W_count_vis   = round(mw_vis$statistic, 1),
    p_count_vis   = round(mw_vis$p.value,   4),
    p_count_vis_adj=round(adj_ps[4],        4),
    sig_count_pd  = ifelse(adj_ps[3] < .05, "*", ""),
    sig_count_vis = ifelse(adj_ps[4] < .05, "*", "")
  )
}

# ---- (B) Paired McNemar tests -----------------------------------------------

run_composite_mcnemar <- function(study_outcome, emotion) {

  # Athletes with both moments
  both <- composite %>%
    filter(outcome == study_outcome, emotion_group == emotion) %>%
    group_by(athlete_id) %>%
    filter(n_distinct(moment) == 2) %>%
    ungroup()

  n_paired <- n_distinct(both$athlete_id)

  # Run McNemar within each pd group and each vision group
  results <- list()

  for (grp_var in c("pd", "vision")) {
    grp_levels <- if (grp_var == "pd")
      c("High-PD", "Low-PD") else c("Sighted", "Blind")

    for (lvl in grp_levels) {
      d_wide <- both %>%
        filter(!!sym(grp_var) == lvl) %>%
        select(athlete_id, moment, composite_present) %>%
        pivot_wider(names_from = moment,
                    values_from = composite_present,
                    names_prefix = "m_")

      if (nrow(d_wide) < 4) next

      # McNemar 2x2: Pre present x Result present
      mc_tbl <- table(
        Pre    = factor(d_wide$m_Pre,    levels = 0:1),
        Result = factor(d_wide$m_Result, levels = 0:1)
      )
      mc <- mcnemar.test(mc_tbl, correct = FALSE)

      results[[paste(grp_var, lvl)]] <- tibble(
        group_var  = grp_var,
        group_level= lvl,
        n_paired   = nrow(d_wide),
        pct_pre    = round(100 * mean(d_wide$m_Pre,    na.rm = TRUE), 1),
        pct_result = round(100 * mean(d_wide$m_Result, na.rm = TRUE), 1),
        chi2       = round(mc$statistic, 3),
        p_raw      = round(mc$p.value,  4)
      )
    }
  }

  res <- bind_rows(results)

  # Bonferroni correction across 2 emotions (applied externally per caller)
  res
}

# ---- Run and print all composite results ------------------------------------

all_composite_cross  <- list()
all_composite_mcnem  <- list()

for (study in c("Winning", "Losing")) {
  slabel <- if (study == "Winning") "STUDY 1: WINNERS" else "STUDY 2: LOSERS"

  cat(strrep("=", 65), "\n")
  cat(sprintf("  COMPOSITE — %s\n", slabel))
  cat(strrep("=", 65), "\n\n")

  for (mom in c("Pre", "Result")) {
    key <- paste(study, mom, sep = "_")
    res <- bind_rows(
      run_composite_cross(study, mom, "Pride"),
      run_composite_cross(study, mom, "Shame")
    )
    all_composite_cross[[key]] <- res

    cat(strrep("-", 65), "\n")
    cat(sprintf("  %s — %s moment\n", slabel, mom))
    cat(strrep("-", 65), "\n\n")

    cat("  (A) Presence composite & category count by PD and Vision\n")
    cat("  * = Bonferroni-corrected p < .05 (4 tests per emotion)\n\n")

    print(kable(res %>% select(
      emotion,
      pct_HiPD_Sight, pct_HiPD_Blind, pct_LoPD_Sight, pct_LoPD_Blind,
      p_pres_pd, p_pres_pd_adj, sig_pres_pd,
      p_pres_vis, p_pres_vis_adj, sig_pres_vis,
      W_count_pd, p_count_pd_adj, sig_count_pd,
      W_count_vis, p_count_vis_adj, sig_count_vis),
      format = "simple", digits = 3), quote = FALSE)
    cat("\n")
  }

  # McNemar paired
  cat(strrep("-", 65), "\n")
  cat(sprintf("  %s — PAIRED McNemar (Pre vs Result within group)\n", slabel))
  cat(strrep("-", 65), "\n\n")

  mc_pride <- run_composite_mcnemar(study, "Pride") %>% mutate(emotion = "Pride")
  mc_shame <- run_composite_mcnemar(study, "Shame") %>% mutate(emotion = "Shame")
  mc_all   <- bind_rows(mc_pride, mc_shame)

  # Bonferroni across 2 emotions per group level
  mc_all <- mc_all %>%
    group_by(group_var, group_level) %>%
    mutate(p_adj = round(p.adjust(p_raw, method = "bonferroni"), 4),
           sig   = ifelse(p_adj < .05, "*", "")) %>%
    ungroup()

  all_composite_mcnem[[study]] <- mc_all

  print(kable(mc_all %>% select(
    emotion, group_var, group_level, n_paired,
    pct_pre, pct_result, chi2, p_raw, p_adj, sig),
    format = "simple", digits = 3), quote = FALSE)
  cat("\n  * = Bonferroni-corrected p < .05 (2 emotions per group)\n\n")
}

# Export composite results
composite_cross_export <- imap_dfr(all_composite_cross,
  function(r, key) {
    parts <- str_split(key, "_", simplify = TRUE)
    r %>% mutate(outcome = parts[1], moment = parts[2])
  })
write_csv(composite_cross_export, "BAPCS_composite_cross_sectional.csv")

composite_mcnem_export <- imap_dfr(all_composite_mcnem,
  function(r, key) r %>% mutate(outcome = key))
write_csv(composite_mcnem_export, "BAPCS_composite_mcnemar.csv")

cat("Composite results exported:\n")
cat("  BAPCS_composite_cross_sectional.csv\n")
cat("  BAPCS_composite_mcnemar.csv\n")
cat("=== COMPOSITE ANALYSIS DONE ===\n")
