"""
Extract the (Sr_No, Analysis Index) -> source video mapping from a FaceReader
.frx project file.

FaceReader exports every participant's name as the bare serial number, so the
event a clip belongs to is only recoverable from the source video path recorded
in the project file (Meta.xml -> Participant -> Analyses -> Analysis ->
ImageSourceData -> SourceFilenames). This writes one row per (participant,
analysis) with the source folder name and video filename, for use by
relabel_raw_export.py.

Reads the .frx (a zip archive) and writes OUTPUT_CSV only.
"""

import zipfile
import xml.etree.ElementTree as ET
import csv
from collections import defaultdict
from pathlib import Path


# Configuration
FRX_PATH   = r"...\Result Part 2 Batch Analysis Feb 18.frx"
OUTPUT_CSV = r"...\Result2_Analysis_To_Video_Mapping.csv"


def main():
    frx = Path(FRX_PATH)
    if not frx.exists():
        raise SystemExit(f"File not found: {frx}")

    z = zipfile.ZipFile(frx)
    if "Meta.xml" not in z.namelist():
        raise SystemExit("No Meta.xml found inside this .frx.")

    root = ET.fromstring(z.read("Meta.xml"))

    rows = []
    n_missing_source = 0
    for p in root.findall(".//Participant"):
        sr_no = (p.findtext("ParticipantInformation/ParticipantName") or "").strip()
        for a in p.findall("./Analyses/Analysis"):
            analysis_id = a.findtext("UniqueID") or ""
            src_path = a.findtext("./ImageSourceData/SourceFilenames/string") or ""
            if not src_path:
                n_missing_source += 1
            parts = src_path.replace("/", "\\").split("\\")
            folder_name = parts[-2] if len(parts) >= 2 else ""
            video_filename = parts[-1] if parts else ""
            rows.append({
                "Sr_No": sr_no,
                "Analysis_Index": analysis_id,
                "Source_Folder_Name": folder_name,
                "Source_Video_Filename": video_filename,
                "Full_Source_Path": src_path,
            })

    folders_by_sr = defaultdict(set)
    for r in rows:
        folders_by_sr[r["Sr_No"]].add(r["Source_Folder_Name"])
    multi = {sr: f for sr, f in folders_by_sr.items() if len(f) > 1}

    print(f"Participants: {len(root.findall('.//Participant'))}")
    print(f"(Sr_No, Analysis) rows: {len(rows)}")
    print(f"Multi-event Sr_No(s): {len(multi)}")
    if n_missing_source:
        print(f"Warning: {n_missing_source} analysis/analyses have no source path recorded.")

    with open(OUTPUT_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["Sr_No", "Analysis_Index", "Source_Folder_Name",
                                               "Source_Video_Filename", "Full_Source_Path"])
        writer.writeheader()
        writer.writerows(rows)

    print(f"Saved: {OUTPUT_CSV}")


if __name__ == "__main__":
    main()
