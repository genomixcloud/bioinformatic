#!/bin/bash

##############################################################
## The spade's skeleton. You can configure this variable in  #
## the spades.ini file.:                                     #
## PARAMETERS/fastq_forward/fastq_reverse/DATA_OUT           #
##############################################################
quast.py $input_file -o $DATA_OUT $PARAMETERS