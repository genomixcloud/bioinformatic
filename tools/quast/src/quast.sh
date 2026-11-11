#!/bin/bash
################################################################
## quast.sh: assesses the quality of one or more assemblies.
## Settings are read from /conf/quast.ini as KEY=VALUE lines.
## An environment variable with the same name overrides the file.
## Settings:
##   input_file        Assemblies to assess (FASTA), separated by spaces
##   DATA_OUT          Output folder
##   PARAMETERS        Extra options, e.g. -r reference.fasta.gz --threads 4
################################################################
set -euo pipefail

INI_FILE="${INI_FILE:-/conf/quast.ini}"

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

read -r -a INPUT_FILES <<< "$(setting input_file)"
DATA_OUT="$(setting DATA_OUT)"
read -r -a PARAMS <<< "$(setting PARAMETERS)"
[ "${#INPUT_FILES[@]}" -gt 0 ] || { echo "ERROR: input_file is not set (in $INI_FILE or as an environment variable)" >&2; exit 1; }
require DATA_OUT
require_file "${INPUT_FILES[@]}"

quast.py "${INPUT_FILES[@]}" -o "$DATA_OUT" "${PARAMS[@]}"
