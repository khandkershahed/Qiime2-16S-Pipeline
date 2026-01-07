import os
import re
import csv

configfile: "config.yaml"
OUTDIR = config.get("outdir", "results")

def split_regions(val):
    if isinstance(val, list):
        return [str(x).strip() for x in val if str(x).strip()]
    if isinstance(val, str):
        return [x for x in re.split(r"[,\s]+", val.strip()) if x]
    return []

REGIONS = split_regions(config.get("regions", ""))

def region_db():
    rf = config.get("regions_full", {}) or {}
    out = {}
    for k, v in rf.items():
        out[str(k).strip()] = v
        out[str(k).strip().lower()] = v
    return out

REGION_DB = region_db()

def get_region(region):
    r = REGION_DB.get(region) or REGION_DB.get(region.lower())
    if not r:
        raise ValueError(f"Region '{region}' not found in config.yaml regions_full.")
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

include: "rules/00_utils.smk"
include: "rules/01_import_qc.smk"
include: "rules/02_trim_denoise.smk"
include: "rules/03_classifier_taxonomy.smk"
include: "rules/04_merge_phylogeny.smk"
include: "rules/05_diversity.smk"
include: "rules/06_gemelli_stats_qurro.smk"
include: "rules/07_export.smk"

rule all:
    input:
        # Import summary
        os.path.join(OUTDIR, "qiime2", "paired-end-demux.qzv"),

        # Optional QC
        os.path.join(OUTDIR, "qc", "multiqc", "multiqc_report.html") if config.get("run_qc") else [],

        # Per-region: trimmed, dada2, taxonomy, barplot
        expand(os.path.join(OUTDIR, "qiime2", "regions", "{region}", "demux_trim.qza"), region=REGIONS),
        expand(os.path.join(OUTDIR, "qiime2", "regions", "{region}", "table.qza"), region=REGIONS),
        expand(os.path.join(OUTDIR, "qiime2", "regions", "{region}", "repseqs.qza"), region=REGIONS),
        expand(os.path.join(OUTDIR, "qiime2", "regions", "{region}", "taxonomy.qza"), region=REGIONS),
        expand(os.path.join(OUTDIR, "qiime2", "regions", "{region}", "taxa-barplot.qzv"), region=REGIONS),

        # Merged + vsearch taxonomy + summaries
        rules.merge_tables.output,
        rules.merge_repseqs.output,
        rules.taxonomy_merged_vsearch.output,
        rules.merged_summaries.output.table_qzv,
        rules.merged_summaries.output.reps_qzv,

        # SEPP + filter + merged barplot
        rules.sepp_tree.output.tree if config.get("run_sepp") else [],
        rules.filter_table_by_sepp.output if config.get("run_sepp") else [],
        rules.merged_taxa_barplot.output,

        # Diversity
        rules.alpha_rarefaction.output,
        rules.core_metrics.output.dist_bray,

        # Gemelli / stats / qurro
        rules.gemelli_rpca_unrarefied.output.dist if config.get("run_gemelli") else [],
        rules.gemelli_rpca_rarefied.output.dist if config.get("run_gemelli") else [],
        rules.gemelli_qc_rarefy.output if config.get("run_gemelli") else [],
        rules.rpca_biplot.output if config.get("run_gemelli") else [],
        rules.permanova_adonis.output if config.get("run_gemelli") else [],
        rules.beta_group_significance.output if config.get("run_gemelli") else [],
        rules.qurro_plot.output if config.get("run_qurro") else [],

        # Exports for R
        rules.export_repseqs_fasta.output,
        rules.export_all.output
