rule cutadapt_trim_paired:
    input:
        demux=os.path.join(OUTDIR, "qiime2", "paired-end-demux.qza")
    output:
        os.path.join(OUTDIR, "qiime2", "regions", "{region}", "demux_trim.qza")
    conda:
        "../envs/qiime2.yml"
    params:
        cores=lambda wc: int(config.get("cores", 8)),
        discard=lambda wc: "--p-discard-untrimmed" if bool(config.get("discard_untrimmed", True)) else ""
    run:
        r = get_region(wildcards.region)
        adapter_f = config.get("adapter_f", "") or ""
        adapter_r = config.get("adapter_r", "") or ""
        adapter_args = ""
        if adapter_f and adapter_r:
            adapter_args = f'--p-adapter-f "{adapter_f}" --p-adapter-r "{adapter_r}"'
        shell(f"""
        mkdir -p {OUTDIR}/qiime2/regions/{wildcards.region}
        qiime cutadapt trim-paired \
          --i-demultiplexed-sequences "{input.demux}" \
          --p-cores {params.cores} \
          --p-front-f "{r['fwd']}" \
          --p-front-r "{r['rev']}" \
          {adapter_args} \
          {params.discard} \
          --o-trimmed-sequences "{output}" \
          --verbose
        """)

rule dada2_denoise_paired:
    input:
        os.path.join(OUTDIR, "qiime2", "regions", "{region}", "demux_trim.qza")
    output:
        table=os.path.join(OUTDIR, "qiime2", "regions", "{region}", "table.qza"),
        repseqs=os.path.join(OUTDIR, "qiime2", "regions", "{region}", "repseqs.qza"),
        stats=os.path.join(OUTDIR, "qiime2", "regions", "{region}", "stats.qza")
    conda:
        "../envs/qiime2.yml"
    run:
        r = get_region(wildcards.region)
        shell(f"""
        qiime dada2 denoise-paired \
          --i-demultiplexed-seqs "{input}" \
          --p-trunc-len-f {int(r.get('trunc_f', 0))} \
          --p-trunc-len-r {int(r.get('trunc_r', 0))} \
          --o-table "{output.table}" \
          --o-representative-sequences "{output.repseqs}" \
          --o-denoising-stats "{output.stats}"
        """)
