#!/bin/bash
# Smoke test for the checkm image: checks the versions of the main tools and
# runs a small job. Usage: tools/checkm/test.sh <image:tag>   (called by `make test`)
set -euo pipefail

IMAGE=${1:?usage: $0 <image:tag>}
run() { docker run --rm --platform linux/amd64 --entrypoint /bin/bash "$IMAGE" -c "$1"; }
fail=0
ok()   { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }
check() { if [ "$2" = "$3" ]; then ok "$1: $2"; else bad "$1: got '$2', expected '$3'"; fi; }
contains() { if printf '%s' "$2" | grep -qF -- "$3"; then ok "$1"; else bad "$1: '$3' not found in: $(printf '%s' "$2" | head -c 300)"; fi; }

contains "CheckM version" "$(run 'checkm 2>&1 | head -5')" "1.2.5"
out=$(run 'checkm taxonomy_wf species "Escherichia coli" /data/checkm_db/test_data/ /tmp/checkm_test 2>&1 | tail -15') || true
contains "CheckM runs the test genome" "$out" "637000110"

[ "$fail" -eq 0 ] && echo "All checks passed for $IMAGE" || { echo "Smoke test FAILED for $IMAGE"; exit 1; }
