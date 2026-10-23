#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 CytherAI
#
# Verify an evidence package's never-CT-logged test chains against each of its
# trust stores, the way a client that ignores revocation and CT would: leaf
# first, the rest of the chain untrusted. Chains are verified as of the
# package's RETRIEVED_AT, so the results still hold after the test leaves
# expire on 2027-05-05.
# Needs OpenSSL 3 or later. macOS's /usr/bin/openssl is LibreSSL, whose verify
# lacks -verify_hostname; install OpenSSL (brew install openssl@3) first in PATH.
# Usage: verify_stores.sh <evidence_dir>
set -u
export LC_ALL=C
dir=${1:?usage: verify_stores.sh <evidence_dir>}
[ -f "$dir/RETRIEVED_AT" ] || { echo "verify_stores.sh: $dir is not an extracted evidence package (no RETRIEVED_AT)" >&2; exit 2; }
case "$(openssl version)" in
  "OpenSSL "[3-9].*) ;;
  *) echo "verify_stores.sh: needs OpenSSL 3 or later, found: $(openssl version)" >&2; exit 2 ;;
esac
t=$(cat "$dir/RETRIEVED_AT")
attime=$(date -u -d "$t" +%s 2> /dev/null || date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$t" +%s)
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
echo "# $(openssl version); trust anchors: only the store tested (-no-CApath -no-CAstore); verified as of $t"
for chain in "$dir"/chains/dv-g3b-noct-emudhra.we-have-a-problem.com.pem "$dir"/chains/dv-g3b-aaa-noct-emudhra.we-have-a-problem.com.pem; do
  host=$(basename "$chain" .pem)
  awk -v d="$work" '/BEGIN CERT/{n++} {print > (d "/c" n ".pem")}' "$chain"
  cat "$work"/c[2-9].pem > "$work/untrusted.pem"
  for store in "$dir"/stores/*/*; do
    # -CAfile replaces only OpenSSL's default CA file; -no-CApath and -no-CAstore
    # stop the default directory and store from adding trust anchors.
    r=$(openssl verify -attime "$attime" -CAfile "$store" -no-CApath -no-CAstore -untrusted "$work/untrusted.pem" \
        -purpose sslserver -verify_hostname "$host" "$work/c1.pem" 2>&1)
    case "$r" in
      *": OK") v=ACCEPTED ;;
      *"depth lookup:"*) v="rejected ($(printf '%s\n' "$r" | grep -m1 'depth lookup:' | sed 's/^error //'))" ;;
      *) printf 'verify_stores.sh: unexpected openssl output for %s:\n%s\n' "$store" "$r" >&2; exit 2 ;;
    esac
    printf '%-16s %-26s %s\n' "${host%%-emudhra*}" "$(basename "$(dirname "$store")")/$(basename "$store")" "$v"
  done
  rm -f "$work"/c*.pem
done
