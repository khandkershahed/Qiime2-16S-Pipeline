rule merge_tables:
    input:
        tables=lambda wc: [os.path.join(OUTDIR, "qiime2", "regions", r, "table.qza") for r in REGIONS]
    output:
        os.path.join(OUTDIR, "qiime2", "merged", "merged_table.qza")
    conda:
        "envs/qiime2.yml"
    shell:
        """
        mkdir -p {OUTDIR}/qiime2/merged
        qiime feature-table merge \
          {" ".join(["--i-tables \"" + t + "\"" for t in input.tables])} \
          --o-merged-table "{output}"
        """

rule merge_repseqs:
    input:
        reps=lambda wc: [os.path.join(OUTDIR, "qiime2", "regions", r, "repseqs.qza") for r in REGIONS]
    output:
        os.path.join(OUTDIR, "qiime2", "merged", "merged_repseqs.qza")
    conda:
        "envs/qiime2.yml"
    shell:
        """
        mkdir -p {OUTDIR}/qiime2/merged
        qiime feature-table merge-seqs \
          {" ".join(["--i-data \"" + r + "\"" for r in input.reps])} \
          --o-merged-data "{output}"
        """

rule taxonomy_merged_vsearch:
    input:
        reps=os.path.join(OUTDIR, "qiime2", "merged", "merged_repseqs.qza"),
        ref_seqs=rules.download_references.output.seqs,
        ref_tax=rules.download_references.output.tax
    output:
        os.path.join(OUTDIR, "qiime2", "merged", "taxonomy_merged_vsearch.qza")
    conda:
        "envs/qiime2.yml"
    params:
        perc_id=lambda wc: float(config.get("merged_tax_perc_identity", 0.97))
    shell:
        """
        qiime feature-classifier classify-consensus-vsearch \
            --i-query "{input.reps}" \
            --i-reference-reads "{input.ref_seqs}" \
            --i-reference-taxonomy "{input.ref_tax}" \
            --p-perc-identity {params.perc_id} \
            --o-classification "{output}"
        """

rule merged_summaries:
    input:
        table=os.path.join(OUTDIR, "qiime2", "merged", "merged_table.qza"),
        reps=os.path.join(OUTDIR, "qiime2", "merged", "merged_repseqs.qza"),
        meta=metadata_path()
    output:
        table_qzv=os.path.join(OUTDIR, "qiime2", "merged", "table_merged.qzv"),
        reps_qzv=os.path.join(OUTDIR, "qiime2", "merged", "repseqs_merged.qzv")
    conda:
        "envs/qiime2.yml"
    shell:
        """
        qiime feature-table summarize \
          --i-table "{input.table}" \
          --m-sample-metadata-file "{input.meta}" \
          --o-visualization "{output.table_qzv}"
        qiime feature-table tabulate-seqs \
          --i-data "{input.reps}" \
          --o-visualization "{output.reps_qzv}"
        """

rule download_sepp_refs:
    output:
        os.path.join(OUTDIR, "refs", "sepp_refs.qza")
    conda:
        "envs/qiime2.yml"
    params:
        db=lambda wc: str(config.get("sepp_refs_db", "silva-128")).lower(),
        silva=lambda wc: config.get("sepp_refs_silva_128_url"),
        gg=lambda wc: config.get("sepp_refs_gg_13_8_url")
    shell:
        """
        mkdir -p {OUTDIR}/refs
        if [ "{params.db}" = "gg-13-8" ]; then
            wget -O "{output}" "{params.gg}"
        else
            wget -O "{output}" "{params.silva}"
        fi
        """

rule sepp_tree:
    input:
        reps=os.path.join(OUTDIR, "qiime2", "merged", "merged_repseqs.qza"),
        refs=rules.download_sepp_refs.output
    output:
        tree=os.path.join(OUTDIR, "qiime2", "merged", "sepp_tree.qza"),
        placements=os.path.join(OUTDIR, "qiime2", "merged", "sepp_placements.qza")
    conda:
        "envs/qiime2.yml"
    run:
        if not bool(config.get("run_sepp", True)):
            shell(f"mkdir -p {OUTDIR}/qiime2/merged && touch {output.tree} {output.placements}")
            return
        shell(f"""
        mkdir -p {OUTDIR}/qiime2/merged
        qiime fragment-insertion sepp \
          --i-representative-sequences "{input.reps}" \
          --i-reference-database "{input.refs}" \
          --p-threads {int(config.get('sepp_threads', 8))} \
          --p-alignment-subset-size {int(config.get('sepp_alignment_subset_size', 1000))} \
          --p-placement-subset-size {int(config.get('sepp_placement_subset_size', 5000))} \
          --o-tree "{output.tree}" \
          --o-placements "{output.placements}" \
          --verbose
        """)

rule filter_table_by_sepp:
    input:
        table=os.path.join(OUTDIR, "qiime2", "merged", "merged_table.qza"),
        tree=os.path.join(OUTDIR, "qiime2", "merged", "sepp_tree.qza")
    output:
        os.path.join(OUTDIR, "qiime2", "merged", "filtered_table_merged.qza")
    conda:
        "envs/qiime2.yml"
    run:
        if not bool(config.get("run_sepp", True)):
            shell(f"cp {input.table} {output}")
            return
        shell(f"""
        qiime fragment-insertion filter-features \
          --i-table "{input.table}" \
          --i-tree "{input.tree}" \
          --o-filtered-table "{output}" \
          --o-removed-table "{OUTDIR}/qiime2/merged/removed_table_merged.qza"
        """)

rule merged_taxa_barplot:
    input:
        table=os.path.join(OUTDIR, "qiime2", "merged", "filtered_table_merged.qza"),
        tax=os.path.join(OUTDIR, "qiime2", "merged", "taxonomy_merged_vsearch.qza"),
        meta=metadata_path()
    output:
        os.path.join(OUTDIR, "qiime2", "merged", "filtered_taxa_merged.qzv")
    conda:
        "envs/qiime2.yml"
    shell:
        """
        qiime taxa barplot \
          --i-table "{input.table}" \
          --i-taxonomy "{input.tax}" \
          --m-metadata-file "{input.meta}" \
          --o-visualization "{output}"
        """
