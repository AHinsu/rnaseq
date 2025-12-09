#!/bin/bash
#SBATCH --job-name=deseq2_qc
#SBATCH --output=logs/10_deseq2_qc_%j.out
#SBATCH --error=logs/10_deseq2_qc_%j.err
#SBATCH --time=2:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --partition=compute

# DESeq2 QC Plots
# This script generates QC plots (PCA, sample correlation) using DESeq2

set -euo pipefail

# Load conda environment
source $(conda info --base)/etc/profile.d/conda.sh
conda activate rnaseq

# Input parameters
COUNTS_FILE="${COUNTS_FILE:-./results/tximport/salmon_gene_counts.tsv}"
OUTPUT_DIR="${OUTPUT_DIR:-./results/deseq2_qc}"
SAMPLESHEET="${SAMPLESHEET:-./samplesheet.csv}"

# Create output directories
mkdir -p ${OUTPUT_DIR}
mkdir -p logs

echo "Starting DESeq2 QC at $(date)"
echo "Input counts: ${COUNTS_FILE}"
echo "Output directory: ${OUTPUT_DIR}"

# Check if counts file exists
if [ ! -f "${COUNTS_FILE}" ]; then
    echo "ERROR: Counts file not found: ${COUNTS_FILE}"
    exit 1
fi

# Create R script for DESeq2 QC
cat > ${OUTPUT_DIR}/run_deseq2_qc.R << 'RSCRIPT'
#!/usr/bin/env Rscript

# Load required libraries
suppressPackageStartupMessages({
    library(DESeq2)
    library(ggplot2)
    library(pheatmap)
    library(RColorBrewer)
})

# Get command line arguments
args <- commandArgs(trailingOnly = TRUE)
counts_file <- args[1]
output_dir <- args[2]
samplesheet_file <- args[3]

cat("Reading count data...\n")
# Read counts matrix
counts <- read.table(counts_file, header = TRUE, row.names = 1, check.names = FALSE)

# Read samplesheet
samples_df <- read.csv(samplesheet_file)
rownames(samples_df) <- samples_df$sample

# Ensure samples match between counts and samplesheet
samples <- intersect(colnames(counts), samples_df$sample)
counts <- counts[, samples]
samples_df <- samples_df[samples, ]

cat("Processing", ncol(counts), "samples with", nrow(counts), "genes\n")

# Remove genes with zero counts across all samples
counts <- counts[rowSums(counts) > 0, ]

cat("After filtering:", nrow(counts), "genes with non-zero counts\n")

# Create DESeq2 dataset
# Use a simple design for QC purposes
coldata <- data.frame(
    sample = samples,
    condition = rep("sample", length(samples)),
    row.names = samples
)

# Create DESeq2 object
dds <- DESeqDataSetFromMatrix(
    countData = round(counts),
    colData = coldata,
    design = ~ 1  # No design for QC
)

cat("Running DESeq2 normalization...\n")
# Estimate size factors and normalize
dds <- estimateSizeFactors(dds)
dds <- estimateDispersions(dds)

# Variance stabilizing transformation for visualization
cat("Performing variance stabilizing transformation...\n")
vst_data <- vst(dds, blind = TRUE)

# PCA plot
cat("Generating PCA plot...\n")
pca_data <- plotPCA(vst_data, intgroup = "condition", returnData = TRUE)
percent_var <- round(100 * attr(pca_data, "percentVar"))

pca_plot <- ggplot(pca_data, aes(x = PC1, y = PC2, label = name)) +
    geom_point(size = 3, alpha = 0.7) +
    geom_text(vjust = -0.5, hjust = 0.5, size = 3) +
    xlab(paste0("PC1: ", percent_var[1], "% variance")) +
    ylab(paste0("PC2: ", percent_var[2], "% variance")) +
    theme_bw() +
    theme(
        panel.grid.major = element_line(color = "gray90"),
        panel.grid.minor = element_blank()
    ) +
    ggtitle("PCA Plot of RNA-seq Samples")

ggsave(
    filename = file.path(output_dir, "deseq2_pca_plot.png"),
    plot = pca_plot,
    width = 10,
    height = 8,
    dpi = 300
)

ggsave(
    filename = file.path(output_dir, "deseq2_pca_plot.pdf"),
    plot = pca_plot,
    width = 10,
    height = 8
)

# Save PCA data
write.table(
    pca_data,
    file = file.path(output_dir, "deseq2_pca_data.tsv"),
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
)

# Sample correlation heatmap
cat("Generating sample correlation heatmap...\n")
sample_dists <- dist(t(assay(vst_data)))
sample_dist_matrix <- as.matrix(sample_dists)

# Correlation matrix
cor_matrix <- cor(assay(vst_data))

# Generate heatmap
png(
    filename = file.path(output_dir, "deseq2_sample_correlation_heatmap.png"),
    width = 10,
    height = 10,
    units = "in",
    res = 300
)

pheatmap(
    cor_matrix,
    clustering_distance_rows = sample_dists,
    clustering_distance_cols = sample_dists,
    main = "Sample-to-Sample Correlation",
    color = colorRampPalette(rev(brewer.pal(9, "Blues")))(255),
    display_numbers = TRUE,
    number_format = "%.2f",
    fontsize = 10,
    fontsize_number = 8
)

dev.off()

pdf(
    file = file.path(output_dir, "deseq2_sample_correlation_heatmap.pdf"),
    width = 10,
    height = 10
)

pheatmap(
    cor_matrix,
    clustering_distance_rows = sample_dists,
    clustering_distance_cols = sample_dists,
    main = "Sample-to-Sample Correlation",
    color = colorRampPalette(rev(brewer.pal(9, "Blues")))(255),
    display_numbers = TRUE,
    number_format = "%.2f",
    fontsize = 10,
    fontsize_number = 8
)

dev.off()

# Save correlation matrix
write.table(
    cor_matrix,
    file = file.path(output_dir, "deseq2_sample_correlation.tsv"),
    sep = "\t",
    quote = FALSE,
    col.names = NA
)

# Sample distance heatmap
png(
    filename = file.path(output_dir, "deseq2_sample_distance_heatmap.png"),
    width = 10,
    height = 10,
    units = "in",
    res = 300
)

pheatmap(
    sample_dist_matrix,
    clustering_distance_rows = sample_dists,
    clustering_distance_cols = sample_dists,
    main = "Sample-to-Sample Distances",
    color = colorRampPalette(rev(brewer.pal(9, "RdYlBu")))(255),
    display_numbers = TRUE,
    number_format = "%.0f",
    fontsize = 10,
    fontsize_number = 8
)

dev.off()

pdf(
    file = file.path(output_dir, "deseq2_sample_distance_heatmap.pdf"),
    width = 10,
    height = 10
)

pheatmap(
    sample_dist_matrix,
    clustering_distance_rows = sample_dists,
    clustering_distance_cols = sample_dists,
    main = "Sample-to-Sample Distances",
    color = colorRampPalette(rev(brewer.pal(9, "RdYlBu")))(255),
    display_numbers = TRUE,
    number_format = "%.0f",
    fontsize = 10,
    fontsize_number = 8
)

dev.off()

# Generate MultiQC-compatible outputs
cat("Generating MultiQC-compatible outputs...\n")

# PCA data for MultiQC
pca_mqc <- data.frame(
    Sample = rownames(pca_data),
    PC1 = pca_data$PC1,
    PC2 = pca_data$PC2
)

writeLines(
    c(
        "# plot_type: 'scatter'",
        "# section_name: 'DESeq2 PCA'",
        "# description: 'Principal Component Analysis of normalized counts'",
        "# pconfig:",
        "#     id: 'deseq2_pca_plot'",
        "#     title: 'DESeq2: PCA Plot'",
        "#     xlab: 'PC1'",
        "#     ylab: 'PC2'"
    ),
    file.path(output_dir, "deseq2_pca_mqc.tsv")
)

write.table(
    pca_mqc,
    file = file.path(output_dir, "deseq2_pca_mqc.tsv"),
    append = TRUE,
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
)

# Correlation heatmap for MultiQC
writeLines(
    c(
        "# plot_type: 'heatmap'",
        "# section_name: 'DESeq2 Sample Correlation'",
        "# description: 'Sample correlation heatmap based on normalized counts'",
        "# pconfig:",
        "#     id: 'deseq2_sample_correlation'",
        "#     title: 'DESeq2: Sample Correlation'"
    ),
    file.path(output_dir, "deseq2_sample_correlation_mqc.tsv")
)

write.table(
    cor_matrix,
    file = file.path(output_dir, "deseq2_sample_correlation_mqc.tsv"),
    append = TRUE,
    sep = "\t",
    quote = FALSE,
    col.names = NA
)

cat("DESeq2 QC completed successfully!\n")
cat("Generated files:\n")
cat("  - PCA plot (PNG and PDF)\n")
cat("  - Sample correlation heatmap (PNG and PDF)\n")
cat("  - Sample distance heatmap (PNG and PDF)\n")
cat("  - MultiQC-compatible outputs\n")

# Save session info
writeLines(capture.output(sessionInfo()), 
           file.path(output_dir, "deseq2_qc_session_info.txt"))
RSCRIPT

chmod +x ${OUTPUT_DIR}/run_deseq2_qc.R

# Run DESeq2 QC
echo "Running DESeq2 QC analysis..."
Rscript ${OUTPUT_DIR}/run_deseq2_qc.R \
    "${COUNTS_FILE}" \
    "${OUTPUT_DIR}" \
    "${SAMPLESHEET}"

echo "DESeq2 QC completed at $(date)"
