# 16S Multi-Region Snakemake Pipeline (QIIME2 2024.10) — Research-Safe v1.0.0

This repository runs a **complete, research-oriented** multi-region 16S analysis pipeline in **Snakemake**, following the step order in your PPTX:
Import → (optional) FastQC/MultiQC → Cutadapt per-region → DADA2 per-region → Train region-specific classifiers → Taxonomy per-region → Merge → VSEARCH consensus taxonomy → SEPP phylogeny → Filtering → Alpha rarefaction → Core metrics → Gemelli RPCA (+ QC) → PERMANOVA/Significance → Qurro → Exports for R.

## 0) Requirements
- Linux / WSL2 / macOS recommended (Windows native is not recommended for QIIME2).
- **Miniforge / Mambaforge** installed (recommended).
- Internet access (for downloading reference databases and SEPP refs).
- Paired-end FASTQ data.

## 1) Download the repo
```bash
git clone <YOUR_GITHUB_REPO_URL>.git
cd <YOUR_GITHUB_REPO_NAME>
```

## 2) Create a fresh Snakemake runner environment (recommended)
This keeps Snakemake stable and lets it create all tool environments automatically.
```bash
mamba env create -f envs/snakemake.yml
mamba activate snakemake
```

## 3) Prepare your input files
Put your files in the `data/` folder (or point to them in `config.yaml`).

### 3.1 manifest.tsv (QIIME2 PairedEndFastqManifestPhred33V2)
`data/manifest.tsv` must look like:

```
sample-id	forward-absolute-filepath	reverse-absolute-filepath
S1	/abs/path/to/S1_R1.fastq.gz	/abs/path/to/S1_R2.fastq.gz
S2	/abs/path/to/S2_R1.fastq.gz	/abs/path/to/S2_R2.fastq.gz
```

**Important:** use absolute paths. Spaces are OK (the pipeline validates and fixes paths).

### 3.2 metadata.tsv
Example `data/metadata.tsv`:

```
#SampleID	Country
S1	BD
S2	BD
```

## 4) Configure the pipeline
Edit `config.yaml`.

Key options:
- `regions`: choose one or more region keys from `regions_full` (space-separated)
- `run_qc`: true/false (FastQC + MultiQC)
- `cores`: threads for cutadapt and generally
- `ref_database`: `silva` or `greengenes`
- `run_sepp`, `run_gemelli`, `run_qurro`: enable/disable major sections

### Primer coverage
A large curated list of commonly used research primer pairs is provided in `regions_full`.
If you need a primer not listed, add a new block under `regions_full` OR use:
- `f_primer` and `r_primer` (global override for all regions in a run)

## 5) Run the pipeline
### 5.1 Dry run (recommended)
```bash
snakemake -n
```

### 5.2 Execute (Snakemake will create all tool environments)
```bash
snakemake --use-conda --cores 12
```

If you want to override inputs without editing config:
```bash
snakemake --use-conda --cores 16 \
  --config manifest=/abs/path/manifest.tsv metadata=/abs/path/metadata.tsv \
  regions="v34_341f_806r v4_515f_806r v45_515f_926r" run_qc=true ref_database=silva
```

## 6) Outputs (where to find results)
All outputs are written to: `results/`

### 6.1 Import summary
- `results/qiime2/paired-end-demux.qzv`

### 6.2 QC (optional)
- `results/qc/multiqc/multiqc_report.html`

### 6.3 Per-region outputs
For each selected region:
- Trimmed demux: `results/qiime2/regions/<region>/demux_trim.qza`
- DADA2 table: `results/qiime2/regions/<region>/table.qza`
- Rep seqs: `results/qiime2/regions/<region>/repseqs.qza`
- Taxonomy: `results/qiime2/regions/<region>/taxonomy.qza`
- Barplot: `results/qiime2/regions/<region>/taxa-barplot.qzv`

### 6.4 Merged outputs
- `results/qiime2/merged/merged_table.qza`
- `results/qiime2/merged/merged_repseqs.qza`
- `results/qiime2/merged/taxonomy_merged_vsearch.qza`
- Summaries: `results/qiime2/merged/table_merged.qzv`, `repseqs_merged.qzv`
- Filtered table (after SEPP): `results/qiime2/merged/filtered_table_merged.qza`
- Merged barplot: `results/qiime2/merged/filtered_taxa_merged.qzv`

### 6.5 Diversity
- `results/qiime2/diversity/alpha_rarefaction.qzv`
- Core metrics output dir: `results/qiime2/diversity/core-metrics/`

### 6.6 Gemelli / PERMANOVA / Qurro
- RPCA (unrarefied): `results/qiime2/gemelli/ordination_unrarefied.qza`, `distance_unrarefied.qza`
- RPCA (rarefied): `results/qiime2/gemelli/ordination_rarefied.qza`, `distance_rarefied.qza`
- QC rarefy: `results/qiime2/gemelli/rarefy_qc.qzv`
- Biplot: `results/qiime2/gemelli/rpca_biplot.qzv`
- PERMANOVA: `results/qiime2/stats/rpca_permanova.qzv`
- Beta group significance: `results/qiime2/stats/beta_group_significance.qzv`
- Qurro: `results/qiime2/qurro/qurro_plot.qzv`

### 6.7 Exports for downstream R
- `results/export/feature-table.tsv`
- `results/export/taxonomy.tsv`
- `results/export/tree.nwk`
- `results/export/dna-sequences.fasta`

## 7) Downstream R analysis (instructions only; no R code in pipeline)
You can now perform the R analyses described in your PPTX (GMPR, GUniFrac, PhILR, breakaway, DivNet) using the exported files in `results/export/`.

## 8) Troubleshooting
### QIIME2 environment issues
This repo pins:
- `qiime2-amplicon=2024.10`
- `python=3.10`
and uses the official QIIME2 2024.10 channel in `envs/qiime2.yml`.

If a solver fails, ensure you are using **mamba** (not classic conda):
```bash
mamba --version
```

### SEPP is heavy
SEPP can require significant RAM/CPU. Reduce threads if needed:
- `sepp_threads` in `config.yaml`



## Research-safe features
- Pinned QIIME2 release (**qiime2-amplicon=2024.10**, **python=3.10**)
- Uses official QIIME2 2024.10 channel (reduces conda solver issues)
- Validates manifest paths **and** validates metadata contains all manifest samples
- Optional QC (FastQC + MultiQC) via `run_qc: true/false`
- Paper-style Methods in `docs/METHODS.md`
- Publishing guide in `docs/PUBLISHING.md`

## Installing Snakemake (conda / mamba / pip)

### A) mamba (recommended)
```bash
mamba env create -f envs/snakemake.yml
mamba activate snakemake
```

### B) conda
```bash
conda env create -f envs/snakemake.yml
conda activate snakemake
```

### C) pip (installs Snakemake only; pipeline still needs conda/mamba for QIIME2 envs)
```bash
python -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install snakemake
```

> Note: QIIME2 is installed by Snakemake using `--use-conda` from `envs/qiime2.yml`.

## Methods for papers
Read: `docs/METHODS.md`
