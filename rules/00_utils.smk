# Shared utility rule(s) used across modules

rule ensure_outdir:
    output:
        directory(OUTDIR)
    shell:
        "mkdir -p {output}"
