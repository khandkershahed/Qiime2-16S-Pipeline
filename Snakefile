import os
import re
import csv
from pathlib import Path

configfile: "config.yaml"
OUTDIR = config.get("outdir", "results")

# ----------------------------
# Helper functions
# ----------------------------
def split_regions(val):
    if isinstance(val, list):
        return [str(x).strip() for x in val if str(x).strip()]
    if isinstance(val, str):
        return [x for x in re.split(r"[,\s]+", val.strip()) if x]
    return []

REGIONS = split_regions(config.get("regions", ""))

def regions_full():
    rf = config.get("regions_full", {}) or {}
    out = {}
    for k, v in rf.items():
        out[str(k).strip()] = v
        out[str(k).strip().lower()] = v
    return out

REGION_DB = regions_full()

def get_region(region):
    r = REGION_DB.get(region) or REGION_DB.get(region.lower())
    if not r:
        raise ValueError(f"Region '{region}' not found in config.yaml regions_full.")
    # Allow global overrides
    f_primer = config.get("f_primer", None)
    r_primer = config.get("r_primer", None)
    if f_primer and r_primer:
        r = dict(r)
        r["fwd"] = f_primer
        r["rev"] = r_primer
    return r

def manifest_path():
    return str(config["manifest"])

def metadata_path():
    return str(config["metadata"])

def read_manifest_fastqs(manifest_tsv):
    """Reads manifest, returns list of SampleIDs (best-effort)."""
    if not os.path.exists(manifest_tsv):
        return []
    ids = []
    with open(manifest_tsv, "r") as f:
        reader = csv.reader(f, delimiter="\t")
        header = next(reader, None)
        if not header:
            return []
        for row in reader:
            if row and not row[0].startswith("#"):
                ids.append(row[0].strip())
    return ids


# ----------------------------
# Include modular rules (keep file count small)
# ----------------------------
include: "rules/00_utils.smk"
include: "rules/01_import_qc.smk"
include: "rules/02_trimming_denoise.smk"
include: "rules/03_classifier_taxonomy.smk"
include: "rules/04_merge_sepp.smk"
include: "rules/05_diversity.smk"
include: "rules/06_stats_qurro.smk"
include: "rules/07_export.smk"


# ----------------------------
# Final targets (research-safe)
# Use explicit final filenames here to avoid Namedlist attribute mismatches.
# ----------------------------
QC_TARGETS = (
    [os.path.join(OUTDIR, "qc", "multiqc", "multiqc_report.html")]
    if bool(config.get("run_qc", True))
    else []
)

PER_REGION_TARGETS = []
for r in REGIONS:
    PER_REGION_TARGETS += [
        os.path.join(OUTDIR, "qiime2", "regions", r, "demux_trim.qza"),
        os.path.join(OUTDIR, "qiime2", "regions", r, "table.qza"),
        os.path.join(OUTDIR, "qiime2", "regions", r, "repseqs.qza"),
        os.path.join(OUTDIR, "qiime2", "regions", r, "taxonomy.qza"),
        os.path.join(OUTDIR, "qiime2", "regions", r, "taxa-barplot.qzv"),
    ]

MERGED_TARGETS = [
    os.path.join(OUTDIR, "qiime2", "merged", "merged_table.qza"),
    os.path.join(OUTDIR, "qiime2", "merged", "merged_repseqs.qza"),
    os.path.join(OUTDIR, "qiime2", "merged", "taxonomy_merged_vsearch.qza"),
    os.path.join(OUTDIR, "qiime2", "merged", "table_merged.qzv"),
    os.path.join(OUTDIR, "qiime2", "merged", "repseqs_merged.qzv"),
]

PHYLOGENY_TARGETS = []
if bool(config.get("run_sepp", True)):
    PHYLOGENY_TARGETS = [
        os.path.join(OUTDIR, "qiime2", "merged", "sepp_tree.qza"),
        os.path.join(OUTDIR, "qiime2", "merged", "sepp_placements.qza"),
        os.path.join(OUTDIR, "qiime2", "merged", "filtered_table_merged.qza"),
    ]

DIVERSITY_TARGETS = [
    os.path.join(OUTDIR, "qiime2", "diversity", "alpha-rarefaction.qzv"),
    os.path.join(OUTDIR, "qiime2", "diversity", "core-metrics", "bray_curtis_distance_matrix.qza"),
]

GEMELLI_TARGETS = (
    [
        os.path.join(OUTDIR, "qiime2", "gemelli", "rpca_unrarefied_biplot.qza"),
        os.path.join(OUTDIR, "qiime2", "gemelli", "rpca_unrarefied_distance.qza"),
        os.path.join(OUTDIR, "qiime2", "gemelli", "rarefied_table.qza"),
        os.path.join(OUTDIR, "qiime2", "gemelli", "rpca_rarefied_biplot.qza"),
        os.path.join(OUTDIR, "qiime2", "gemelli", "rpca_rarefied_distance.qza"),
        os.path.join(OUTDIR, "qiime2", "gemelli", "qc_rarefy.qzv"),
    ]
    if bool(config.get("run_gemelli", True))
    else []
)

PERMANOVA_TARGETS = (
    [
        os.path.join(OUTDIR, "qiime2", "stats", "adonis.qzv"),
        os.path.join(OUTDIR, "qiime2", "stats", "beta-group-significance.qzv"),
    ]
    if str(config.get("beta_group_column", "")).strip()
    else []
)

QURRO_TARGETS = (
    [os.path.join(OUTDIR, "qiime2", "qurro", "qurro_plot.qzv")]
    if bool(config.get("run_qurro", True))
    else []
)

EXPORT_TARGETS = [
    os.path.join(OUTDIR, "export", "dna-sequences.fasta"),
    os.path.join(OUTDIR, "export", "feature-table.tsv"),
    os.path.join(OUTDIR, "export", "taxonomy.tsv"),
    os.path.join(OUTDIR, "export", "tree.nwk"),
]


rule all:
    input:
        QC_TARGETS
        + PER_REGION_TARGETS
        + MERGED_TARGETS
        + PHYLOGENY_TARGETS
        + DIVERSITY_TARGETS
        + GEMELLI_TARGETS
        + PERMANOVA_TARGETS
        + QURRO_TARGETS
        + EXPORT_TARGETS
