version 1.2

import "../tasks/deepvariant.wdl" as tasks

workflow deep_variant {
    meta {
        description: "Run DeepVariant for variant calling from aligned reads"
        author: "KIDS25-hackathon/Team-20"
        outputs: {
            vcf: "some description",
            vcf_index: "some description",
            gvcf: "some description",
            gvcf_index: "some description",
            visual_report: "some description",
        }
    }

    parameter_meta {
        bam: {
            description: "Input BAM file with aligned reads",
            category: "required",
        }
        bam_index: {
            description: "BAM index file (.bai)",
            category: "required",
        }
        ref_fasta: {
            description: "Reference genome FASTA file",
            category: "required",
        }
        ref_fasta_index: {
            description: "Reference genome index (.fai)",
            category: "required",
        }
        sample_name: {
            description: "Sample identifier for output files",
            category: "required",
        }
        model_type: {
            description: "DeepVariant model type",
            category: "optional",
            choices: [
                "WGS",
                "WES",
                "PACBIO",
                "ONT_R104",
                "HYBRID_PACBIO_ILLUMINA",
            ],
        }
        docker_image: {
            description: "DeepVariant Docker image",
            category: "optional",
        }
        num_shards: {
            description: "Number of shards for parallel processing",
            category: "optional",
        }
    }

    input {
        File bam
        File bam_index
        File ref_fasta
        File ref_fasta_index
        String sample_name
        String model_type = "WGS"  # Options: WGS, WES, PACBIO, ONT_R104, HYBRID_PACBIO_ILLUMINA
        String docker_image = "google/deepvariant:1.9.0"
        Int num_shards = 16
    }

    call tasks.run_deep_variant {
        bam = bam,
        bam_index = bam_index,
        ref_fasta = ref_fasta,
        ref_fasta_index = ref_fasta_index,
        sample_name = sample_name,
        model_type = model_type,
        num_shards = num_shards,
        docker_image = docker_image,
    }

    output {
        File vcf = run_deep_variant.vcf
        File vcf_index = run_deep_variant.vcf_index
        File gvcf = run_deep_variant.gvcf
        File gvcf_index = run_deep_variant.gvcf_index
        File visual_report = run_deep_variant.visual_report
    }
}
