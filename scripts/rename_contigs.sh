#!/usr/bin/env bash
# rename_contigs.sh
# Prepares a Bakta GFF3 for Roary:
#   1. removes the ##feature-ontology header line (breaks Roary's GFF parsing)
#   2. renames contig_N -> <SAMPLE>_contig_N everywhere (features + ##FASTA headers)
#      so contig IDs are unique when all samples are combined.
#
# Usage: rename_contigs.sh <input.gff3> <sample_name> <output.gff>
# Example: rename_contigs.sh $DATA_OUT/assembly.gff3 S01 /tmp/S01.gff

set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <input.gff3> <sample_name> <output.gff>" >&2
  exit 1
fi

IN="$1"
SAMPLE="$2"
OUT="$3"

# input checks
[ -s "$IN" ] || { echo "ERROR: input '$IN' missing or empty" >&2; exit 1; }
if ! [[ "$SAMPLE" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo "ERROR: sample name '$SAMPLE' must contain only letters, digits, _ or -" >&2
  exit 1
fi
grep -q '^##FASTA' "$IN" || { echo "ERROR: '$IN' has no ##FASTA section (Roary needs it)" >&2; exit 1; }

# clean + rename
# Portable regex (works with GNU, BSD/macOS and busybox sed): match contig_N
# only when it is not preceded by a letter, digit or _ (so an already renamed
# SAMPLE_contig_N is left alone). Strip Windows line endings too.
tr -d '\r' < "$IN" | sed -E \
  -e '/^##feature-ontology/d' \
  -e "s/(^|[^A-Za-z0-9_])contig_([0-9]+)/\1${SAMPLE}_contig_\2/g" \
  > "$OUT"

# output checks
if grep -qE '^(>)?contig_' "$OUT"; then
  echo "ERROR: renamed contig IDs left in '$OUT'. First offending lines:" >&2
  grep -nE '^(>)?contig_' "$OUT" | head -5 | cut -c1-120 >&2
  exit 1
fi
n_contigs=$(grep -c "^>${SAMPLE}_contig_" "$OUT" || true)
n_cds=$(awk -F'\t' '$3=="CDS"' "$OUT" | wc -l)
echo "OK: $OUT  (contigs: $n_contigs, CDS: $n_cds)"