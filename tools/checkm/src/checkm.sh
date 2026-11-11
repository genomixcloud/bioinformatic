#!/bin/bash
################################################################
## checkm.sh: assesses the completeness and contamination of genomes or bins.
## Settings are read from /conf/checkm.ini as KEY=VALUE lines.
## An environment variable with the same name overrides the file.
## Settings:
##   DATA_IN           Folder with one FASTA file per genome
##   DATA_OUT          Output folder (CheckM creates it)
##   EXTENSION         Extension of the genome files (default: fasta)
##   CHECKM_DB         CheckM database folder (default: /data/checkm_db)
##   PARAMETERS        Extra options for checkm tree (default: --reduced_tree --threads 8)
################################################################
set -euo pipefail

INI_FILE="${INI_FILE:-/conf/checkm.ini}"

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

DATA_IN="$(setting DATA_IN)"
DATA_OUT="$(setting DATA_OUT)"
EXTENSION="$(setting EXTENSION fasta)"
CHECKM_DB="$(setting CHECKM_DB /data/checkm_db)"
read -r -a PARAMS <<< "$(setting PARAMETERS "--reduced_tree --threads 8")"
require DATA_IN DATA_OUT
[ -d "$DATA_IN" ] || { echo "ERROR: input folder '$DATA_IN' not found" >&2; exit 1; }

checkm data setRoot "$CHECKM_DB"
checkm taxonomy_wf life Prokaryote "$DATA_IN/" -x "$EXTENSION" "$DATA_OUT/taxonomy_wf"
checkm tree "$DATA_IN/" -x "$EXTENSION" "$DATA_OUT/lineage" "${PARAMS[@]}"
checkm tree_qa -o 2 "$DATA_OUT/lineage"
checkm gc_plot "$DATA_OUT/lineage/bins" "$DATA_OUT/lineage/plots" 95
