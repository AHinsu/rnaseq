#!/bin/bash
#SBATCH --job-name=06-stringtie
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

# StringTie Transcript Assembly and Quantification
# This script performs transcript assembly and quantification using StringTie
# Load conda environment
# Input parameters
# Create output directories

printf "\n\nStarted: stringtie\n\n"
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
INPUT_DIR="${INPUT_DIR:-./results/markduplicates}"
GTF_FILE="${GTF_FILE:-}"
OUTPUT_DIR="${OUTPUT_DIR:-./results/stringtie}"
THREADS="${SLURM_CPUS_PER_TASK:-8}"

# Create output directories
mkdir -p ${OUTPUT_DIR}
mkdir -p logs

# Parse samplesheet to get sample info for this array task
# Get sample name for this array task
SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" ${UNIQUE_SAMPLES})

# Get sample info
SAMPLE_LINE=$(grep "^${SAMPLE_NAME}	" ${SAMPLE_FILES})

# Parse CSV line
IFS=$'\t' read -r SAMPLE_NAME FASTQ_1_FILES FASTQ_2_FILES STRANDEDNESS <<< "${SAMPLE_LINE}"

echo "Starting StringTie for sample: ${SAMPLE_NAME}"
echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "Strandedness: ${STRANDEDNESS}"
echo "Timestamp: $(date)"

# Create sample output directory
SAMPLE_DIR="${OUTPUT_DIR}/${SAMPLE_NAME}"
mkdir -p ${SAMPLE_DIR}

# Determine input BAM (use deduplicated if available, otherwise original STAR BAM)
if [ -f "${INPUT_DIR}/${SAMPLE_NAME}/${SAMPLE_NAME}.markdup.bam" ]; then
    INPUT_BAM="${INPUT_DIR}/${SAMPLE_NAME}/${SAMPLE_NAME}.markdup.bam"
elif [ -f "${INPUT_DIR}/${SAMPLE_NAME}/${SAMPLE_NAME}_Aligned.sortedByCoord.out.bam" ]; then
    INPUT_BAM="${INPUT_DIR}/${SAMPLE_NAME}/${SAMPLE_NAME}_Aligned.sortedByCoord.out.bam"
else
    echo "ERROR: No input BAM found for ${SAMPLE_NAME}"
    exit 1
fi

echo "Input BAM: ${INPUT_BAM}"

# Determine strand flag for StringTie
case ${STRANDEDNESS} in
    forward)
        STRAND_FLAG="--fr"
        ;;
    reverse)
        STRAND_FLAG="--rf"
        ;;
    *)
        STRAND_FLAG=""
        ;;
esac

# Build StringTie command
STRINGTIE_CMD="stringtie ${INPUT_BAM} ${STRAND_FLAG}"

# Add GTF if provided
if [ -n "${GTF_FILE}" ] && [ -f "${GTF_FILE}" ]; then
    STRINGTIE_CMD="${STRINGTIE_CMD} \
        -G ${GTF_FILE} \
        -C ${SAMPLE_DIR}/${SAMPLE_NAME}.coverage.gtf \
        -b ${SAMPLE_DIR}/${SAMPLE_NAME}.ballgown"
fi

STRINGTIE_CMD="${STRINGTIE_CMD} \
    -o ${SAMPLE_DIR}/${SAMPLE_NAME}.transcripts.gtf \
    -A ${SAMPLE_DIR}/${SAMPLE_NAME}.gene.abundance.txt \
    -p ${THREADS} \
    -e"

# Run StringTie
eval ${STRINGTIE_CMD}

echo "StringTie completed for ${SAMPLE_NAME} at $(date)"

printf "\n\nCompleted: stringtie\n\n"
pwd
date
