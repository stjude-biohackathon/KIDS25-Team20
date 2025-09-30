# Copyright 2022 NVIDIA CORPORATION & AFFILIATES
version 1.2

task mutect2_call {
    meta {
        Author: "Nvidia Clara Parabricks"
        description: "Runs Mutect2 from Parabricks to call somatic variants from tumor-normal paired samples."
        outputs: {
            vcf_out: "Output VCF file",
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
        interval_file: "Optional- Path to interval file to restrict variant calling to specific regions."
        tumor_bqsr: "Optional- Path to base quality score recalibration file for the tumor sample."
        normal_bqsr: "Optional- Path to base quality score recalibration file for the normal sample."
        pon_file: "Optional- Path to panel of normals file in VCF format."
        pon_vcf: "Optional- Path to panel of normals VCF file."
        pon_tbi: "Optional- Path to index file for the panel of normals VCF."
    }

    input {
        File tumor_bam
        File tumor_bai
        File normal_bam
        File normal_bai
        File reftarball
        String tumor_name
        String normal_name
        File? interval_file
        File? tumor_bqsr
        File? normal_bqsr
        File? pon_file
        File? pon_vcf
        File? pon_tbi
    }

    String ref = basename(reftarball, ".tar")
    String outbase = basename(tumor_bam, ".bam") + "." + basename(normal_bam, ".bam") + ".mutectcaller"

    command <<<
        tar xf ~{reftarball} && \

         ~pbrun mutectcaller \
        --ref ~{ref} \
        --tumor-name ~{tumor_name} \
        ~{"--in-tumor-recal-file " + tumor_bqsr} \
        --in-tumor-bam ~{tumor_bam} \
        --normal-name ~{normal_name} \
        --in-normal-bam ~{normal_bam} \
        ~{"--in-normal-recal-file " + normal_bqsr} \
        ~{"--pon " + pon_vcf} \
        ~{"--interval-file " + interval_file} \
        --out-vcf ~{outbase}.vcf
    >>>

    output {
        File vcf_out = "~{outbase}.vcf"
    }

    requirements {
        container: "nvcr.io/nvidia/clara/clara-parabricks:4.3.2-1"
        gpu: true
        cpu: 32
        disks: 500
        memory: "120 GB"
        max_retries: 2
    }

    hints {
        gpu: 1
        nvidiaDriver: "525.60.13"
        nvidiaModel: "nvidia-tesla-t4"
    }
}

task mutect2_postpon {
    meta {
        Author: "Nvidia Clara Parabricks"
        description: "Runs Mutect2 after filtering variants using a panel of normals."
        outputs: {
            vcf_annot: "Annotated Output VCF file",
        }
    }

    parameter_meta {
        vcf_in: "Path to input VCF file from Mutect2"
        pon_file: "Optional- Path to panel of normals file in VCF format."
        pon_vcf: "Optional- Path to panel of normals VCF file."
        pon_tbi: "Optional- Path to index file for the panel of normals VCF."
    }

    input {
        File vcf_in
        File pon_file
        File pon_vcf
        File pon_tbi
    }

    String outbase = basename(basename(vcf_in, ".gz"), ".vcf")

    command <<<
        time ~ pbrun postpon \
        --in-vcf ~{vcf_in} \
        --in-pon-file ~{pon_vcf} \
        --out-vcf ~{outbase}.postpon.vcf
    >>>

    output {
        File vcf_annot = "~{outbase}.postpon.vcf"
    }

    requirements {
        container: "nvcr.io/nvidia/clara/clara-parabricks:4.3.2-1"
        gpu: true
        cpu: 32
        disks: 500
        memory: "120 GB"
        max_retries: 2
    }

    hints {
        gpu: 1
        nvidiaDriver: "525.60.13"
        nvidiaModel: "nvidia-tesla-t4"
    }
}

task compress_and_index_vcf {
    meta {
        Author: "Nvidia Clara Parabricks"
        description: "Use samtools to compress and index VCF files from mutect2 with or without filtering frompanel of normals."
        outputs: {
            vcf_out2: "Compressed VCF file in .vcf.gz format",
            tbi_out2: "Index file for the compressed VCF in .tbi format",
        }
    }

    parameter_meta {
        vcf_in: "Path to input VCF file from Mutect2 witth or without filtering from panel of normals."
        bgzipDocker: "Docker image to use for bgzip and tabix. Default is claraparabricks/samtools."
    }

    input {
        File vcf_in
        String bgzip_docker = "claraparabricks/samtools"
    }

    String local_vcf = basename(vcf_in)

    command <<<
        bgzip -c -@ ~32 ~{vcf_in} > ~{local_vcf}.gz  && \
        tabix ~{local_vcf}.gz
    >>>

    output {
        File vcf_out2 = "~{local_vcf}.gz"
        File tbi_out2 = "~{local_vcf}.gz.tbi"
    }

    requirements {
        container: "nvcr.io/nvidia/clara/clara-parabricks:4.3.2-1"
        gpu: true
        cpu: 32
        disks: 500
        memory: "120 GB"
        max_retries: 2
    }

    hints {
        gpu: 1
        nvidiaDriver: "525.60.13"
        nvidiaModel: "nvidia-tesla-t4"
    }
}

workflow clara_parabricks_somatic {
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
        call mutect2_call as pb_mutect2_pon { input:
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
        call mutect2_postpon { input:
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
        call mutect2_call as pb_mutect2_without_pon { input:
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

    call compress_and_index_vcf { input: vcf_in = select_first([
        to_compress_vcf,
    ]) }

    output {
        File vcf_final_out = compress_and_index_vcf.vcf_out2
        File tbi_final_out = compress_and_index_vcf.tbi_out2
    }
}
