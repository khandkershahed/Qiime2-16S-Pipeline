rule alpha_rarefaction:
    input:
        table=os.path.join(OUTDIR, "qiime2", "merged", "filtered_table_merged.qza"),
        tree=os.path.join(OUTDIR, "qiime2", "merged", "sepp_tree.qza"),
        meta=metadata_path()
    output:
        os.path.join(OUTDIR, "qiime2", "diversity", "alpha-rarefaction.qzv")
    params:
        max_depth=lambda wc: int(config.get("alpha_max_depth", 50000))
    conda:
        "../envs/qiime2.yml"
    shell:
        """
        mkdir -p "{OUTDIR}/qiime2/diversity"
        qiime diversity alpha-rarefaction \
            --i-table "{input.table}" \
            --i-phylogeny "{input.tree}" \
            --p-max-depth {params.max_depth} \
            --m-metadata-file "{input.meta}" \
            --o-visualization "{output}" \
            --verbose
        """


rule core_metrics:
    input:
        table=os.path.join(OUTDIR, "qiime2", "merged", "filtered_table_merged.qza"),
        tree=os.path.join(OUTDIR, "qiime2", "merged", "sepp_tree.qza"),
        meta=metadata_path()
    output:
        # Marker output expected by rule all (one file inside the core-metrics dir)
        os.path.join(OUTDIR, "qiime2", "diversity", "core-metrics", "bray_curtis_distance_matrix.qza")
    params:
        depth=lambda wc: int(config.get("sampling_depth", 550))
    conda:
        "../envs/qiime2.yml"
    shell:
        """
        mkdir -p "{OUTDIR}/qiime2/diversity/core-metrics"
        qiime diversity core-metrics-phylogenetic \
            --i-table "{input.table}" \
            --i-phylogeny "{input.tree}" \
            --p-sampling-depth {params.depth} \
            --m-metadata-file "{input.meta}" \
            --output-dir "{OUTDIR}/qiime2/diversity/core-metrics" \
            --verbose
        """
