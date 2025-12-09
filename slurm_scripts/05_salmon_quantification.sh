#!/bin/bash
#SBATCH --job-name=salmon_quant
#SBATCH --output=logs/05_salmon_quant_%A_%a.out
#SBATCH --error=logs/05_salmon_quant_%A_%a.err
#SBATCH --time=4:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --partition=compute
#SBATCH --array=1-N  # Replace N with the number of samples

# Salmon Quantification from STAR Transcriptome BAM
# This script quantifies transcript abundance using Salmon in alignment-based mode

set -euo pipefail

# Load conda environment
source $(conda info --base)/etc/profile.d/conda.sh
conda activate rnaseq

# Input parameters
SAMPLESHEET="${SAMPLESHEET:-./samplesheet.csv}"
STAR_DIR="${STAR_DIR:-./results/star}"
SALMON_INDEX="${SALMON_INDEX:-./reference/salmon_index}"
GTF_FILE="${GTF_FILE:-./reference/annotations.gtf}"
OUTPUT_DIR="${OUTPUT_DIR:-./results/salmon}"
THREADS="${SLURM_CPUS_PER_TASK:-8}"

# Create output directories
mkdir -p ${OUTPUT_DIR}
mkdir -p logs

# Parse samplesheet to get sample info for this array task
SAMPLE_LINE=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" ${SAMPLESHEET})

# Parse CSV line
IFS=',' read -r SAMPLE FASTQ_1 FASTQ_2 STRANDEDNESS <<< "${SAMPLE_LINE}"

echo "Starting Salmon quantification for sample: ${SAMPLE}"
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
TRANSCRIPTOME_BAM="${STAR_DIR}/${SAMPLE}/${SAMPLE}_Aligned.toTranscriptome.out.bam"

if [ ! -f "${TRANSCRIPTOME_BAM}" ]; then
    echo "ERROR: Transcriptome BAM not found: ${TRANSCRIPTOME_BAM}"
    exit 1
fi

# Run Salmon quantification in alignment-based mode
salmon quant \
    -t ${SALMON_INDEX}/transcripts.bin \
    -l ${LIB_TYPE} \
    -a ${TRANSCRIPTOME_BAM} \
    -o ${OUTPUT_DIR}/${SAMPLE} \
    --threads ${THREADS} \
    -g ${GTF_FILE} \
    --seqBias \
    --gcBias

echo "Salmon quantification completed for ${SAMPLE} at $(date)"
