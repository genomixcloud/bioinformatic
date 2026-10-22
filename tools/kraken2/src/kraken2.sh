#!/bin/bash

##############################################################
## The pilon's skeleton. You can configure this variable in  #
## the kraken.ini file.:                                     #
## PARAMETERS/fastq_forward/fastq_reverse/DATA_OUT           #
##############################################################


# Run the tool
kraken2 --paired $fastq_forward $fastq_reverse --db $KRAKENDB $PARAMETERS --report $DATA_OUT/taxonomic_identification/$pattern.kraken-report.txt