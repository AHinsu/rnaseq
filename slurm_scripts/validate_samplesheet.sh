#!/bin/bash
# validate_samplesheet.sh
# Utility script to validate samplesheet before submission
# This script incorporates logic from 00_prepare_samplesheet.sh to handle
# multiple FASTQ file pairs per sample

set -euo pipefail

SAMPLESHEET="${1:-samplesheet.csv}"

echo "========================================"
echo "Samplesheet Validation"
echo "========================================"
echo "Checking: ${SAMPLESHEET}"
echo ""

# Check if file exists
if [ ! -f "${SAMPLESHEET}" ]; then
    echo "❌ ERROR: Samplesheet not found: ${SAMPLESHEET}"
    exit 1
fi

echo "✓ File exists"

# Check header
HEADER=$(head -1 "${SAMPLESHEET}")
EXPECTED_HEADER="sample,fastq_1,fastq_2,strandedness"

if [ "${HEADER}" != "${EXPECTED_HEADER}" ]; then
    echo "❌ ERROR: Invalid header"
    echo "   Expected: ${EXPECTED_HEADER}"
    echo "   Found: ${HEADER}"
    exit 1
fi

echo "✓ Header is valid"

# Count total rows (including duplicate samples)
N_ROWS=$(tail -n +2 "${SAMPLESHEET}" | grep -v '^$' | wc -l)

if [ ${N_ROWS} -eq 0 ]; then
    echo "❌ ERROR: No samples found in samplesheet"
    exit 1
fi

echo "✓ Found ${N_ROWS} total rows"

# Count unique samples (like 00_prepare_samplesheet.sh does)
N_UNIQUE=$(tail -n +2 "${SAMPLESHEET}" | cut -d',' -f1 | sort -u | wc -l)

echo "✓ Found ${N_UNIQUE} unique samples"

if [ ${N_UNIQUE} -lt ${N_ROWS} ]; then
    echo "ℹ Note: Some samples have multiple FASTQ file pairs"
    echo "  Total rows: ${N_ROWS}"
    echo "  Unique samples: ${N_UNIQUE}"
    echo "  Array jobs will use: 1-${N_UNIQUE}"
fi

# Check each sample/row
echo ""
echo "Validating samples and file paths:"
echo ""

ERROR_COUNT=0
ROW_NUM=0

# First, get unique samples
declare -A SAMPLE_ROW_COUNT
while IFS=',' read -r SAMPLE FASTQ_1 FASTQ_2 STRANDEDNESS; do
    # Skip empty lines
    if [ -z "${SAMPLE}" ]; then
        continue
    fi
    SAMPLE_ROW_COUNT["${SAMPLE}"]=$((${SAMPLE_ROW_COUNT["${SAMPLE}"]:-0} + 1))
done < <(tail -n +2 "${SAMPLESHEET}")

# Now validate each row
while IFS=',' read -r SAMPLE FASTQ_1 FASTQ_2 STRANDEDNESS; do
    # Skip empty lines
    if [ -z "${SAMPLE}" ]; then
        continue
    fi
    
    ROW_NUM=$((ROW_NUM + 1))
    
    # Show if sample has multiple rows
    if [ ${SAMPLE_ROW_COUNT["${SAMPLE}"]} -gt 1 ]; then
        echo "Row ${ROW_NUM}: ${SAMPLE} (${SAMPLE_ROW_COUNT["${SAMPLE}"]} FASTQ pairs total)"
    else
        echo "Row ${ROW_NUM}: ${SAMPLE}"
    fi
    
    # Check FASTQ_1
    if [ -z "${FASTQ_1}" ]; then
        echo "  ❌ Missing FASTQ_1"
        ERROR_COUNT=$((ERROR_COUNT + 1))
    else
        if [ -f "${FASTQ_1}" ]; then
            echo "  ✓ FASTQ_1 exists: ${FASTQ_1}"
        else
            echo "  ⚠ FASTQ_1 not found (will fail at runtime): ${FASTQ_1}"
        fi
    fi
    
    # Check FASTQ_2 (optional)
    if [ -n "${FASTQ_2}" ]; then
        if [ -f "${FASTQ_2}" ]; then
            echo "  ✓ FASTQ_2 exists: ${FASTQ_2}"
        else
            echo "  ⚠ FASTQ_2 not found (will fail at runtime): ${FASTQ_2}"
        fi
    else
        echo "  ℹ Single-end sample (no FASTQ_2)"
    fi
    
    # Check strandedness
    VALID_STRAND=("forward" "reverse" "unstranded" "auto")
    if [[ ! " ${VALID_STRAND[@]} " =~ " ${STRANDEDNESS} " ]]; then
        echo "  ❌ Invalid strandedness: ${STRANDEDNESS}"
        echo "     Valid options: forward, reverse, unstranded, auto"
        ERROR_COUNT=$((ERROR_COUNT + 1))
    else
        echo "  ✓ Strandedness: ${STRANDEDNESS}"
    fi
    
    echo ""
    
done < <(tail -n +2 "${SAMPLESHEET}")

echo "========================================"
echo "Validation Summary"
echo "========================================"
echo "Total rows: ${N_ROWS}"
echo "Unique samples: ${N_UNIQUE}"
echo "Errors found: ${ERROR_COUNT}"

if [ ${ERROR_COUNT} -eq 0 ]; then
    echo ""
    echo "✓ Samplesheet is valid!"
    echo ""
    if [ ${N_UNIQUE} -lt ${N_ROWS} ]; then
        echo "ℹ Note: Multiple FASTQ pairs detected for some samples"
        echo "  - 00_prepare_samplesheet.sh will merge them automatically"
        echo "  - Array jobs will use 1-${N_UNIQUE} (unique samples)"
        echo ""
    fi
    echo "Ready to submit pipeline with:"
    echo "  ./submit_pipeline.sh --samplesheet ${SAMPLESHEET}"
    exit 0
else
    echo ""
    echo "❌ Please fix errors before submitting pipeline"
    exit 1
fi
