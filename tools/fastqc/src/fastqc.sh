#!/bin/bash

##############################################################
## The fastqc's skeleton. You can configure this variable in  #
## the fastqc.ini file.:                                     #
## PARAMETERS/fastq_forward/fastq_reverse/DATA_OUT           #
##############################################################
fastqc $fastq_forward $fastq_reverse -t 2 -o $DATA_OUT