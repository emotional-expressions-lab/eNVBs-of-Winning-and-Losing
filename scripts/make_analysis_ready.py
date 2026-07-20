"""
Convert aggregator output to analysis-ready files.

For each timepoint, reads the aggregator's 'Pooled_By_Participant' sheet and
writes a file with two sheets, 'Study1_Winners' (Result == Win) and
'Study2_Losers' (Result == Loss), holding the 9 emotions and 20 combined Action
Units under the short column names the analysis script expects, plus a derived
Vision column (Olympic -> Sighted, otherwise -> Blind).

Left/right AU channels are dropped; the analysis uses only the combined channel.
'Blindness Status' is written as a placeholder and is not used in any statistic.
"""

import os
import pandas as pd


# Configuration
AGG_DIR = r"...\FaceReader_Aggregated_PY_Final"
OUT_DIR = r"...\Analysis_Ready"
TIMEPOINTS = ["Pre", "Mid", "Result", "Post"]

EMOTIONS = ["Neutral", "Happy", "Sad", "Angry", "Surprised",
            "Scared", "Disgusted", "Valence", "Arousal"]

AU_MAP = {
    "Action Unit 01 - Inner Brow Raiser":    "AU01_InnerBrowRaiser",
    "Action Unit 02 - Outer Brow Raiser":    "AU02_OuterBrowRaiser",
    "Action Unit 04 - Brow Lowerer":         "AU04_BrowLowerer",
    "Action Unit 05 - Upper Lid Raiser":     "AU05_UpperLidRaiser",
    "Action Unit 06 - Cheek Raiser":         "AU06_CheekRaiser",
    "Action Unit 07 - Lid Tightener":        "AU07_LidTightener",
    "Action Unit 09 - Nose Wrinkler":        "AU09_NoseWrinkler",
    "Action Unit 10 - Upper Lip Raiser":     "AU10_UpperLipRaiser",
    "Action Unit 12 - Lip Corner Puller":    "AU12_LipCornerPuller",
    "Action Unit 14 - Dimpler":              "AU14_Dimpler",
    "Action Unit 15 - Lip Corner Depressor": "AU15_LipCornerDepressor",
    "Action Unit 17 - Chin Raiser":          "AU17_ChinRaiser",
    "Action Unit 18 - Lip Pucker":           "AU18_LipPucker",
    "Action Unit 20 - Lip Stretcher":        "AU20_LipStretcher",
    "Action Unit 23 - Lip Tightener":        "AU23_LipTightener",
    "Action Unit 24 - Lip Pressor":          "AU24_LipPressor",
    "Action Unit 25 - Lips Part":            "AU25_LipsPart",
    "Action Unit 26 - Jaw Drop":             "AU26_JawDrop",
    "Action Unit 27 - Mouth Stretch":        "AU27_MouthStretch",
    "Action Unit 43 - Eye Closure":          "AU43_EyeClosure",
}

META_ORDER = ["Study", "Timepoint", "Sr_No", "Participant_Name_Full", "Name",
              "Nationality", "Gender", "Competition", "Vision", "Blindness Status",
              "PD", "Result"]


def derive_vision(competition):
    if pd.isna(competition):
        return None
    return "Sighted" if str(competition).strip().lower() == "olympic" else "Blind"


def convert_one(tp):
    src = os.path.join(AGG_DIR, f"{tp}_PROCESSED_v9_PY.xlsx")
    if not os.path.exists(src):
        print(f"[{tp}] skipped, not found: {src}")
        return
    df = pd.read_excel(src, sheet_name="Pooled_By_Participant")

    out = pd.DataFrame()
    out["Study"] = None
    out["Timepoint"] = tp
    for c in ["Sr_No", "Participant_Name_Full", "Name", "Nationality",
              "Gender", "Competition", "PD", "Result"]:
        out[c] = df[c] if c in df.columns else None
    out["Vision"] = df["Competition"].map(derive_vision) if "Competition" in df.columns else None
    out["Blindness Status"] = out["Vision"].map(
        lambda v: "N/A (Sighted)" if v == "Sighted" else "Unknown")

    for e in EMOTIONS:
        col = f"{e}_AllAnalyses"
        out[e] = df[col] if col in df.columns else None
    for long_name, short in AU_MAP.items():
        col = f"{long_name}_AllAnalyses"
        out[short] = df[col] if col in df.columns else None

    ordered = META_ORDER + EMOTIONS + list(AU_MAP.values())
    out = out[[c for c in ordered if c in out.columns]]

    winners = out[out["Result"] == "Win"].copy();  winners["Study"] = "Study 1"
    losers = out[out["Result"] == "Loss"].copy(); losers["Study"] = "Study 2"

    os.makedirs(OUT_DIR, exist_ok=True)
    dst = os.path.join(OUT_DIR, f"{tp}_Analysed_Participants.xlsx")
    with pd.ExcelWriter(dst, engine="openpyxl") as xw:
        winners.to_excel(xw, sheet_name="Study1_Winners", index=False)
        losers.to_excel(xw, sheet_name="Study2_Losers", index=False)

    other = out[~out["Result"].isin(["Win", "Loss"])]
    msg = f"[{tp}] Winners: {len(winners)} | Losers: {len(losers)}"
    if len(other):
        msg += (f" | EXCLUDED {len(other)} row(s) with Result not Win/Loss: "
                f"{sorted(other['Sr_No'].dropna().astype(int).unique())}")
    print(msg)


def main():
    for tp in TIMEPOINTS:
        convert_one(tp)


if __name__ == "__main__":
    main()
