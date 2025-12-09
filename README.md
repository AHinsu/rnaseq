<h1>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/images/nf-core-rnaseq_logo_dark.png">
    <img alt="RNA-seq Pipeline" src="docs/images/nf-core-rnaseq_logo_light.png">
  </picture>
</h1>

# RNA-seq SLURM Pipeline

A comprehensive collection of SLURM batch scripts for running RNA-seq analysis on HPC clusters. Based on the nf-core/rnaseq pipeline workflows, adapted for direct execution on SLURM job schedulers without Nextflow dependencies.

[![Get help on Slack](http://img.shields.io/badge/slack-nf--core%20%23rnaseq-4A154B?labelColor=000000&logo=slack)](https://nfcore.slack.com/channels/rnaseq)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)

## Introduction

This repository provides **SLURM batch scripts** for RNA sequencing data analysis on HPC clusters. The pipeline implements a comprehensive RNA-seq workflow using industry-standard tools, designed for parallel processing via SLURM array jobs.

![RNA-seq pipeline metro map](docs/images/nf-core-rnaseq_metro_map_grey.svg)

> In case the image above is not loading, please have a look at the [static version](docs/images/nf-core-rnaseq_metro_map_grey.png).

## Pipeline Steps

The pipeline implements the following analysis steps:

1. **Read QC** ([`FastQC`](https://www.bioinformatics.babraham.ac.uk/projects/fastqc/))
2. **Adapter and quality trimming** ([`fastp`](https://github.com/OpenGene/fastp))
3. **Alignment** ([`STAR`](https://github.com/alexdobin/STAR))
4. **Sort and index alignments** ([`SAMtools`](https://sourceforge.net/projects/samtools/files/samtools/))
5. **Duplicate read marking** ([`picard MarkDuplicates`](https://broadinstitute.github.io/picard/))
6. **Transcript assembly and quantification** ([`StringTie`](https://ccb.jhu.edu/software/stringtie/))
7. **Transcript quantification from alignment** ([`Salmon`](https://combine-lab.github.io/salmon/))
8. **Pseudo-alignment and quantification** ([`Kallisto`](https://pachterlab.github.io/kallisto/))
9. **Gene-level import and summarization** ([`tximport`](https://bioconductor.org/packages/release/bioc/html/tximport.html))
10. **Quality control visualizations** ([`DESeq2`](https://bioconductor.org/packages/release/bioc/html/DESeq2.html))
11. **Aggregate QC reporting** ([`MultiQC`](http://multiqc.info/))

## Quick Start

### 1. Setup Environment

```bash
# Clone the repository
git clone https://github.com/AHinsu/rnaseq.git
cd rnaseq

# Create conda environment
conda env create -f environment.yml
conda activate rnaseq
```

> **Note**: For older conda versions that have slow dependency resolution, see [CONDA_SETUP.md](CONDA_SETUP.md) for optimized installation methods.

### 2. Prepare Input

Create a samplesheet with your input data:

**samplesheet.csv**:

```csv
sample,fastq_1,fastq_2,strandedness
CONTROL_REP1,/path/to/reads/CONTROL_REP1_R1.fastq.gz,/path/to/reads/CONTROL_REP1_R2.fastq.gz,reverse
CONTROL_REP2,/path/to/reads/CONTROL_REP2_R1.fastq.gz,/path/to/reads/CONTROL_REP2_R2.fastq.gz,reverse
TREATMENT_REP1,/path/to/reads/TREATMENT_REP1_R1.fastq.gz,/path/to/reads/TREATMENT_REP1_R2.fastq.gz,reverse
```

Each row represents a FASTQ file (single-end) or pair of FASTQ files (paired-end). The strandedness column specifies library preparation:
- `forward`: Forward stranded (ISF for Salmon)
- `reverse`: Reverse stranded (ISR for Salmon) - most common for Illumina TruSeq
- `unstranded`: Unstranded (IU for Salmon)
- `auto`: Automatic detection (Salmon only)

### 3. Prepare Reference Genome (One-time setup)

```bash
# Edit script to set your paths
nano slurm_scripts/01_prepare_genome.sh

# Submit genome preparation job
sbatch slurm_scripts/01_prepare_genome.sh
```

This builds STAR, Salmon, and Kallisto indices from your reference genome and GTF annotation.

### 4. Run the Pipeline

```bash
cd slurm_scripts

# Automated submission (recommended)
./submit_pipeline.sh \
    --samplesheet ../samplesheet.csv \
    --genome /path/to/genome.fa \
    --gtf /path/to/annotations.gtf \
    --outdir ../results \
    --skip-genome-prep  # if indices already exist
```

The automated script submits all pipeline steps with proper SLURM dependencies, managing job execution order automatically.

### 5. Monitor Progress

```bash
# Check job status
./check_jobs.sh

# View specific logs
tail -f logs/04_star_align_*_1.out

# Monitor with squeue
squeue -u $USER
```

## Pipeline Architecture

### SLURM Array Jobs

All sample-level processing steps use SLURM array jobs for efficient parallel execution:

```
Sample 1 ──┐
Sample 2 ──┼─→ [Array Job: 1-N] ─→ Parallel Processing
Sample N ──┘
```

Array job indices automatically scale based on the number of samples in your samplesheet.

### Workflow Diagram

```
Raw FASTQ Files
      ↓
[FastQC] ← Quality control on raw reads
      ↓
[fastp] ← Adapter trimming and quality filtering
      ↓
      ├─→ [STAR] ← Genome alignment
      │     ↓
      │   [MarkDuplicates] ← Mark duplicate reads (Picard)
      │     ↓
      │   [StringTie] ← Transcript assembly and quantification
      │     ↓
      │   [Salmon] ← Transcript quantification (alignment-based)
      │
      └─→ [Kallisto] ← Pseudo-alignment and quantification
            ↓
          [tximport] ← Import and summarize to gene-level
            ↓
          [DESeq2 QC] ← PCA and correlation plots
            ↓
          [MultiQC] ← Comprehensive QC report
```

## Output Structure

```
results/
├── fastqc_raw/          # FastQC reports on raw reads
├── fastp/               # Trimmed reads and QC reports
├── star/                # STAR alignments and gene counts
│   └── sample1/
│       ├── sample1_Aligned.sortedByCoord.out.bam
│       ├── sample1_Aligned.toTranscriptome.out.bam
│       └── sample1_ReadsPerGene.out.tab
├── markduplicates/      # Picard MarkDuplicates output
│   └── sample1/
│       ├── sample1.markdup.bam
│       └── sample1.MarkDuplicates.metrics.txt
├── stringtie/           # StringTie transcript assembly
│   └── sample1/
│       ├── sample1.transcripts.gtf
│       └── sample1.gene.abundance.txt
├── salmon/              # Salmon quantification
│   └── sample1/
│       └── quant.sf
├── kallisto/            # Kallisto quantification
│   └── sample1/
│       └── abundance.tsv
├── tximport/            # tximport gene-level summaries
│   ├── salmon_gene_counts.tsv
│   ├── salmon_gene_tpm.tsv
│   ├── kallisto_gene_counts.tsv
│   └── kallisto_gene_tpm.tsv
├── deseq2_qc/           # DESeq2 QC plots
│   ├── deseq2_pca_plot.png
│   ├── deseq2_sample_correlation_heatmap.png
│   └── deseq2_sample_distance_heatmap.png
└── multiqc/             # MultiQC report
    └── rnaseq_multiqc_report.html
```

## Scripts Overview

| Script | Description | Resources |
|--------|-------------|-----------|
| `01_prepare_genome.sh` | Build genome indices | 16 CPUs, 64GB, 24h |
| `02_fastqc_raw.sh` | QC on raw reads | 4 CPUs, 8GB, 4h |
| `03_fastp_trimming.sh` | Trim and filter reads | 8 CPUs, 16GB, 6h |
| `04_star_alignment.sh` | Align to genome | 16 CPUs, 64GB, 12h |
| `05_mark_duplicates.sh` | Mark duplicate reads | 4 CPUs, 32GB, 8h |
| `06_stringtie.sh` | Transcript assembly | 8 CPUs, 16GB, 6h |
| `07_salmon_quantification.sh` | Quantify with Salmon | 8 CPUs, 16GB, 4h |
| `08_kallisto_quantification.sh` | Quantify with Kallisto | 8 CPUs, 16GB, 4h |
| `09_tximport.sh` | Import transcript counts | 4 CPUs, 16GB, 2h |
| `10_deseq2_qc.sh` | Generate QC plots | 4 CPUs, 16GB, 2h |
| `11_multiqc_report.sh` | Generate QC report | 4 CPUs, 8GB, 2h |

### Utility Scripts

- `submit_pipeline.sh` - Automated pipeline submission with dependency management
- `check_jobs.sh` - Monitor pipeline progress
- `cancel_pipeline.sh` - Cancel all pipeline jobs
- `validate_samplesheet.sh` - Validate input data before submission

## Documentation

Comprehensive documentation is available:

- **[slurm_scripts/README.md](slurm_scripts/README.md)** - Detailed usage instructions and step-by-step guide
- **[CONDA_SETUP.md](CONDA_SETUP.md)** - Environment setup for older conda versions
- **[SLURM_PIPELINE_README.md](SLURM_PIPELINE_README.md)** - Quick start and configuration guide

## Tool Versions

- FastQC: 0.12.1
- fastp: 0.24.0
- STAR: 2.7.11b
- Samtools: 1.21
- Picard: 3.1.1
- StringTie: 2.2.3
- Salmon: 1.10.3
- Kallisto: 0.51.1
- MultiQC: 1.31
- R: 4.4.2 with DESeq2, tximport, tximeta

## Configuration

### Adjusting Resources

Edit the `#SBATCH` directives in each script to match your cluster configuration:

```bash
#SBATCH --cpus-per-task=16    # CPU cores
#SBATCH --mem=64G             # Memory
#SBATCH --time=12:00:00       # Time limit
#SBATCH --partition=compute   # Your partition name
#SBATCH --mail-user=user@example.com  # Your email for notifications
```

### Centralized Logging

All scripts use a centralized logging format compatible with SLURM job tracking:

```bash
#SBATCH --output=logs/job-%j.%x.out  # %j = job ID, %x = job name
#SBATCH --error=logs/job-%j.%x.err
```

Logs are named as: `job-<JOBID>.<JOBNAME>.out` (e.g., `job-12345.04-star_alignment.out`)

### Email Notifications

All scripts include email notification settings. Edit the `--mail-user` directive:

```bash
#SBATCH --mail-type=ALL              # Mail events (NONE, BEGIN, END, FAIL, ALL)
#SBATCH --mail-user=your.email@institution.edu  # EDIT THIS
```

To disable email notifications, change `--mail-type=ALL` to `--mail-type=NONE`.

### Module Loading

If your cluster uses environment modules, uncomment and modify this line in each script:

```bash
# module load apps/anaconda-4.7.12.tcl
```

Scripts use `eval "$(conda shell.bash hook)"` for conda activation, which is compatible with most systems.

### Adjusting Tool Parameters

Tool command lines are clearly visible in each script and can be easily modified. For example, in `04_star_alignment.sh`:

```bash
STAR \
    --runThreadN ${THREADS} \
    --outFilterMultimapNmax 20 \    # Adjust as needed
    --alignIntronMax 1000000 \      # Adjust as needed
    ...
```

## Advantages of SLURM Implementation

1. **Transparent** - Clear, readable bash scripts
2. **Flexible** - Easy to modify tool parameters
3. **Efficient** - Parallel processing via array jobs
4. **Trackable** - Individual scripts for each pipeline step
5. **Portable** - No Nextflow/Java dependencies
6. **Debuggable** - Straightforward error investigation

## Troubleshooting

### Common Issues

**Problem**: Conda environment creation is slow  
**Solution**: See [CONDA_SETUP.md](CONDA_SETUP.md) for mamba or staged installation

**Problem**: SLURM job fails with memory error  
**Solution**: Increase `--mem` in script's `#SBATCH` directives

**Problem**: Array job indices don't match samples  
**Solution**: Verify samplesheet has no empty lines; check `#SBATCH --array=1-N`

For detailed troubleshooting, see [slurm_scripts/README.md](slurm_scripts/README.md).

## Citations

If you use this pipeline, please cite the tools:

- **STAR**: Dobin A, et al. (2013). STAR: ultrafast universal RNA-seq aligner. *Bioinformatics*.
- **Salmon**: Patro R, et al. (2017). Salmon provides fast and bias-aware quantification. *Nat Methods*.
- **Kallisto**: Bray NL, et al. (2016). Near-optimal probabilistic RNA-seq quantification. *Nat Biotechnol*.
- **fastp**: Chen S, et al. (2018). fastp: an ultra-fast all-in-one FASTQ preprocessor. *Bioinformatics*.
- **StringTie**: Pertea M, et al. (2015). StringTie enables improved reconstruction of a transcriptome. *Nat Biotechnol*.
- **Picard**: Broad Institute. Picard Tools. http://broadinstitute.github.io/picard/
- **DESeq2**: Love MI, et al. (2014). Moderated estimation of fold change and dispersion. *Genome Biology*.
- **MultiQC**: Ewels P, et al. (2016). MultiQC: summarize analysis results. *Bioinformatics*.

Full citation list available in [CITATIONS.md](CITATIONS.md).

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- Check documentation in [slurm_scripts/README.md](slurm_scripts/README.md)
- Review [CONDA_SETUP.md](CONDA_SETUP.md) for environment issues
- Examine logs in the `logs/` directory
- Open an issue on GitHub

## Acknowledgments

- Pipeline workflows based on [nf-core/rnaseq](https://nf-co.re/rnaseq)
- Adapted for SLURM cluster architecture
- Tool versions and parameters derived from nf-core modules
