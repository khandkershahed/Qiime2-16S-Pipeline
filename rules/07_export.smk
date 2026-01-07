rule export_repseqs_fasta:
    input:
        reps=os.path.join(OUTDIR, "qiime2", "merged", "merged_repseqs.qza")
    output:
        os.path.join(OUTDIR, "export", "dna-sequences.fasta")
    conda:
        "envs/qiime2.yml"
    shell:
        """
        mkdir -p {OUTDIR}/export/_temp_fasta
        qiime tools export \
          --input-path "{input.reps}" \
          --output-path "{OUTDIR}/export/_temp_fasta"
        cp "{OUTDIR}/export/_temp_fasta/dna-sequences.fasta" "{output}"
        rm -rf "{OUTDIR}/export/_temp_fasta"
        """

rule export_all:
    input:
        table=os.path.join(OUTDIR, "qiime2", "merged", "filtered_table_merged.qza"),
        tax=os.path.join(OUTDIR, "qiime2", "merged", "taxonomy_merged_vsearch.qza"),
        tree=os.path.join(OUTDIR, "qiime2", "merged", "sepp_tree.qza")
    output:
        table_tsv=os.path.join(OUTDIR, "export", "feature-table.tsv"),
        tax_tsv=os.path.join(OUTDIR, "export", "taxonomy.tsv"),
        tree_nwk=os.path.join(OUTDIR, "export", "tree.nwk")
    conda:
        "envs/qiime2.yml"
    shell:
        """
        mkdir -p {OUTDIR}/export

        # Export Table (.biom -> .tsv)
        qiime tools export --input-path "{input.table}" --output-path "{OUTDIR}/export/_temp_table"
        biom convert \
          -i "{OUTDIR}/export/_temp_table/feature-table.biom" \
          -o "{output.table_tsv}" \
          --to-tsv

        # Export Taxonomy
        qiime tools export --input-path "{input.tax}" --output-path "{OUTDIR}/export/_temp_tax"
        cp "{OUTDIR}/export/_temp_tax/taxonomy.tsv" "{output.tax_tsv}"

        # Export Tree
        qiime tools export --input-path "{input.tree}" --output-path "{OUTDIR}/export/_temp_tree"
        cp "{OUTDIR}/export/_temp_tree/tree.nwk" "{output.tree_nwk}"

        rm -rf "{OUTDIR}/export/_temp_table" "{OUTDIR}/export/_temp_tax" "{OUTDIR}/export/_temp_tree"
        """
