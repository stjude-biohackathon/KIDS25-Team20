# KIDS25-Team20

 Clara Parabricks v 4.5.1 with WDL 1.2
-----------------------

# Introduction
This repository contains  WDL workflows sing Nvidia Clara Parabricks

# Available workflows adapted from (https://github.com/clara-parabricks-workflows/parabricks-wdl) Clara parabricks workflow 
 - fq2bam : Align reads with Clara Parabricks' accelerated version of BWA mem.
 - bam2fq2bam: Extract FASTQ files from a BAM file and realign them to produce a new BAM file on a different reference.
 - germline_calling: Run accelerated GATK HaplotypeCaller and/or accelerated DeepVariant to produce germline VCF or gVCF files for a single sample.
 - somatic_calling: Run accelerated Mutect2 on a matched tumor-normal sample pair to generate a somatic VCF.
 - deepvariant-retraining: Retrain the DeepVariant model on a custom dataset generated from a .bam 

# Getting Started
All pipelines in this repository have been validated using Sprocket 0.17.1.

## Setting up your runtime environment
 Insert sprocket github link


## Download test data or bring your own
We recommend test data provided by Google Brain's Public Sequencing project. The HG002 FASTQ files
can be downloaded with the following commands:



## Run your first workflow
There are example JSON input slugs in the `example_inputs` directory. To run your first workflow, you can edit the minimal inputs file (`fq2bam.minimalInputs.json`). If you want
more advanced control over inputs or need additional ones you can modify the full inputs file (`fq2bam.fullInputs.json`).







