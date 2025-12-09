#!/bin/bash
#SBATCH --job-name=05-mark_duplicates
#SBATCH --output=logs/job-%j.%x.out
#SBATCH --error=logs/job-%j.%x.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=8:00:00
#SBATCH --partition=compute
#SBATCH --array=1-N  # Replace N with the number of UNIQUE samples
#SBATCH --mail-type=ALL              # Mail events (NONE, BEGIN, END, FAIL, ALL)
#SBATCH --mail-user=user@example.com # Where to send mail (EDIT THIS)

# Picard MarkDuplicates - Mark duplicate reads
# This script marks duplicate reads in BAM files using Picard MarkDuplicates
# Load conda environment
# Input parameters
# Create output directories

printf "\n\nStarted: mark_duplicates\n\n"
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
STAR_DIR="${STAR_DIR:-./results/star}"
GENOME_FASTA="${GENOME_FASTA:-}"
OUTPUT_DIR="${OUTPUT_DIR:-./results/markduplicates}"
THREADS="${SLURM_CPUS_PER_TASK:-4}"

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

echo "Starting Picard MarkDuplicates for sample: ${SAMPLE_NAME}"
echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "Timestamp: $(date)"

# Create sample output directory
SAMPLE_DIR="${OUTPUT_DIR}/${SAMPLE_NAME}"
mkdir -p ${SAMPLE_DIR}

# Input BAM from STAR
INPUT_BAM="${STAR_DIR}/${SAMPLE_NAME}/${SAMPLE_NAME}_Aligned.sortedByCoord.out.bam"

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
    --OUTPUT ${SAMPLE_DIR}/${SAMPLE_NAME}.markdup.bam \
    --METRICS_FILE ${SAMPLE_DIR}/${SAMPLE_NAME}.MarkDuplicates.metrics.txt \
    --REMOVE_DUPLICATES false \
    --ASSUME_SORTED true \
    --CREATE_INDEX true \
    --VALIDATION_STRINGENCY LENIENT

# Generate alignment statistics on deduplicated BAM
echo "Generating alignment statistics on deduplicated BAM..."
samtools flagstat ${SAMPLE_DIR}/${SAMPLE_NAME}.markdup.bam > ${SAMPLE_DIR}/${SAMPLE_NAME}.markdup.flagstat.txt
samtools idxstats ${SAMPLE_DIR}/${SAMPLE_NAME}.markdup.bam > ${SAMPLE_DIR}/${SAMPLE_NAME}.markdup.idxstats.txt
samtools stats ${SAMPLE_DIR}/${SAMPLE_NAME}.markdup.bam > ${SAMPLE_DIR}/${SAMPLE_NAME}.markdup.stats.txt

echo "Picard MarkDuplicates completed for ${SAMPLE_NAME} at $(date)"

printf "\n\nCompleted: mark_duplicates\n\n"
pwd
date
