#!/bin/bash
# Smoke test for the bakta image: checks the versions of the main tools and
# runs a small job. Usage: tools/bakta/test.sh <image:tag>   (called by `make test`)
set -euo pipefail

IMAGE=${1:?usage: $0 <image:tag>}
run() { docker run --rm --platform linux/amd64 --entrypoint /bin/bash "$IMAGE" -c "$1"; }
fail=0
ok()   { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }
check() { if [ "$2" = "$3" ]; then ok "$1: $2"; else bad "$1: got '$2', expected '$3'"; fi; }
contains() { if printf '%s' "$2" | grep -qF -- "$3"; then ok "$1"; else bad "$1: '$3' not found in: $(printf '%s' "$2" | head -c 300)"; fi; }

check "Bakta version" "$(run 'bakta --version')" "bakta 1.11.4"
check "bakta on PATH without activating" "$(run 'command -v bakta')" "/root/miniconda3/envs/bakta_env/bin/bakta"
# AMRFinderPlus isn't pinned (only a minimum version): check it runs and show its version
contains "AMRFinderPlus runs" "$(run 'amrfinder --version 2>&1')" "."
echo "info AMRFinderPlus $(run 'amrfinder --version 2>&1' | tail -1)"
contains "Configuration copied" "$(run 'ls /conf')" "bakta.ini"

[ "$fail" -eq 0 ] && echo "All checks passed for $IMAGE" || { echo "Smoke test FAILED for $IMAGE"; exit 1; }
