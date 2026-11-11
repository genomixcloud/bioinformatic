#!/bin/bash
# Smoke test for the quast image: checks the versions of the main tools and
# runs a small job. Usage: tools/quast/test.sh <image:tag>   (called by `make test`)
set -euo pipefail

IMAGE=${1:?usage: $0 <image:tag>}
run() { docker run --rm --platform linux/amd64 --entrypoint /bin/bash "$IMAGE" -c "$1"; }
fail=0
ok()   { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }
check() { if [ "$2" = "$3" ]; then ok "$1: $2"; else bad "$1: got '$2', expected '$3'"; fi; }
contains() { if printf '%s' "$2" | grep -qF -- "$3"; then ok "$1"; else bad "$1: '$3' not found in: $(printf '%s' "$2" | head -c 300)"; fi; }

check "QUAST version" "$(run 'quast.py --version 2>&1' | grep -oE 'v[0-9.]+' | head -1)" "v5.2.0"
check "Python is 3" "$(run 'python --version 2>&1' | cut -d. -f1)" "Python 3"
out=$(run 'awk "BEGIN{srand(42); printf \">contig_1\n\"; for(i=1;i<=20000;i++){printf substr(\"ACGT\",int(rand()*4)+1,1); if(i%60==0) printf \"\n\"} printf \"\n\"}" > /tmp/test.fasta; quast.py /tmp/test.fasta -o /tmp/q --fast >/dev/null 2>&1 && grep -E "^Total length" /tmp/q/report.txt') || true
contains "QUAST reports the assembly length" "$out" "20000"

[ "$fail" -eq 0 ] && echo "All checks passed for $IMAGE" || { echo "Smoke test FAILED for $IMAGE"; exit 1; }
