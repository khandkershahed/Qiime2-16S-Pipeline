rule alpha_rarefaction:
    input:
        table=os.path.join(OUTDIR, "qiime2", "merged", "filtered_table_merged.qza"),
        tree=os.path.join(OUTDIR, "qiime2", "merged", "sepp_tree.qza"),
        meta=metadata_path()
    output:
        os.path.join(OUTDIR, "qiime2", "diversity", "alpha_rarefaction.qzv")
    conda:
        "envs/qiime2.yml"
    shell:
        """
        mkdir -p {OUTDIR}/qiime2/diversity
        qiime diversity alpha-rarefaction \
          --i-table "{input.table}" \
          --i-phylogeny "{input.tree}" \
          --p-max-depth {int(config.get('alpha_max_depth', 50000))} \
          --m-metadata-file "{input.meta}" \
          --o-visualization "{output}"
        """

rule core_metrics:
    input:
        table=os.path.join(OUTDIR, "qiime2", "merged", "filtered_table_merged.qza"),
        tree=os.path.join(OUTDIR, "qiime2", "merged", "sepp_tree.qza"),
        meta=metadata_path()
    output:
        dist_bray=os.path.join(OUTDIR, "qiime2", "diversity", "core-metrics", "bray_curtis_distance_matrix.qza")
    conda:
        "envs/qiime2.yml"
    shell:
        """
        mkdir -p {OUTDIR}/qiime2/diversity/core-metrics
        qiime diversity core-metrics-phylogenetic \
          --i-table "{input.table}" \
          --i-phylogeny "{input.tree}" \
          --p-sampling-depth {int(config.get('sampling_depth', 550))} \
          --m-metadata-file "{input.meta}" \
          --output-dir "{OUTDIR}/qiime2/diversity/core-metrics" \
          --verbose
        """
