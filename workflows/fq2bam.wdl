# Copyright 2021 NVIDIA CORPORATION & AFFILIATES

version 1.2

import "../tasks/fq2bam.wdl" as tasks

workflow fq2bam {
    meta {
        description: "Converts FASTQ files to BAM files using Parabricks fq2bam."
        Author: "KIDS25-hackathon/Team-20"
        outputs: {
            bam_output: "BAM format file",
            bai_output: "BAM index file",
            bqsr_output: "Optional BQSR report file",
        }
    }

    parameter_meta {
        fastq_1: " FASTQ input file (R1)"
        fastq_2: " FASTQ input file (R2)"
        read_group_sample_name: "Read group sample name"
        read_group_library_name: "Read group library name"
        read_group_id: "Read group ID"
        read_group_platform_name: "Read group platform name"
        ref_tarball: "Reference tarball containing bwa index files"
        known_sites_vcf: "Optional known sites VCF file for BQSR"
        known_sites_tbi: "Optional index file for known sites VCF"
        use_best_practices: "Enable GATK best practices workflow??"
        tmp_dir: "Temporary directory for intermediate files"
    }

    input {
        File fastq_1
        File fastq_2
        #String read_group_pu = "Barcode1"
        File ref_tarball
        File? known_sites_vcf
        File? known_sites_tbi
        String read_group_sample_name = "SAMPLE"
        String read_group_library_name = "LIB1"
        String read_group_id = "RG1"
        String read_group_platform_name = "ILMN"
        #Boolean low_memory = true
        String tmp_dir = "tmp_fq2bam"
        Boolean use_best_practices = false
    }

    call tasks.fq2bam { input:
        fastq_1 = fastq_1,
        fastq_2 = fastq_2,
        ref_tarball = ref_tarball,
        known_sites_vcf = known_sites_vcf,
        known_sites_tbi = known_sites_tbi,
        use_best_practices = use_best_practices,
        read_group_sample_name = read_group_sample_name,
        read_group_library_name = read_group_library_name,
        read_group_id = read_group_id,
        read_group_platform_name = read_group_platform_name,
        tmp_dir = tmp_dir,
    }

    output {
        File bam = fq2bam.bam
        File bai = fq2bam.bai
        File? bqsr = fq2bam.bqsr
    }
}
