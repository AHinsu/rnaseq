#!/bin/bash
#SBATCH --job-name=11-multiqc_report
#SBATCH --output=logs/job-%j.%x.out
#SBATCH --error=logs/job-%j.%x.err
#SBATCH --ntasks=1
#SBATCH --time=2:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --partition=compute
#SBATCH --mail-type=ALL              # Mail events (NONE, BEGIN, END, FAIL, ALL)
#SBATCH --mail-user=user@example.com # Where to send mail (EDIT THIS)

# MultiQC Report Generation
# This script generates a comprehensive quality control report using MultiQC


printf "\n\nStarted: multiqc_report\n\n"
pwd
date
printf "\n\n"
set -euo pipefail

# Load conda environment
eval "$(conda shell.bash hook)"
conda activate rnaseq
unset PYTHONPATH

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

printf "\n\nCompleted: multiqc_report\n\n"
pwd
date
