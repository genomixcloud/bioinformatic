#!/bin/bash

##############################################################
## The spade's skeleton. You can configure this variable in  #
## the spades.ini file.:                                     #
## PARAMETERS/fastq_forward/fastq_reverse/DATA_OUT           #
##############################################################
spades.py $PARAMETERS -1 $fastq_forward -2 $fastq_reverse -o $DATA_OUT