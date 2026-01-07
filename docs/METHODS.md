# Methods (Simple English)

This pipeline runs a complete 16S rRNA amplicon workflow using **QIIME2 (2024.10)** with **Snakemake** so the analysis is reproducible and easy to rerun.

## Inputs
- Paired-end FASTQ reads are provided using a QIIME2 manifest file (PairedEndFastqManifestPhred33V2 format).
- Sample metadata is provided as a tab-separated file. The first column must be `#SampleID`.
- Before analysis, the pipeline checks:
  1) FASTQ paths exist (manifest validation)
  2) every sample in the manifest exists in the metadata

## Optional quality control (FastQC + MultiQC)
If enabled, FastQC is run on all input FASTQ files and summarized using MultiQC.

## Primer trimming (Cutadapt)
Reads are trimmed using `qiime cutadapt trim-paired` with region-specific forward and reverse primers.
By default, reads without primers are discarded (discard-untrimmed), so downstream steps use consistent data.

## Denoising (DADA2)
For each selected region, DADA2 is run independently using `qiime dada2 denoise-paired`.
This produces:
- an ASV feature table
- representative sequences
- denoising statistics

Truncation lengths are controlled per region in `config.yaml`.

## Taxonomy assignment
A reference database is selected by the user:
- **SILVA 138** (default) or
- **Greengenes 13_8**

For each region:
1) reference reads are extracted in silico using the selected primer pair
2) a Naive Bayes classifier is trained (or a pretrained classifier is used)
3) taxonomy is assigned to representative sequences

## Multi-region merging + consensus taxonomy
Feature tables and representative sequences from all regions are merged.
Merged taxonomy is assigned with VSEARCH consensus classification using the same selected reference database.

## Phylogeny (SEPP) + filtering
A phylogenetic tree is built using SEPP fragment insertion (`qiime fragment-insertion sepp`).
The merged feature table is filtered to keep only features that were placed into the SEPP reference tree.

## Diversity analysis
- Alpha rarefaction is computed using the filtered table and SEPP tree.
- Core phylogenetic diversity metrics are computed (including Bray–Curtis and UniFrac) using the selected sampling depth.

## Compositional analysis (Gemelli) + visualization (Qurro)
If enabled:
- RPCA (Robust Aitchison PCA) is computed with Gemelli.
- QC-rarefy is generated to compare rarefied vs unrarefied results.
- PERMANOVA-style tests are generated (Adonis and beta-group-significance).
- Qurro is used for log-ratio exploration.

## Exports for downstream R analysis
The pipeline exports:
- `feature-table.tsv`
- `taxonomy.tsv`
- `tree.nwk`
- `dna-sequences.fasta`

These are ready for downstream R workflows (phyloseq, GUniFrac, PhILR, breakaway, DivNet, etc.).
