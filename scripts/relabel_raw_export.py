"""
Relabel multi-event participants in a raw FaceReader detailed export.

FaceReader exports every participant's name as the bare serial number, so an
athlete competing in more than one event has all events pooled under one label.
Using the mapping from extract_frx_mapping.py, this replaces 'Participant Name'
for serials whose analyses came from more than one source folder, so each event
becomes a distinct participant label. Single-event athletes are left unchanged.

Writes the relabelled export (OUTPUT_PATH) and a cross-check audit workbook
(AUDIT_OUTPUT) reporting, per serial, whether the number of labels produced
matches the number of distinct source folders expected.
"""

import pandas as pd


# Configuration
RAW_EXCEL_PATH = r"...\Combined Result Batch Analysis - Jun 3_detailed.xlsx"
MAPPING_CSV    = r"...\Result_Analysis_To_Video_Mapping.csv"
OUTPUT_PATH    = r"...\Result_Analysis_RELABELED.xlsx"
AUDIT_OUTPUT   = r"...\Result_Relabel_Audit.xlsx"


def normalize_ai(x):
    """Digits only from an Analysis Index value ('Analysis 7', '7', 'AI7' -> '7')."""
    s = str(x)
    digits = "".join(ch for ch in s if ch.isdigit())
    return digits if digits else s.strip()


def normalize_sr(x):
    """Serial number stripped of leading zeros and non-digits; None if no digits."""
    s = "".join(ch for ch in str(x) if ch.isdigit())
    return str(int(s)) if s else None


def main():
    mapping = pd.read_csv(MAPPING_CSV, dtype=str)
    mapping["Sr_No_Norm"] = mapping["Sr_No"].apply(normalize_sr)
    mapping["AI_Key"] = mapping["Analysis_Index"].apply(normalize_ai)

    folder_counts = mapping.groupby("Sr_No_Norm")["Source_Folder_Name"].nunique()
    duplicate_srnos = set(folder_counts[folder_counts > 1].index)
    print(f"Duplicate Sr_No(s) to relabel: {len(duplicate_srnos)}")

    dup_mapping = mapping[mapping["Sr_No_Norm"].isin(duplicate_srnos)].copy()
    lookup = dup_mapping.set_index(["Sr_No_Norm", "AI_Key"])["Source_Folder_Name"]
    if lookup.index.duplicated().any():
        lookup = lookup[~lookup.index.duplicated(keep="first")]

    df = pd.read_excel(RAW_EXCEL_PATH, sheet_name=0)
    df.columns = [str(c).strip() for c in df.columns]
    if "Participant Name" not in df.columns or "Analysis Index" not in df.columns:
        raise SystemExit("Expected 'Participant Name' and 'Analysis Index' columns not found.")

    orig_pn = df["Participant Name"].astype(str).str.strip()
    pn_norm = df["Participant Name"].apply(normalize_sr)
    ai_key = df["Analysis Index"].apply(normalize_ai)

    is_dup_row = pn_norm.isin(duplicate_srnos)
    print(f"Total rows: {len(df)} | rows to relabel: {int(is_dup_row.sum())}")

    keys = list(zip(pn_norm[is_dup_row], ai_key[is_dup_row]))
    new_labels = lookup.reindex(keys)
    n_missing = int(new_labels.isna().sum())
    if n_missing:
        missing_srnos = sorted(set(pn_norm[is_dup_row][new_labels.isna().values]))
        print(f"Warning: {n_missing} row(s) had no matching mapping entry and keep their "
              f"original name. Affected Sr_No(s): {', '.join(missing_srnos)}")

    final_labels = new_labels.where(new_labels.notna(),
                                    pd.Series(orig_pn[is_dup_row].values, index=new_labels.index))
    df["Participant Name"] = df["Participant Name"].astype(object)
    df.loc[is_dup_row, "Participant Name"] = final_labels.values

    n_after = df["Participant Name"].astype(str).str.strip().nunique()
    print(f"Distinct participant names: {orig_pn.nunique()} -> {n_after}")

    # Cross-check audit: one row per (Sr_No, new label).
    audit_src = df.loc[is_dup_row, ["Participant Name", "Analysis Index"]].copy()
    audit_src["Sr_No"] = pn_norm[is_dup_row].values
    audit_src["Original_Bare_Name"] = orig_pn[is_dup_row].values

    audit_rows = []
    for (sr, label), g in audit_src.groupby(["Sr_No", "Participant Name"]):
        ai_list = sorted(g["Analysis Index"].astype(str).unique().tolist())
        audit_rows.append({
            "Sr_No": sr,
            "Original_Bare_Name": g["Original_Bare_Name"].iloc[0],
            "New_Participant_Name": label,
            "Num_Rows_Frames": len(g),
            "Num_Analyses": len(ai_list),
            "Analysis_Indices": ", ".join(ai_list),
        })
    audit_df = pd.DataFrame(audit_rows)

    expected = mapping.groupby("Sr_No_Norm")["Source_Folder_Name"].nunique()
    audit_df["Expected_Distinct_Events"] = audit_df["Sr_No"].map(expected)
    audit_df["Actual_Distinct_Labels"] = audit_df.groupby("Sr_No")["New_Participant_Name"].transform("nunique")
    audit_df["Match_OK"] = audit_df["Actual_Distinct_Labels"] == audit_df["Expected_Distinct_Events"]
    audit_df = audit_df.sort_values(["Sr_No", "New_Participant_Name"]).reset_index(drop=True)

    n_mismatch = audit_df.loc[~audit_df["Match_OK"], "Sr_No"].nunique()
    if n_mismatch:
        print(f"Warning: {n_mismatch} Sr_No(s) have Match_OK = FALSE; see {AUDIT_OUTPUT}.")

    audit_df.to_excel(AUDIT_OUTPUT, index=False)
    df.to_excel(OUTPUT_PATH, index=False)
    print(f"Saved: {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
