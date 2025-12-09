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
# This script runs FastQC on raw fastq files as array jobs
# Handles multiple FASTQ files per sample (e.g., from multiple sequencing runs)
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

# Get all FASTQ files for this sample
SAMPLE_LINE=$(grep "^${SAMPLE}	" ${SAMPLE_FILES})
IFS=$'\t' read -r SAMPLE_NAME FASTQ_1_FILES FASTQ_2_FILES STRANDEDNESS <<< "${SAMPLE_LINE}"

echo "Starting FastQC for sample: ${SAMPLE_NAME}"
echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "Timestamp: $(date)"

# Convert space-separated file lists to arrays
read -ra FASTQ_1_ARRAY <<< "${FASTQ_1_FILES}"
read -ra FASTQ_2_ARRAY <<< "${FASTQ_2_FILES}"

echo "Number of R1 files: ${#FASTQ_1_ARRAY[@]}"
if [ -n "${FASTQ_2_FILES}" ] && [ "${FASTQ_2_FILES}" != " " ]; then
    echo "Number of R2 files: ${#FASTQ_2_ARRAY[@]}"
fi

# Run FastQC on all FASTQ files for this sample
ALL_FILES=""
for fq1 in "${FASTQ_1_ARRAY[@]}"; do
    if [ -n "${fq1}" ] && [ -f "${fq1}" ]; then
        ALL_FILES="${ALL_FILES} ${fq1}"
    fi
done

# Add R2 files if paired-end
if [ -n "${FASTQ_2_FILES}" ] && [ "${FASTQ_2_FILES}" != " " ]; then
    for fq2 in "${FASTQ_2_ARRAY[@]}"; do
        if [ -n "${fq2}" ] && [ -f "${fq2}" ]; then
            ALL_FILES="${ALL_FILES} ${fq2}"
        fi
    done
fi

if [ -n "${ALL_FILES}" ]; then
    echo "Running FastQC on all files for ${SAMPLE_NAME}..."
    echo "Files: ${ALL_FILES}"
    fastqc \
        --threads ${THREADS} \
        --outdir ${OUTPUT_DIR} \
        ${ALL_FILES}
else
    echo "ERROR: No valid FASTQ files found for ${SAMPLE_NAME}"
    exit 1
fi

echo "FastQC completed for ${SAMPLE_NAME} at $(date)"

printf "\n\nCompleted: FastQC on Raw Reads\n\n"
pwd
date
