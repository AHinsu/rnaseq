#!/bin/bash
#SBATCH --job-name=mark_duplicates
#SBATCH --output=logs/05_mark_duplicates_%A_%a.out
#SBATCH --error=logs/05_mark_duplicates_%A_%a.err
#SBATCH --time=8:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --partition=compute
#SBATCH --array=1-N  # Replace N with the number of samples

# Picard MarkDuplicates - Mark duplicate reads
# This script marks duplicate reads in BAM files using Picard MarkDuplicates

set -euo pipefail

# Load conda environment
source $(conda info --base)/etc/profile.d/conda.sh
conda activate rnaseq

# Input parameters
SAMPLESHEET="${SAMPLESHEET:-./samplesheet.csv}"
STAR_DIR="${STAR_DIR:-./results/star}"
GENOME_FASTA="${GENOME_FASTA:-}"
OUTPUT_DIR="${OUTPUT_DIR:-./results/markduplicates}"
THREADS="${SLURM_CPUS_PER_TASK:-4}"

# Create output directories
mkdir -p ${OUTPUT_DIR}
mkdir -p logs

# Parse samplesheet to get sample info for this array task
SAMPLE_LINE=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" ${SAMPLESHEET})

# Parse CSV line
IFS=',' read -r SAMPLE FASTQ_1 FASTQ_2 STRANDEDNESS <<< "${SAMPLE_LINE}"

echo "Starting Picard MarkDuplicates for sample: ${SAMPLE}"
echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "Timestamp: $(date)"

# Create sample output directory
SAMPLE_DIR="${OUTPUT_DIR}/${SAMPLE}"
mkdir -p ${SAMPLE_DIR}

# Input BAM from STAR
INPUT_BAM="${STAR_DIR}/${SAMPLE}/${SAMPLE}_Aligned.sortedByCoord.out.bam"

if [ ! -f "${INPUT_BAM}" ]; then
    echo "ERROR: Input BAM not found: ${INPUT_BAM}"
    exit 1
fi

echo "Input BAM: ${INPUT_BAM}"

# Calculate available memory (80% of allocated)
AVAIL_MEM=$((${SLURM_MEM_PER_NODE:-32768} * 80 / 100))

# Run Picard MarkDuplicates
picard \
    -Xmx${AVAIL_MEM}M \
    MarkDuplicates \
    --INPUT ${INPUT_BAM} \
    --OUTPUT ${SAMPLE_DIR}/${SAMPLE}.markdup.bam \
    --METRICS_FILE ${SAMPLE_DIR}/${SAMPLE}.MarkDuplicates.metrics.txt \
    --REMOVE_DUPLICATES false \
    --ASSUME_SORTED true \
    --CREATE_INDEX true \
    --VALIDATION_STRINGENCY LENIENT

# Generate alignment statistics on deduplicated BAM
echo "Generating alignment statistics on deduplicated BAM..."
samtools flagstat ${SAMPLE_DIR}/${SAMPLE}.markdup.bam > ${SAMPLE_DIR}/${SAMPLE}.markdup.flagstat.txt
samtools idxstats ${SAMPLE_DIR}/${SAMPLE}.markdup.bam > ${SAMPLE_DIR}/${SAMPLE}.markdup.idxstats.txt
samtools stats ${SAMPLE_DIR}/${SAMPLE}.markdup.bam > ${SAMPLE_DIR}/${SAMPLE}.markdup.stats.txt

echo "Picard MarkDuplicates completed for ${SAMPLE} at $(date)"
