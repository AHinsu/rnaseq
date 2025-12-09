#!/bin/bash
#SBATCH --job-name=fastqc_raw
#SBATCH --output=logs/02_fastqc_raw_%A_%a.out
#SBATCH --error=logs/02_fastqc_raw_%A_%a.err
#SBATCH --time=4:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --partition=compute
#SBATCH --array=1-N  # Replace N with the number of samples

# FastQC Quality Control on Raw Reads
# This script runs FastQC on raw fastq files as array jobs

set -euo pipefail

# Load conda environment
source $(conda info --base)/etc/profile.d/conda.sh
conda activate rnaseq

# Input parameters
SAMPLESHEET="${SAMPLESHEET:-./samplesheet.csv}"
OUTPUT_DIR="${OUTPUT_DIR:-./results/fastqc_raw}"
THREADS="${SLURM_CPUS_PER_TASK:-4}"

# Create output directory
mkdir -p ${OUTPUT_DIR}
mkdir -p logs

# Parse samplesheet to get sample info for this array task
# Skip header line and get the line corresponding to array task ID
SAMPLE_LINE=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" ${SAMPLESHEET})

# Parse CSV line
IFS=',' read -r SAMPLE FASTQ_1 FASTQ_2 STRANDEDNESS <<< "${SAMPLE_LINE}"

echo "Starting FastQC for sample: ${SAMPLE}"
echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "FASTQ_1: ${FASTQ_1}"
echo "FASTQ_2: ${FASTQ_2}"
echo "Timestamp: $(date)"

# Run FastQC on FASTQ files
if [ -n "${FASTQ_2}" ] && [ "${FASTQ_2}" != "" ]; then
    # Paired-end
    echo "Running FastQC on paired-end reads..."
    fastqc \
        --threads ${THREADS} \
        --outdir ${OUTPUT_DIR} \
        ${FASTQ_1} ${FASTQ_2}
else
    # Single-end
    echo "Running FastQC on single-end reads..."
    fastqc \
        --threads ${THREADS} \
        --outdir ${OUTPUT_DIR} \
        ${FASTQ_1}
fi

echo "FastQC completed for ${SAMPLE} at $(date)"
