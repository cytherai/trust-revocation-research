#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 CytherAI
#
# Check an evidence package against its public sources, now: each Node.js
# roots.pem (and archived header) against src/node_root_certs.h at its release
# tag, the test chains against the disclosure site's chains.zip, and the
# node:20 image tags against the digests recorded in results/registry-state.txt.
# Prints MATCH, MISMATCH or CHANGED per item. Needs bash, curl and python3.
# Usage: check_provenance.sh <evidence_dir>
set -euo pipefail
export LC_ALL=C
dir=${1:?usage: check_provenance.sh <evidence_dir>}
CHAINS_ZIP=https://emudhra.we-have-a-problem.com/chains.zip
CHAINS_SHA256=7b949956955fc501a30f4d98d2f513d34c0bbbe92e29a968194c96e097ce2345
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
fetch() { curl -sSfL --retry 3 "$@"; }
report() { if cmp -s "$1" "$2"; then echo "MATCH     $3"; else echo "MISMATCH  $3"; fi; }
if command -v sha256sum > /dev/null 2>&1; then SHA256="sha256sum"; else SHA256="shasum -a 256"; fi

for store in "$dir"/stores/node-v*/roots.pem; do
  v=$(basename "$(dirname "$store")"); v=${v#node-}
  fetch -o "$work/h" "https://raw.githubusercontent.com/nodejs/node/$v/src/node_root_certs.h"
  # Each PEM line in the header is a C string literal: "MIIE...\n" or "-----END CERTIFICATE-----",
  python3 -I - "$work/h" > "$work/roots.pem" << 'PY'
import sys
for line in open(sys.argv[1]):
    if line.startswith('"'):
        pem = line.strip()[1:].rstrip(",").rstrip('"')
        print(pem[:-2] if pem.endswith("\\n") else pem)
PY
  report "$work/roots.pem" "$store" "stores/node-$v/roots.pem = src/node_root_certs.h at nodejs/node $v"
  h="$dir/sources/node-$v-node_root_certs.h"
  [ ! -f "$h" ] || report "$work/h" "$h" "sources/node-$v-node_root_certs.h = nodejs/node $v"
done

fetch -o "$work/chains.zip" "$CHAINS_ZIP"
got=$($SHA256 < "$work/chains.zip" | cut -d' ' -f1)
if [ "$got" = "$CHAINS_SHA256" ]; then echo "MATCH     $CHAINS_ZIP sha256 $got"; else echo "CHANGED   $CHAINS_ZIP sha256 now $got, was $CHAINS_SHA256"; fi
for pem in "$dir"/chains/*.pem; do
  n=$(basename "$pem")
  if python3 -I -c 'import sys, zipfile; sys.stdout.buffer.write(zipfile.ZipFile(sys.argv[1]).read("chains/" + sys.argv[2]))' "$work/chains.zip" "$n" > "$work/pem" 2> /dev/null; then
    report "$work/pem" "$pem" "chains/$n = chains.zip member"
  else
    echo "MISMATCH  chains/$n is no longer in chains.zip"
  fi
done

for tag in 20 20-slim 20-alpine; do
  was=$(awk -v s="library/node:$tag" '$0 == s {f = 1; next} f && /index digest:/ {print $3; exit}' "$dir/results/registry-state.txt")
  now=$(fetch "https://hub.docker.com/v2/repositories/library/node/tags/$tag" | python3 -I -c 'import json, sys; print(json.load(sys.stdin)["digest"])')
  if [ "$now" = "$was" ]; then echo "MATCH     node:$tag still $was"; else echo "CHANGED   node:$tag now $now, was $was"; fi
done
