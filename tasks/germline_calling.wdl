version 1.2

task haplotypecaller {
    input {
        File input_bam
        File input_bai
        File input_ref_tarball
        File? input_recal
        File? interval_file
        String? haplotypecaller_passthrough_options = ""
        String annotation_args = ""
        Boolean gvcf_mode = false
        Boolean use_best_practices = false
        Int n_threads = 24
        Int gb_ram = 120
        Int disk_gb = 0
    }

    String outbase = basename(input_bam, ".bam")
    String local_tarball = basename(input_ref_tarball)
    String ref = basename(input_ref_tarball, ".tar")

    Int auto_disk_gb = if disk_gb == 0 then ceil(2.0 * size(input_bam, "GB")) + ceil(2.0 * size(
        input_ref_tarball, "GB")) + ceil(size(input_bai, "GB")) + 120 else disk_gb

    String out_vcf = outbase + ".haplotypecaller" + (if gvcf_mode then ".g" else "") + ".vcf"

    String quantization_band_stub = if use_best_practices then " -GQB 10 -GQB 20 -GQB 30 -GQB 40 -GQB 50 -GQB 60 -GQB 70 -GQB 80 -GQB 90 "
        else ""
    String quantization_qual_stub = if use_best_practices then " --static-quantized-quals 10 --static-quantized-quals 20 --static-quantized-quals 30"
        else ""
    String annotation_stub_base = if use_best_practices then "-G StandardAnnotation -G StandardHCAnnotation"
        else annotation_args
    String annotation_stub = if use_best_practices && gvcf_mode then annotation_stub_base
        + " -G AS_StandardAnnotation " else annotation_stub_base

    command <<<
        cp ~{input_ref_tarball} ~{local_tarball} && \
        tar xvf ~{local_tarball} && \
        pbrun haplotypecaller \
        --in-bam ~{input_bam} \
        --ref ~{ref} \
        --out-variants ~{out_vcf} \
        ~{"--in-recal-file " + input_recal} \
        ~{if gvcf_mode then "--gvcf " else ""} \
        ~{"--haplotypecaller-options " + "\"" + haplotypecaller_passthrough_options + "\""
             } \
        ~{annotation_stub} \
        ~{quantization_band_stub} \
        ~{quantization_qual_stub}
    >>>

    output {
        File haplotypecaller_vcf = "~{out_vcf}"
    }

    requirements {
        container: "nvcr.io/nvidia/clara/clara-parabricks:4.5.1-1"
        cpu: n_threads
        memory: "~{gb_ram} GB"
        gpu: true
        disks: "local-disk ~{auto_disk_gb} SSD"
    }
}

task deepvariant {
    input {
        File input_bam
        File input_bai
        File input_ref_tarball
        Boolean gvcf_mode = false
        Int n_threads = 24
        Int gb_ram = 120
        Int disk_gb = 0
    }

    String ref = basename(input_ref_tarball, ".tar")
    String local_tarball = basename(input_ref_tarball)
    String outbase = basename(input_bam, ".bam")

    Int auto_disk_gb = if disk_gb == 0 then ceil(size(input_bam, "GB")) + ceil(size(
        input_ref_tarball, "GB")) + ceil(size(input_bai, "GB")) + 65 else disk_gb

    String out_vcf = outbase + ".deepvariant" + (if gvcf_mode then ".g" else "") + ".vcf"

    command <<<
        cp ~{input_ref_tarball} ~{local_tarball} && \
        tar xvf ~{local_tarball} && \
        pbrun deepvariant \
        ~{if gvcf_mode then "--gvcf " else ""} \
        --ref ~{ref} \
        --in-bam ~{input_bam} \
        --out-variants ~{out_vcf}
    >>>

    output {
        File deepvariant_vcf = "~{out_vcf}"
    }

    requirements {
        container: "nvcr.io/nvidia/clara/clara-parabricks:4.5.1-1"
        cpu: n_threads
        memory: "~{gb_ram} GB"
        gpu: true
        disks: "local-disk ~{auto_disk_gb} SSD"
    }
}
