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
        Int n_threads = 24
        Int gb_ram = 120
        Int disk_gb = 0
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
        tar xvf ~{local_tarball} && \
        ~{pb_path} haplotypecaller \
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
        container : "nvcr.io/nvidia/clara/clara-parabricks:4.3.0-1"
        cpu : n_threads
        memory : "~{gb_ram} GB"
        gpu : true
        disks : "local-disk ~{auto_disk_gb} SSD"
    }
}


task deepvariant {
    input {
        File input_bam
        File input_bai
        File input_ref_tarball
        String pb_path = "pbrun"
        File? pb_license_bin
        Boolean gvcf_mode = false
        Int n_threads = 24
        Int gb_ram = 120
        Int disk_gb = 0
    }

    String ref = basename(input_ref_tarball, ".tar")
    String local_tarball = basename(input_ref_tarball)
    String outbase = basename(input_bam, ".bam")

    Int auto_disk_gb = if disk_gb == 0 then ceil(size(input_bam, "GB")) + ceil(size(input_ref_tarball, "GB")) + ceil(size(input_bai, "GB")) + 65 else disk_gb

    String out_vcf = outbase + ".deepvariant" + (if gvcf_mode then '.g' else '') + ".vcf"


    command <<<
        mv ~{input_ref_tarball} ~{local_tarball} && \
        tar xvf ~{local_tarball} && \
        ~{pb_path} deepvariant \
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
        container : "nvcr.io/nvidia/clara/clara-parabricks:4.3.0-1"
        cpu : n_threads
        memory : "~{gb_ram} GB"
        gpu: true
        disks : "local-disk ~{auto_disk_gb} SSD"
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

        Boolean run_deep_variant = true
        Boolean run_haplotype_caller = true
        ## Run both DeepVariant and haplotype_caller in gVCF mode
        Boolean gvcf_mode = false

        ## DeepVariant Runtime Args
        Int n_threads_deep_variant = 24
        Int gb_ram_deep_variant = 120
        Int disk_gb_deep_variant = 0

        ## HaplotypeCaller Runtime Args
        String? haplotypecaller_passthrough_options
        Int n_threads_haplotype_caller = 24
        Int gb_ram_haplotype_caller = 120
        Int disk_gb_haplotype_caller = 0
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
                gb_ram = gb_ram_haplotype_caller,
                disk_gb = disk_gb_haplotype_caller
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
                gb_ram = gb_ram_deep_variant,
                disk_gb = disk_gb_deep_variant
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
