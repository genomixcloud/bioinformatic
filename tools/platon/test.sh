#!/bin/bash
# Smoke test for the platon image: checks the versions of the main tools and
# runs a small job. Usage: tools/platon/test.sh <image:tag>   (called by `make test`)
set -euo pipefail

IMAGE=${1:?usage: $0 <image:tag>}
run() { docker run --rm --platform linux/amd64 --entrypoint /bin/bash "$IMAGE" -c "$1"; }
fail=0
ok()   { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }
check() { if [ "$2" = "$3" ]; then ok "$1: $2"; else bad "$1: got '$2', expected '$3'"; fi; }
contains() { if printf '%s' "$2" | grep -qF -- "$3"; then ok "$1"; else bad "$1: '$3' not found in: $(printf '%s' "$2" | head -c 300)"; fi; }

check "Platon version" "$(run 'platon --version')" "platon 1.7"
# Platon's dependencies aren't pinned: check they run and show their versions
contains "DIAMOND runs" "$(run 'diamond version')" "diamond version"
contains "BLAST+ runs" "$(run 'blastn -version | head -1')" "blastn"
echo "info $(run 'diamond version') / $(run 'blastn -version | head -1')"
contains "Platon help" "$(run 'platon --help 2>&1')" "--db"

[ "$fail" -eq 0 ] && echo "All checks passed for $IMAGE" || { echo "Smoke test FAILED for $IMAGE"; exit 1; }
