#!/bin/bash
################################################################
## kraken2.sh: classifies paired-end reads taxonomically.
## Settings are read from /conf/kraken.ini as KEY=VALUE lines.
## An environment variable with the same name overrides the file.
## Settings:
##   fastq_forward     Read 1
##   fastq_reverse     Read 2
##   KRAKENDB          Kraken2 database folder (with the .k2d files)
##   DATA_OUT          Output folder
##   pattern           Sample name, used as prefix of the output files
##   PARAMETERS        Extra options, e.g. --threads 16 --confidence 0.1 (default: --threads 8)
################################################################
set -euo pipefail

INI_FILE="${INI_FILE:-/conf/kraken.ini}"

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
KRAKENDB="$(setting KRAKENDB)"
DATA_OUT="$(setting DATA_OUT)"
pattern="$(setting pattern)"
read -r -a PARAMS <<< "$(setting PARAMETERS "--threads 8")"
require fastq_forward fastq_reverse KRAKENDB DATA_OUT pattern
check_name "$pattern"
require_file "$fastq_forward" "$fastq_reverse" "$KRAKENDB/hash.k2d"

OUT="$DATA_OUT/taxonomic_identification"
mkdir -p "$OUT"
kraken2 --paired "$fastq_forward" "$fastq_reverse" --db "$KRAKENDB" "${PARAMS[@]}" \
  --output "$OUT/$pattern.kraken-output.txt" \
  --report "$OUT/$pattern.kraken-report.txt"
