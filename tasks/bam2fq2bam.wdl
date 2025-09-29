# Copyright 2021 NVIDIA CORPORATION & AFFILIATES
version 1.2

import "https://raw.githubusercontent.com/clara-parabricks-workflows/parabricks-wdl/main/wdl/fq2bam.wdl"
    as ToBam

task bam2fq {
    meta {
        Author: "Nvidia Clara Parabricks"
        description: "Convert a BAM file into a pair of FASTQ files"
        outputs: {
            fastq_1: "Output FASTQ file, 1st read",
            fastq_2: "Output FASTQ file, 2nd read",
        }
    }

    parameter_meta {
        file_bam: "Path to the BAM file"
        file_bai: "Path to the BAM index file"
        original_ref_tarball: "Original reference tarball. Required for CRAM input."
        pb_license_bin: "Path to the Parabricks license binary"
        ref: "Name of FASTA reference file, required for CRAM input"
        pb_path: "Parabricks command pbrun"
        pb_docker: "The docker image to use for the task"
        hpc_queue: ""
        n_threads: "Number of threads to use; default 16"
        gb_ram: "GB of RAM to use; default 120"
        disk_gb: "GB of disk space to use; default 0"
        runtime_minutes: "Runtime minutes, set to 600"
    }

    input {
        File file_bam
        File file_bai
        File? original_ref_tarball
        File? pb_license_bin
        String? ref
        String pb_path = "pbrun"
        String pb_docker = "nvcr.io/nvidia/clara/clara-parabricks:4.3.0-1"
        String hpc_queue = "gpu"
        Int n_threads = 16
        Int gb_ram = 120
        Int disk_gb = 0
        Int runtime_minutes = 600
    }

    String outbase = basename(file_bam, ".bam")

    Int auto_disk_gb = if disk_gb == 0 then ceil(5.0 * size(file_bam, "GB")) + ceil(size(
        file_bai, "GB")) + 100 else disk_gb

    command <<<
        ~{"tar xvf " + original_ref_tarball + " && "} \
        time ~{pb_path} bam2fq \
            --in-bam ~{file_bam} \
            --out-prefix ~{outbase} \
            ~{"--license-file " + pb_license_bin} \
            ~{"--ref " + ref} \
    >>>

    output {
        File fastq_1 = "~{outbase}_1.fastq.gz"
        File fastq_2 = "~{outbase}_2.fastq.gz"
    }

    requirements {
        container: "~{pb_docker}"
        disks: "local-disk ~{auto_disk_gb} SSD"
        cpu: n_threads
        memory: "~{gb_ram} GB"
    }

    hints {
        hpc_memory: gb_ram
        hpc_queue: "~{hpc_queue}"
        hpc_runtime_minutes: runtime_minutes
        zones: [
            "us-central1-a",
            "us-central1-b",
            "us-central1-c",
        ]
        preemptible: 3
    }
}

workflow clara_parabricks_bam2fq2bam {
    meta {
        Author: "Nvidia Clara Parabricks"
        description: "Extract FASTQ files from a BAM file and realign them to produce a new BAM file on a different reference. Given a BAM file, extract the reads from it and realign them to a new reference genome. Expected runtime for a 30X BAM is less than 3 hours on a 4x V100 system. We recommend running with at least 32 threads and 4x V100 GPUs on Baremetal and utilizing 4x T4s on the cloud."
        outputs: {
            fastq_1: "Output FASTQ file, 1st read",
            fastq_2: "Output FASTQ file, 2nd read",
            file_bam: "Output BAM file",
            file_bai: "Output BAM index file",
            file_bqsr: "Output BQSR file",
        }
    }

    parameter_meta {
        file_bam: "Path to the BAM file"
        file_bai: "Path to the BAM index file"
        ref_tarball: ""
        known_sites_vcf: ""
        known_sites_tbi: ""
        original_ref_tarball: "Original reference tarball. Required for CRAM input."
        pb_license_bin: "Path to the Parabricks license binary"
        pb_path: "Parabricks command pbrun"
        pb_docker: "The docker image to use for the task"
        tmp_dir: ""
        gpu_model_fq_2_bam: ""
        gpu_driver_version_fq_2_bam: ""
        hpc_queue_bam_2_fq: ""
        hpc_queue_fq_2_bam: ""
        n_gpu_fq_2_bam: ""
        n_threads_bam_2_fq: "Number of threads to use; ..."
        n_threads_fq_2_bam: "Number of threads to use; ..."
        gb_ram_bam_2_fq: "GB of RAM to use; ..."
        gb_ram_fq_2_bam: "GB of RAM to use; ..."
        disk_gb: "GB of disk space to use; default 0"
        runtime_minutes_bam_2_fq: "Runtime minutes, ..."
        runtime_minutes_fq_2_bam: "Runtime minutes, ..."
    }

    input {
        File file_bam
        File file_bai
        File ref_tarball
        File? known_sites_vcf
        File? known_sites_tbi
        File? original_ref_tarball  # for CRAM input
        File? pb_license_bin
        String pb_path = "pbrun"
        String pb_docker = "nvcr.io/nvidia/clara/clara-parabricks:4.3.0-1"
        String tmp_dir = "tmp_fq2bam"
        String gpu_model_fq_2_bam = "nvidia-tesla-t4"
        String gpu_driver_version_fq_2_bam = "525.60.13"
        String hpc_queue_bam_2_fq = "norm"
        String hpc_queue_fq_2_bam = "gpu"
        Int n_gpu_fq_2_bam = 4
        Int n_threads_bam_2_fq = 16
        Int n_threads_fq_2_bam = 32
        Int gb_ram_bam_2_fq = 120
        Int gb_ram_fq_2_bam = 180
        Int disk_gb = 0
        Int runtime_minutes_bam_2_fq = 600
        Int runtime_minutes_fq_2_bam = 600
    }

    if (defined(original_ref_tarball)) {
        String ref = basename(select_first([
            original_ref_tarball,
        ]), ".tar")
    }

    # Run the BAM -> FASTQ conversion
    call bam2fq { input:
        file_bam = file_bam,
        file_bai = file_bai,
        original_ref_tarball = original_ref_tarball,
        ref = ref,
        pb_path = pb_path,
        pb_license_bin = pb_license_bin,
        n_threads = n_threads_bam_2_fq,
        gb_ram = gb_ram_bam_2_fq,
        runtime_minutes = runtime_minutes_bam_2_fq,
        hpc_queue = hpc_queue_bam_2_fq,
        disk_gb = disk_gb,
        pb_docker = pb_docker,
    }

    # Remap the reads from the bam2fq stage to the new reference to produce a BAM file.
    call ToBam.fq2bam as fq2bam { input:
        fastq_1 = bam2fq.fastq_1,
        fastq_2 = bam2fq.fastq_2,
        ref_tarball = ref_tarball,
        known_sites_vcf = known_sites_vcf,
        known_sites_tbi = known_sites_tbi,
        pb_license_bin = pb_license_bin,
        pb_path = pb_path,
        n_gpu = n_gpu_fq_2_bam,
        n_threads = n_threads_fq_2_bam,
        gb_ram = gb_ram_fq_2_bam,
        runtime_minutes = runtime_minutes_fq_2_bam,
        gpu_model = gpu_model_fq_2_bam,
        gpu_driver_version = gpu_driver_version_fq_2_bam,
        disk_gb = disk_gb,
        tmp_dir = tmp_dir,
        hpc_queue = hpc_queue_fq_2_bam,
        pb_docker = pb_docker,
    }

    output {
        File fastq_1 = bam2fq.fastq_1
        File fastq_2 = bam2fq.fastq_2
        File file_bam = fq2bam.file_bam
        File file_bai = fq2bam.file_bai
        File? file_bqsr = fq2bam.file_bqsr
    }
}
