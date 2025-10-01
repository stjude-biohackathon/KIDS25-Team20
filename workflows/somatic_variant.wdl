# Copyright 2022 NVIDIA CORPORATION & AFFILIATES

version 1.2

import "../tasks/somatic_variant.wdl"

workflow somatic {
    meta {
        Author: "Nvidia Clara Parabricks"
        description: "Calls somatic variants from tumor-normal paired samples using Mutect2 from Parabricks, with optional filtering using a panel of normals."
        outputs: {
            vcf_final_out: "Final Compressed VCF file in .vcf.gz format",
            tbi_final_out: "Index file for the compressed VCF in .tbi format",
        }
    }

    parameter_meta {
        tumor_bam: "Path to input tumor BAM file"
        tumor_bai: "Path to index file for the tumor BAM"
        normal_bam: "Path to input normal BAM file"
        normal_bai: "Path to index file for the normal BAM"
        reftarball: "Path to reference tarball. The tarball should contain the fasta file and its associated index and dictionary files."
        tumor_name: "Sample name for the tumor sample"
        normal_name: "Sample name for the normal sample"
        tumor_bqsr: "Optional- Path to base quality score recalibration file for the tumor sample."
        normal_bqsr: "Optional- Path to base quality score recalibration file for the normal sample."
        pon_vcf: "Optional- Path to panel of normals VCF file."
        pon_tbi: "Optional- Path to index file for the panel of normals VCF."
        pon_file: "Optional- Path to panel of normals file in VCF format."
    }

    input {
        File tumor_bam
        File tumor_bai
        File normal_bam
        File normal_bai
        File reftarball
        String tumor_name
        String normal_name
        File? tumor_bqsr
        File? normal_bqsr
        File? pon_vcf
        File? pon_tbi
        File? pon_file
    }

    Boolean do_pon = defined(pon_vcf)

    if (do_pon) {
        call somatic_variant.mutect2_call as pb_mutect2_pon { input:
            tumor_bam = tumor_bam,
            tumor_bai = tumor_bai,
            tumor_name = tumor_name,
            normal_bam = normal_bam,
            normal_bai = normal_bai,
            normal_name = normal_name,
            reftarball = reftarball,
            pon_file = pon_file,
            pon_vcf = pon_vcf,
            pon_tbi = pon_tbi,
        }
        call somatic_variant.mutect2_postpon { input:
            vcf_in = pb_mutect2_pon.vcf_out,
            pon_file = select_first([
                pon_file,
            ]),
            pon_vcf = select_first([
                pon_vcf,
            ]),
            pon_tbi = select_first([
                pon_tbi,
            ]),
        }
    }

    if (!do_pon) {
        call somatic_variant.mutect2_call as pb_mutect2_without_pon { input:
            tumor_bam = tumor_bam,
            tumor_bai = tumor_bai,
            tumor_name = tumor_name,
            normal_bam = normal_bam,
            normal_bai = normal_bai,
            normal_name = normal_name,
            reftarball = reftarball,
        }
    }

    File? to_compress_vcf = if do_pon then select_first([
        mutect2_postpon.vcf_annot,
    ]) else pb_mutect2_without_pon.vcf_out

    call somatic_variant.compress_and_index_vcf { input: vcf_in = select_first([
        to_compress_vcf,
    ]) }

    output {
        File vcf_final_out = compress_and_index_vcf.vcf_out2
        File tbi_final_out = compress_and_index_vcf.tbi_out2
    }
}
