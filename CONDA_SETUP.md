# Conda Environment Setup Guide for RNA-seq Pipeline

This guide provides detailed instructions for creating the conda environment for the RNA-seq SLURM pipeline.

## Quick Start

For modern conda versions (conda >= 23.x):
```bash
conda env create -f environment.yml
conda activate rnaseq
```

## For Older Conda Versions (Slow Dependency Resolution)

If you're using an older version of conda (4.x - 22.x) that takes a very long time to solve the environment, follow these steps:

### Option 1: Use Mamba (Recommended)

Mamba is a faster alternative to conda that uses the same commands:

```bash
# Install mamba in base environment (one-time setup)
conda install -n base -c conda-forge mamba

# Create environment using mamba (much faster)
mamba env create -f environment.yml
conda activate rnaseq
```

### Option 2: Create Environment in Stages

If mamba is not available, create the environment in stages to speed up resolution:

```bash
# Stage 1: Create environment and install core tools
conda create -n rnaseq -c conda-forge -c bioconda python=3.9
conda activate rnaseq

# Stage 2: Install alignment and quantification tools
conda install -c bioconda -c conda-forge \
    star=2.7.11b \
    salmon=1.10.3 \
    kallisto=0.51.1 \
    samtools=1.21 \
    htslib=1.21

# Stage 3: Install QC and trimming tools
conda install -c bioconda -c conda-forge \
    fastqc=0.12.1 \
    fastp=0.24.0 \
    multiqc=1.31

# Stage 4: Install annotation processing tools
conda install -c bioconda -c conda-forge \
    gffread=0.12.7

# Stage 5: Install R and Bioconductor packages
conda install -c conda-forge -c bioconda \
    r-base=4.4.2 \
    r-optparse=1.7.5 \
    r-ggplot2=3.5.1 \
    r-rcolorbrewer=1.1_3 \
    r-pheatmap=1.0.12

conda install -c bioconda -c conda-forge \
    bioconductor-deseq2=1.46.0 \
    bioconductor-tximport=1.34.0 \
    bioconductor-tximeta=1.20.1 \
    bioconductor-biocparallel=1.40.0 \
    bioconductor-complexheatmap=2.22.0

# Stage 6: Install utilities
conda install -c conda-forge \
    gawk=5.1.0 \
    pigz=2.8 \
    parallel=20240722
```

### Option 3: Generate and Use Explicit Specification

This is the fastest method for repeated installations on the same system:

```bash
# First-time setup (can be done on a faster machine or with mamba)
conda env create -f environment.yml
conda activate rnaseq

# Generate explicit specification
conda list --explicit > environment_explicit_complete.txt

# Share this file with your team/cluster
# Copy it to your HPC cluster

# On the cluster, create environment from explicit file (very fast!)
conda create -n rnaseq --file environment_explicit_complete.txt
```

### Option 4: Pre-built Environment Archive

For cluster installations, you can create and transfer the entire environment:

```bash
# On a machine where you successfully created the environment:
conda activate rnaseq
conda pack -n rnaseq -o rnaseq_env.tar.gz

# Transfer to cluster
scp rnaseq_env.tar.gz user@cluster:/path/to/destination/

# On cluster, unpack the environment
mkdir -p $HOME/conda_envs/rnaseq
tar -xzf rnaseq_env.tar.gz -C $HOME/conda_envs/rnaseq

# Activate the unpacked environment
source $HOME/conda_envs/rnaseq/bin/activate

# Fix paths after unpacking
conda-unpack
```

Note: `conda pack` requires installation first:
```bash
conda install -c conda-forge conda-pack
```

## Verification

After creating the environment, verify all tools are installed:

```bash
conda activate rnaseq

# Check versions
fastqc --version
fastp --version
STAR --version
salmon --version
kallisto version
samtools --version
multiqc --version
gffread --version

# Check R packages
Rscript -e "library(DESeq2); library(tximport); library(tximeta)"
```

Expected output:
```
FastQC v0.12.1
fastp 0.24.0
STAR_2.7.11b
salmon 1.10.3
kallisto, version 0.51.1
samtools 1.21
multiqc, version 1.31
gffread 0.12.7
```

## Troubleshooting

### Issue: "Solving environment: failed with initial frozen solve"

Try:
```bash
conda config --set channel_priority flexible
conda env create -f environment.yml
```

### Issue: "PackagesNotFoundError"

Some packages might not be available for your platform. Check:
```bash
conda search -c bioconda -c conda-forge star
```

For ARM64/Apple Silicon Macs, use Rosetta 2:
```bash
CONDA_SUBDIR=osx-64 conda env create -f environment.yml
```

### Issue: Very slow dependency resolution

Use mamba or create environment in stages (see Option 1 and 2 above).

### Issue: Conflicting dependencies

If you encounter conflicts, try:
```bash
# Use stricter channel priority
conda config --set channel_priority strict

# Or specify exact builds
conda install star=2.7.11b=h43eeafb_1
```

## Minimal Environment (Core Tools Only)

If you only need the essential tools and want to skip R packages:

```bash
conda create -n rnaseq_minimal -c bioconda -c conda-forge \
    fastqc=0.12.1 \
    fastp=0.24.0 \
    star=2.7.11b \
    salmon=1.10.3 \
    kallisto=0.51.1 \
    samtools=1.21 \
    gffread=0.12.7 \
    multiqc=1.31 \
    gawk=5.1.0
```

## Container Alternative

If conda installation is problematic, consider using containers:

```bash
# Using Singularity/Apptainer on HPC
singularity pull docker://nfcore/rnaseq:3.14.0

# Run tools through container
singularity exec rnaseq_3.14.0.sif fastqc --version
```

## Environment Management

```bash
# List all environments
conda env list

# Update environment
conda env update -f environment.yml

# Remove environment
conda env remove -n rnaseq

# Export current environment
conda env export > environment_current.yml
```

## Platform-Specific Notes

### Linux (HPC Clusters)
- Should work out of the box with the provided environment.yml
- Ensure you have write access to conda installation directory

### macOS
- For Intel Macs: Should work with environment.yml
- For Apple Silicon (M1/M2): Use CONDA_SUBDIR=osx-64 or use Mamba

### Windows (WSL2)
- Install conda in WSL2 Ubuntu/Debian environment
- Follow Linux instructions

## Additional Resources

- Conda documentation: https://docs.conda.io/
- Mamba documentation: https://mamba.readthedocs.io/
- Bioconda: https://bioconda.github.io/
- Package versions: https://anaconda.org/bioconda

## Support

If you encounter persistent issues:
1. Check conda version: `conda --version`
2. Update conda: `conda update -n base conda`
3. Clear cache: `conda clean --all`
4. Try with mamba: `conda install -n base -c conda-forge mamba`
5. Use staged installation approach
