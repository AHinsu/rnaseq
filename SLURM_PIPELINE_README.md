# SLURM-based RNA-seq Pipeline

This repository provides SLURM batch scripts for running an RNA-seq analysis pipeline on HPC clusters. The scripts are based on the nf-core/rnaseq pipeline and implement the following workflow:

- **Trimming**: fastp for adapter trimming and quality filtering
- **Alignment**: STAR aligner
- **Quantification**: Both STAR-Salmon and Kallisto pathways
- **Quality Control**: FastQC and MultiQC

The scripts exclude steps for bedGraphtoBigWig, RSeQC, QualiMap, PreSeq, dupRadar, and Kraken2/Bracken as requested.

## Features

- ✅ SLURM array jobs for parallel sample processing
- ✅ Automatic dependency management between pipeline steps
- ✅ Samplesheet-based architecture for easy sample management
- ✅ Both STAR-Salmon and Kallisto quantification pathways
- ✅ Comprehensive quality control with MultiQC
- ✅ Optimized for older conda versions with explicit environment files

## Quick Start

### 1. Setup Conda Environment

```bash
# For modern conda (>= 23.x)
conda env create -f environment.yml

# For older conda or faster installation, use mamba
conda install -n base -c conda-forge mamba
mamba env create -f environment.yml

# Activate environment
conda activate rnaseq
```

**Note**: For detailed conda setup instructions, especially for older conda versions, see [CONDA_SETUP.md](CONDA_SETUP.md).

### 2. Prepare Your Samplesheet

Create a CSV file with your samples (see `slurm_scripts/samplesheet_template.csv`):

```csv
sample,fastq_1,fastq_2,strandedness
sample1,/path/to/sample1_R1.fastq.gz,/path/to/sample1_R2.fastq.gz,reverse
sample2,/path/to/sample2_R1.fastq.gz,/path/to/sample2_R2.fastq.gz,reverse
sample3,/path/to/sample3_R1.fastq.gz,,unstranded
```

**Strandedness options**:
- `forward`: Forward stranded (ISF for Salmon)
- `reverse`: Reverse stranded (ISR for Salmon) - most common for Illumina TruSeq
- `unstranded`: Unstranded (IU for Salmon)
- `auto`: Automatic detection (Salmon only)

### 3. Prepare Reference Genome (One-time)

Edit and run the genome preparation script:

```bash
# Edit the script to set your paths
nano slurm_scripts/01_prepare_genome.sh

# Set these variables:
# GENOME_FASTA=/path/to/genome.fa
# GTF_FILE=/path/to/annotations.gtf
# OUTPUT_DIR=./reference

# Submit the job
sbatch slurm_scripts/01_prepare_genome.sh
```

This will create STAR, Salmon, and Kallisto indices.

### 4. Run the Pipeline

**Option A: Automated submission (recommended)**

```bash
cd slurm_scripts
./submit_pipeline.sh \
    --samplesheet ../samplesheet.csv \
    --genome /path/to/genome.fa \
    --gtf /path/to/annotations.gtf \
    --outdir ../results \
    --skip-genome-prep  # if indices already exist
```

**Option B: Manual step-by-step submission**

See detailed instructions in [slurm_scripts/README.md](slurm_scripts/README.md).

### 5. Monitor Progress

```bash
# Check job status
squeue -u $USER

# View logs
tail -f logs/03_fastp_trim_*.out

# Check MultiQC report when complete
firefox results/multiqc/rnaseq_multiqc_report.html
```

## Pipeline Overview

```
Raw FASTQ Files
      ↓
[FastQC] ← Quality control on raw reads
      ↓
[fastp] ← Adapter trimming and quality filtering
      ↓
      ├─→ [STAR] ← Genome alignment
      │     ↓
      │   [Salmon] ← Transcript quantification (alignment-based)
      │
      └─→ [Kallisto] ← Pseudo-alignment and quantification
      
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
│       ├── sample1_Log.final.out
│       └── sample1_ReadsPerGene.out.tab
├── salmon/              # Salmon quantification (from STAR)
│   └── sample1/
│       ├── quant.sf
│       └── quant.genes.sf
├── kallisto/            # Kallisto quantification
│   └── sample1/
│       ├── abundance.tsv
│       └── abundance.h5
└── multiqc/             # MultiQC report
    └── rnaseq_multiqc_report.html
```

## Documentation

- [slurm_scripts/README.md](slurm_scripts/README.md) - Detailed pipeline documentation
- [CONDA_SETUP.md](CONDA_SETUP.md) - Comprehensive conda environment setup guide
- [slurm_scripts/samplesheet_template.csv](slurm_scripts/samplesheet_template.csv) - Sample samplesheet template

## Scripts

| Script | Description | Resource Requirements |
|--------|-------------|----------------------|
| `01_prepare_genome.sh` | Build genome indices | 16 CPUs, 64GB RAM, 24h |
| `02_fastqc_raw.sh` | QC on raw reads | 4 CPUs, 8GB RAM, 4h |
| `03_fastp_trimming.sh` | Trim and filter reads | 8 CPUs, 16GB RAM, 6h |
| `04_star_alignment.sh` | Align to genome | 16 CPUs, 64GB RAM, 12h |
| `05_salmon_quantification.sh` | Quantify with Salmon | 8 CPUs, 16GB RAM, 4h |
| `06_kallisto_quantification.sh` | Quantify with Kallisto | 8 CPUs, 16GB RAM, 4h |
| `07_multiqc_report.sh` | Generate QC report | 4 CPUs, 8GB RAM, 2h |
| `submit_pipeline.sh` | Automated submission | - |

## Tool Versions

- FastQC: 0.12.1
- fastp: 0.24.0
- STAR: 2.7.11b
- Samtools: 1.21
- Salmon: 1.10.3
- Kallisto: 0.51.1
- MultiQC: 1.31
- gffread: 0.12.7
- R: 4.4.2 (with DESeq2, tximport, tximeta)

## Customization

### Adjusting SLURM Parameters

Edit the `#SBATCH` directives in each script:

```bash
#SBATCH --cpus-per-task=16    # Number of CPU cores
#SBATCH --mem=64G             # Memory allocation
#SBATCH --time=12:00:00       # Time limit
#SBATCH --partition=compute   # Partition name (cluster-specific)
```

### Adjusting Tool Parameters

Modify the tool command lines in each script. For example, in `04_star_alignment.sh`:

```bash
STAR \
    --runThreadN ${THREADS} \
    --outFilterMultimapNmax 20 \    # Adjust as needed
    --alignIntronMin 20 \            # Adjust as needed
    --alignIntronMax 1000000 \       # Adjust as needed
    ...
```

## Troubleshooting

### Common Issues

1. **Conda environment creation is slow**
   - See [CONDA_SETUP.md](CONDA_SETUP.md) for solutions using mamba or staged installation

2. **SLURM job fails with memory error**
   - Increase `--mem` in the script's `#SBATCH` directives

3. **STAR index creation fails**
   - Check available memory (STAR needs ~30-50GB for human genome)
   - Verify genome FASTA and GTF files are correct

4. **Array job indices don't match samples**
   - Verify samplesheet has no empty lines
   - Ensure correct number of samples in `#SBATCH --array=1-N`

### Getting Help

Check the logs directory for detailed error messages:
```bash
ls -lth logs/
cat logs/04_star_align_*_1.err  # View error log for first sample
```

## Citation

If you use this pipeline, please cite:

- **nf-core/rnaseq**: Ewels PA, et al. (2020). nf-core/rnaseq. https://doi.org/10.5281/zenodo.1400710
- **STAR**: Dobin A, et al. (2013). STAR: ultrafast universal RNA-seq aligner. Bioinformatics.
- **Salmon**: Patro R, et al. (2017). Salmon provides fast and bias-aware quantification. Nat Methods.
- **Kallisto**: Bray NL, et al. (2016). Near-optimal probabilistic RNA-seq quantification. Nat Biotechnol.
- **fastp**: Chen S, et al. (2018). fastp: an ultra-fast all-in-one FASTQ preprocessor. Bioinformatics.
- **MultiQC**: Ewels P, et al. (2016). MultiQC: summarize analysis results. Bioinformatics.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Based on the [nf-core/rnaseq](https://nf-co.re/rnaseq) pipeline
- Adapted for SLURM cluster architecture
- Tool versions and parameters derived from nf-core modules

## Support

For issues or questions:
1. Check the documentation in [slurm_scripts/README.md](slurm_scripts/README.md)
2. Review [CONDA_SETUP.md](CONDA_SETUP.md) for environment issues
3. Check logs in the `logs/` directory
4. Open an issue on GitHub

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

---

**Note**: These scripts are designed for SLURM-based HPC clusters. Adjust partition names, resource limits, and paths according to your cluster configuration.
