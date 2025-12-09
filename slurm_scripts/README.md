# SLURM Scripts for RNA-seq Pipeline

This directory contains SLURM batch scripts for running an RNA-seq analysis pipeline on a SLURM cluster. The scripts are designed to process samples in parallel using SLURM array jobs.

## Pipeline Overview

The pipeline follows these steps:

1. **Genome Preparation** - Build STAR, Salmon, and Kallisto indices
2. **Quality Control (Raw)** - FastQC on raw reads
3. **Trimming/Filtering** - fastp for adapter trimming and quality filtering
4. **Alignment** - STAR alignment to reference genome
5. **Quantification (STAR-Salmon)** - Salmon quantification from STAR transcriptome BAM
6. **Quantification (Kallisto)** - Kallisto pseudo-alignment and quantification
7. **MultiQC Report** - Comprehensive quality control report

## Requirements

### Conda Environment

Create the conda environment with all required tools:

```bash
# Option 1: Standard installation (may take long with older conda)
conda env create -f environment.yml

# Option 2: For older conda versions, generate and use explicit specification
conda env create -f environment.yml
conda activate rnaseq
conda list --explicit > environment_explicit_generated.txt
# Save this file for future quick installations
conda create -n rnaseq --file environment_explicit_generated.txt
```

### Input Files

1. **Samplesheet** (`samplesheet.csv`): CSV file with sample information
   ```
   sample,fastq_1,fastq_2,strandedness
   sample1,/path/to/sample1_R1.fastq.gz,/path/to/sample1_R2.fastq.gz,reverse
   sample2,/path/to/sample2_R1.fastq.gz,/path/to/sample2_R2.fastq.gz,reverse
   sample3,/path/to/sample3_R1.fastq.gz,,unstranded
   ```

2. **Reference Genome Files**:
   - Genome FASTA file
   - Gene annotation GTF file

## Usage

### Step 1: Prepare Reference Genome (One-time setup)

Edit the script to set paths to your reference files, then submit:

```bash
# Edit these variables in 01_prepare_genome.sh:
# - GENOME_FASTA
# - GTF_FILE
# - OUTPUT_DIR

sbatch slurm_scripts/01_prepare_genome.sh
```

### Step 2: Quality Control on Raw Reads

Update the array size based on number of samples in your samplesheet:

```bash
# Count samples (excluding header)
N_SAMPLES=$(tail -n +2 samplesheet.csv | wc -l)

# Edit #SBATCH --array=1-N in the script
# Replace N with the actual number
sed -i "s/#SBATCH --array=1-N/#SBATCH --array=1-${N_SAMPLES}/" slurm_scripts/02_fastqc_raw.sh

# Submit the job
sbatch slurm_scripts/02_fastqc_raw.sh
```

### Step 3: Trimming with fastp

```bash
# Update array size if not done already
sed -i "s/#SBATCH --array=1-N/#SBATCH --array=1-${N_SAMPLES}/" slurm_scripts/03_fastp_trimming.sh

# Submit the job
sbatch slurm_scripts/03_fastp_trimming.sh
```

### Step 4: STAR Alignment

```bash
# Update array size
sed -i "s/#SBATCH --array=1-N/#SBATCH --array=1-${N_SAMPLES}/" slurm_scripts/04_star_alignment.sh

# Submit the job (can submit after trimming jobs start)
# Add dependency if you want to wait for trimming to complete
JOB_ID_TRIM=$(sbatch --parsable slurm_scripts/03_fastp_trimming.sh)
sbatch --dependency=afterok:${JOB_ID_TRIM} slurm_scripts/04_star_alignment.sh

# Or submit independently if trimming is already done
sbatch slurm_scripts/04_star_alignment.sh
```

### Step 5: Salmon Quantification (STAR-Salmon pathway)

```bash
# Update array size
sed -i "s/#SBATCH --array=1-N/#SBATCH --array=1-${N_SAMPLES}/" slurm_scripts/05_salmon_quantification.sh

# Submit with dependency on STAR
JOB_ID_STAR=$(sbatch --parsable slurm_scripts/04_star_alignment.sh)
sbatch --dependency=afterok:${JOB_ID_STAR} slurm_scripts/05_salmon_quantification.sh
```

### Step 6: Kallisto Quantification

```bash
# Update array size
sed -i "s/#SBATCH --array=1-N/#SBATCH --array=1-${N_SAMPLES}/" slurm_scripts/06_kallisto_quantification.sh

# Submit with dependency on trimming
JOB_ID_TRIM=$(sbatch --parsable slurm_scripts/03_fastp_trimming.sh)
sbatch --dependency=afterok:${JOB_ID_TRIM} slurm_scripts/06_kallisto_quantification.sh
```

### Step 7: MultiQC Report

Run after all analysis steps are complete:

```bash
# Submit with dependencies on all quantification jobs
JOB_ID_SALMON=$(sbatch --parsable slurm_scripts/05_salmon_quantification.sh)
JOB_ID_KALLISTO=$(sbatch --parsable slurm_scripts/06_kallisto_quantification.sh)
sbatch --dependency=afterok:${JOB_ID_SALMON}:${JOB_ID_KALLISTO} slurm_scripts/07_multiqc_report.sh
```

## Automated Submission Script

For convenience, you can create a master submission script:

```bash
#!/bin/bash
# submit_all.sh

set -euo pipefail

# Count samples
N_SAMPLES=$(tail -n +2 samplesheet.csv | wc -l)
echo "Number of samples: ${N_SAMPLES}"

# Update array sizes in all scripts
for script in slurm_scripts/{02,03,04,05,06}_*.sh; do
    sed -i "s/#SBATCH --array=1-[0-9]\+/#SBATCH --array=1-${N_SAMPLES}/" $script
done

# Submit genome preparation (if not done)
# JOB_GENOME=$(sbatch --parsable slurm_scripts/01_prepare_genome.sh)

# Submit QC on raw reads
JOB_QC_RAW=$(sbatch --parsable slurm_scripts/02_fastqc_raw.sh)

# Submit trimming
JOB_TRIM=$(sbatch --parsable slurm_scripts/03_fastp_trimming.sh)

# Submit STAR alignment (depends on trimming)
JOB_STAR=$(sbatch --parsable --dependency=afterok:${JOB_TRIM} slurm_scripts/04_star_alignment.sh)

# Submit Salmon quantification (depends on STAR)
JOB_SALMON=$(sbatch --parsable --dependency=afterok:${JOB_STAR} slurm_scripts/05_salmon_quantification.sh)

# Submit Kallisto quantification (depends on trimming)
JOB_KALLISTO=$(sbatch --parsable --dependency=afterok:${JOB_TRIM} slurm_scripts/06_kallisto_quantification.sh)

# Submit MultiQC (depends on all quantifications)
JOB_MULTIQC=$(sbatch --parsable --dependency=afterok:${JOB_SALMON}:${JOB_KALLISTO} slurm_scripts/07_multiqc_report.sh)

echo "Jobs submitted:"
echo "  QC Raw: ${JOB_QC_RAW}"
echo "  Trimming: ${JOB_TRIM}"
echo "  STAR: ${JOB_STAR}"
echo "  Salmon: ${JOB_SALMON}"
echo "  Kallisto: ${JOB_KALLISTO}"
echo "  MultiQC: ${JOB_MULTIQC}"
```

## Configuration

### SLURM Parameters

You may need to adjust these parameters in each script based on your cluster configuration:

- `--partition`: Change to your cluster's partition name
- `--time`: Adjust based on your data size
- `--cpus-per-task`: Adjust based on available resources
- `--mem`: Adjust based on available memory

### Environment Variables

Each script accepts environment variables for configuration. Set these before submission:

```bash
export SAMPLESHEET=/path/to/samplesheet.csv
export GENOME_FASTA=/path/to/genome.fa
export GTF_FILE=/path/to/annotations.gtf
export OUTPUT_DIR=/path/to/results

sbatch slurm_scripts/03_fastp_trimming.sh
```

## Output Structure

```
results/
├── fastqc_raw/          # FastQC reports on raw reads
├── fastp/               # Trimmed reads and reports
├── star/                # STAR alignments
│   └── sample1/
│       ├── sample1_Aligned.sortedByCoord.out.bam
│       ├── sample1_Aligned.toTranscriptome.out.bam
│       └── sample1_Log.final.out
├── salmon/              # Salmon quantification
│   └── sample1/
│       └── quant.sf
├── kallisto/            # Kallisto quantification
│   └── sample1/
│       └── abundance.tsv
└── multiqc/             # MultiQC report
    └── rnaseq_multiqc_report.html
```

## Monitoring Jobs

```bash
# Check job status
squeue -u $USER

# Check specific array job
squeue -j <job_id>

# Check job details
scontrol show job <job_id>

# View log files
tail -f logs/03_fastp_trim_<jobid>_<array_task_id>.out
```

## Tools Versions

- FastQC: 0.12.1
- fastp: 0.24.0
- STAR: 2.7.11b
- Samtools: 1.21
- Salmon: 1.10.3
- Kallisto: 0.51.1
- MultiQC: 1.31
- gffread: 0.12.7

See `environment.yml` for complete list of dependencies.

## Notes

1. **Array Job Indices**: The scripts use 1-based indexing for array jobs and skip the header line (line 1) of the samplesheet.

2. **Strandedness**: Ensure the strandedness column in your samplesheet is correctly set:
   - `forward`: Forward stranded
   - `reverse`: Reverse stranded
   - `unstranded`: Unstranded
   - `auto`: Automatic detection (Salmon only)

3. **Resource Requirements**: Adjust memory and CPU allocations based on:
   - Genome size (larger genomes need more memory for STAR)
   - Read depth (higher depth needs more processing time)
   - Number of samples (for array job limits)

4. **Storage**: Ensure sufficient storage space:
   - STAR index: ~30-50 GB (human genome)
   - BAM files: Variable, typically 2-10 GB per sample
   - Raw and trimmed FASTQ: Keep originals, trimmed copies

## Troubleshooting

**Problem**: "conda: command not found"
**Solution**: Source conda initialization script in your `~/.bashrc` or load conda module

**Problem**: "Unable to locate a modulefile"
**Solution**: Conda activation failed; ensure conda is properly installed

**Problem**: Array job fails for some samples
**Solution**: Check individual log files in `logs/` directory for specific errors

**Problem**: Out of memory errors
**Solution**: Increase `--mem` parameter in SBATCH directives

## References

- nf-core/rnaseq pipeline: https://nf-co.re/rnaseq
- STAR manual: https://github.com/alexdobin/STAR/blob/master/doc/STARmanual.pdf
- Salmon documentation: https://salmon.readthedocs.io/
- Kallisto manual: https://pachterlab.github.io/kallisto/manual
