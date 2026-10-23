#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 CytherAI
#
# Check that verify_stores.sh trusts only the store it is given. It runs
# verify_stores.sh twice: once as is, and once with OpenSSL's default trust
# locations (SSL_CERT_FILE, SSL_CERT_DIR) holding emSign ECC Root CA - G3, the
# root the test chain needs. The two outputs must be identical.
# Exit status: 0 isolated, 1 the default locations changed a result,
# 2 the input is not an extracted evidence package.
# Needs bash and OpenSSL 3 or later. Usage: check_isolation.sh <evidence_dir>
set -euo pipefail
export LC_ALL=C
dir=${1:?usage: check_isolation.sh <evidence_dir>}
[ -f "$dir/RETRIEVED_AT" ] || { echo "check_isolation.sh: $dir is not an extracted evidence package (no RETRIEVED_AT)" >&2; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
mkdir "$work/ambient"

# Take emSign ECC Root CA - G3 from the Node.js 20.20.2 store in the package.
awk -v d="$work" '/BEGIN CERT/{n++} {print > (d "/r" n ".pem")}' "$dir/stores/node-v20.20.2/roots.pem"
for c in "$work"/r[1-9]*.pem; do
  case "$(openssl x509 -in "$c" -noout -subject 2> /dev/null)" in
    *"CN=emSign ECC Root CA - G3" | *"CN = emSign ECC Root CA - G3") cp "$c" "$work/ambient/root.pem" ;;
  esac
done
[ -f "$work/ambient/root.pem" ] || { echo "check_isolation.sh: emSign ECC Root CA - G3 not found in node-v20.20.2/roots.pem" >&2; exit 2; }
openssl rehash "$work/ambient" > /dev/null

bash "$here/verify_stores.sh" "$dir" > "$work/clean.txt"
SSL_CERT_FILE="$work/ambient/root.pem" SSL_CERT_DIR="$work/ambient" bash "$here/verify_stores.sh" "$dir" > "$work/ambient.txt"
if cmp -s "$work/clean.txt" "$work/ambient.txt"; then
  echo "PASS: results unchanged with emSign ECC Root CA - G3 in OpenSSL's default trust locations"
else
  echo "FAIL: OpenSSL's default trust locations changed the results:"
  diff "$work/clean.txt" "$work/ambient.txt" || true
  exit 1
fi
