#!/bin/bash

##############################################################
## The pilon's skeleton. You can configure this variable in  #
## the pilon.ini file.:                                     #
## PARAMETERS/fastq_forward/fastq_reverse/DATA_OUT           #
##############################################################

source activate roary_env

# Run the tool
## roary -e --mafft -p $THREADS $DATA_IN/*.gff -f $DATA_OUT/pangenome
## fasttree -nt -gtr $DATA_OUT/pangenome/core_gene_alignment.aln > $DATA_OUT/pangenome/core_gene_alignment.newick
## perl roary2svg.pl $DATA_OUT/pangenome/gene_presence_absence.csv --colour=Blue > $DATA_OUT/pangenome/pangenome.svg

roary "$@"