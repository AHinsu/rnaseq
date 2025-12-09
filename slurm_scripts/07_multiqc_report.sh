#!/bin/bash
#SBATCH --job-name=multiqc
#SBATCH --output=logs/07_multiqc_%j.out
#SBATCH --error=logs/07_multiqc_%j.err
#SBATCH --time=2:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --partition=compute

# MultiQC Report Generation
# This script generates a comprehensive quality control report using MultiQC

set -euo pipefail

# Load conda environment
source $(conda info --base)/etc/profile.d/conda.sh
conda activate rnaseq

# Input parameters
RESULTS_DIR="${RESULTS_DIR:-./results}"
OUTPUT_DIR="${OUTPUT_DIR:-./results/multiqc}"
REPORT_NAME="${REPORT_NAME:-rnaseq_multiqc_report}"

# Create output directory
mkdir -p ${OUTPUT_DIR}
mkdir -p logs

echo "Starting MultiQC report generation at $(date)"
echo "Results directory: ${RESULTS_DIR}"
echo "Output directory: ${OUTPUT_DIR}"

# Run MultiQC
multiqc \
    ${RESULTS_DIR} \
    --outdir ${OUTPUT_DIR} \
    --filename ${REPORT_NAME} \
    --force \
    --verbose \
    --config ${OUTPUT_DIR}/multiqc_config.yml 2>/dev/null || \
multiqc \
    ${RESULTS_DIR} \
    --outdir ${OUTPUT_DIR} \
    --filename ${REPORT_NAME} \
    --force \
    --verbose

echo "MultiQC report generated: ${OUTPUT_DIR}/${REPORT_NAME}.html"
echo "Completed at $(date)"
