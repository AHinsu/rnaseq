#!/bin/bash
#SBATCH --job-name=01-prepare_genome
#SBATCH --output=/storage/users/ahinsu/sbatch_logs/job-%j.%x.out
#SBATCH --error=/storage/users/ahinsu/sbatch_logs/job-%j.%x.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=40
#SBATCH --mail-type=ALL              # Mail events (NONE, BEGIN, END, FAIL, ALL)
#SBATCH --mail-user=user@example.com # Where to send mail (EDIT THIS)

# Genome Preparation Script for RNA-seq Pipeline
# This script prepares reference genome files including STAR and Salmon indices
# Usage: sbatch 01_prepare_genome.sh

printf "\n\nStarted: Genome Preparation\n\n"
pwd
date
printf "\n\n"

set -euo pipefail

# Load required modules and activate conda environment
# Uncomment and modify the following line if using environment modules:
module load apps/anaconda-4.7.12.tcl
eval "$(conda shell.bash hook)"
conda activate rnaseq
unset PYTHONPATH

# Input parameters - modify these for your setup
GENOME_FASTA="${GENOME_FASTA:-/storage/users/ahinsu/DD-RNAseq/reference/Bos_taurus.chromsomal.fa}"
GTF_FILE="${GTF_FILE:-/storage/users/ahinsu/DD-RNAseq/reference/Bos_taurus.cleaned.filtered.gtf}"
OUTPUT_DIR="${OUTPUT_DIR:-/storage/users/ahinsu/DD-RNAseq/pipeline}"
THREADS="${SLURM_CPUS_PER_TASK:-40}"

# Create output directories
mkdir -p ${OUTPUT_DIR}/star_index
mkdir -p ${OUTPUT_DIR}/salmon_index
mkdir -p ${OUTPUT_DIR}/kallisto_index
mkdir -p logs

echo "Starting genome preparation at $(date)"
echo "Genome FASTA: ${GENOME_FASTA}"
echo "GTF File: ${GTF_FILE}"
echo "Output Directory: ${OUTPUT_DIR}"
echo "Threads: ${THREADS}"

# Step 1: Create STAR genome index
echo "Building STAR genome index..."
STAR --runMode genomeGenerate \
    --genomeDir ${OUTPUT_DIR}/star_index \
    --genomeFastaFiles ${GENOME_FASTA} \
    --sjdbGTFfile ${GTF_FILE} \
    --sjdbOverhang 99 \
    --runThreadN ${THREADS}

# Step 2: Extract transcript sequences from genome
echo "Extracting transcript sequences..."
gffread -w ${OUTPUT_DIR}/transcripts.fa \
    -g ${GENOME_FASTA} \
    ${GTF_FILE}

# Step 3: Create Salmon index
echo "Building Salmon index..."
salmon index \
    -t ${OUTPUT_DIR}/transcripts.fa \
    -i ${OUTPUT_DIR}/salmon_index \
    -p ${THREADS} \
    --gencode

# Step 4: Create Kallisto index
echo "Building Kallisto index..."
kallisto index \
    -i ${OUTPUT_DIR}/kallisto_index/transcripts.idx \
    ${OUTPUT_DIR}/transcripts.fa

# Step 5: Create samtools index for genome FASTA
echo "Creating samtools FASTA index..."
samtools faidx ${GENOME_FASTA}

# Step 6: Create chromosome sizes file
echo "Creating chromosome sizes file..."
cut -f1,2 ${GENOME_FASTA}.fai > ${OUTPUT_DIR}/chrom.sizes

echo "Genome preparation completed at $(date)"
echo "STAR index: ${OUTPUT_DIR}/star_index"
echo "Salmon index: ${OUTPUT_DIR}/salmon_index"
echo "Kallisto index: ${OUTPUT_DIR}/kallisto_index"

printf "\n\nCompleted: Genome Preparation\n\n"
pwd
date
