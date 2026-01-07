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

def read_manifest_sample_ids(manifest_tsv):
    if not os.path.exists(manifest_tsv):
        return []
    ids = []
    with open(manifest_tsv, "r", newline="") as f:
        reader = csv.reader(f, delimiter="\t")
        header = next(reader, None)
        if not header:
            return []
        for row in reader:
            if not row:
                continue
            if row[0].startswith("#"):
                continue
            ids.append(row[0].strip())
    return ids


# ----------------------------
# Include rule modules (exactly your repo filenames)
# ----------------------------
include: "rules/00_utils.smk"
include: "rules/01_import_qc.smk"
include: "rules/02_trim_denoise.smk"
include: "rules/03_classifier_taxonomy.smk"
include: "rules/04_merge_phylogeny.smk"
include: "rules/05_diversity.smk"
include: "rules/06_gemelli_stats_qurro.smk"
include: "rules/07_export.smk"


# ----------------------------
# Rule all (research-safe)
# IMPORTANT: do not hardcode gemelli/permanova filenames.
# We use the actual outputs from the rules to avoid mismatches.
# ----------------------------
rule all:
    input:
        # Optional QC (FastQC+MultiQC)
        (rules.fastqc_multiqc.output if bool(config.get("run_qc", True)) else []),

        # Per-region core artifacts
        expand(os.path.join(OUTDIR, "qiime2", "regions", "{region}", "demux_trim.qza"), region=REGIONS),
        expand(os.path.join(OUTDIR, "qiime2", "regions", "{region}", "table.qza"), region=REGIONS),
        expand(os.path.join(OUTDIR, "qiime2", "regions", "{region}", "repseqs.qza"), region=REGIONS),
        expand(os.path.join(OUTDIR, "qiime2", "regions", "{region}", "taxonomy.qza"), region=REGIONS),
        expand(os.path.join(OUTDIR, "qiime2", "regions", "{region}", "taxa-barplot.qzv"), region=REGIONS),

        # Merged artifacts
        rules.merge_tables.output,
        rules.merge_repseqs.output,
        rules.taxonomy_merged_vsearch.output,
        rules.merged_summaries.output,

        # SEPP + filtering (optional)
        ([rules.sepp_tree.output, rules.filter_table_by_sepp.output] if bool(config.get("run_sepp", True)) else []),

        # Diversity outputs
        rules.alpha_rarefaction.output,
        rules.core_metrics.output,

        # Gemelli outputs (optional)
        ([rules.gemelli_rpca_unrarefied.output,
          rules.rarefy_table.output,
          rules.gemelli_rpca_rarefied.output,
          rules.gemelli_qc_rarefy.output] if bool(config.get("run_gemelli", True)) else []),

        # PERMANOVA outputs (optional: only if beta_group_column is set)
        ([rules.permanova_adonis.output,
          rules.beta_group_significance.output] if str(config.get("beta_group_column", "")).strip() else []),

        # Qurro output (optional)
        (rules.qurro_plot.output if bool(config.get("run_qurro", True)) else []),

        # Exports for R
        rules.export_repseqs_fasta.output,
        rules.export_all.output
