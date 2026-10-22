#!/bin/bash

#################################################################
## This bash script has been created for testing purposes. The idea ##
## that can be tested from the local environment from docker   ##
## with no need  to enter into the containers.                 ##
#################################################################

source activate roary_env

perl /usr/bin/roary2svg.pl "$@"