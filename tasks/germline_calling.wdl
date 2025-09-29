version 1.2

task haplotypecaller {
    input {
        File input_bam
        File input_bai
        File? input_recal
        File input_ref_tarball
        String pb_path = "pbrun"
        File? interval_file
        Boolean gvcf_mode = false
        Boolean use_best_practices = false
        String? haplotypecaller_passthrough_options = ""
        String annotation_args = ""

        File? pb_license_bin
        String? pb_docker
        Int n_gpu = 2
        String gpu_model = "nvidia-tesla-t4"
        String gpu_driver_version = "525.60.13"
        Int n_threads = 24
        Int gb_ram = 120
        Int disk_gb = 0
        Int runtime_minutes = 600
        String hpc_queue = "gpu"
        Int max_preempt_attempts = 3
    }

    String outbase = basename(input_bam, ".bam")
    String local_tarball = basename(input_ref_tarball)
    String ref = basename(input_ref_tarball, ".tar")

    Int auto_disk_gb = if disk_gb == 0 then ceil(2.0 * size(input_bam, "GB")) + ceil(2.0 * size(input_ref_tarball, "GB")) + ceil(size(input_bai, "GB")) + 120 else disk_gb

    String out_vcf = outbase + ".haplotypecaller" + (if gvcf_mode then '.g' else '') + ".vcf"

    String quantization_band_stub = if use_best_practices then " -GQB 10 -GQB 20 -GQB 30 -GQB 40 -GQB 50 -GQB 60 -GQB 70 -GQB 80 -GQB 90 " else ""
    String quantization_qual_stub = if use_best_practices then " --static-quantized-quals 10 --static-quantized-quals 20 --static-quantized-quals 30" else ""
    String annotation_stub_base = if use_best_practices then "-G StandardAnnotation -G StandardHCAnnotation" else annotation_args
    String annotation_stub = if use_best_practices && gvcf_mode then annotation_stub_base + " -G AS_StandardAnnotation " else annotation_stub_base

    command <<<
        mv ~{input_ref_tarball} ~{local_tarball} && \
        time tar xvf ~{local_tarball} && \
        time ~{pb_path} haplotypecaller \
        --in-bam ~{input_bam} \
        --ref ~{ref} \
        --out-variants ~{out_vcf} \
        ~{"--in-recal-file " + input_recal} \
        ~{if gvcf_mode then "--gvcf " else ""} \
        ~{"--haplotypecaller-options " + '"' + haplotypecaller_passthrough_options + '"'} \
        ~{annotation_stub} \
        ~{quantization_band_stub} \
        ~{quantization_qual_stub} \
        ~{"--license-file " + pb_license_bin}
    >>>

    output {
        File haplotypecaller_vcf = "~{out_vcf}"
    }

    requirements {
        container : "~{pb_docker}"
        cpu : n_threads
        memory : "~{gb_ram} GB"
        gpu : true
    }

    hints {
        disks : "local-disk ~{auto_disk_gb} SSD"
        gpuType : "~{gpu_model}"
        gpuCount : n_gpu
        nvidiaDriverVersion : "~{gpu_driver_version}"
        hpcMemory : gb_ram
        hpc_queue : "~{hpc_queue}"
        hpcruntime_minutes : runtime_minutes
        zones : ["us-central1-a", "us-central1-b", "us-central1-c"]
        preemptible : max_preempt_attempts
    }
}


task deepvariant {
    input {
        File input_bam
        File input_bai
        File input_ref_tarball
        String pb_path = "pbrun"
        File? pb_license_bin
        String? pb_docker
        Boolean gvcf_mode = false
        Int n_gpu = 4
        String gpu_model = "nvidia-tesla-t4"
        String gpu_driver_version = "525.60.13"
        Int n_threads = 24
        Int gb_ram = 120
        Int disk_gb = 0
        Int runtime_minutes = 600
        String hpc_queue = "gpu"
        Int max_preempt_attempts = 3
    }

    String ref = basename(input_ref_tarball, ".tar")
    String local_tarball = basename(input_ref_tarball)
    String outbase = basename(input_bam, ".bam")

    Int auto_disk_gb = if disk_gb == 0 then ceil(size(input_bam, "GB")) + ceil(size(input_ref_tarball, "GB")) + ceil(size(input_bai, "GB")) + 65 else disk_gb

    String out_vcf = outbase + ".deepvariant" + (if gvcf_mode then '.g' else '') + ".vcf"


    command <<<
        mv ~{input_ref_tarball} ~{local_tarball} && \
        time tar xvf ~{local_tarball} && \
        time ~{pb_path} deepvariant \
        ~{if gvcf_mode then "--gvcf " else ""} \
        --ref ~{ref} \
        --in-bam ~{input_bam} \
        --out-variants ~{out_vcf} \
        ~{"--license-file " + pb_license_bin}
    >>>

    output {
        File deepvariant_vcf = "~{out_vcf}"
    }

    requirements {
        container : "~{pb_docker}"
        cpu : n_threads
        memory : "~{gb_ram} GB"
        gpu: true
    }
    hints {
        disks : "local-disk ~{auto_disk_gb} SSD"
        hpcMemory : gb_ram
        hpc_queue : "~{hpc_queue}"
        hpcruntime_minutes : runtime_minutes
        gpuType : "~{gpu_model}"
        gpuCount : n_gpu
        nvidiaDriverVersion : "~{gpu_driver_version}"
        zones : ["us-central1-a", "us-central1-b", "us-central1-c"]
        preemptible : max_preempt_attempts
    }
}


workflow clara_parabricks_germline {
    input {
        File input_bam
        File input_bai
        File? input_recal
        File input_ref_tarball
        String pb_path = "pbrun"

        File? pb_license_bin
        String pb_docker = "nvcr.io/nvidia/clara/clara-parabricks:4.3.0-1"

        Boolean run_deep_variant = true
        Boolean run_haplotype_caller = true
        ## Run both DeepVariant and haplotype_caller in gVCF mode
        Boolean gvcf_mode = false

        ## Universal preemptible limit
        Int max_preempt_attempts = 3

        ## DeepVariant Runtime Args
        Int n_gpu_deep_variant = 4
        String gpu_model_deep_variant = "nvidia-tesla-t4"
        String gpu_driver_version_deep_variant = "525.60.13"
        Int n_threads_deep_variant = 24
        Int gb_ram_deep_variant = 120
        Int disk_gb_deep_variant = 0
        Int runtime_minutes_deep_variant = 600
        String hpc_queue_deep_variant = "gpu"

        ## HaplotypeCaller Runtime Args
        String? haplotypecaller_passthrough_options
        Int n_gpu_haplotype_caller = 2
        String gpu_model_haplotype_caller = "nvidia-tesla-t4"
        String gpu_driver_version_haplotype_caller = "525.60.13"
        Int n_threads_haplotype_caller = 24
        Int gb_ram_haplotype_caller = 120
        Int disk_gb_haplotype_caller = 0
        Int runtime_minutes_haplotype_caller = 600
        String hpc_queue_haplotype_caller = "gpu"
    }

    if (run_haplotype_caller){
        call haplotypecaller {
            input:
                input_bam = input_bam,
                input_bai = input_bai,
                input_recal = input_recal,
                input_ref_tarball = input_ref_tarball,
                pb_license_bin = pb_license_bin,
                pb_path = pb_path,
                gvcf_mode = gvcf_mode,
                haplotypecaller_passthrough_options = haplotypecaller_passthrough_options,
                n_threads = n_threads_haplotype_caller,
                n_gpu = n_gpu_haplotype_caller,
                gpu_model = gpu_model_haplotype_caller,
                gpu_driver_version = gpu_driver_version_haplotype_caller,
                gb_ram = gb_ram_haplotype_caller,
                disk_gb = disk_gb_haplotype_caller,
                runtime_minutes = runtime_minutes_haplotype_caller,
                hpc_queue = hpc_queue_haplotype_caller,
                pb_docker = pb_docker,
                max_preempt_attempts = max_preempt_attempts
        }

    }

    if (run_deep_variant){
        call deepvariant {
            input:
                input_bam = input_bam,
                input_bai = input_bai,
                input_ref_tarball = input_ref_tarball,
                pb_license_bin = pb_license_bin,
                pb_path = pb_path,
                gvcf_mode = gvcf_mode,
                n_threads = n_threads_deep_variant,
                n_gpu = n_gpu_deep_variant,
                gpu_model = gpu_model_deep_variant,
                gpu_driver_version = gpu_driver_version_deep_variant,
                gb_ram = gb_ram_deep_variant,
                disk_gb = disk_gb_deep_variant,
                runtime_minutes = runtime_minutes_deep_variant,
                hpc_queue = hpc_queue_deep_variant,
                pb_docker = pb_docker,
                max_preempt_attempts = max_preempt_attempts
        }
    }

    output {
        File? deepvariant_vcf = deepvariant.deepvariant_vcf
        File? haplotypecaller_vcf = haplotypecaller.haplotypecaller_vcf
    }

    meta {
        author: "Nvidia Clara Parabricks"
        outputs: {
            deepvariant_vcf: "Output VCF from DeepVariant",
            haplotypecaller_vcf: "Output VCF from GATK HaplotypeCaller"
        }
    }
}
