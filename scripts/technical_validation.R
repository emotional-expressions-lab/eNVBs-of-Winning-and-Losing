# Technical validation of facial-emotion measures for Olympic and Paralympic
# athletes across four match timepoints (Pre, Mid, Result, Post).
#
# Reproduces the group comparisons reported in the Technical Validation section:
# within each timepoint and study (Study 1 = Winners, Study 2 = Losers), four
# two-group contrasts are tested across the nine affect channels and, separately,
# the twenty combined Action Units. Each contrast reports Welch's t-test, Cohen's
# d and Hedges' g, a Bayesian t-test, Levene's and Shapiro-Wilk assumption
# checks, and Benjamini-Hochberg FDR q-values across the dependent variables in
# the panel. For the nine affect channels a parametric MANOVA (Pillai's trace)
# and a robust MANOVA (modified ANOVA-type statistic with a bootstrap p-value)
# with simultaneous confidence intervals are additionally reported.
#
# Input: one Excel file per timepoint, each with sheets 'Study1_Winners' and
# 'Study2_Losers' holding one pooled value per participant per channel.
# Output: one CSV of univariate results and one CSV of MANOVA results per
# timepoint x study, written to OUTPUT_DIR.

library(readxl)
library(dplyr)
library(tidyr)
library(car)
library(effsize)
library(BayesFactor)
library(MANOVA.RM)

# ---- Configuration ----------------------------------------------------------

TIMEPOINTS <- c(
  Pre    = "../data/Pre_Analysed_Participants.xlsx",
  Mid    = "../data/Mid_Analysed_Participants.xlsx",
  Result = "../data/Result_Analysed_Participants.xlsx",
  Post   = "../data/Post_Analysed_Participants.xlsx"
)
OUTPUT_DIR   <- "../results"

MANOVA_ITER  <- 5000
MANOVA_SEED  <- 12345
BAYES_PRIOR  <- sqrt(2) / 2

# Athletes excluded from the analysed sample (non-blind Paralympic competitors),
# identified by serial number.
DISABLED_IDS <- as.character(c(
  226, 231, 274, 297, 364, 365, 366, 368, 369, 370, 371, 372, 373, 374, 375,
  376, 377, 378, 379, 380, 381, 382, 383, 384, 385, 386, 387, 388, 389, 390,
  391, 392, 393, 394, 395, 396, 397, 398, 399, 400, 401, 403, 458, 459, 460,
  461, 462, 463, 464, 465, 466, 467, 468, 469, 471, 472, 473, 474, 475, 476,
  481, 483, 484, 485, 486, 487, 488, 489, 491, 492, 493, 495, 512, 513, 535,
  536, 537, 538, 539, 540, 541, 542, 543, 546, 547))

EMOTIONS <- c("Neutral", "Happy", "Sad", "Angry", "Surprised", "Scared",
              "Disgusted", "Valence", "Arousal")
ACTION_UNITS <- c(
  "AU01_InnerBrowRaiser", "AU02_OuterBrowRaiser", "AU04_BrowLowerer",
  "AU05_UpperLidRaiser", "AU06_CheekRaiser", "AU07_LidTightener",
  "AU09_NoseWrinkler", "AU10_UpperLipRaiser", "AU12_LipCornerPuller",
  "AU14_Dimpler", "AU15_LipCornerDepressor", "AU17_ChinRaiser",
  "AU18_LipPucker", "AU20_LipStretcher", "AU23_LipTightener",
  "AU24_LipPressor", "AU25_LipsPart", "AU26_JawDrop", "AU27_MouthStretch",
  "AU43_EyeClosure")

# ---- Univariate tests -------------------------------------------------------

welch_test <- function(data, dv, group, levels) {
  d  <- data[data[[group]] %in% levels, c(dv, group)] %>% drop_na()
  g1 <- d[[dv]][d[[group]] == levels[1]]
  g2 <- d[[dv]][d[[group]] == levels[2]]
  if (length(g1) < 2 || length(g2) < 2) return(NULL)
  if (sd(g1) == 0 && sd(g2) == 0) return(NULL)
  tt <- t.test(g1, g2, var.equal = FALSE)
  d_est <- cohen.d(g1, g2)$estimate
  J     <- 1 - 3 / (4 * (length(g1) + length(g2) - 2) - 1)
  data.frame(
    dv = dv, group = paste(levels, collapse = " vs "),
    n1 = length(g1), mean1 = mean(g1), sd1 = sd(g1),
    n2 = length(g2), mean2 = mean(g2), sd2 = sd(g2),
    t = unname(tt$statistic), df = unname(tt$parameter), p = tt$p.value,
    cohens_d = d_est, hedges_g = d_est * J,
    stringsAsFactors = FALSE)
}

levene_test <- function(data, dv, group, levels) {
  d <- data[data[[group]] %in% levels, c(dv, group)] %>% drop_na()
  d[[group]] <- factor(d[[group]], levels = levels)
  if (nrow(d) < 4 || sd(d[[dv]]) == 0) return(NA_real_)
  lv <- leveneTest(as.formula(paste(dv, "~", group)), data = d, center = "median")
  lv$`Pr(>F)`[1]
}

shapiro_test <- function(data, dv, group, levels) {
  d <- data[data[[group]] %in% levels, c(dv, group)] %>% drop_na()
  res <- unlist(lapply(levels, function(l) {
    v <- d[[dv]][d[[group]] == l]; v - mean(v)
  }))
  if (length(res) < 3 || length(res) > 5000 || sd(res) == 0) return(NA_real_)
  shapiro.test(res)$p.value
}

bayes_test <- function(data, dv, group, levels) {
  d <- data[data[[group]] %in% levels, c(dv, group)] %>% drop_na()
  d[[group]] <- factor(d[[group]], levels = levels)
  if (nlevels(d[[group]]) < 2 || nrow(d) < 4) return(NA_real_)
  v <- tapply(d[[dv]], d[[group]], sd)
  if (any(is.na(v)) || any(v == 0)) return(NA_real_)
  bf <- ttestBF(formula = as.formula(paste(dv, "~", group)),
                data = as.data.frame(d), rscale = BAYES_PRIOR)
  exp(bf@bayesFactor$bf[1])
}

run_panel <- function(data, group, levels, dvs) {
  res <- lapply(dvs, function(dv) {
    w <- welch_test(data, dv, group, levels)
    if (is.null(w)) return(NULL)
    w$levene_p   <- levene_test(data, dv, group, levels)
    w$shapiro_p  <- shapiro_test(data, dv, group, levels)
    w$bf10       <- bayes_test(data, dv, group, levels)
    w
  })
  res <- do.call(rbind, res)
  if (!is.null(res)) res$q <- p.adjust(res$p, method = "BH")
  res
}

# ---- Multivariate tests (affect channels) -----------------------------------

manova_pillai <- function(data, dvs, group, levels) {
  d <- data[data[[group]] %in% levels, c(dvs, group)] %>% drop_na()
  d[[group]] <- factor(d[[group]], levels = levels)
  if (nlevels(d[[group]]) < 2 || nrow(d) < length(dvs) + 2) return(NULL)
  m <- manova(as.matrix(d[, dvs]) ~ d[[group]])
  s <- summary(m, test = "Pillai")$stats
  data.frame(pillai = s[1, "Pillai"], approx_f = s[1, "approx F"],
             num_df = s[1, "num Df"], den_df = s[1, "den Df"],
             p = s[1, "Pr(>F)"], n = nrow(d))
}

manova_robust <- function(data, dvs, group, levels) {
  d <- data[data[[group]] %in% levels, c(dvs, group)] %>% drop_na()
  d[[group]] <- factor(d[[group]], levels = levels)
  if (nlevels(d[[group]]) < 2 || nrow(d) < length(dvs) + 2) return(NULL)
  fml <- as.formula(paste0("cbind(", paste(dvs, collapse = ", "), ") ~ ", group))
  m   <- MANOVA.wide(fml, data = as.data.frame(d),
                     iter = MANOVA_ITER, seed = MANOVA_SEED)
  list(model = m, group = group)
}

# ---- Load, filter, and run one timepoint x study ----------------------------

analyse <- function(file, timepoint, study) {
  sheet  <- if (study == "Winners") "Study1_Winners" else "Study2_Losers"
  result <- if (study == "Winners") "Win" else "Loss"
  df <- read_excel(file, sheet = sheet)

  df <- df[!as.character(as.integer(suppressWarnings(as.numeric(df$Sr_No))))
           %in% DISABLED_IDS, ]
  df <- df[df$Vision %in% c("Sighted", "Blind") & df$Result == result, ]

  panels <- list(
    list(sub = df[df$Vision == "Blind", ],   group = "PD",     levels = c("High", "Low")),
    list(sub = df[df$Vision == "Sighted", ], group = "PD",     levels = c("High", "Low")),
    list(sub = df[df$PD == "High", ],        group = "Vision", levels = c("Sighted", "Blind")),
    list(sub = df[df$PD == "Low", ],         group = "Vision", levels = c("Sighted", "Blind")))
  panel_names <- c("Blind_HighVsLowPD", "Sighted_HighVsLowPD",
                   "HighPD_SightedVsBlind", "LowPD_SightedVsBlind")

  uni <- list(); mvt <- list()
  for (i in seq_along(panels)) {
    p <- panels[[i]]
    for (set in list(list(name = "Emotions", dvs = EMOTIONS),
                     list(name = "AU",       dvs = ACTION_UNITS))) {
      r <- run_panel(p$sub, p$group, p$levels, set$dvs)
      if (!is.null(r)) {
        r <- cbind(Timepoint = timepoint, Study = study,
                   Panel = panel_names[i], VarSet = set$name, r)
        uni[[length(uni) + 1]] <- r
      }
    }
    pil <- manova_pillai(p$sub, EMOTIONS, p$group, p$levels)
    rob <- manova_robust(p$sub, EMOTIONS, p$group, p$levels)
    if (!is.null(pil)) {
      mats <- suppressWarnings(as.numeric(rob$model$MATS[1]))
      mvt[[length(mvt) + 1]] <- cbind(
        Timepoint = timepoint, Study = study, Panel = panel_names[i], pil,
        mats = mats)
    }
  }
  list(univariate = do.call(rbind, uni), multivariate = do.call(rbind, mvt))
}

# ---- Run all timepoints and studies -----------------------------------------

dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)
uni_all <- list(); mvt_all <- list()
for (tp in names(TIMEPOINTS)) {
  file <- TIMEPOINTS[[tp]]
  if (!file.exists(file)) next
  for (study in c("Winners", "Losers")) {
    out <- analyse(file, tp, study)
    uni_all[[length(uni_all) + 1]] <- out$univariate
    mvt_all[[length(mvt_all) + 1]] <- out$multivariate
  }
}

write.csv(do.call(rbind, uni_all),
          file.path(OUTPUT_DIR, "univariate_results.csv"), row.names = FALSE)
write.csv(do.call(rbind, mvt_all),
          file.path(OUTPUT_DIR, "manova_results.csv"), row.names = FALSE)

sessionInfo()
