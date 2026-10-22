#!/bin/bash

##############################################################
## The pilon's skeleton. You can configure this variable in  #
## the pilon.ini file.:                                     #
## PARAMETERS/fastq_forward/fastq_reverse/DATA_OUT           #
##############################################################


# Run the tool
bwa-mem2 index $assembly_fasta
bwa-mem2 mem -t 2 -P -S -Y -M -o $DATA_OUT/pilon/sample.sam $assembly_fasta $fastq_forward $fastq_reverse
samtools view -Sb $DATA_OUT/pilon/sample.sam -o $DATA_OUT/pilon/sample.bam --threads 16
samtools sort $DATA_OUT/pilon/sample.bam -o $DATA_OUT/pilon/sample.sort.bam
samtools index $DATA_OUT/pilon/sample.sort.bam
pilon --genome $assembly_fasta --bam $DATA_OUT/pilon/sample.sort.bam --outdir $DATA_OUT/pilon/ --output assembly.polish --threads 16 --minqual 30 --nostrays
