# Copyright 2021 NVIDIA CORPORATION & AFFILIATES

version 1.2

import "./fq2bam.wdl"
import "../tasks/bam2fq2bam.wdl"

workflow bam2fq2bam {
    input {
        File file_bam
        File file_bai
        File ref_tarball
        File? known_sites_vcf
        File? known_sites_tbi
        File? original_ref_tarball  # for CRAM input
        String tmp_dir = "tmp_fq2bam"
    }

    if (defined(original_ref_tarball)) {
        String ref = basename(select_first([
            original_ref_tarball,
        ]), ".tar")
    }

    # Run the BAM -> FASTQ conversion
    call bam2fq2bam.bam2fq { input:
        file_bam = file_bam,
        file_bai = file_bai,
        original_ref_tarball = original_ref_tarball,
        ref = ref
    }

    # Remap the reads from the bam2fq stage to the new reference to produce a BAM file.
    call fq2bam.fq2bam as fq2bam { input:
        fastq_1 = bam2fq.fastq_1,
        fastq_2 = bam2fq.fastq_2,
        ref_tarball = ref_tarball,
        known_sites_vcf = known_sites_vcf,
        known_sites_tbi = known_sites_tbi,
        tmp_dir = tmp_dir,
    }

    output {
        File fastq_1 = bam2fq.fastq_1
        File fastq_2 = bam2fq.fastq_2
        File bam = fq2bam.bam
        File bai = fq2bam.bai
        File? bqsr = fq2bam.bqsr
    }
}
