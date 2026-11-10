#!/bin/bash
# Smoke test for the roary image: checks that FastTree, roary and roary2svg.pl
# run and that the main tools have the expected versions.
# Usage: tools/roary/test.sh <image:tag>      (called by `make test DOCKER_IMAGE=roary`)
set -euo pipefail

IMAGE=${1:?usage: $0 <image:tag>}
EXPECTED_ROARY="3.13.0"
EXPECTED_FASTTREE="2.2.0"

run() { docker run --rm --platform linux/amd64 --entrypoint /bin/bash "$IMAGE" -c "source activate roary_env >/dev/null && $1"; }
fail=0
check() { if [ "$2" = "$3" ]; then echo "ok   $1: $2"; else echo "FAIL $1: got '$2', expected '$3'"; fail=1; fi; }

check "roary version"    "$(run 'roary --version 2>&1 | tail -1')" "$EXPECTED_ROARY"
check "fasttree package" "$(run "conda list -n roary_env '^fasttree\$' | awk '/^fasttree /{print \$2}'")" "$EXPECTED_FASTTREE"

# FastTree builds a tree from a tiny alignment
tree=$(run 'printf ">a\nACGTACGTAC\n>b\nACGTACGTTC\n>c\nACGAACGTAC\n>d\nTCGTACGTAC\n" | FastTree -nt -quiet 2>/dev/null')
if [[ "$tree" == \(*\; ]]; then echo "ok   FastTree: tree built"; else echo "FAIL FastTree: no tree"; fail=1; fi

# roary2svg.pl compiles, so all its Perl modules (SVG, Text::CSV, ...) load
if out=$(run 'perl -c /usr/bin/roary2svg.pl 2>&1'); then echo "ok   roary2svg.pl: modules load"; else echo "FAIL roary2svg.pl: $out"; fail=1; fi

# convert (ImageMagick) turns an SVG into a PNG, as the production script does
if run 'printf "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"10\" height=\"10\"><rect width=\"10\" height=\"10\" fill=\"blue\"/></svg>" > /tmp/t.svg && convert /tmp/t.svg /tmp/t.png && test -s /tmp/t.png' >/dev/null 2>&1; then
  echo "ok   convert: svg -> png"; else echo "FAIL convert: svg -> png"; fail=1; fi

[ "$fail" -eq 0 ] && echo "All checks passed for $IMAGE" || { echo "Smoke test FAILED for $IMAGE"; exit 1; }
