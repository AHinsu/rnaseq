#!/bin/bash
#SBATCH --job-name=02-fastqc_raw
#SBATCH --output=logs/job-%j.%x.out
#SBATCH --error=logs/job-%j.%x.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=4:00:00
#SBATCH --partition=compute
#SBATCH --array=1-N  # Replace N with the number of UNIQUE samples
#SBATCH --mail-type=ALL              # Mail events (NONE, BEGIN, END, FAIL, ALL)
#SBATCH --mail-user=user@example.com # Where to send mail (EDIT THIS)

# FastQC Quality Control on Raw Reads
# This script runs FastQC on raw fastq files from rawdata directory
# Usage: sbatch 02_fastqc_raw.sh

printf "\n\nStarted: FastQC on Raw Reads\n\n"
pwd
date
printf "\n\n"

set -euo pipefail

# Load required modules and activate conda environment
# Uncomment and modify the following line if using environment modules:
# module load apps/anaconda-4.7.12.tcl
eval "$(conda shell.bash hook)"
conda activate rnaseq
unset PYTHONPATH

# Input parameters
SAMPLE_FILES="${SAMPLE_FILES:-./sample_files.tsv}"
UNIQUE_SAMPLES="${UNIQUE_SAMPLES:-./samples_unique.txt}"
OUTPUT_DIR="${OUTPUT_DIR:-./results/fastqc_raw}"
THREADS="${SLURM_CPUS_PER_TASK:-4}"

# Create output directory
mkdir -p ${OUTPUT_DIR}
mkdir -p logs

# Get sample name for this array task
SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" ${UNIQUE_SAMPLES})

# Get FASTQ files for this sample from rawdata
SAMPLE_LINE=$(grep "^${SAMPLE}	" ${SAMPLE_FILES})
IFS=$'\t' read -r SAMPLE_NAME FASTQ_1 FASTQ_2 STRANDEDNESS <<< "${SAMPLE_LINE}"

echo "Starting FastQC for sample: ${SAMPLE_NAME}"
echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "Timestamp: $(date)"

# Check if files exist
if [ ! -f "${FASTQ_1}" ]; then
    echo "ERROR: FASTQ_1 file not found: ${FASTQ_1}"
    exit 1
fi

# Build file list for FastQC
ALL_FILES="${FASTQ_1}"

# Add R2 file if paired-end
if [ -n "${FASTQ_2}" ] && [ "${FASTQ_2}" != "" ] && [ -f "${FASTQ_2}" ]; then
    ALL_FILES="${ALL_FILES} ${FASTQ_2}"
    echo "Paired-end detected"
else
    echo "Single-end detected"
fi

echo "Running FastQC on files for ${SAMPLE_NAME}..."
echo "Files: ${ALL_FILES}"

fastqc \
    --threads ${THREADS} \
    --outdir ${OUTPUT_DIR} \
    ${ALL_FILES}

echo "FastQC completed for ${SAMPLE_NAME} at $(date)"

printf "\n\nCompleted: FastQC on Raw Reads\n\n"
pwd
date
