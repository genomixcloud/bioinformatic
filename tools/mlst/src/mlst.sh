#!/bin/bash

##############################################################
## The spade's skeleton. You can configure this variable in  #
## the spades.ini file.:                                     #
## PARAMETERS/fastq_forward/fastq_reverse/DATA_OUT           #
##############################################################
mlst $assembly_fasta $PARAMETERS > $DATA_OUT/$pattern.tsv