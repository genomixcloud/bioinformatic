#!/bin/bash

##############################################################
## The fastp's skeleton. You can configure this variable in  #
## the fastp.ini file.:                                     #
## PARAMETERS/fastq_forward/fastq_reverse/DATA_OUT           #
##############################################################
fastp --in1 $fastq_forward --in2 $fastq_reverse --out1 $DATA_OUT/$forward_filename --out2 $DATA_OUT/$reverse_filename