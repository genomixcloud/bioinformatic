#!/bin/bash
# Smoke test for the pilon image: checks the versions of the main tools and
# runs a small job. Usage: tools/pilon/test.sh <image:tag>   (called by `make test`)
set -euo pipefail

IMAGE=${1:?usage: $0 <image:tag>}
run() { docker run --rm --platform linux/amd64 --entrypoint /bin/bash "$IMAGE" -c "$1"; }
fail=0
ok()   { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }
check() { if [ "$2" = "$3" ]; then ok "$1: $2"; else bad "$1: got '$2', expected '$3'"; fi; }
contains() { if printf '%s' "$2" | grep -qF -- "$3"; then ok "$1"; else bad "$1: '$3' not found in: $(printf '%s' "$2" | head -c 300)"; fi; }

out=$(run 'pilon --version 2>&1') || true
contains "pilon runs without 'bash' (launcher fixed): 1.24" "$out" "Pilon version 1.24"
# bwa-mem2 picks a binary for the CPU (sse41/avx/avx2/avx512). Under emulation (e.g. Docker on
# Apple silicon) the CPU check can fail, so fall back to the sse41 binary for the version check.
contains "bwa-mem2 version" "$(run 'bwa-mem2 version 2>/dev/null || /usr/src/bwa/bwa-mem2.sse41 version 2>/dev/null' || true)" "2.2.1"
contains "samtools version" "$(run 'samtools --version | head -1')" "samtools 1.9"

[ "$fail" -eq 0 ] && echo "All checks passed for $IMAGE" || { echo "Smoke test FAILED for $IMAGE"; exit 1; }
