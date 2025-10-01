version 1.2

task run_deep_variant {
    meta {
        description: "Run DeepVariant variant calling pipeline"
        author: "KIDS25-hackathon/Team-20"
        volatile: true
        outputs: {
            vcf: "some description",
            vcf_index: "some description",
            gvcf: "some description",
            gvcf_index: "some description",
            visual_report: "some description",
        }
    }

    parameter_meta {
        bam: "Input BAM file with aligned reads"
        bam_index: "BAM index file"
        ref_fasta: "Reference genome FASTA"
        ref_fasta_index: "Reference genome index"
        sample_name: "Sample name for output files"
        model_type: "DeepVariant model type (WGS, WES, PACBIO, ONT_R104, HYBRID_PACBIO_ILLUMINA)"
        docker_image: "Docker container image"
        num_shards: "Number of parallel shards"
        cpu: "Number of CPUs"
        memory_gb: "Memory in GB"
        disk_size_gb: "Disk space in GB"
    }

    input {
        File bam
        File bam_index
        File ref_fasta
        File ref_fasta_index
        String sample_name
        String model_type
        String docker_image
        Int num_shards
        Int cpu = 16
        Int memory_gb = 64
        Int disk_size_gb = 500
    }

    command <<<
        set -euo pipefail

        # Run DeepVariant
        /opt/deepvariant/bin/run_deepvariant \
          --model_type=~{model_type} \
          --ref=~{ref_fasta} \
          --reads=~{bam} \
          --vcf=~{sample_name}.vcf.gz \
          --gvcf=~{sample_name}.g.vcf.gz \
          --num_shards=~{num_shards} \
          --intermediate_results_dir=/tmp/intermediate_results \
          --make_examples_extra_args="min_mapping_quality=1" \
          --sample_name=~{sample_name}

        # Index the output VCF files
        tabix -p vcf ~{sample_name}.vcf.gz
        tabix -p vcf ~{sample_name}.g.vcf.gz
    >>>

    output {
        File vcf = "~{sample_name}.vcf.gz"
        File vcf_index = "~{sample_name}.vcf.gz.tbi"
        File gvcf = "~{sample_name}.g.vcf.gz"
        File gvcf_index = "~{sample_name}.g.vcf.gz.tbi"
        File visual_report = "~{sample_name}.visual_report.html"
    }

    requirements {
        container: docker_image
        cpu: cpu
        gpu: true
        memory: "~{memory_gb} GB"
        disks: "local-disk ~{disk_size_gb} SSD"
        maxRetries: 1
    }

    hints {
        preemptible: 2
    }
}
