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
# Handles multiple FASTQ files per sample by merging them first
# Load conda environment
# Input parameters

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
mkdir -p ${OUTPUT_DIR}/merged
mkdir -p logs

# Get sample name for this array task
SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" ${UNIQUE_SAMPLES})

# Get all FASTQ files for this sample
SAMPLE_LINE=$(grep "^${SAMPLE}	" ${SAMPLE_FILES})
IFS=$'\t' read -r SAMPLE_NAME FASTQ_1_FILES FASTQ_2_FILES STRANDEDNESS <<< "${SAMPLE_LINE}"

echo "Starting fastp trimming for sample: ${SAMPLE_NAME}"
echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "Timestamp: $(date)"

# Convert space-separated file lists to arrays
read -ra FASTQ_1_ARRAY <<< "${FASTQ_1_FILES}"
read -ra FASTQ_2_ARRAY <<< "${FASTQ_2_FILES}"

N_FILES=${#FASTQ_1_ARRAY[@]}
echo "Number of file sets to process: ${N_FILES}"

# Determine if paired-end or single-end
IS_PAIRED=false
if [ -n "${FASTQ_2_FILES}" ] && [ "${FASTQ_2_FILES}" != " " ]; then
    IS_PAIRED=true
fi

# If multiple files, merge them first; otherwise use directly
if [ ${N_FILES} -gt 1 ]; then
    echo "Merging ${N_FILES} file sets for ${SAMPLE_NAME}..."
    
    MERGED_R1="${OUTPUT_DIR}/merged/${SAMPLE_NAME}_merged_R1.fastq.gz"
    MERGED_R2="${OUTPUT_DIR}/merged/${SAMPLE_NAME}_merged_R2.fastq.gz"
    
    # Merge R1 files
    echo "Merging R1 files..."
    cat "${FASTQ_1_ARRAY[@]}" > "${MERGED_R1}"
    
    if [ "${IS_PAIRED}" = true ]; then
        # Merge R2 files
        echo "Merging R2 files..."
        cat "${FASTQ_2_ARRAY[@]}" > "${MERGED_R2}"
    fi
    
    INPUT_R1="${MERGED_R1}"
    INPUT_R2="${MERGED_R2}"
else
    # Single file set, use directly
    INPUT_R1="${FASTQ_1_ARRAY[0]}"
    if [ "${IS_PAIRED}" = true ]; then
        INPUT_R2="${FASTQ_2_ARRAY[0]}"
    else
        INPUT_R2=""
    fi
fi

# Run fastp
if [ "${IS_PAIRED}" = true ] && [ -n "${INPUT_R2}" ]; then
    # Paired-end
    echo "Running fastp on paired-end reads..."
    fastp \
        --in1 ${INPUT_R1} \
        --in2 ${INPUT_R2} \
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
        --in1 ${INPUT_R1} \
        --out1 ${OUTPUT_DIR}/${SAMPLE_NAME}.fastp.fastq.gz \
        --json ${OUTPUT_DIR}/${SAMPLE_NAME}.fastp.json \
        --html ${OUTPUT_DIR}/${SAMPLE_NAME}.fastp.html \
        --thread ${THREADS} \
        --qualified_quality_phred 15 \
        --unqualified_percent_limit 40 \
        --length_required 20
fi

# Clean up merged files if they were created
if [ ${N_FILES} -gt 1 ]; then
    echo "Cleaning up temporary merged files..."
    rm -f "${MERGED_R1}" "${MERGED_R2}"
fi

echo "Fastp trimming completed for ${SAMPLE_NAME} at $(date)"

printf "\n\nCompleted: fastp_trimming\n\n"
pwd
date
