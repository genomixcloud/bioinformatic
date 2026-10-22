## This file contains information about the creation of the FimTyper image

This is an alpha version image that can be customized to run in AWS production environment.

### Recommended improvement in the next releases:

1. Implement a multi-stage build to reduce the image size and complexity
2. Add a non-root user to the image

### Scripts in /src folder
1. tmp_brew.sh: the script installs cpanm and the FimTyper's Perl dependencies. This is a temporal script tested in ubuntu (20.04/22.04). 
2. update_blast-ver.sh: the script updates ncbi-blast+ to an specific version. The ncbi-blast+ versions included in apt repositories **are not always the latest**. This script installs the ncbi-blast+ in /usr/local/fimtyper/ and doesn't replace the base ncbi-blast+(/usr/local/bin) so you have explicitly to indicate that you want to use the new version of ncbi-blast+(**/usr/local/fimtyper/ncbi-blast-${downloaded version}+**)