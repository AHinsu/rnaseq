#!/bin/bash
# submit_pipeline.sh
# Automated submission script for RNA-seq SLURM pipeline

set -euo pipefail

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Automated submission script for RNA-seq SLURM pipeline

OPTIONS:
    -s, --samplesheet FILE    Path to samplesheet CSV (default: ./samplesheet.csv)
    -o, --outdir DIR          Output directory (default: ./results)
    -g, --genome FASTA        Path to genome FASTA file
    -a, --gtf FILE            Path to GTF annotation file
    -r, --reference DIR       Path to reference directory (default: ./reference)
    --skip-genome-prep        Skip genome preparation step
    --skip-qc-raw             Skip QC on raw reads
    -h, --help                Show this help message

EXAMPLE:
    $0 -s samples.csv -g genome.fa -a annotations.gtf -o results

EOF
    exit 1
}

# Default parameters
SAMPLESHEET="./samplesheet.csv"
OUTDIR="./results"
REFERENCE_DIR="./reference"
SKIP_GENOME_PREP=false
SKIP_QC_RAW=false
GENOME_FASTA=""
GTF_FILE=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--samplesheet)
            SAMPLESHEET="$2"
            shift 2
            ;;
        -o|--outdir)
            OUTDIR="$2"
            shift 2
            ;;
        -g|--genome)
            GENOME_FASTA="$2"
            shift 2
            ;;
        -a|--gtf)
            GTF_FILE="$2"
            shift 2
            ;;
        -r|--reference)
            REFERENCE_DIR="$2"
            shift 2
            ;;
        --skip-genome-prep)
            SKIP_GENOME_PREP=true
            shift
            ;;
        --skip-qc-raw)
            SKIP_QC_RAW=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required files
if [ ! -f "${SAMPLESHEET}" ]; then
    echo "ERROR: Samplesheet not found: ${SAMPLESHEET}"
    exit 1
fi

echo "========================================"
echo "RNA-seq Pipeline Submission"
echo "========================================"
echo "Samplesheet: ${SAMPLESHEET}"
echo "Output directory: ${OUTDIR}"
echo "Reference directory: ${REFERENCE_DIR}"
echo "========================================"

# Create output directories
mkdir -p ${OUTDIR}
mkdir -p logs

# Prepare samplesheet - handle multiple FASTQ files per sample
SCRIPT_DIR="$(dirname $0)"
echo ""
echo "Preparing samplesheet..."
bash ${SCRIPT_DIR}/00_prepare_samplesheet.sh "${SAMPLESHEET}" "${OUTDIR}"

# Use the prepared files
UNIQUE_SAMPLES="${OUTDIR}/samples_unique.txt"
SAMPLE_FILES="${OUTDIR}/sample_files.tsv"

# Count unique samples
N_SAMPLES=$(wc -l < ${UNIQUE_SAMPLES})
if [ ${N_SAMPLES} -eq 0 ]; then
    echo "ERROR: No samples found in samplesheet"
    exit 1
fi

echo "Number of unique samples: ${N_SAMPLES}"
echo "========================================"

# Update array sizes in all scripts
echo ""
echo "Updating array sizes in scripts..."
for script in ${SCRIPT_DIR}/{02,03,04,05,06,07,08}_*.sh; do
    if [ -f "$script" ]; then
        sed -i "s/#SBATCH --array=1-[0-9]\+/#SBATCH --array=1-${N_SAMPLES}/" "$script"
        echo "  Updated: $(basename $script)"
    fi
done

# Clean up any backup files
rm -f ${SCRIPT_DIR}/{02,03,04,05,06,07,08}_*.sh.bak 2>/dev/null || true

# Track job IDs
declare -A JOB_IDS

# Step 1: Genome preparation
if [ "${SKIP_GENOME_PREP}" = false ]; then
    if [ -z "${GENOME_FASTA}" ] || [ -z "${GTF_FILE}" ]; then
        echo ""
        echo "WARNING: Genome preparation requested but --genome and --gtf not provided"
        echo "Skipping genome preparation step"
        echo "Ensure reference indices exist in: ${REFERENCE_DIR}"
    else
        echo ""
        echo "Submitting genome preparation..."
        JOB_GENOME=$(sbatch --parsable \
            --export=GENOME_FASTA=${GENOME_FASTA},GTF_FILE=${GTF_FILE},OUTPUT_DIR=${REFERENCE_DIR} \
            ${SCRIPT_DIR}/01_prepare_genome.sh)
        JOB_IDS[GENOME]=$JOB_GENOME
        echo "  Job ID: ${JOB_GENOME}"
    fi
fi

# Step 2: FastQC on raw reads
if [ "${SKIP_QC_RAW}" = false ]; then
    echo ""
    echo "Submitting FastQC on raw reads..."
    JOB_QC_RAW=$(sbatch --parsable \
        --export=SAMPLE_FILES=${SAMPLE_FILES},UNIQUE_SAMPLES=${UNIQUE_SAMPLES},OUTPUT_DIR=${OUTDIR}/fastqc_raw \
        ${SCRIPT_DIR}/02_fastqc_raw.sh)
    JOB_IDS[QC_RAW]=$JOB_QC_RAW
    echo "  Job ID: ${JOB_QC_RAW}"
fi

# Step 3: Fastp trimming
echo ""
echo "Submitting fastp trimming..."
JOB_TRIM=$(sbatch --parsable \
    --export=SAMPLE_FILES=${SAMPLE_FILES},UNIQUE_SAMPLES=${UNIQUE_SAMPLES},OUTPUT_DIR=${OUTDIR}/fastp \
    ${SCRIPT_DIR}/03_fastp_trimming.sh)
JOB_IDS[TRIM]=$JOB_TRIM
echo "  Job ID: ${JOB_TRIM}"

# Step 4: STAR alignment
echo ""
echo "Submitting STAR alignment..."
STAR_DEPS="--dependency=afterok:${JOB_TRIM}"
if [ ! -z "${JOB_IDS[GENOME]:-}" ]; then
    STAR_DEPS="${STAR_DEPS}:${JOB_IDS[GENOME]}"
fi

# Prepare GTF export if available
GTF_EXPORT=""
if [ ! -z "${GTF_FILE}" ]; then
    GTF_EXPORT=",GTF_FILE=${GTF_FILE}"
fi

JOB_STAR=$(sbatch --parsable ${STAR_DEPS} \
    --export=SAMPLE_FILES=${SAMPLE_FILES},UNIQUE_SAMPLES=${UNIQUE_SAMPLES},TRIMMED_DIR=${OUTDIR}/fastp,STAR_INDEX=${REFERENCE_DIR}/star_index${GTF_EXPORT},OUTPUT_DIR=${OUTDIR}/star \
    ${SCRIPT_DIR}/04_star_alignment.sh)
JOB_IDS[STAR]=$JOB_STAR
echo "  Job ID: ${JOB_STAR}"

# Step 5: Mark duplicates with Picard
echo ""
echo "Submitting Picard MarkDuplicates..."
MARKDUP_DEPS="--dependency=afterok:${JOB_STAR}"
JOB_MARKDUP=$(sbatch --parsable ${MARKDUP_DEPS} \
    --export=SAMPLE_FILES=${SAMPLE_FILES},UNIQUE_SAMPLES=${UNIQUE_SAMPLES},STAR_DIR=${OUTDIR}/star,OUTPUT_DIR=${OUTDIR}/markduplicates \
    ${SCRIPT_DIR}/05_mark_duplicates.sh)
JOB_IDS[MARKDUP]=$JOB_MARKDUP
echo "  Job ID: ${JOB_MARKDUP}"

# Step 6: StringTie transcript assembly
echo ""
echo "Submitting StringTie..."
STRINGTIE_DEPS="--dependency=afterok:${JOB_MARKDUP}"
if [ ! -z "${GTF_FILE}" ]; then
    GTF_EXPORT=",GTF_FILE=${GTF_FILE}"
else
    GTF_EXPORT=""
fi
JOB_STRINGTIE=$(sbatch --parsable ${STRINGTIE_DEPS} \
    --export=SAMPLE_FILES=${SAMPLE_FILES},UNIQUE_SAMPLES=${UNIQUE_SAMPLES},INPUT_DIR=${OUTDIR}/markduplicates${GTF_EXPORT},OUTPUT_DIR=${OUTDIR}/stringtie \
    ${SCRIPT_DIR}/06_stringtie.sh)
JOB_IDS[STRINGTIE]=$JOB_STRINGTIE
echo "  Job ID: ${JOB_STRINGTIE}"

# Step 7: Salmon quantification
echo ""
echo "Submitting Salmon quantification..."
SALMON_DEPS="--dependency=afterok:${JOB_STAR}"
if [ ! -z "${JOB_IDS[GENOME]:-}" ]; then
    SALMON_DEPS="${SALMON_DEPS}:${JOB_IDS[GENOME]}"
fi

# Prepare GTF export if available
GTF_EXPORT=""
if [ ! -z "${GTF_FILE}" ]; then
    GTF_EXPORT=",GTF_FILE=${GTF_FILE}"
fi

JOB_SALMON=$(sbatch --parsable ${SALMON_DEPS} \
    --export=SAMPLE_FILES=${SAMPLE_FILES},UNIQUE_SAMPLES=${UNIQUE_SAMPLES},STAR_DIR=${OUTDIR}/star,SALMON_INDEX=${REFERENCE_DIR}/salmon_index${GTF_EXPORT},OUTPUT_DIR=${OUTDIR}/salmon \
    ${SCRIPT_DIR}/07_salmon_quantification.sh)
JOB_IDS[SALMON]=$JOB_SALMON
echo "  Job ID: ${JOB_SALMON}"

# Step 8: Kallisto quantification
echo ""
echo "Submitting Kallisto quantification..."
KALLISTO_DEPS="--dependency=afterok:${JOB_TRIM}"
if [ ! -z "${JOB_IDS[GENOME]:-}" ]; then
    KALLISTO_DEPS="${KALLISTO_DEPS}:${JOB_IDS[GENOME]}"
fi
JOB_KALLISTO=$(sbatch --parsable ${KALLISTO_DEPS} \
    --export=SAMPLE_FILES=${SAMPLE_FILES},UNIQUE_SAMPLES=${UNIQUE_SAMPLES},TRIMMED_DIR=${OUTDIR}/fastp,KALLISTO_INDEX=${REFERENCE_DIR}/kallisto_index/transcripts.idx,OUTPUT_DIR=${OUTDIR}/kallisto \
    ${SCRIPT_DIR}/08_kallisto_quantification.sh)
JOB_IDS[KALLISTO]=$JOB_KALLISTO
echo "  Job ID: ${JOB_KALLISTO}"

# Step 9: tximport
echo ""
echo "Submitting tximport..."
TXIMPORT_DEPS="--dependency=afterok:${JOB_SALMON}:${JOB_KALLISTO}"
if [ ! -z "${GTF_FILE}" ]; then
    GTF_EXPORT=",GTF_FILE=${GTF_FILE}"
else
    GTF_EXPORT=""
fi
JOB_TXIMPORT=$(sbatch --parsable ${TXIMPORT_DEPS} \
    --export=UNIQUE_SAMPLES=${UNIQUE_SAMPLES},SALMON_DIR=${OUTDIR}/salmon,KALLISTO_DIR=${OUTDIR}/kallisto${GTF_EXPORT},OUTPUT_DIR=${OUTDIR}/tximport \
    ${SCRIPT_DIR}/09_tximport.sh)
JOB_IDS[TXIMPORT]=$JOB_TXIMPORT
echo "  Job ID: ${JOB_TXIMPORT}"

# Step 10: DESeq2 QC
echo ""
echo "Submitting DESeq2 QC..."
DESEQ2_DEPS="--dependency=afterok:${JOB_TXIMPORT}"
JOB_DESEQ2=$(sbatch --parsable ${DESEQ2_DEPS} \
    --export=COUNTS_FILE=${OUTDIR}/tximport/salmon_gene_counts.tsv,OUTPUT_DIR=${OUTDIR}/deseq2_qc,UNIQUE_SAMPLES=${UNIQUE_SAMPLES} \
    ${SCRIPT_DIR}/10_deseq2_qc.sh)
JOB_IDS[DESEQ2]=$JOB_DESEQ2
echo "  Job ID: ${JOB_DESEQ2}"

# Step 11: MultiQC report
echo ""
echo "Submitting MultiQC report generation..."
JOB_MULTIQC=$(sbatch --parsable \
    --dependency=afterok:${JOB_STRINGTIE}:${JOB_DESEQ2} \
    --export=RESULTS_DIR=${OUTDIR},OUTPUT_DIR=${OUTDIR}/multiqc \
    ${SCRIPT_DIR}/11_multiqc_report.sh)
JOB_IDS[MULTIQC]=$JOB_MULTIQC
echo "  Job ID: ${JOB_MULTIQC}"

# Summary
echo ""
echo "========================================"
echo "Pipeline Submitted Successfully!"
echo "========================================"
echo "All jobs have been submitted with dependencies."
echo ""
echo "Job Summary:"
[ ! -z "${JOB_IDS[GENOME]:-}" ] && echo "  Genome Prep:   ${JOB_IDS[GENOME]}"
[ ! -z "${JOB_IDS[QC_RAW]:-}" ] && echo "  QC Raw:        ${JOB_IDS[QC_RAW]}"
echo "  Trimming:      ${JOB_IDS[TRIM]}"
echo "  STAR:          ${JOB_IDS[STAR]}"
echo "  MarkDup:       ${JOB_IDS[MARKDUP]}"
echo "  StringTie:     ${JOB_IDS[STRINGTIE]}"
echo "  Salmon:        ${JOB_IDS[SALMON]}"
echo "  Kallisto:      ${JOB_IDS[KALLISTO]}"
echo "  tximport:      ${JOB_IDS[TXIMPORT]}"
echo "  DESeq2 QC:     ${JOB_IDS[DESEQ2]}"
echo "  MultiQC:       ${JOB_IDS[MULTIQC]}"
echo ""
echo "Monitor jobs with: squeue -u \$USER"
echo "Check logs in: ./logs/"
echo ""
