import sys
import os
import csv

def fix_path(p):
    return p.strip().strip('"').strip("'")

def validate_and_fix(manifest_in, manifest_out):
    if not os.path.exists(manifest_in):
        print(f"Error: Manifest {manifest_in} not found.")
        sys.exit(1)

    fixed_lines = []
    with open(manifest_in, 'r', newline='') as fin:
        reader = csv.reader(fin, delimiter='\t')
        header = next(reader, None)
        if not header:
            print("Error: Empty manifest.")
            sys.exit(1)

        fixed_lines.append("\t".join(header))

        for row in reader:
            if not row:
                continue
            if row[0].startswith("#"):
                continue
            if len(row) < 3:
                print("Error: Manifest row must have 3 columns: sample-id, forward-absolute-filepath, reverse-absolute-filepath")
                sys.exit(1)

            sample_id = row[0]
            fwd = fix_path(row[1])
            rev = fix_path(row[2])

            if not os.path.exists(fwd):
                print(f"Error: FASTQ not found: {fwd}")
                sys.exit(1)
            if not os.path.exists(rev):
                print(f"Error: FASTQ not found: {rev}")
                sys.exit(1)

            fixed_lines.append(f"{sample_id}\t{os.path.abspath(fwd)}\t{os.path.abspath(rev)}")

    os.makedirs(os.path.dirname(manifest_out), exist_ok=True)
    with open(manifest_out, 'w', newline='') as fout:
        fout.write("\n".join(fixed_lines) + "\n")

    print(f"Manifest validated and fixed: {manifest_out}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python scripts/validate_manifest.py <manifest_in.tsv> <manifest_out.tsv>")
        sys.exit(1)
    validate_and_fix(sys.argv[1], sys.argv[2])
