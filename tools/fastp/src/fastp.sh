#!/bin/bash
################################################################
## fastp.sh: trims and filters paired-end reads.
## Settings are read from /conf/fastp.ini as KEY=VALUE lines.
## An environment variable with the same name overrides the file.
## Settings:
##   fastq_forward     Read 1 (FASTQ, gzipped or not)
##   fastq_reverse     Read 2
##   DATA_OUT          Output folder
##   forward_filename  Name of trimmed read 1. Default: trimmed_<name of read 1>
##   reverse_filename  Name of trimmed read 2. Default: trimmed_<name of read 2>
##   PARAMETERS        Extra fastp options, e.g. -w 8 --detect_adapter_for_pe
################################################################
set -euo pipefail

INI_FILE="${INI_FILE:-/conf/fastp.ini}"

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

fastq_forward="$(setting fastq_forward)"
fastq_reverse="$(setting fastq_reverse)"
DATA_OUT="$(setting DATA_OUT)"
require fastq_forward fastq_reverse DATA_OUT
forward_filename="$(setting forward_filename "trimmed_$(basename "$fastq_forward")")"
reverse_filename="$(setting reverse_filename "trimmed_$(basename "$fastq_reverse")")"
read -r -a PARAMS <<< "$(setting PARAMETERS)"
require_file "$fastq_forward" "$fastq_reverse"

mkdir -p "$DATA_OUT"
fastp --in1 "$fastq_forward" --in2 "$fastq_reverse" \
  --out1 "$DATA_OUT/$forward_filename" --out2 "$DATA_OUT/$reverse_filename" \
  -h "$DATA_OUT/fastp.html" -j "$DATA_OUT/fastp.json" "${PARAMS[@]}"
