#!/bin/bash
# check_jobs.sh
# Utility script to check status of pipeline jobs

set -euo pipefail

echo "========================================"
echo "RNA-seq Pipeline Job Status"
echo "========================================"
echo ""

# Get user's jobs
echo "Your SLURM Jobs:"
squeue -u $USER -o "%.18i %.9P %.30j %.8T %.10M %.6D %R"

echo ""
echo "Job Summary:"
squeue -u $USER --format="%.10T" | tail -n +2 | sort | uniq -c

echo ""
echo "========================================"
echo "Recent Log Files (last 5):"
echo "========================================"
if [ -d "logs" ]; then
    ls -lth logs/ | head -6
else
    echo "No logs directory found"
fi

echo ""
echo "========================================"
echo "Pipeline Progress Check:"
echo "========================================"

# Check for completed steps
check_step() {
    local step=$1
    local dir=$2
    if [ -d "$dir" ] && [ "$(ls -A $dir 2>/dev/null)" ]; then
        echo "✓ $step: COMPLETED"
        echo "  Files: $(find $dir -type f | wc -l)"
    else
        echo "✗ $step: NOT STARTED or IN PROGRESS"
    fi
}

if [ -d "results" ]; then
    check_step "FastQC Raw" "results/fastqc_raw"
    check_step "Fastp Trimming" "results/fastp"
    check_step "STAR Alignment" "results/star"
    check_step "Salmon Quantification" "results/salmon"
    check_step "Kallisto Quantification" "results/kallisto"
    check_step "MultiQC Report" "results/multiqc"
    
    echo ""
    if [ -f "results/multiqc/rnaseq_multiqc_report.html" ]; then
        echo "🎉 MultiQC Report Ready: results/multiqc/rnaseq_multiqc_report.html"
    fi
else
    echo "No results directory found. Pipeline may not have started."
fi

echo ""
