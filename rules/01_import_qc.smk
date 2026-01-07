rule validate_manifest:
    input:
        manifest=manifest_path()
    output:
        fixed=os.path.join(OUTDIR, "intermediate", "manifest_fixed.tsv")
    conda:
        "envs/qiime2.yml"
    shell:
        """
        python scripts/validate_manifest.py "{input.manifest}" "{output.fixed}"
        """

rule validate_metadata:
    input:
        fixed=rules.validate_manifest.output.fixed,
        # meta_ok=rules.validate_metadata.output,
        meta=metadata_path()
    output:
        touch(os.path.join(OUTDIR, "intermediate", "metadata.validated"))
    conda:
        "envs/qiime2.yml"
    shell:
        """
        python scripts/validate_metadata.py "{input.fixed}" "{input.meta}"
        touch "{output}"
        """

rule qiime_import:
    input:
        fixed=rules.validate_manifest.output.fixed
        meta_ok=rules.validate_metadata.output
    output:
        os.path.join(OUTDIR, "qiime2", "paired-end-demux.qza")
    conda:
        "envs/qiime2.yml"
    shell:
        """
        mkdir -p {OUTDIR}/qiime2
        qiime tools import \
          --type 'SampleData[PairedEndSequencesWithQuality]' \
          --input-path "{input.fixed}" \
          --output-path "{output}" \
          --input-format PairedEndFastqManifestPhred33V2
        """

rule demux_summarize:
    input:
        os.path.join(OUTDIR, "qiime2", "paired-end-demux.qza")
    output:
        os.path.join(OUTDIR, "qiime2", "paired-end-demux.qzv")
    conda:
        "envs/qiime2.yml"
    shell:
        """
        qiime demux summarize \
          --i-data "{input}" \
          --o-visualization "{output}"
        """

rule fastqc_multiqc:
    input:
        fixed=rules.validate_manifest.output.fixed
    output:
        os.path.join(OUTDIR, "qc", "multiqc", "multiqc_report.html")
    conda:
        "envs/qc.yml"
    run:
        if not bool(config.get("run_qc", True)):
            shell(f"mkdir -p {OUTDIR}/qc/multiqc && echo 'QC disabled' > {output}")
            return
        qc_threads = int(config.get("qc_threads", 3))
        shell(f"""
        mkdir -p {OUTDIR}/qc/fastqc {OUTDIR}/qc/multiqc
        awk 'NR>1 && $1!~/^#/{{print $2"\n"$3}}' "{input.fixed}" | while read f; do
          [ -z "$f" ] && continue
          fastqc -t {qc_threads} -o {OUTDIR}/qc/fastqc "$f"
        done
        multiqc {OUTDIR}/qc/fastqc -o {OUTDIR}/qc/multiqc
        """)
