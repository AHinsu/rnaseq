#!/bin/bash
#SBATCH --job-name=salmon_quant
#SBATCH --output=logs/05_salmon_quant_%A_%a.out
#SBATCH --error=logs/05_salmon_quant_%A_%a.err
#SBATCH --time=4:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --partition=compute
#SBATCH --array=1-N  # Replace N with the number of UNIQUE samples

# Salmon Quantification from STAR Transcriptome BAM
# This script quantifies transcript abundance using Salmon in alignment-based mode

set -euo pipefail

# Load conda environment
source $(conda info --base)/etc/profile.d/conda.sh
conda activate rnaseq

# Input parameters
SAMPLE_FILES="${SAMPLE_FILES:-./sample_files.tsv}"
UNIQUE_SAMPLES="${UNIQUE_SAMPLES:-./samples_unique.txt}"
STAR_DIR="${STAR_DIR:-./results/star}"
SALMON_INDEX="${SALMON_INDEX:-./reference/salmon_index}"
GTF_FILE="${GTF_FILE:-}"
OUTPUT_DIR="${OUTPUT_DIR:-./results/salmon}"
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

echo "Starting Salmon quantification for sample: ${SAMPLE_NAME}"
echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "Strandedness: ${STRANDEDNESS}"
echo "Timestamp: $(date)"

# Determine library type for Salmon
case ${STRANDEDNESS} in
    forward)
        LIB_TYPE="ISF"  # inward, stranded, forward
        ;;
    reverse)
        LIB_TYPE="ISR"  # inward, stranded, reverse
        ;;
    unstranded)
        LIB_TYPE="IU"   # inward, unstranded
        ;;
    auto)
        LIB_TYPE="A"    # automatic detection
        ;;
    *)
        LIB_TYPE="A"    # default to automatic
        ;;
esac

# Transcriptome BAM from STAR
TRANSCRIPTOME_BAM="${STAR_DIR}/${SAMPLE_NAME}/${SAMPLE_NAME}_Aligned.toTranscriptome.out.bam"

if [ ! -f "${TRANSCRIPTOME_BAM}" ]; then
    echo "ERROR: Transcriptome BAM not found: ${TRANSCRIPTOME_BAM}"
    exit 1
fi

# Build Salmon command
SALMON_CMD="salmon quant \
    -t ${SALMON_INDEX}/transcripts.bin \
    -l ${LIB_TYPE} \
    -a ${TRANSCRIPTOME_BAM} \
    -o ${OUTPUT_DIR}/${SAMPLE_NAME} \
    --threads ${THREADS}"

# Add GTF if provided
if [ -n "${GTF_FILE}" ] && [ -f "${GTF_FILE}" ]; then
    SALMON_CMD="${SALMON_CMD} \
    -g ${GTF_FILE}"
fi

SALMON_CMD="${SALMON_CMD} \
    --seqBias \
    --gcBias"

# Run Salmon quantification
eval ${SALMON_CMD}

echo "Salmon quantification completed for ${SAMPLE_NAME} at $(date)"
