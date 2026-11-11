#!/bin/bash
# Smoke test for the fastqc image: checks the versions of the main tools and
# runs a small job. Usage: tools/fastqc/test.sh <image:tag>   (called by `make test`)
set -euo pipefail

IMAGE=${1:?usage: $0 <image:tag>}
run() { docker run --rm --platform linux/amd64 --entrypoint /bin/bash "$IMAGE" -c "$1"; }
fail=0
ok()   { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }
check() { if [ "$2" = "$3" ]; then ok "$1: $2"; else bad "$1: got '$2', expected '$3'"; fi; }
contains() { if printf '%s' "$2" | grep -qF -- "$3"; then ok "$1"; else bad "$1: '$3' not found in: $(printf '%s' "$2" | head -c 300)"; fi; }

check "FastQC version" "$(run 'fastqc --version' | awk '{print $2}')" "v0.12.1"
out=$(run 'printf "@r1/1\nACGTACGTACGTACGTACGTACGTACGTACGTACGTACGT\n+\nIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII\n@r2/1\nTTGCATTGCATTGCATTGCATTGCATTGCATTGCATTGCA\n+\nIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIIII\n" > /tmp/r1.fq; sed "s#/1#/2#" /tmp/r1.fq > /tmp/r2.fq; fastqc /tmp/r1.fq -o /tmp >/dev/null 2>&1 && test -s /tmp/r1_fastqc.html && echo REPORT_OK') || true
contains "FastQC writes the HTML report" "$out" "REPORT_OK"

[ "$fail" -eq 0 ] && echo "All checks passed for $IMAGE" || { echo "Smoke test FAILED for $IMAGE"; exit 1; }
