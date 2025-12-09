#!/bin/bash
#SBATCH --job-name=tximport
#SBATCH --output=logs/09_tximport_%j.out
#SBATCH --error=logs/09_tximport_%j.err
#SBATCH --time=2:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --partition=compute

# tximport - Import and Summarize Transcript-Level Quantifications
# This script imports Salmon and Kallisto quantifications and summarizes to gene level

set -euo pipefail

# Load conda environment
source $(conda info --base)/etc/profile.d/conda.sh
conda activate rnaseq

# Input parameters
UNIQUE_SAMPLES="${UNIQUE_SAMPLES:-./samples_unique.txt}"
SALMON_DIR="${SALMON_DIR:-./results/salmon}"
KALLISTO_DIR="${KALLISTO_DIR:-./results/kallisto}"
GTF_FILE="${GTF_FILE:-}"
OUTPUT_DIR="${OUTPUT_DIR:-./results/tximport}"
QUANT_TYPE="${QUANT_TYPE:-both}"  # salmon, kallisto, or both

# Create output directories
mkdir -p ${OUTPUT_DIR}
mkdir -p logs

echo "Starting tximport at $(date)"
echo "Quantification type: ${QUANT_TYPE}"
echo "Output directory: ${OUTPUT_DIR}"

# Create a simple CSV from unique samples for R
echo "sample" > ${OUTPUT_DIR}/samples.csv
cat ${UNIQUE_SAMPLES} >> ${OUTPUT_DIR}/samples.csv

SAMPLESHEET="${OUTPUT_DIR}/samples.csv"

# Create tx2gene mapping from GTF
if [ -n "${GTF_FILE}" ] && [ -f "${GTF_FILE}" ]; then
    echo "Creating tx2gene mapping from GTF..."
    
    # Extract transcript to gene mapping
    grep -v "^#" ${GTF_FILE} | \
    awk -F'\t' '$3=="transcript"' | \
    perl -ne '
        /transcript_id "([^"]+)"/ && ($tx = $1);
        /gene_id "([^"]+)"/ && ($gene = $1);
        print "$tx\t$gene\n" if $tx && $gene;
    ' | sort -u > ${OUTPUT_DIR}/tx2gene.tsv
    
    TX2GENE="${OUTPUT_DIR}/tx2gene.tsv"
else
    echo "WARNING: GTF file not provided. Cannot create tx2gene mapping."
    TX2GENE=""
fi

# Create R script for tximport
cat > ${OUTPUT_DIR}/run_tximport.R << 'RSCRIPT'
#!/usr/bin/env Rscript

# Load required libraries
suppressPackageStartupMessages({
    library(tximport)
    library(readr)
})

# Get command line arguments
args <- commandArgs(trailingOnly = TRUE)
quant_type <- args[1]
quant_dir <- args[2]
output_dir <- args[3]
tx2gene_file <- args[4]
samplesheet <- args[5]

# Read samplesheet
samples_df <- read.csv(samplesheet)
samples <- samples_df$sample

# Read tx2gene mapping
if (file.exists(tx2gene_file) && file.size(tx2gene_file) > 0) {
    tx2gene <- read_tsv(tx2gene_file, col_names = c("transcript_id", "gene_id"), show_col_types = FALSE)
} else {
    stop("tx2gene file not found or empty")
}

# Import quantifications based on type
if (quant_type %in% c("salmon", "both")) {
    cat("Importing Salmon quantifications...\n")
    salmon_files <- file.path(quant_dir, samples, "quant.sf")
    names(salmon_files) <- samples
    
    # Check which files exist
    salmon_files <- salmon_files[file.exists(salmon_files)]
    
    if (length(salmon_files) > 0) {
        # Import with tximport
        txi_salmon <- tximport(salmon_files, type = "salmon", tx2gene = tx2gene)
        
        # Save gene-level counts
        write.table(txi_salmon$counts, 
                    file = file.path(output_dir, "salmon_gene_counts.tsv"),
                    sep = "\t", quote = FALSE, col.names = NA)
        
        write.table(txi_salmon$abundance, 
                    file = file.path(output_dir, "salmon_gene_tpm.tsv"),
                    sep = "\t", quote = FALSE, col.names = NA)
        
        write.table(txi_salmon$length, 
                    file = file.path(output_dir, "salmon_gene_lengths.tsv"),
                    sep = "\t", quote = FALSE, col.names = NA)
        
        cat("Salmon import complete. Processed", length(salmon_files), "samples.\n")
    } else {
        cat("WARNING: No Salmon quantification files found.\n")
    }
}

if (quant_type %in% c("kallisto", "both")) {
    cat("Importing Kallisto quantifications...\n")
    kallisto_files <- file.path(quant_dir, samples, "abundance.tsv")
    names(kallisto_files) <- samples
    
    # Check which files exist  
    kallisto_files <- kallisto_files[file.exists(kallisto_files)]
    
    if (length(kallisto_files) > 0) {
        # Import with tximport
        txi_kallisto <- tximport(kallisto_files, type = "kallisto", tx2gene = tx2gene)
        
        # Save gene-level counts
        write.table(txi_kallisto$counts, 
                    file = file.path(output_dir, "kallisto_gene_counts.tsv"),
                    sep = "\t", quote = FALSE, col.names = NA)
        
        write.table(txi_kallisto$abundance, 
                    file = file.path(output_dir, "kallisto_gene_tpm.tsv"),
                    sep = "\t", quote = FALSE, col.names = NA)
        
        write.table(txi_kallisto$length, 
                    file = file.path(output_dir, "kallisto_gene_lengths.tsv"),
                    sep = "\t", quote = FALSE, col.names = NA)
        
        cat("Kallisto import complete. Processed", length(kallisto_files), "samples.\n")
    } else {
        cat("WARNING: No Kallisto quantification files found.\n")
    }
}

cat("tximport completed successfully!\n")

# Save session info
writeLines(capture.output(sessionInfo()), 
           file.path(output_dir, "tximport_session_info.txt"))
RSCRIPT

chmod +x ${OUTPUT_DIR}/run_tximport.R

# Run tximport for Salmon
if [ "${QUANT_TYPE}" == "salmon" ] || [ "${QUANT_TYPE}" == "both" ]; then
    if [ -d "${SALMON_DIR}" ]; then
        echo "Running tximport for Salmon..."
        Rscript ${OUTPUT_DIR}/run_tximport.R \
            "salmon" \
            "${SALMON_DIR}" \
            "${OUTPUT_DIR}" \
            "${TX2GENE}" \
            "${SAMPLESHEET}"
    fi
fi

# Run tximport for Kallisto
if [ "${QUANT_TYPE}" == "kallisto" ] || [ "${QUANT_TYPE}" == "both" ]; then
    if [ -d "${KALLISTO_DIR}" ]; then
        echo "Running tximport for Kallisto..."
        Rscript ${OUTPUT_DIR}/run_tximport.R \
            "kallisto" \
            "${KALLISTO_DIR}" \
            "${OUTPUT_DIR}" \
            "${TX2GENE}" \
            "${SAMPLESHEET}"
    fi
fi

echo "tximport completed at $(date)"
