import sys
import os
import csv

def read_manifest_ids(manifest_tsv):
    ids = []
    with open(manifest_tsv, "r", newline="") as f:
        reader = csv.reader(f, delimiter="\t")
        header = next(reader, None)
        if not header:
            return ids
        for row in reader:
            if not row or row[0].startswith("#"):
                continue
            ids.append(row[0].strip())
    return ids

def read_metadata_ids(metadata_tsv):
    ids = []
    with open(metadata_tsv, "r", newline="") as f:
        reader = csv.reader(f, delimiter="\t")
        header = next(reader, None)
        if not header:
            return ids, None
        first_col = header[0].strip()
        for row in reader:
            if not row:
                continue
            if row[0].startswith("#") and row[0].strip() != "#SampleID":
                continue
            ids.append(row[0].strip())
    return ids, first_col

def validate_metadata(manifest_fixed, metadata_tsv):
    if not os.path.exists(manifest_fixed):
        print(f"Error: fixed manifest not found: {manifest_fixed}")
        sys.exit(1)
    if not os.path.exists(metadata_tsv):
        print(f"Error: metadata not found: {metadata_tsv}")
        sys.exit(1)

    manifest_ids = set(read_manifest_ids(manifest_fixed))
    metadata_ids, first_col = read_metadata_ids(metadata_tsv)

    if first_col not in ["#SampleID", "SampleID"]:
        print("Error: metadata.tsv first column must be '#SampleID' (preferred) or 'SampleID'.")
        sys.exit(1)

    if not metadata_ids:
        print("Error: metadata.tsv has no samples.")
        sys.exit(1)

    missing = [sid for sid in manifest_ids if sid not in set(metadata_ids)]
    if missing:
        print("Error: These samples are in manifest but missing in metadata.tsv:")
        for sid in missing[:50]:
            print(f"  - {sid}")
        if len(missing) > 50:
            print(f"  ... plus {len(missing)-50} more")
        sys.exit(1)

    print("Metadata validation OK: all manifest samples exist in metadata.tsv")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python scripts/validate_metadata.py <manifest_fixed.tsv> <metadata.tsv>")
        sys.exit(1)
    validate_metadata(sys.argv[1], sys.argv[2])
