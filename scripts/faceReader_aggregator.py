"""
Aggregate frame-level FaceReader output to one value per athlete-event.

Frames are grouped by the full 'Participant Name' label (not by serial number),
so multi-event athletes stay split into separate events. Error tokens are
treated as missing; each measure is the mean over valid frames, pooled across
all of a participant's analyses. Writes one workbook per timepoint with three
sheets: Pooled_By_Participant, Analysis_Quality, and Verification.

The Win/Loss result is taken from the per-row 'Result' column where present
(majority value if a participant's rows disagree), otherwise from the master
list by serial number. Other metadata is taken from the master list.
"""

import os
import re
from collections import Counter

import numpy as np
import pandas as pd


# Configuration
TIMEPOINTS = {
    "Pre":    r"...\Prematch_Analysis_RELABELED_FINAL.xlsx",
    "Mid":    r"...\Midmatch_Analysis_RELABELED_FINAL.xlsx",
    "Result": r"...\Result_Analysis_RELABELED_FINAL.xlsx",
    "Post":   r"...\Postmatch_Analysis_RELABELED_FINAL.xlsx",
}
MASTER_LIST_FILE = r"...\Master List_Final.xlsx"   # "" to skip
OUTPUT_DIR       = r"...\FaceReader_Aggregated_PY_Final"

EMOTION_COLUMNS = ["Neutral", "Happy", "Sad", "Angry", "Surprised",
                   "Scared", "Disgusted", "Valence", "Arousal"]
AU_PREFIX = "Action Unit"
ERROR_TOKENS = {"fit_failed", "find_failed", "no_face", "missing",
                "n/a", "na", "error", "invalid", "none", ""}
INVALID_30 = 0.30
INVALID_50 = 0.50

PD_MAP = {"high": "High", "hi": "High", "h": "High", "highpd": "High",
          "high pd": "High", "high-pd": "High",
          "low": "Low", "lo": "Low", "l": "Low", "lowpd": "Low"}
GENDER_MAP = {"male": "Male", "m": "Male", "man": "Male",
              "female": "Female", "f": "Female", "woman": "Female"}
RESULT_MAP = {"win": "Win", "won": "Win", "w": "Win", "winner": "Win", "gold": "Win",
              "loss": "Loss", "lost": "Loss", "l": "Loss", "lose": "Loss",
              "loser": "Loss", "4th": "Loss"}


def coerce_numeric(series):
    """Turn error tokens into NaN, parse everything else numerically."""
    def one(v):
        s = str(v).strip().lower()
        if s in ERROR_TOKENS:
            return np.nan
        try:
            return float(v)
        except (ValueError, TypeError):
            return np.nan
    return series.map(one)


def sr_from_label(label):
    """Leading integer of a participant label ('0099_2Para24 - ...' -> 99)."""
    m = re.match(r"^0*(\d+)", str(label).strip())
    return int(m.group(1)) if m else None


def std_result(v):
    if pd.isna(v):
        return None
    return RESULT_MAP.get(str(v).strip().lower(), str(v).strip())


def std_pd(v):
    if pd.isna(v):
        return None
    return PD_MAP.get(str(v).strip().lower(), str(v).strip())


def std_gender(v):
    if pd.isna(v):
        return None
    return GENDER_MAP.get(str(v).strip().lower(), str(v).strip())


def std_comp(v):
    if pd.isna(v):
        return None
    vl = str(v).strip().lower()
    if vl.startswith("para"):
        return "Paralympic"
    if vl.startswith("oly") or "olympic" in vl:
        return "Olympic"
    return str(v).strip()


def load_master(path):
    """Sr_No -> dict(Name, Nationality, PD, Gender, Competition, Result)."""
    if not path or not os.path.exists(path):
        return {}
    m = pd.read_excel(path)
    m.columns = [str(c).strip() for c in m.columns]

    def find(*keys):
        for c in m.columns:
            cl = c.lower()
            if any(k in cl for k in keys):
                return c
        return None

    col_sr = find("serial", "serail", "sr no", "sr_no", "srno")
    col_name = find("athlete", "name")
    col_nat = find("nation", "country")
    col_pd = find("pd", "pressure")
    col_gen = find("gender", "sex")
    col_comp = find("olympic", "paralympic", "compet")
    col_res = find("win", "lose", "result", "outcome")

    lookup = {}
    for _, r in m.iterrows():
        sr = sr_from_label(r[col_sr]) if col_sr else None
        if sr is None:
            continue
        lookup[sr] = {
            "Name": r[col_name] if col_name else None,
            "Nationality": r[col_nat] if col_nat else None,
            "PD": std_pd(r[col_pd]) if col_pd else None,
            "Gender": std_gender(r[col_gen]) if col_gen else None,
            "Competition": std_comp(r[col_comp]) if col_comp else None,
            "Result": std_result(r[col_res]) if col_res else None,
        }
    return lookup


def aggregate_one(tp, path, master):
    df = pd.read_excel(path)
    df.columns = [str(c).strip() for c in df.columns]

    pn_col = "Participant Name"
    ai_col = "Analysis Index"
    if pn_col not in df.columns:
        raise SystemExit(f"'{pn_col}' column not found in {path}")

    target_cols = [c for c in df.columns
                   if c in EMOTION_COLUMNS or c.startswith(AU_PREFIX)]
    emo_present = [c for c in EMOTION_COLUMNS if c in target_cols]
    for c in target_cols:
        df[c] = coerce_numeric(df[c])

    ref_col = "Neutral" if "Neutral" in target_cols else target_cols[0]
    has_injected_result = "Result" in df.columns

    pooled_rows = []
    aq_rows = []

    for pn, grp in df.groupby(pn_col, sort=False):
        sr = sr_from_label(pn)
        meta = master.get(sr, {}) if sr is not None else {}

        result = meta.get("Result")
        if has_injected_result:
            inj = grp["Result"].dropna()
            inj = inj[inj.astype(str).str.strip() != ""]
            if len(inj):
                uniq = inj.map(std_result).unique()
                if len(uniq) > 1:
                    result = Counter(inj.map(std_result)).most_common(1)[0][0]
                else:
                    result = uniq[0]

        n_analyses = grp[ai_col].nunique() if ai_col in grp.columns else 1
        detail_parts = []
        for ai, asub in (grp.groupby(ai_col, sort=True) if ai_col in grp.columns
                         else [("Analysis 1", grp)]):
            tot = len(asub)
            val = int(asub[ref_col].notna().sum())
            inv = tot - val
            ipct = round(inv / tot * 100, 1) if tot else 0.0
            f30 = "YES" if (tot and inv / tot > INVALID_30) else "no"
            f50 = "YES" if (tot and inv / tot > INVALID_50) else "no"
            detail_parts.append(f"AI{ai}: {val}v/{tot}t ({ipct}% inv)")
            aq_rows.append({
                "Sr_No": sr, "Duplicate_Group": "", "Participant_Name_Full": pn,
                "Name": meta.get("Name"), "PD": meta.get("PD"),
                "Gender": meta.get("Gender"), "Competition": meta.get("Competition"),
                "Result": result, "Analysis_Index": ai,
                "Total_Frames": tot, "Valid_Frames": val, "Invalid_Frames": inv,
                "Invalid_Pct": ipct, "Flagged_30pct": f30, "Flagged_50pct": f50,
            })

        tot = len(grp)
        val = int(grp[ref_col].notna().sum())
        row = {
            "Sr_No": sr, "Duplicate_Group": "", "Name": meta.get("Name"),
            "Participant_Name_Full": pn, "Nationality": meta.get("Nationality"),
            "PD": meta.get("PD"), "Gender": meta.get("Gender"),
            "Competition": meta.get("Competition"), "Result": result, "TimePoint": tp,
            "Num_Analyses": n_analyses,
            "Analyses": ", ".join(str(x) for x in sorted(grp[ai_col].unique())) if ai_col in grp.columns else "",
            "Total_Frames": tot, "Valid_Frames": val, "Invalid_Frames": tot - val,
            "Valid_Pct": round(val / tot * 100, 1) if tot else 0.0,
            "Analysis_Quality_Detail": " | ".join(detail_parts),
        }
        for col in target_cols:
            vv = grp[col].dropna()
            row[f"{col}_AllAnalyses"] = vv.mean() if len(vv) else np.nan
            row[f"{col}_AllAnalyses_NFrames"] = len(vv)
            row[f"{col}_Sum"] = vv.sum()
            row[f"{col}_Count"] = len(vv)
        pooled_rows.append(row)

    P = pd.DataFrame(pooled_rows)

    sr_counts = P["Sr_No"].value_counts()
    multi = set(sr_counts[sr_counts > 1].index)
    P["Duplicate_Group"] = P["Sr_No"].map(lambda s: str(int(s)) if s in multi else "")

    aq = pd.DataFrame(aq_rows)
    dup_map = P.set_index("Participant_Name_Full")["Duplicate_Group"].to_dict()
    aq["Duplicate_Group"] = aq["Participant_Name_Full"].map(dup_map).fillna("")

    meta_cols = ["Sr_No", "Duplicate_Group", "Name", "Participant_Name_Full",
                 "Nationality", "PD", "Gender", "Competition", "Result", "TimePoint",
                 "Num_Analyses", "Analyses", "Total_Frames", "Valid_Frames",
                 "Invalid_Frames", "Valid_Pct", "Analysis_Quality_Detail"]
    ordered_measures = [c for c in EMOTION_COLUMNS if c in target_cols] + \
                       sorted([c for c in target_cols if c.startswith(AU_PREFIX)])
    measure_cols = []
    for col in ordered_measures:
        measure_cols += [f"{col}_AllAnalyses", f"{col}_AllAnalyses_NFrames"]
    pooled_out = P[meta_cols + measure_cols].copy()
    pooled_out = pooled_out.sort_values(["Sr_No", "Participant_Name_Full"]).reset_index(drop=True)

    aq_cols = ["Sr_No", "Duplicate_Group", "Participant_Name_Full", "Name", "PD",
               "Gender", "Competition", "Result", "Analysis_Index", "Total_Frames",
               "Valid_Frames", "Invalid_Frames", "Invalid_Pct", "Flagged_30pct", "Flagged_50pct"]
    aq_out = aq[aq_cols].sort_values(["Sr_No", "Analysis_Index"]).reset_index(drop=True)

    ver_cols = ["Sr_No", "Name", "Valid_Frames"]
    for col in emo_present[:3]:
        for s in (f"{col}_AllAnalyses", f"{col}_Sum", f"{col}_Count"):
            if s in P.columns:
                ver_cols.append(s)
    ver_out = P[ver_cols].copy()

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    out_path = os.path.join(OUTPUT_DIR, f"{tp}_PROCESSED_v9_PY.xlsx")
    with pd.ExcelWriter(out_path, engine="openpyxl") as xw:
        pooled_out.to_excel(xw, sheet_name="Pooled_By_Participant", index=False)
        aq_out.to_excel(xw, sheet_name="Analysis_Quality", index=False)
        ver_out.to_excel(xw, sheet_name="Verification", index=False)

    print(f"[{tp}] {len(pooled_out)} participants -> {os.path.basename(out_path)}")


def main():
    master = load_master(MASTER_LIST_FILE)
    print(f"Master list: {len(master)} athletes" if master else "Master list: not used")
    for tp, path in TIMEPOINTS.items():
        if not os.path.exists(path):
            print(f"[{tp}] skipped, file not found: {path}")
            continue
        aggregate_one(tp, path, master)


if __name__ == "__main__":
    main()
