# Differences from nf-core/rnaseq Pipeline

This document explains the key differences between this SLURM-based implementation and the original nf-core/rnaseq Nextflow pipeline.

## What's Included

### ✅ Implemented Components

1. **Quality Control**
   - FastQC on raw reads
   - MultiQC for comprehensive reporting

2. **Trimming and Filtering**
   - fastp (as specified in requirements)
   - Adapter removal
   - Quality filtering

3. **Alignment**
   - STAR aligner
   - Genome alignment with BAM output
   - Transcriptome alignment for Salmon

4. **Quantification**
   - **STAR-Salmon pathway**: Salmon quantification from STAR transcriptome BAM
   - **Kallisto pathway**: Pseudo-alignment and quantification
   - Both gene-level and transcript-level counts

5. **Reference Preparation**
   - STAR genome index
   - Salmon transcriptome index
   - Kallisto transcriptome index

## What's Excluded (As Requested)

### ❌ Not Implemented

The following features from the nf-core/rnaseq pipeline are **not** included as per requirements:

1. **bedGraphToBigWig**
   - No conversion of coverage tracks to BigWig format
   - Genome coverage generation is skipped

2. **RSeQC**
   - No read distribution analysis
   - No infer_experiment for strandedness detection
   - No junction annotation
   - No inner distance calculation
   - No read duplication analysis
   - No TIN (Transcript Integrity Number) calculation

3. **QualiMap**
   - No QualiMap RNA-seq QC

4. **PreSeq**
   - No library complexity estimation

5. **dupRadar**
   - No duplication rate quality control

6. **Kraken2/Bracken**
   - No contamination screening
   - No taxonomic classification

## Additional Features in SLURM Implementation

### ➕ SLURM-Specific Enhancements

1. **Array Jobs**
   - Parallel processing of multiple samples
   - Efficient resource utilization on HPC clusters

2. **Dependency Management**
   - Automatic job dependencies using SLURM's `--dependency` flag
   - Sequential execution of pipeline steps

3. **Modular Scripts**
   - Each step is a separate, independent script
   - Easy to modify, debug, and re-run individual steps

4. **Manual Submission Control**
   - Users can submit jobs one at a time or use automated script
   - Better control over job submission timing

5. **Utility Scripts**
   - `check_jobs.sh`: Monitor pipeline progress
   - `cancel_pipeline.sh`: Cancel all pipeline jobs
   - `validate_samplesheet.sh`: Validate input before submission

## Simplified Workflow

### nf-core/rnaseq (Full Pipeline)

```
Input → QC → Trim → Align → Quant
         ↓      ↓      ↓      ↓
      RSeQC  QualMap  PreSeq  dupRadar
         ↓      ↓      ↓      ↓
      BigWig Kraken2 → MultiQC
```

### SLURM Implementation (Streamlined)

```
Input → FastQC → fastp → STAR → Salmon
                    ↓            ↓
                 Kallisto    MultiQC
```

## Feature Comparison Table

| Feature | nf-core/rnaseq | SLURM Implementation | Reason |
|---------|----------------|----------------------|--------|
| FastQC | ✅ | ✅ | Required for QC |
| fastp | ✅ | ✅ | Specified in requirements |
| TrimGalore | ✅ | ❌ | Using fastp instead |
| STAR | ✅ | ✅ | Specified pathway |
| HISAT2 | ✅ | ❌ | Not requested |
| Salmon | ✅ | ✅ | Specified pathway |
| Kallisto | ✅ | ✅ | Specified pathway |
| RSEM | ✅ | ❌ | Not requested |
| RSeQC | ✅ | ❌ | Excluded by request |
| QualiMap | ✅ | ❌ | Excluded by request |
| PreSeq | ✅ | ❌ | Excluded by request |
| dupRadar | ✅ | ❌ | Excluded by request |
| BigWig | ✅ | ❌ | Excluded by request |
| Kraken2 | ✅ | ❌ | Excluded by request |
| StringTie | ✅ | ❌ | Not requested |
| featureCounts | ✅ | ❌ | Using STAR/Salmon counts |
| DESeq2 QC | ✅ | ✅ (via R packages) | Included in environment |
| MultiQC | ✅ | ✅ | Required for QC |

## Workflow Differences

### Reference Genome Preparation

**nf-core/rnaseq**: Automatic index generation based on parameters
**SLURM**: Manual one-time setup with `01_prepare_genome.sh`

### Sample Processing

**nf-core/rnaseq**: Nextflow handles parallelization automatically
**SLURM**: SLURM array jobs for parallel processing (requires manual array size setup)

### Dependency Management

**nf-core/rnaseq**: Nextflow DAG manages all dependencies
**SLURM**: Manual dependency specification with `--dependency` flags

### Resource Allocation

**nf-core/rnaseq**: Dynamic resource allocation based on config
**SLURM**: Fixed resource allocation in SBATCH directives (can be edited)

### Error Handling

**nf-core/rnaseq**: Automatic retry and resume capabilities
**SLURM**: Manual inspection of logs and re-submission of failed jobs

## Advantages of SLURM Implementation

1. **Transparency**: Clear, readable bash scripts
2. **Flexibility**: Easy to modify tool parameters
3. **Control**: Manual job submission and monitoring
4. **Simplicity**: No Nextflow/Java dependencies
5. **Debugging**: Straightforward error investigation

## Limitations of SLURM Implementation

1. **Manual Array Sizing**: Need to update array size for different sample counts
2. **No Automatic Resume**: Must manually re-run failed samples
3. **Less Portable**: Tied to SLURM scheduling system
4. **No Automatic Resource Scaling**: Fixed resource allocations

## Migration Notes

If you're familiar with nf-core/rnaseq, here are key differences:

### Parameter Equivalents

| nf-core/rnaseq | SLURM Implementation |
|----------------|----------------------|
| `--input` | `SAMPLESHEET` variable |
| `--outdir` | `OUTPUT_DIR` variable |
| `--genome` | `GENOME_FASTA` variable |
| `--gtf` | `GTF_FILE` variable |
| `--aligner star_salmon` | Scripts 04 + 05 |
| `--pseudo_aligner kallisto` | Script 06 |
| `--trimmer fastp` | Script 03 |
| `--skip_qc` | Skip scripts 02, 07 |

### Output Equivalents

| nf-core/rnaseq Output | SLURM Output |
|-----------------------|--------------|
| `star_salmon/` | `results/star/` + `results/salmon/` |
| `kallisto/` | `results/kallisto/` |
| `fastqc/` | `results/fastqc_raw/` |
| `fastp/` | `results/fastp/` |
| `multiqc/` | `results/multiqc/` |

## Recommendations

### Use SLURM Implementation When:
- You want fine-grained control over job submission
- Your cluster has strict resource policies
- You need to debug or modify specific steps
- You want to learn the tools and parameters
- You don't need the excluded QC steps

### Use nf-core/rnaseq When:
- You need all QC features
- You want automatic resume capabilities
- You need to run on multiple compute platforms
- You want the latest tool versions automatically
- You need extensive downstream analysis options

## Future Enhancements

Potential additions to the SLURM implementation:

- [ ] Automatic sample count detection and array sizing
- [ ] Failed sample re-submission script
- [ ] Resource usage monitoring and reporting
- [ ] Integration with DESeq2 for differential expression
- [ ] Optional RSeQC module (as separate script)
- [ ] Optional coverage track generation

## Support

For questions about:
- **This implementation**: See documentation in this repository
- **nf-core/rnaseq**: Visit https://nf-co.re/rnaseq
- **SLURM**: Consult your cluster documentation

---

**Note**: This SLURM implementation focuses on the core RNA-seq analysis workflow as specified in the requirements. For comprehensive QC and additional analysis options, consider using the full nf-core/rnaseq pipeline.
