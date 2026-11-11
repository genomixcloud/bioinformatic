#!/bin/bash
# Smoke test for the fimtyper image: checks the versions of the main tools and
# runs a small job. Usage: tools/fimtyper/test.sh <image:tag>   (called by `make test`)
set -euo pipefail

IMAGE=${1:?usage: $0 <image:tag>}
run() { docker run --rm --platform linux/amd64 --entrypoint /bin/bash "$IMAGE" -c "$1"; }
fail=0
ok()   { echo "ok   $1"; }
bad()  { echo "FAIL $1"; fail=1; }
check() { if [ "$2" = "$3" ]; then ok "$1: $2"; else bad "$1: got '$2', expected '$3'"; fi; }
contains() { if printf '%s' "$2" | grep -qF -- "$3"; then ok "$1"; else bad "$1: '$3' not found in: $(printf '%s' "$2" | head -c 300)"; fi; }

check "FimTyper commit" "$(run 'git -C /usr/local/fimtyper rev-parse HEAD')" "311023be5c2caf8ad0673b15169ee02af5c46954"
check "FimTyper database commit" "$(run 'git -C /usr/local/fimtyper/fimtyper_db rev-parse HEAD')" "820782c9dd7334cd707b161d9ab8ef541a0a68c2"
out=$(run 'cd /tmp && perl /usr/local/fimtyper/fimtyper.pl -d /usr/local/fimtyper/fimtyper_db -i /usr/local/fimtyper/test.fsa -o /tmp/out -k 95.00 -l 0.60 >/dev/null 2>&1; cat /tmp/out/results_tab.txt 2>/dev/null || ls /tmp/out') || true
contains "FimTyper types the test genome" "$out" "fimH"

[ "$fail" -eq 0 ] && echo "All checks passed for $IMAGE" || { echo "Smoke test FAILED for $IMAGE"; exit 1; }
