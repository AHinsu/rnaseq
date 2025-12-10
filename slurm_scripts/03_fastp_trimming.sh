#!/bin/bash
#SBATCH --job-name=03-fastp_trimming
#SBATCH --output=logs/job-%j.%x.out
#SBATCH --error=logs/job-%j.%x.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=6:00:00
#SBATCH --partition=compute
#SBATCH --array=1-N  # Replace N with the number of UNIQUE samples
#SBATCH --mail-type=ALL              # Mail events (NONE, BEGIN, END, FAIL, ALL)
#SBATCH --mail-user=user@example.com # Where to send mail (EDIT THIS)

# Fastp Trimming and Filtering
# This script performs adapter trimming and quality filtering using fastp
# Uses pre-merged files from rawdata directory
# Usage: sbatch 03_fastp_trimming.sh

printf "\n\nStarted: fastp_trimming\n\n"
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
OUTPUT_DIR="${OUTPUT_DIR:-./results/fastp}"
THREADS="${SLURM_CPUS_PER_TASK:-8}"

# Create output directories
mkdir -p ${OUTPUT_DIR}
mkdir -p logs

# Get sample name for this array task
SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" ${UNIQUE_SAMPLES})

# Get FASTQ files for this sample from rawdata
SAMPLE_LINE=$(grep "^${SAMPLE}	" ${SAMPLE_FILES})
IFS=$'\t' read -r SAMPLE_NAME FASTQ_1 FASTQ_2 STRANDEDNESS <<< "${SAMPLE_LINE}"

echo "Starting fastp trimming for sample: ${SAMPLE_NAME}"
echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "Timestamp: $(date)"

# Check if input files exist
if [ ! -f "${FASTQ_1}" ]; then
    echo "ERROR: FASTQ_1 file not found: ${FASTQ_1}"
    exit 1
fi

# Determine if paired-end or single-end
IS_PAIRED=false
if [ -n "${FASTQ_2}" ] && [ "${FASTQ_2}" != "" ] && [ -f "${FASTQ_2}" ]; then
    IS_PAIRED=true
    echo "Paired-end detected"
else
    echo "Single-end detected"
fi

# Run fastp
if [ "${IS_PAIRED}" = true ]; then
    # Paired-end
    echo "Running fastp on paired-end reads..."
    fastp \
        --in1 ${FASTQ_1} \
        --in2 ${FASTQ_2} \
        --out1 ${OUTPUT_DIR}/${SAMPLE_NAME}_1.fastp.fastq.gz \
        --out2 ${OUTPUT_DIR}/${SAMPLE_NAME}_2.fastp.fastq.gz \
        --json ${OUTPUT_DIR}/${SAMPLE_NAME}.fastp.json \
        --html ${OUTPUT_DIR}/${SAMPLE_NAME}.fastp.html \
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
        --out1 ${OUTPUT_DIR}/${SAMPLE_NAME}.fastp.fastq.gz \
        --json ${OUTPUT_DIR}/${SAMPLE_NAME}.fastp.json \
        --html ${OUTPUT_DIR}/${SAMPLE_NAME}.fastp.html \
        --thread ${THREADS} \
        --qualified_quality_phred 15 \
        --unqualified_percent_limit 40 \
        --length_required 20
fi

echo "Fastp trimming completed for ${SAMPLE_NAME} at $(date)"

printf "\n\nCompleted: fastp_trimming\n\n"
pwd
date
