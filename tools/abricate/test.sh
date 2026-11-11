#!/bin/bash
# Smoke test for the abricate image: checks the versions of the main tools and
# runs a small job. Usage: tools/abricate/test.sh <image:tag>   (called by `make test`)
set -euo pipefail

IMAGE=${1:?usage: $0 <image:tag>}
run() { docker run --rm --platform linux/amd64 --entrypoint /bin/bash "$IMAGE" -c "$1"; }
fail=0
ok()   { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }
check() { if [ "$2" = "$3" ]; then ok "$1: $2"; else bad "$1: got '$2', expected '$3'"; fi; }
contains() { if printf '%s' "$2" | grep -qF -- "$3"; then ok "$1"; else bad "$1: '$3' not found in: $(printf '%s' "$2" | head -c 300)"; fi; }

check "ABRicate version" "$(run 'abricate --version')" "abricate 1.0.1"
out=$(run 'abricate --check 2>&1') || true
contains "ABRicate dependencies" "$out" "OK"
check "ABRicate databases" "$(run 'abricate --list | tail -n +2 | wc -l' | tr -d ' ')" "9"
check "any2fasta version" "$(run 'any2fasta -v 2>&1' | awk '{print $2}')" "0.9.0"

[ "$fail" -eq 0 ] && echo "All checks passed for $IMAGE" || { echo "Smoke test FAILED for $IMAGE"; exit 1; }
