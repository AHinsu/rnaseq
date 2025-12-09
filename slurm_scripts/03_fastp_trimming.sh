#!/bin/bash
#SBATCH --job-name=fastp_trim
#SBATCH --output=logs/03_fastp_trim_%A_%a.out
#SBATCH --error=logs/03_fastp_trim_%A_%a.err
#SBATCH --time=6:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --partition=compute
#SBATCH --array=1-N  # Replace N with the number of samples

# Fastp Trimming and Filtering
# This script performs adapter trimming and quality filtering using fastp

set -euo pipefail

# Load conda environment
source $(conda info --base)/etc/profile.d/conda.sh
conda activate rnaseq

# Input parameters
SAMPLESHEET="${SAMPLESHEET:-./samplesheet.csv}"
OUTPUT_DIR="${OUTPUT_DIR:-./results/fastp}"
THREADS="${SLURM_CPUS_PER_TASK:-8}"

# Create output directories
mkdir -p ${OUTPUT_DIR}
mkdir -p logs

# Parse samplesheet to get sample info for this array task
SAMPLE_LINE=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" ${SAMPLESHEET})

# Parse CSV line
IFS=',' read -r SAMPLE FASTQ_1 FASTQ_2 STRANDEDNESS <<< "${SAMPLE_LINE}"

echo "Starting fastp trimming for sample: ${SAMPLE}"
echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "FASTQ_1: ${FASTQ_1}"
echo "FASTQ_2: ${FASTQ_2}"
echo "Timestamp: $(date)"

# Run fastp
if [ -n "${FASTQ_2}" ] && [ "${FASTQ_2}" != "" ]; then
    # Paired-end
    echo "Running fastp on paired-end reads..."
    fastp \
        --in1 ${FASTQ_1} \
        --in2 ${FASTQ_2} \
        --out1 ${OUTPUT_DIR}/${SAMPLE}_1.fastp.fastq.gz \
        --out2 ${OUTPUT_DIR}/${SAMPLE}_2.fastp.fastq.gz \
        --json ${OUTPUT_DIR}/${SAMPLE}.fastp.json \
        --html ${OUTPUT_DIR}/${SAMPLE}.fastp.html \
        --thread ${THREADS} \
        --detect_adapter_for_pe \
        --qualified_quality_phred 15 \
        --unqualified_percent_limit 40 \
        --length_required 20
else
    # Single-end
    echo "Running fastp on single-end reads..."
    fastp \
        --in1 ${FASTQ_1} \
        --out1 ${OUTPUT_DIR}/${SAMPLE}.fastp.fastq.gz \
        --json ${OUTPUT_DIR}/${SAMPLE}.fastp.json \
        --html ${OUTPUT_DIR}/${SAMPLE}.fastp.html \
        --thread ${THREADS} \
        --qualified_quality_phred 15 \
        --unqualified_percent_limit 40 \
        --length_required 20
fi

echo "Fastp trimming completed for ${SAMPLE} at $(date)"
