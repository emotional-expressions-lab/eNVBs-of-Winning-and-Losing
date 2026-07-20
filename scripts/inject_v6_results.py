"""
Inject the verified Win/Loss result onto every row of a relabelled raw export.

The result is taken from the verified per-timepoint reference file (V6_FILE),
joined per (serial, event) rather than per serial alone, since a multi-event
athlete can win one event and lose another. Rows with no match in the reference
(athletes outside the analysed sample) are dropped, so the aggregated output
needs no further filtering. Fails rather than writing a row with a blank result.

Run after relabel_raw_export.py, once per timepoint.
"""

import re
import pandas as pd


# Configuration
RELABELED_RAW_PATH = r"...\Result_Analysis_RELABELED.xlsx"
V6_FILE            = r"...\Result_PROCESSED_v6.xlsx"
OUTPUT_PATH        = r"...\Result_Analysis_RELABELED_FINAL.xlsx"


def normalize_sr(x):
    """Leading integer run of a label ('0099_2Para24 - ...' -> '99')."""
    m = re.match(r"^0*(\d+)", str(x).strip())
    return m.group(1) if m else None


def norm_key(label):
    """Everything before the first ' - ', lowercased; bare serials stripped of
    leading zeros so a zero-padded and an unpadded serial match. Compound
    event labels (containing '_') are left as-is."""
    head = str(label).split(" - ")[0].strip("_ ")
    if re.fullmatch(r"0*\d+", head):
        return str(int(head))
    return head.lower()


def main():
    v6 = pd.read_excel(V6_FILE, sheet_name="Pooled_By_Participant")
    for col in ("Sr_No", "Participant_Name_Full", "Result"):
        if col not in v6.columns:
            raise SystemExit(f"Reference file is missing expected column: {col}")

    v6["Sr_Norm"] = v6["Sr_No"].apply(normalize_sr)
    v6["Key"] = v6["Participant_Name_Full"].apply(norm_key)

    blank = v6["Result"].isna() | (v6["Result"].astype(str).str.strip() == "")
    if blank.any():
        raise SystemExit(
            f"Reference has {int(blank.sum())} row(s) with a blank Result. "
            f"Affected Sr_No(s): {sorted(v6.loc[blank, 'Sr_No'].unique())}"
        )

    lookup = v6.set_index(["Sr_Norm", "Key"])["Result"]
    if lookup.index.duplicated().any():
        collide = v6[v6.duplicated(["Sr_Norm", "Key"], keep=False)]
        conflict = collide.groupby(["Sr_Norm", "Key"])["Result"].nunique()
        bad = conflict[conflict > 1]
        if len(bad):
            raise SystemExit(
                "Colliding (serial, event) keys disagree on Result:\n"
                f"{collide[collide.set_index(['Sr_Norm','Key']).index.isin(bad.index)][['Sr_No','Participant_Name_Full','Result']]}"
            )
        lookup = lookup[~lookup.index.duplicated(keep="first")]
    print(f"Reference participants (serial x event): {len(lookup)}")

    df = pd.read_excel(RELABELED_RAW_PATH, sheet_name=0)
    df.columns = [str(c).strip() for c in df.columns]
    if "Participant Name" not in df.columns:
        raise SystemExit("Expected 'Participant Name' column not found in the relabelled export.")

    pn = df["Participant Name"].astype(str).str.strip()
    keys = pd.MultiIndex.from_arrays([pn.apply(normalize_sr), pn.apply(norm_key)])

    n_before = len(df)
    df["Result"] = lookup.reindex(keys).values

    missing = df["Result"].isna()
    df = df[~missing].copy()
    print(f"Rows: {n_before} total | {int(missing.sum())} dropped (not in reference) | {len(df)} retained")

    if df["Result"].isna().any():
        raise SystemExit("Blank Result survived filtering. Aborting.")

    kept = df["Participant Name"].astype(str).str.strip().nunique()
    if kept != len(lookup):
        print(f"Warning: {kept} participants retained, reference expects {len(lookup)}.")

    print("Result distribution:")
    print(df["Result"].value_counts().to_string())

    df.to_excel(OUTPUT_PATH, index=False)
    print(f"Saved: {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
