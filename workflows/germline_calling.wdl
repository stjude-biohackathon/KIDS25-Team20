version 1.2

import "../tasks/germline_calling.wdl"

workflow germline {
    meta {
        author: "Nvidia Clara Parabricks"
        outputs: {
            deepvariant_vcf: "Output VCF from DeepVariant",
            haplotypecaller_vcf: "Output VCF from GATK HaplotypeCaller",
        }
    }

    input {
        File input_bam
        File input_bai
        File input_ref_tarball
        File? input_recal

        ## HaplotypeCaller Runtime Args
        String? haplotypecaller_passthrough_options
        String pb_path = "pbrun"
        Boolean run_deep_variant = true
        Boolean run_haplotype_caller = true
        ## Run both DeepVariant and haplotype_caller in gVCF mode
        Boolean gvcf_mode = false

        ## DeepVariant Runtime Args
        Int n_threads_deep_variant = 24
        Int gb_ram_deep_variant = 120
        Int disk_gb_deep_variant = 0
        Int n_threads_haplotype_caller = 24
        Int gb_ram_haplotype_caller = 120
        Int disk_gb_haplotype_caller = 0
    }

    if (run_haplotype_caller) {
        call germline_calling.haplotypecaller { input:
            input_bam = input_bam,
            input_bai = input_bai,
            input_recal = input_recal,
            input_ref_tarball = input_ref_tarball,
            pb_path = pb_path,
            gvcf_mode = gvcf_mode,
            haplotypecaller_passthrough_options = haplotypecaller_passthrough_options,
            n_threads = n_threads_haplotype_caller,
            gb_ram = gb_ram_haplotype_caller,
            disk_gb = disk_gb_haplotype_caller,
        }

    }

    if (run_deep_variant) {
        call germline_calling.deepvariant { input:
            input_bam = input_bam,
            input_bai = input_bai,
            input_ref_tarball = input_ref_tarball,
            pb_path = pb_path,
            gvcf_mode = gvcf_mode,
            n_threads = n_threads_deep_variant,
            gb_ram = gb_ram_deep_variant,
            disk_gb = disk_gb_deep_variant,
        }
    }

    output {
        File? deepvariant_vcf = deepvariant.deepvariant_vcf
        File? haplotypecaller_vcf = haplotypecaller.haplotypecaller_vcf
    }
}
