#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: hashline.sh <filepath>" >&2
  exit 1
fi

filepath="$1"

if [ ! -f "$filepath" ]; then
  echo "Error: file not found: $filepath" >&2
  exit 1
fi

linenum=0
while IFS= read -r line || [ -n "$line" ]; do
  linenum=$((linenum + 1))
  stripped="${line%"${line##*[![:space:]]}"}"
  stripped="${stripped#"${stripped%%[![:space:]]*}"}"

  if [ -z "$stripped" ]; then
    printf "%-4s  %-8s  %s\n" "$linenum" "-" ""
    continue
  fi

  hash=$(printf '%s' "$stripped" | md5sum | cut -c1-8)
  preview="${stripped:0:40}"
  printf "%-4s  %-8s  %s\n" "$linenum" "$hash" "$preview"
done < "$filepath"