#!/bin/bash
# Prepare Samplesheet - Create unique samples list and merge file paths
# This script processes the input samplesheet to handle multiple FASTQ files per sample
# Usage: bash 00_prepare_samplesheet.sh samplesheet.csv output_dir

printf "\n\nStarted: Prepare Samplesheet\n\n"
pwd
date
printf "\n\n"

set -euo pipefail

# Input parameters
INPUT_SAMPLESHEET="${1:-./samplesheet.csv}"
OUTPUT_DIR="${2:-.}"

if [ ! -f "${INPUT_SAMPLESHEET}" ]; then
    echo "ERROR: Input samplesheet not found: ${INPUT_SAMPLESHEET}"
    exit 1
fi

echo "Processing samplesheet: ${INPUT_SAMPLESHEET}"

# Create output files
UNIQUE_SAMPLES="${OUTPUT_DIR}/samples_unique.txt"
SAMPLE_FILES="${OUTPUT_DIR}/sample_files.tsv"

# Extract unique sample names (skip header)
tail -n +2 "${INPUT_SAMPLESHEET}" | cut -d',' -f1 | sort -u > "${UNIQUE_SAMPLES}"

N_SAMPLES=$(wc -l < "${UNIQUE_SAMPLES}")
echo "Found ${N_SAMPLES} unique samples"

# Create sample files mapping (sample -> all FASTQ files)
echo "Creating sample to files mapping..."
echo -e "sample\tfastq_1_files\tfastq_2_files\tstrandedness" > "${SAMPLE_FILES}"

while IFS= read -r sample; do
    # Get all rows for this sample
    sample_rows=$(tail -n +2 "${INPUT_SAMPLESHEET}" | grep "^${sample},")
    
    # Collect all FASTQ_1 files
    fastq_1_files=$(echo "${sample_rows}" | cut -d',' -f2 | tr '\n' ' ' | sed 's/ $//')
    
    # Collect all FASTQ_2 files (may be empty for single-end)
    fastq_2_files=$(echo "${sample_rows}" | cut -d',' -f3 | tr '\n' ' ' | sed 's/ $//')
    
    # Get strandedness (should be same for all rows of a sample)
    strandedness=$(echo "${sample_rows}" | head -1 | cut -d',' -f4)
    
    echo -e "${sample}\t${fastq_1_files}\t${fastq_2_files}\t${strandedness}" >> "${SAMPLE_FILES}"
done < "${UNIQUE_SAMPLES}"

echo "Created:"
echo "  - ${UNIQUE_SAMPLES} (${N_SAMPLES} unique samples)"
echo "  - ${SAMPLE_FILES} (sample to files mapping)"
echo ""
echo "Use these files for array job submission:"
echo "  - Set array size to 1-${N_SAMPLES}"
echo "  - Use samples_unique.txt and sample_files.tsv in scripts"

printf "\n\nCompleted: Prepare Samplesheet\n\n"
pwd
date
