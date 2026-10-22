#!/bin/bash

###############################################################
## The checkm config file. You can configure this variable in #
## the checkm.ini file.:                                      #
## PARAMETERS                                                 #
###############################################################
checkm data setRoot $TAXON_SET
checkm taxonomy_wf life Prokaryote $DATA_IN/ -x fasta $DATA_OUT
checkm tree $DATA_IN/ -x fasta $DATA_OUT $PARAMETERS
checkm tree_qa -o 2 $DATA_OUT
checkm gc_plot $DATA_OUT/bins $DATA_OUT/plots 95
