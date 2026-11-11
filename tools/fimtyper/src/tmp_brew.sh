#!/bin/bash

# PerlBrew 
cd /usr/local/fimtyper
wget -O - https://install.perlbrew.pl | bash
source ~/perl5/perlbrew/etc/bashrc
perlbrew init
perlbrew install-cpanm
make install