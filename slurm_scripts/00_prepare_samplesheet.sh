#!/bin/bash
# Prepare Samplesheet - Create unique samples list and prepare raw data
# This script processes the input samplesheet to handle multiple FASTQ files per sample
# Creates symlinks for single-file samples or merges multiple files per sample
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

# Create output directories and files
RAWDATA_DIR="${OUTPUT_DIR}/rawdata"
mkdir -p "${RAWDATA_DIR}"

UNIQUE_SAMPLES="${OUTPUT_DIR}/samples_unique.txt"
SAMPLE_FILES="${OUTPUT_DIR}/sample_files.tsv"

# Extract unique sample names (skip header)
tail -n +2 "${INPUT_SAMPLESHEET}" | cut -d',' -f1 | sort -u > "${UNIQUE_SAMPLES}"

N_SAMPLES=$(wc -l < "${UNIQUE_SAMPLES}")
echo "Found ${N_SAMPLES} unique samples"

# Create sample files mapping (sample -> standardized FASTQ files in rawdata)
echo "Creating sample to files mapping and preparing rawdata..."
echo -e "sample\tfastq_1\tfastq_2\tstrandedness" > "${SAMPLE_FILES}"

while IFS= read -r sample; do
    # Get all rows for this sample
    sample_rows=$(tail -n +2 "${INPUT_SAMPLESHEET}" | grep "^${sample},")
    
    # Count number of file pairs for this sample
    n_pairs=$(echo "${sample_rows}" | wc -l)
    
    # Collect all FASTQ_1 files
    fastq_1_files=($(echo "${sample_rows}" | cut -d',' -f2))
    
    # Collect all FASTQ_2 files (may be empty for single-end)
    fastq_2_files=($(echo "${sample_rows}" | cut -d',' -f3))
    
    # Get strandedness (should be same for all rows of a sample)
    strandedness=$(echo "${sample_rows}" | head -1 | cut -d',' -f4)
    
    # Determine if paired-end or single-end
    is_paired=false
    if [ -n "${fastq_2_files[0]}" ] && [ "${fastq_2_files[0]}" != "" ]; then
        is_paired=true
    fi
    
    echo "Processing sample ${sample}: ${n_pairs} file pair(s)"
    
    # Standardized output filenames
    OUT_R1="${RAWDATA_DIR}/${sample}_1.fq.gz"
    OUT_R2="${RAWDATA_DIR}/${sample}_2.fq.gz"
    
    if [ ${n_pairs} -eq 1 ]; then
        # Single file pair - create symlinks
        echo "  Creating symlinks for single file pair..."
        
        # Check if input is gzipped and create appropriate symlink
        if [[ "${fastq_1_files[0]}" == *.gz ]]; then
            ln -sf "$(readlink -f ${fastq_1_files[0]})" "${OUT_R1}"
        else
            # If not gzipped, compress it
            echo "  Compressing ${fastq_1_files[0]}..."
            gzip -c "${fastq_1_files[0]}" > "${OUT_R1}"
        fi
        
        if [ "${is_paired}" = true ]; then
            if [[ "${fastq_2_files[0]}" == *.gz ]]; then
                ln -sf "$(readlink -f ${fastq_2_files[0]})" "${OUT_R2}"
            else
                echo "  Compressing ${fastq_2_files[0]}..."
                gzip -c "${fastq_2_files[0]}" > "${OUT_R2}"
            fi
        fi
    else
        # Multiple file pairs - merge/concatenate them
        echo "  Merging ${n_pairs} file pairs..."
        
        # Merge R1 files
        echo "  Merging R1 files..."
        > "${OUT_R1}"  # Create empty file
        for fq1 in "${fastq_1_files[@]}"; do
            if [[ "${fq1}" == *.gz ]]; then
                cat "${fq1}" >> "${OUT_R1}"
            else
                gzip -c "${fq1}" >> "${OUT_R1}"
            fi
        done
        
        # Merge R2 files if paired-end
        if [ "${is_paired}" = true ]; then
            echo "  Merging R2 files..."
            > "${OUT_R2}"  # Create empty file
            for fq2 in "${fastq_2_files[@]}"; do
                if [[ "${fq2}" == *.gz ]]; then
                    cat "${fq2}" >> "${OUT_R2}"
                else
                    gzip -c "${fq2}" >> "${OUT_R2}"
                fi
            done
        fi
    fi
    
    # Add to sample_files.tsv with standardized paths
    if [ "${is_paired}" = true ]; then
        echo -e "${sample}\t${OUT_R1}\t${OUT_R2}\t${strandedness}" >> "${SAMPLE_FILES}"
    else
        echo -e "${sample}\t${OUT_R1}\t\t${strandedness}" >> "${SAMPLE_FILES}"
    fi
    
    echo "  Completed processing ${sample}"
done < "${UNIQUE_SAMPLES}"

echo ""
echo "Created:"
echo "  - ${RAWDATA_DIR}/ (standardized FASTQ files)"
echo "  - ${UNIQUE_SAMPLES} (${N_SAMPLES} unique samples)"
echo "  - ${SAMPLE_FILES} (sample to files mapping)"
echo ""
echo "Use these files for array job submission:"
echo "  - Set array size to 1-${N_SAMPLES}"
echo "  - Use samples_unique.txt and sample_files.tsv in scripts"
echo "  - All scripts will use files from rawdata/ directory"

printf "\n\nCompleted: Prepare Samplesheet\n\n"
pwd
date
