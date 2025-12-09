#!/bin/bash
# validate_samplesheet.sh
# Utility script to validate samplesheet before submission

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

# Count samples
N_SAMPLES=$(tail -n +2 "${SAMPLESHEET}" | grep -v '^$' | wc -l)

if [ ${N_SAMPLES} -eq 0 ]; then
    echo "❌ ERROR: No samples found in samplesheet"
    exit 1
fi

echo "✓ Found ${N_SAMPLES} samples"

# Check each sample
echo ""
echo "Validating samples:"
echo ""

ERROR_COUNT=0
LINE_NUM=1

while IFS=',' read -r SAMPLE FASTQ_1 FASTQ_2 STRANDEDNESS; do
    LINE_NUM=$((LINE_NUM + 1))
    
    # Skip header
    if [ ${LINE_NUM} -eq 2 ]; then
        continue
    fi
    
    # Skip empty lines
    if [ -z "${SAMPLE}" ]; then
        continue
    fi
    
    echo "Sample: ${SAMPLE}"
    
    # Check sample name
    if [ -z "${SAMPLE}" ]; then
        echo "  ❌ Empty sample name at line ${LINE_NUM}"
        ERROR_COUNT=$((ERROR_COUNT + 1))
    else
        echo "  ✓ Sample name: ${SAMPLE}"
    fi
    
    # Check FASTQ_1
    if [ -z "${FASTQ_1}" ]; then
        echo "  ❌ Missing FASTQ_1 at line ${LINE_NUM}"
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
    
done < "${SAMPLESHEET}"

echo "========================================"
echo "Validation Summary"
echo "========================================"
echo "Total samples: ${N_SAMPLES}"
echo "Errors found: ${ERROR_COUNT}"

if [ ${ERROR_COUNT} -eq 0 ]; then
    echo ""
    echo "✓ Samplesheet is valid!"
    echo ""
    echo "Ready to submit pipeline with:"
    echo "  ./submit_pipeline.sh --samplesheet ${SAMPLESHEET}"
    exit 0
else
    echo ""
    echo "❌ Please fix errors before submitting pipeline"
    exit 1
fi
