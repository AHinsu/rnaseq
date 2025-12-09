#!/bin/bash
#SBATCH --job-name=kallisto_quant
#SBATCH --output=logs/06_kallisto_quant_%A_%a.out
#SBATCH --error=logs/06_kallisto_quant_%A_%a.err
#SBATCH --time=4:00:00
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --partition=compute
#SBATCH --array=1-N  # Replace N with the number of samples

# Kallisto Pseudo-alignment and Quantification
# This script performs pseudo-alignment and quantification using Kallisto

set -euo pipefail

# Load conda environment
source $(conda info --base)/etc/profile.d/conda.sh
conda activate rnaseq

# Input parameters
SAMPLESHEET="${SAMPLESHEET:-./samplesheet.csv}"
TRIMMED_DIR="${TRIMMED_DIR:-./results/fastp}"
KALLISTO_INDEX="${KALLISTO_INDEX:-./reference/kallisto_index/transcripts.idx}"
OUTPUT_DIR="${OUTPUT_DIR:-./results/kallisto}"
THREADS="${SLURM_CPUS_PER_TASK:-8}"
BOOTSTRAP="${BOOTSTRAP:-100}"

# Create output directories
mkdir -p ${OUTPUT_DIR}
mkdir -p logs

# Parse samplesheet to get sample info for this array task
SAMPLE_LINE=$(sed -n "$((SLURM_ARRAY_TASK_ID + 1))p" ${SAMPLESHEET})

# Parse CSV line
IFS=',' read -r SAMPLE FASTQ_1 FASTQ_2 STRANDEDNESS <<< "${SAMPLE_LINE}"

echo "Starting Kallisto quantification for sample: ${SAMPLE}"
echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "Strandedness: ${STRANDEDNESS}"
echo "Timestamp: $(date)"

# Create sample output directory
SAMPLE_DIR="${OUTPUT_DIR}/${SAMPLE}"
mkdir -p ${SAMPLE_DIR}

# Determine input files (trimmed)
if [ -n "${FASTQ_2}" ] && [ "${FASTQ_2}" != "" ]; then
    # Paired-end
    TRIMMED_R1="${TRIMMED_DIR}/${SAMPLE}_1.fastp.fastq.gz"
    TRIMMED_R2="${TRIMMED_DIR}/${SAMPLE}_2.fastp.fastq.gz"
    
    # Determine strand flag for Kallisto
    case ${STRANDEDNESS} in
        forward)
            STRAND_FLAG="--fr-stranded"
            ;;
        reverse)
            STRAND_FLAG="--rf-stranded"
            ;;
        *)
            STRAND_FLAG=""
            ;;
    esac
    
    # Run Kallisto for paired-end
    kallisto quant \
        -i ${KALLISTO_INDEX} \
        -o ${SAMPLE_DIR} \
        -b ${BOOTSTRAP} \
        -t ${THREADS} \
        ${STRAND_FLAG} \
        ${TRIMMED_R1} ${TRIMMED_R2}
else
    # Single-end
    TRIMMED_R1="${TRIMMED_DIR}/${SAMPLE}.fastp.fastq.gz"
    
    # For single-end, need fragment length and SD (estimates)
    FRAG_LEN="${FRAG_LEN:-200}"
    FRAG_SD="${FRAG_SD:-20}"
    
    # Determine strand flag for Kallisto
    case ${STRANDEDNESS} in
        forward)
            STRAND_FLAG="--fr-stranded"
            ;;
        reverse)
            STRAND_FLAG="--rf-stranded"
            ;;
        *)
            STRAND_FLAG=""
            ;;
    esac
    
    # Run Kallisto for single-end
    kallisto quant \
        -i ${KALLISTO_INDEX} \
        -o ${SAMPLE_DIR} \
        -b ${BOOTSTRAP} \
        -t ${THREADS} \
        --single \
        -l ${FRAG_LEN} \
        -s ${FRAG_SD} \
        ${STRAND_FLAG} \
        ${TRIMMED_R1}
fi

echo "Kallisto quantification completed for ${SAMPLE} at $(date)"
