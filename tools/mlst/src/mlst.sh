#!/bin/bash
################################################################
## mlst.sh: types an assembly against the PubMLST schemes.
## Settings are read from /conf/mlst.ini as KEY=VALUE lines.
## An environment variable with the same name overrides the file.
## Settings:
##   assembly_fasta    Assembly to type (FASTA, GenBank or EMBL)
##   DATA_OUT          Output folder
##   pattern           Sample name, used as the output file name
##   PARAMETERS        Extra options, e.g. --scheme ecoli --threads 2 (default: --nopath --quiet)
################################################################
set -euo pipefail

INI_FILE="${INI_FILE:-/conf/mlst.ini}"

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
DATA_OUT="$(setting DATA_OUT)"
pattern="$(setting pattern)"
read -r -a PARAMS <<< "$(setting PARAMETERS "--nopath --quiet")"
require assembly_fasta DATA_OUT pattern
check_name "$pattern"
require_file "$assembly_fasta"

mkdir -p "$DATA_OUT"
mlst "$assembly_fasta" "${PARAMS[@]}" > "$DATA_OUT/$pattern.tsv"
echo "Results: $DATA_OUT/$pattern.tsv"
