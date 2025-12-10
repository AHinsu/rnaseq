#!/bin/bash
# cancel_pipeline.sh
# Utility script to cancel all running pipeline jobs

set -euo pipefail

echo "========================================"
echo "Cancel RNA-seq Pipeline Jobs"
echo "========================================"
echo ""

# Get all job IDs for the user with pipeline-related names
JOB_NAMES=("prepare_genome" "fastqc_raw" "fastp_trim" "star_align" "salmon_quant" "kallisto_quant" "multiqc")

echo "Finding pipeline jobs to cancel..."
echo ""

for job_name in "${JOB_NAMES[@]}"; do
    # Find jobs matching this name
    job_ids=$(squeue -u $USER -n $job_name -h -o "%A" 2>/dev/null || true)
    
    if [ ! -z "$job_ids" ]; then
        echo "Found jobs for: $job_name"
        for job_id in $job_ids; do
            echo "  Canceling job: $job_id"
            scancel $job_id
        done
    fi
done

echo ""
echo "All pipeline jobs cancelled."
echo ""
echo "Current job status:"
squeue -u $USER

echo ""
