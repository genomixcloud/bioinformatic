#!/bin/bash
# Smoke test for the prokka image: checks the versions of the main tools and
# runs a small job. Usage: tools/prokka/test.sh <image:tag>   (called by `make test`)
set -euo pipefail

IMAGE=${1:?usage: $0 <image:tag>}
run() { docker run --rm --platform linux/amd64 --entrypoint /bin/bash "$IMAGE" -c "$1"; }
fail=0
ok()   { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }
check() { if [ "$2" = "$3" ]; then ok "$1: $2"; else bad "$1: got '$2', expected '$3'"; fi; }
contains() { if printf '%s' "$2" | grep -qF -- "$3"; then ok "$1"; else bad "$1: '$3' not found in: $(printf '%s' "$2" | head -c 300)"; fi; }

contains "Prokka version" "$(run 'prokka --version 2>&1')" "prokka 1.14.6"
contains "BLAST+ version" "$(run 'blastp -version | head -1')" "2.9.0"
out=$(run 'awk "BEGIN{srand(42); printf \">contig_1\n\"; for(i=1;i<=20000;i++){printf substr(\"ACGT\",int(rand()*4)+1,1); if(i%60==0) printf \"\n\"} printf \"\n\"}" > /tmp/test.fasta; cd /tmp && prokka --outdir /tmp/p --prefix t --cpu 2 /tmp/test.fasta >/dev/null 2>&1 && test -s /tmp/p/t.gff && test -s /tmp/p/t.gbk && echo GFF_OK') || true
contains "Prokka annotates a 20 kb sequence (GFF and GenBank)" "$out" "GFF_OK"

[ "$fail" -eq 0 ] && echo "All checks passed for $IMAGE" || { echo "Smoke test FAILED for $IMAGE"; exit 1; }
