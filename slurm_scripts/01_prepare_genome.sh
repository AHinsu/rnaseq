#!/bin/bash
#SBATCH --job-name=prepare_genome
#SBATCH --output=logs/01_prepare_genome_%j.out
#SBATCH --error=logs/01_prepare_genome_%j.err
#SBATCH --time=24:00:00
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --partition=compute

# Genome Preparation Script for RNA-seq Pipeline
# This script prepares reference genome files including STAR and Salmon indices

set -euo pipefail

# Load conda environment
source $(conda info --base)/etc/profile.d/conda.sh
conda activate rnaseq

# Input parameters - modify these for your setup
GENOME_FASTA="${GENOME_FASTA:-/path/to/genome.fa}"
GTF_FILE="${GTF_FILE:-/path/to/annotations.gtf}"
OUTPUT_DIR="${OUTPUT_DIR:-./reference}"
THREADS="${SLURM_CPUS_PER_TASK:-16}"

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
