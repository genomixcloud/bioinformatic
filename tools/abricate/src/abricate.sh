#!/bin/bash

################################################################
## The abricate's skeleton. You can configure this variable in #
## the abricate.ini file.:                                     #
## PARAMETERS/contig.fasta/database/DATA_OUT                   #
## Other_Params/threads/minid/mincov/nopath                    #
################################################################
abricate $contig_fasta --db $database $Other_Params> $DATA_OUT/out.tab