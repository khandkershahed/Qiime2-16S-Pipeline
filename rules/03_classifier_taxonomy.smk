rule download_references:
    output:
        seqs=os.path.join(OUTDIR, "refs", "ref_seqs.qza"),
        tax=os.path.join(OUTDIR, "refs", "ref_tax.qza")
    params:
        db_choice=lambda wc: str(config.get("ref_database", "silva")).lower(),
        s_seq=lambda wc: config.get("silva_seqs_url"),
        s_tax=lambda wc: config.get("silva_tax_url"),
        g_seq=lambda wc: config.get("gg_seqs_url"),
        g_tax=lambda wc: config.get("gg_tax_url")
    conda:
        "envs/qiime2.yml"
    shell:
        """
        mkdir -p {OUTDIR}/refs
        if [ "{params.db_choice}" = "greengenes" ]; then
            wget -O "{output.seqs}" "{params.g_seq}"
            wget -O "{output.tax}"  "{params.g_tax}"
        else
            wget -O "{output.seqs}" "{params.s_seq}"
            wget -O "{output.tax}"  "{params.s_tax}"
        fi
        """

rule extract_reads:
    input:
        seqs=rules.download_references.output.seqs
    output:
        os.path.join(OUTDIR, "classifiers", "{region}", "ref_seqs_extracted.qza")
    conda:
        "envs/qiime2.yml"
    run:
        r = get_region(wildcards.region)
        min_l = int(r.get("min_len", config["classifier_defaults"]["min_length"]))
        max_l = int(r.get("max_len", config["classifier_defaults"]["max_length"]))
        shell(f"""
        mkdir -p {OUTDIR}/classifiers/{wildcards.region}
        qiime feature-classifier extract-reads \
            --i-sequences "{input.seqs}" \
            --p-f-primer "{r['fwd']}" \
            --p-r-primer "{r['rev']}" \
            --p-min-length {min_l} \
            --p-max-length {max_l} \
            --o-reads "{output}"
        """)

rule train_classifier:
    input:
        reads=os.path.join(OUTDIR, "classifiers", "{region}", "ref_seqs_extracted.qza"),
        tax=rules.download_references.output.tax
    output:
        os.path.join(OUTDIR, "classifiers", "{region}", "classifier.qza")
    conda:
        "envs/qiime2.yml"
    run:
        train_ok = bool(config.get("run_classifier_training", True))
        pretrained_dir = (config.get("classifier_pretrained_dir", "") or "").strip()
        region = wildcards.region

        if pretrained_dir:
            candidate = os.path.join(pretrained_dir, region, "classifier.qza")
            if not os.path.exists(candidate):
                raise FileNotFoundError(f"Pretrained classifier not found: {candidate}")
            shell(f'mkdir -p {OUTDIR}/classifiers/{region} && cp "{candidate}" "{output}"')
            return

        if not train_ok:
            raise ValueError("run_classifier_training is false but classifier_pretrained_dir is empty. Provide pretrained classifiers or enable training.")

        shell(f"""
        qiime feature-classifier fit-classifier-naive-bayes \
            --i-reference-reads "{input.reads}" \
            --i-reference-taxonomy "{input.tax}" \
            --o-classifier "{output}"
        """)

rule classify_region:

    input:
        reps=os.path.join(OUTDIR, "qiime2", "regions", "{region}", "repseqs.qza"),
        classifier=os.path.join(OUTDIR, "classifiers", "{region}", "classifier.qza")
    output:
        os.path.join(OUTDIR, "qiime2", "regions", "{region}", "taxonomy.qza")
    conda:
        "envs/qiime2.yml"
    shell:
        """
        qiime feature-classifier classify-sklearn \
            --i-classifier "{input.classifier}" \
            --i-reads "{input.reps}" \
            --o-classification "{output}"
        """

rule taxa_barplot_region:
    input:
        table=os.path.join(OUTDIR, "qiime2", "regions", "{region}", "table.qza"),
        tax=os.path.join(OUTDIR, "qiime2", "regions", "{region}", "taxonomy.qza"),
        meta=metadata_path()
    output:
        os.path.join(OUTDIR, "qiime2", "regions", "{region}", "taxa-barplot.qzv")
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
