#!/bin/bash
#SBATCH --job-name=08-kallisto_quantification
#SBATCH --output=logs/job-%j.%x.out
#SBATCH --error=logs/job-%j.%x.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=4:00:00
#SBATCH --partition=compute
#SBATCH --array=1-N  # Replace N with the number of UNIQUE samples
#SBATCH --mail-type=ALL              # Mail events (NONE, BEGIN, END, FAIL, ALL)
#SBATCH --mail-user=user@example.com # Where to send mail (EDIT THIS)

# Kallisto Pseudo-alignment and Quantification
# This script performs pseudo-alignment and quantification using Kallisto
# Load conda environment
# Input parameters
# Create output directories

printf "\n\nStarted: kallisto_quantification\n\n"
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
KALLISTO_INDEX="${KALLISTO_INDEX:-./reference/kallisto_index/transcripts.idx}"
OUTPUT_DIR="${OUTPUT_DIR:-./results/kallisto}"
THREADS="${SLURM_CPUS_PER_TASK:-8}"
BOOTSTRAP="${BOOTSTRAP:-100}"

# Create output directories
mkdir -p ${OUTPUT_DIR}
mkdir -p logs

# Parse samplesheet to get sample info for this array task
# Get sample name for this array task
SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" ${UNIQUE_SAMPLES})

# Get sample info
SAMPLE_LINE=$(grep "^${SAMPLE}	" ${SAMPLE_FILES})

# Parse CSV line
IFS=$'\t' read -r SAMPLE_NAME FASTQ_1_FILES FASTQ_2_FILES STRANDEDNESS <<< "${SAMPLE_LINE}"

echo "Starting Kallisto quantification for sample: ${SAMPLE}	"
echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "Strandedness: ${STRANDEDNESS}"
echo "Timestamp: $(date)"

# Create sample output directory
SAMPLE_DIR="${OUTPUT_DIR}/${SAMPLE}	"
mkdir -p ${SAMPLE_DIR}

# Determine input files (trimmed)
if [ -n "${FASTQ_2}" ] && [ "${FASTQ_2}" != "" ]; then
    # Paired-end
    TRIMMED_R1="${TRIMMED_DIR}/${SAMPLE}	_1.fastp.fastq.gz"
    TRIMMED_R2="${TRIMMED_DIR}/${SAMPLE}	_2.fastp.fastq.gz"
    
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
    TRIMMED_R1="${TRIMMED_DIR}/${SAMPLE}	.fastp.fastq.gz"
    
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

echo "Kallisto quantification completed for ${SAMPLE}	 at $(date)"

printf "\n\nCompleted: kallisto_quantification\n\n"
pwd
date
