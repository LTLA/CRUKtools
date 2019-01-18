# CRUK tools

This repository provides some tools for processing genomics data on the CRUK Cambridge Institute SLURM server.

**Alignment**

- `solo_align.sh` provides a script for aligning a single library (single-end or paired-end).
- `multi_align.sh` is a convenience wrapper to submit alignment jobs for many libraries in a data set.
- `guess_encoding.py` guesses the Phred encoding for the aligner.

Alignment is performed using the [_subread_](http://subread.sourceforge.net/) aligner.
It also requires [_samtools_](http://www.htslib.org/) and [_MarkDuplicates_](https://broadinstitute.github.io/picard/).

**Read counting**

`counter.R` provides a template for read counting to produce a gene-by-sample count matrix.
It requires specification of the BAM files for which to perform the counting as well as a set of GTF annotation files.
It will use the `featureCounts` function in the [_Rsubread_](https://bioconductor.org/packages/Rsubread) package.

**Data mangling**

- `cram2fastq.sh` will convert a CRAM file into FASTQ for entry into the alignment pipelines above.
- `sanger_dump.sh` will convert an entire folder of CRAM files into FASTQs.

**Other**

`cell_ranger.sh` will call the [_CellRanger_](https://support.10xgenomics.com/single-cell-gene-expression/software/pipelines/latest/what-is-cell-ranger) pipeline to create a count matrix for single-cell transcriptomics data from the 10X Genomics platform.

