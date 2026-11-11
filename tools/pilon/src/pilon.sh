#!/bin/bash
################################################################
## pilon.sh: aligns paired-end reads to an assembly with bwa-mem2 and samtools, then polishes it with Pilon.
## Settings are read from /conf/pilon.ini as KEY=VALUE lines.
## An environment variable with the same name overrides the file.
## Settings:
##   assembly_fasta    Assembly to polish (FASTA)
##   fastq_forward     Read 1
##   fastq_reverse     Read 2
##   DATA_OUT          Output folder (results go to DATA_OUT/pilon)
##   THREADS           Number of CPUs for each step (default: 16)
################################################################
set -euo pipefail

INI_FILE="${INI_FILE:-/conf/pilon.ini}"

# Value of KEY in the ini file (last KEY=VALUE line wins; comments are ignored)
read_ini() {
  [ -f "$INI_FILE" ] || return 0
  sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*//p" "$INI_FILE" | sed 's/[[:space:]]*$//' | tail -n 1
}
# setting NAME [DEFAULT]: environment variable NAME, else the ini file, else DEFAULT
setting() {
  local value="${!1:-}"
  [ -n "$value" ] || value="$(read_ini "$1")"
  [ -n "$value" ] || value="${2:-}"
  printf '%s' "$value"
}
# require NAME...: stop if a setting is empty
require() {
  local name
  for name in "$@"; do
    [ -n "${!name:-}" ] || { echo "ERROR: $name is not set (in $INI_FILE or as an environment variable)" >&2; exit 1; }
  done
}
# require_file PATH...: stop if an input file is missing or empty
require_file() {
  local f
  for f in "$@"; do
    [ -s "$f" ] || { echo "ERROR: input file '$f' is missing or empty" >&2; exit 1; }
  done
}
# check_name VALUE: sample names may only have letters, digits, _ and -
check_name() {
  [[ "$1" =~ ^[A-Za-z0-9_-]+$ ]] || { echo "ERROR: name '$1' may only contain letters, digits, _ or -" >&2; exit 1; }
}

assembly_fasta="$(setting assembly_fasta)"
fastq_forward="$(setting fastq_forward)"
fastq_reverse="$(setting fastq_reverse)"
DATA_OUT="$(setting DATA_OUT)"
THREADS="$(setting THREADS 16)"
require assembly_fasta fastq_forward fastq_reverse DATA_OUT
require_file "$assembly_fasta" "$fastq_forward" "$fastq_reverse"

OUT="$DATA_OUT/pilon"
mkdir -p "$OUT"
bwa-mem2 index "$assembly_fasta"
bwa-mem2 mem -t "$THREADS" -P -S -Y -M -o "$OUT/sample.sam" "$assembly_fasta" "$fastq_forward" "$fastq_reverse"
samtools view -Sb "$OUT/sample.sam" -o "$OUT/sample.bam" --threads "$THREADS"
samtools sort "$OUT/sample.bam" -o "$OUT/sample.sort.bam"
samtools index "$OUT/sample.sort.bam"
pilon --genome "$assembly_fasta" --bam "$OUT/sample.sort.bam" --outdir "$OUT/" \
  --output assembly.polish --threads "$THREADS" --minqual 30 --nostrays
