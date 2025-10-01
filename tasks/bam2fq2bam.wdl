# Copyright 2021 NVIDIA CORPORATION & AFFILIATES

version 1.2

task bam2fq {
    parameter_meta {
        file_bam: "Path to the BAM file"
        file_bai: "Path to the BAM index file"
        original_ref_tarball: "Original reference tarball. Required for CRAM input."
        pb_license_bin: "Path to the Parabricks license binary"
        ref: "Name of FASTA reference file, required for CRAM input"
        pb_path: "Parabricks command pbrun"
        pb_docker: "The docker image to use for the task"
        hpc_queue: "foobar"
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
        String pb_docker = "nvcr.io/nvidia/clara/clara-parabricks:4.5.1-1"
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
        gpu: true
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
