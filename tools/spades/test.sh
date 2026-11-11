#!/bin/bash
# Smoke test for the spades image: checks the versions of the main tools and
# runs a small job. Usage: tools/spades/test.sh <image:tag>   (called by `make test`)
set -euo pipefail

IMAGE=${1:?usage: $0 <image:tag>}
run() { docker run --rm --platform linux/amd64 --entrypoint /bin/bash "$IMAGE" -c "$1"; }
fail=0
ok()   { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }
check() { if [ "$2" = "$3" ]; then ok "$1: $2"; else bad "$1: got '$2', expected '$3'"; fi; }
contains() { if printf '%s' "$2" | grep -qF -- "$3"; then ok "$1"; else bad "$1: '$3' not found in: $(printf '%s' "$2" | head -c 300)"; fi; }

check "SPAdes version" "$(run 'spades.py --version 2>&1' | awk '{print $NF}')" "v3.15.5"
check "Python is 3" "$(run 'python --version 2>&1' | cut -d. -f1)" "Python 3"
out=$(run 'cd /tmp && spades.py --isolate --test 2>&1 | grep -E "TEST PASSED|finished abnormally"') || true
contains "SPAdes self-test on its toy data" "$out" "TEST PASSED CORRECTLY"

[ "$fail" -eq 0 ] && echo "All checks passed for $IMAGE" || { echo "Smoke test FAILED for $IMAGE"; exit 1; }
