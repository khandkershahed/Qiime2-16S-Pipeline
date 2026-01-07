rule gemelli_rpca_unrarefied:
    input:
        table=os.path.join(OUTDIR, "qiime2", "merged", "filtered_table_merged.qza")
    output:
        biplot=os.path.join(OUTDIR, "qiime2", "gemelli", "ordination_unrarefied.qza"),
        dist=os.path.join(OUTDIR, "qiime2", "gemelli", "distance_unrarefied.qza")
    conda:
        "../envs/qiime2.yml"
    run:
        if not bool(config.get("run_gemelli", True)):
            shell(f"mkdir -p {OUTDIR}/qiime2/gemelli && touch {output.biplot} {output.dist}")
            return
        shell(f"""
        mkdir -p {OUTDIR}/qiime2/gemelli
        qiime gemelli rpca \
          --i-table "{input.table}" \
          --p-min-feature-frequency {int(config.get('gemelli_min_feature_frequency', 1))} \
          --o-biplot "{output.biplot}" \
          --o-distance-matrix "{output.dist}"
        """)

rule rarefy_table:
    input:
        table=os.path.join(OUTDIR, "qiime2", "merged", "filtered_table_merged.qza")
    output:
        os.path.join(OUTDIR, "qiime2", "gemelli", "rarefied_table.qza")
    conda:
        "../envs/qiime2.yml"
    run:
        if not bool(config.get("run_gemelli", True)):
            shell(f"mkdir -p {OUTDIR}/qiime2/gemelli && touch {output}")
            return
        shell(f"""
        mkdir -p {OUTDIR}/qiime2/gemelli
        qiime feature-table rarefy \
          --i-table "{input.table}" \
          --p-sampling-depth {int(config.get('sampling_depth', 550))} \
          --o-rarefied-table "{output}"
        """)

rule gemelli_rpca_rarefied:
    input:
        table=rules.rarefy_table.output
    output:
        biplot=os.path.join(OUTDIR, "qiime2", "gemelli", "ordination_rarefied.qza"),
        dist=os.path.join(OUTDIR, "qiime2", "gemelli", "distance_rarefied.qza")
    conda:
        "../envs/qiime2.yml"
    run:
        if not bool(config.get("run_gemelli", True)):
            shell(f"touch {output.biplot} {output.dist}")
            return
        shell(f"""
        qiime gemelli rpca \
          --i-table "{input.table}" \
          --p-min-feature-frequency {int(config.get('gemelli_min_feature_frequency', 1))} \
          --o-biplot "{output.biplot}" \
          --o-distance-matrix "{output.dist}"
        """)

rule gemelli_qc_rarefy:
    input:
        table=os.path.join(OUTDIR, "qiime2", "merged", "filtered_table_merged.qza"),
        rarefied=rules.gemelli_rpca_rarefied.output.dist,
        unrarefied=rules.gemelli_rpca_unrarefied.output.dist
    output:
        os.path.join(OUTDIR, "qiime2", "gemelli", "rarefy_qc.qzv")
    conda:
        "../envs/qiime2.yml"
    run:
        if not bool(config.get("run_gemelli", True)):
            shell(f"touch {output}")
            return
        shell(f"""
        qiime gemelli qc-rarefy \
          --i-table "{input.table}" \
          --i-rarefied-distance "{input.rarefied}" \
          --i-unrarefied-distance "{input.unrarefied}" \
          --o-visualization "{output}"
        """)

rule rpca_biplot:
    input:
        biplot=rules.gemelli_rpca_unrarefied.output.biplot,
        meta=metadata_path()
    output:
        os.path.join(OUTDIR, "qiime2", "gemelli", "rpca_biplot.qzv")
    conda:
        "../envs/qiime2.yml"
    run:
        if not bool(config.get("run_gemelli", True)):
            shell(f"touch {output}")
            return
        shell(f"""
        qiime emperor biplot \
          --i-biplot "{input.biplot}" \
          --m-sample-metadata-file "{input.meta}" \
          --o-visualization "{output}"
        """)

rule permanova_adonis:
    input:
        dist=rules.gemelli_rpca_unrarefied.output.dist,
        meta=metadata_path()
    output:
        os.path.join(OUTDIR, "qiime2", "stats", "rpca_permanova.qzv")
    conda:
        "../envs/qiime2.yml"
    run:
        if not bool(config.get("run_gemelli", True)):
            shell(f"mkdir -p {OUTDIR}/qiime2/stats && touch {output}")
            return
        shell(f"""
        mkdir -p {OUTDIR}/qiime2/stats
        qiime diversity adonis \
          --i-distance-matrix "{input.dist}" \
          --m-metadata-file "{input.meta}" \
          --p-formula "{config.get('permanova_formula', 'Group')}" \
          --p-permutations {int(config.get('permutations', 999))} \
          --o-visualization "{output}"
        """)

rule beta_group_significance:
    input:
        dist=rules.gemelli_rpca_unrarefied.output.dist,
        meta=metadata_path()
    output:
        os.path.join(OUTDIR, "qiime2", "stats", "beta_group_significance.qzv")
    conda:
        "../envs/qiime2.yml"
    run:
        if not bool(config.get("run_gemelli", True)):
            shell(f"mkdir -p {OUTDIR}/qiime2/stats && touch {output}")
            return
        shell(f"""
        mkdir -p {OUTDIR}/qiime2/stats
        qiime diversity beta-group-significance \
          --i-distance-matrix "{input.dist}" \
          --m-metadata-file "{input.meta}" \
          --m-metadata-column "{config.get('beta_group_column', 'Group')}" \
          --p-method permanova \
          --p-permutations {int(config.get('permutations', 999))} \
          --o-visualization "{output}"
        """)

rule qurro_plot:
    input:
        ranks=rules.gemelli_rpca_unrarefied.output.biplot,
        table=os.path.join(OUTDIR, "qiime2", "merged", "filtered_table_merged.qza"),
        meta=metadata_path(),
        tax=os.path.join(OUTDIR, "qiime2", "merged", "taxonomy_merged_vsearch.qza")
    output:
        os.path.join(OUTDIR, "qiime2", "qurro", "qurro_plot.qzv")
    conda:
        "../envs/qiime2.yml"
    run:
        if not bool(config.get("run_qurro", True)):
            shell(f"mkdir -p {OUTDIR}/qiime2/qurro && touch {output}")
            return
        shell(f"""
        mkdir -p {OUTDIR}/qiime2/qurro
        qiime qurro loading-plot \
          --i-ranks "{input.ranks}" \
          --i-table "{input.table}" \
          --m-sample-metadata-file "{input.meta}" \
          --m-feature-metadata-file "{input.tax}" \
          --o-visualization "{output}"
        """)

