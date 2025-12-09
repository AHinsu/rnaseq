#!/bin/bash
#SBATCH --job-name=star_align
#SBATCH --output=logs/04_star_align_%A_%a.out
#SBATCH --error=logs/04_star_align_%A_%a.err
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --partition=compute
#SBATCH --array=1-N  # Replace N with the number of samples

# STAR Alignment
# This script aligns trimmed reads to the reference genome using STAR

set -euo pipefail

# Load conda environment
source $(conda info --base)/etc/profile.d/conda.sh
conda activate rnaseq

# Input parameters
SAMPLESHEET="${SAMPLESHEET:-./samplesheet.csv}"
TRIMMED_DIR="${TRIMMED_DIR:-./results/fastp}"
STAR_INDEX="${STAR_INDEX:-./reference/star_index}"
GTF_FILE="${GTF_FILE:-./reference/annotations.gtf}"
OUTPUT_DIR="${OUTPUT_DIR:-./results/star}"
THREADS="${SLURM_CPUS_PER_TASK:-16}"

# Create output directories
mkdir -p ${OUTPUT_DIR}
mkdir -p logs

# Parse samplesheet to get sample info for this array task
SAMPLE_LINE=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" ${SAMPLESHEET})

# Parse CSV line
IFS=',' read -r SAMPLE FASTQ_1 FASTQ_2 STRANDEDNESS <<< "${SAMPLE_LINE}"

echo "Starting STAR alignment for sample: ${SAMPLE}"
echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "Timestamp: $(date)"

# Create sample output directory
SAMPLE_DIR="${OUTPUT_DIR}/${SAMPLE}"
mkdir -p ${SAMPLE_DIR}

# Determine input files (trimmed)
if [ -n "${FASTQ_2}" ] && [ "${FASTQ_2}" != "" ]; then
    # Paired-end
    TRIMMED_R1="${TRIMMED_DIR}/${SAMPLE}_1.fastp.fastq.gz"
    TRIMMED_R2="${TRIMMED_DIR}/${SAMPLE}_2.fastp.fastq.gz"
    READ_FILES="${TRIMMED_R1} ${TRIMMED_R2}"
else
    # Single-end
    TRIMMED_R1="${TRIMMED_DIR}/${SAMPLE}.fastp.fastq.gz"
    READ_FILES="${TRIMMED_R1}"
fi

echo "Input reads: ${READ_FILES}"

# Run STAR alignment
STAR \
    --runThreadN ${THREADS} \
    --genomeDir ${STAR_INDEX} \
    --sjdbGTFfile ${GTF_FILE} \
    --readFilesIn ${READ_FILES} \
    --readFilesCommand zcat \
    --outFileNamePrefix ${SAMPLE_DIR}/${SAMPLE}_ \
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
    --alignMatesGapMax 1000000

# Index the BAM file
echo "Indexing BAM file..."
samtools index ${SAMPLE_DIR}/${SAMPLE}_Aligned.sortedByCoord.out.bam

# Generate alignment statistics
echo "Generating alignment statistics..."
samtools flagstat ${SAMPLE_DIR}/${SAMPLE}_Aligned.sortedByCoord.out.bam > ${SAMPLE_DIR}/${SAMPLE}_flagstat.txt
samtools idxstats ${SAMPLE_DIR}/${SAMPLE}_Aligned.sortedByCoord.out.bam > ${SAMPLE_DIR}/${SAMPLE}_idxstats.txt
samtools stats ${SAMPLE_DIR}/${SAMPLE}_Aligned.sortedByCoord.out.bam > ${SAMPLE_DIR}/${SAMPLE}_stats.txt

echo "STAR alignment completed for ${SAMPLE} at $(date)"
