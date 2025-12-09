#!/bin/bash
#SBATCH --job-name=04-star_alignment
#SBATCH --output=logs/job-%j.%x.out
#SBATCH --error=logs/job-%j.%x.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=12:00:00
#SBATCH --partition=compute
#SBATCH --array=1-N  # Replace N with the number of UNIQUE samples
#SBATCH --mail-type=ALL              # Mail events (NONE, BEGIN, END, FAIL, ALL)
#SBATCH --mail-user=user@example.com # Where to send mail (EDIT THIS)

# STAR Alignment
# This script aligns trimmed reads to the reference genome using STAR
# Load conda environment
# Input parameters
# Create output directories

printf "\n\nStarted: star_alignment\n\n"
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
TRIMMED_DIR="${TRIMMED_DIR:-./results/fastp}"
STAR_INDEX="${STAR_INDEX:-./reference/star_index}"
GTF_FILE="${GTF_FILE:-}"
OUTPUT_DIR="${OUTPUT_DIR:-./results/star}"
THREADS="${SLURM_CPUS_PER_TASK:-16}"

# Create output directories
mkdir -p ${OUTPUT_DIR}
mkdir -p logs

# Get sample name for this array task
SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" ${UNIQUE_SAMPLES})

# Get sample info
SAMPLE_LINE=$(grep "^${SAMPLE}	" ${SAMPLE_FILES})
IFS=$'\t' read -r SAMPLE_NAME FASTQ_1_FILES FASTQ_2_FILES STRANDEDNESS <<< "${SAMPLE_LINE}"

echo "Starting STAR alignment for sample: ${SAMPLE_NAME}"
echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "Timestamp: $(date)"

# Create sample output directory
SAMPLE_DIR="${OUTPUT_DIR}/${SAMPLE_NAME}"
mkdir -p ${SAMPLE_DIR}

# Determine if paired-end or single-end
IS_PAIRED=false
if [ -n "${FASTQ_2_FILES}" ] && [ "${FASTQ_2_FILES}" != " " ]; then
    IS_PAIRED=true
fi

# Determine input files (trimmed)
if [ "${IS_PAIRED}" = true ]; then
    # Paired-end
    TRIMMED_R1="${TRIMMED_DIR}/${SAMPLE_NAME}_1.fastp.fastq.gz"
    TRIMMED_R2="${TRIMMED_DIR}/${SAMPLE_NAME}_2.fastp.fastq.gz"
    READ_FILES="${TRIMMED_R1} ${TRIMMED_R2}"
else
    # Single-end
    TRIMMED_R1="${TRIMMED_DIR}/${SAMPLE_NAME}.fastp.fastq.gz"
    READ_FILES="${TRIMMED_R1}"
fi

echo "Input reads: ${READ_FILES}"

# Build STAR command
STAR_CMD="STAR \
    --runThreadN ${THREADS} \
    --genomeDir ${STAR_INDEX}"

# Add GTF if provided
if [ -n "${GTF_FILE}" ] && [ -f "${GTF_FILE}" ]; then
    STAR_CMD="${STAR_CMD} \
    --sjdbGTFfile ${GTF_FILE}"
fi

STAR_CMD="${STAR_CMD} \
    --readFilesIn ${READ_FILES} \
    --readFilesCommand zcat \
    --outFileNamePrefix ${SAMPLE_DIR}/${SAMPLE_NAME}_ \
    --outSAMtype BAM SortedByCoordinate \
    --outSAMunmapped Within \
    --outSAMattributes NH HI AS NM MD \
    --quantMode TranscriptomeSAM GeneCounts \
    --twopassMode Basic \
    --outFilterMultimapNmax 20 \
    --alignSJoverhangMin 8 \
    --alignSJDBoverhangMin 1 \
    --outFilterMismatchNmax 999 \
    --outFilterMismatchNoverReadLmax 0.04 \
    --alignIntronMin 20 \
    --alignIntronMax 1000000 \
    --alignMatesGapMax 1000000"

# Run STAR alignment
eval ${STAR_CMD}

# Index the BAM file
echo "Indexing BAM file..."
samtools index ${SAMPLE_DIR}/${SAMPLE_NAME}_Aligned.sortedByCoord.out.bam

# Generate alignment statistics
echo "Generating alignment statistics..."
samtools flagstat ${SAMPLE_DIR}/${SAMPLE_NAME}_Aligned.sortedByCoord.out.bam > ${SAMPLE_DIR}/${SAMPLE_NAME}_flagstat.txt
samtools idxstats ${SAMPLE_DIR}/${SAMPLE_NAME}_Aligned.sortedByCoord.out.bam > ${SAMPLE_DIR}/${SAMPLE_NAME}_idxstats.txt
samtools stats ${SAMPLE_DIR}/${SAMPLE_NAME}_Aligned.sortedByCoord.out.bam > ${SAMPLE_DIR}/${SAMPLE_NAME}_stats.txt

echo "STAR alignment completed for ${SAMPLE_NAME} at $(date)"

printf "\n\nCompleted: star_alignment\n\n"
pwd
date
