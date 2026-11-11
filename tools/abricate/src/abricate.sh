#!/bin/bash
################################################################
## abricate.sh: screens an assembly for antimicrobial resistance and virulence genes.
## Settings are read from /conf/abricate.ini as KEY=VALUE lines.
## An environment variable with the same name overrides the file.
## Settings:
##   contig_fasta      Assembly to screen (FASTA, GenBank or EMBL)
##   database          ABRicate database (abricate --list) (default: ncbi)
##   DATA_OUT          Output folder
##   Other_Params      Extra options, e.g. --threads 4 --minid 90 --mincov 80 --nopath
################################################################
set -euo pipefail

INI_FILE="${INI_FILE:-/conf/abricate.ini}"

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

contig_fasta="$(setting contig_fasta)"
database="$(setting database ncbi)"
DATA_OUT="$(setting DATA_OUT)"
read -r -a OTHER_PARAMS <<< "$(setting Other_Params)"
require contig_fasta DATA_OUT
require_file "$contig_fasta"

mkdir -p "$DATA_OUT"
abricate "$contig_fasta" --db "$database" "${OTHER_PARAMS[@]}" > "$DATA_OUT/out.tab"
echo "Results: $DATA_OUT/out.tab"
