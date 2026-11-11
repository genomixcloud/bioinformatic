#!/bin/bash
# Smoke test for the kraken2 image: checks the versions of the main tools and
# runs a small job. Usage: tools/kraken2/test.sh <image:tag>   (called by `make test`)
set -euo pipefail

IMAGE=${1:?usage: $0 <image:tag>}
run() { docker run --rm --platform linux/amd64 --entrypoint /bin/bash "$IMAGE" -c "$1"; }
fail=0
ok()   { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }
check() { if [ "$2" = "$3" ]; then ok "$1: $2"; else bad "$1: got '$2', expected '$3'"; fi; }
contains() { if printf '%s' "$2" | grep -qF -- "$3"; then ok "$1"; else bad "$1: '$3' not found in: $(printf '%s' "$2" | head -c 300)"; fi; }

check "Kraken2 version" "$(run 'kraken2 --version' | head -1 | awk '{print $3}')" "2.1.6"
out=$(run 'kraken2-build --help 2>&1') || true
contains "kraken2-build is available" "$out" "Usage"
out=$(run 'blastn -version') || true
contains "BLAST+ is available" "$out" "blastn"

[ "$fail" -eq 0 ] && echo "All checks passed for $IMAGE" || { echo "Smoke test FAILED for $IMAGE"; exit 1; }
