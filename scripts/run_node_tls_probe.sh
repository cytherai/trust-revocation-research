#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 CytherAI
#
# Live HTTPS test of the Node.js runtime in the official images against the
# disclosure site's test endpoint, with certificate verification on. Each case
# runs scripts/node_tls_probe.js in a container and appends one JSON line to
# results.jsonl. The run then checks that every case was recorded with the
# expected Node.js version, outcome and detail (error code, or the accepted
# leaf certificate's fingerprint), and seals the output with SHA256SUMS.
# Needs Docker and python3.
# Usage: run_node_tls_probe.sh [<output_dir>]
#   The output directory must not exist yet; a failed run keeps its own record.
#   DOCKER_PLATFORM=linux/amd64 matches the amd64 digests recorded in the
#   evidence; the default is linux/arm64.
set -euo pipefail

HOST='https://dv-g3b-noct-emudhra.we-have-a-problem.com/'
CONTROL='https://example.com/'
# Leaf of chains/dv-g3b-noct-emudhra.we-have-a-problem.com.pem in node20-trust-evidence.zip.
LEAF='0C:BF:E2:2B:82:43:85:82:3F:D3:BF:4B:E4:D1:31:E8:90:13:42:93:3A:7F:EE:F1:CF:8B:31:10:B8:E4:4A:70'
# Both images are pinned by index digest. The node:20-slim digest is the one
# recorded in node20-trust-evidence.zip (results/registry-state.txt).
NODE20='node:20-slim@sha256:2cf067cfed83d5ea958367df9f966191a942351a2df77d6f0193e162b5febfc0'
PATCHED='node:22.23.4-bookworm-slim@sha256:de170b39439eb0e5a3444ad7d60b015614a381e10fecae2e30ec9e735122f38d'
ARCH="${DOCKER_PLATFORM:-linux/arm64}"
OUT="${1:-tls-node-runtime-$(date -u +%Y%m%dT%H%M%SZ)}"
if command -v sha256sum > /dev/null 2>&1; then SHA256="sha256sum"; else SHA256="shasum -a 256"; fi
# Never reuse an output directory: an earlier run's evidence must not be overwritten.
if [ -e "$OUT" ]; then
  echo "run_node_tls_probe.sh: $OUT already exists; give a new output directory" >&2
  exit 2
fi
# Check Docker before creating any output, so a run that cannot start leaves
# no sealed directory behind.
if ! docker info > /dev/null 2>&1; then
  echo "run_node_tls_probe.sh: the Docker daemon is not running. Start Docker and wait until 'docker info' succeeds." >&2
  exit 2
fi
mkdir "$OUT" || { echo "run_node_tls_probe.sh: cannot create $OUT" >&2; exit 2; }
cp "$(dirname "$0")/node_tls_probe.js" "$OUT/node_tls_probe.js"
: > "$OUT/results.jsonl"
ANY_FAILURE=0
CASES=""
seal_evidence() {
  (cd "$OUT" && $SHA256 node_tls_probe.js results.jsonl environment.txt > SHA256SUMS)
}
trap seal_evidence EXIT
{
  printf 'Timestamp UTC: %s\n' "$(date -u +%FT%TZ)"
  printf 'Docker platform: %s\n' "$ARCH"
  printf 'Affected reference: %s\nPatched reference: %s\n' "$NODE20" "$PATCHED"
  docker version --format 'Docker client {{.Client.Version}} server {{.Server.Version}}'
} | tee "$OUT/environment.txt"

docker pull --platform "$ARCH" "$NODE20"
docker pull --platform "$ARCH" "$PATCHED"
# The architecture each case ran is recorded by the probe itself (the arch field).
for image in "$NODE20" "$PATCHED"; do
  docker image inspect "$image" --format 'IMAGE={{json .RepoTags}} REPO_DIGESTS={{json .RepoDigests}} IMAGE_ID={{.Id}}' | tee -a "$OUT/environment.txt"
done

run_case() {
  local label="$1" image="$2" expected_ver="$3" expected_outcome="$4" expected_detail="$5" target="$6"; shift 6
  CASES="$CASES $label"
  printf '\n### %s ###\n' "$label" | tee -a "$OUT/environment.txt"
  # Clear NODE_* switches and leave SSL_CERT_FILE / SSL_CERT_DIR unset, so
  # --use-openssl-ca loads OpenSSL's own default store.
  set +e
  docker run --rm --platform "$ARCH" --network bridge \
    --mount "type=bind,src=$(cd "$OUT" && pwd),dst=/probe,readonly" \
    -e PROBE_LABEL="$label" -e EXPECT_NODE_VERSION="$expected_ver" -e EXPECT_OUTCOME="$expected_outcome" \
    -e EXPECT_DETAIL="$expected_detail" \
    -e NODE_OPTIONS= -e NODE_EXTRA_CA_CERTS= -e NODE_USE_SYSTEM_CA= \
    "$image" node "$@" /probe/node_tls_probe.js "$target" | tee -a "$OUT/results.jsonl"
  local statuses=("${PIPESTATUS[@]}")
  set -e
  if [[ "${statuses[0]}" -ne 0 || "${statuses[1]}" -ne 0 ]]; then
    printf "CASE_FAILED %s docker_exit=%s tee_exit=%s\n" "$label" "${statuses[0]}" "${statuses[1]}" | tee -a "$OUT/environment.txt"
    ANY_FAILURE=1
  fi
}

# Both images must complete an ordinary HTTPS request: network and client control.
run_case node20-control "$NODE20" v20.20.2 ACCEPT "" "$CONTROL"
run_case node22-control "$PATCHED" v22.23.4 ACCEPT "" "$CONTROL"
# Main comparison: an HTTPS GET with Node's default certificate verification.
run_case node20-default "$NODE20" v20.20.2 ACCEPT "$LEAF" "$HOST"
run_case node20-forced-bundled "$NODE20" v20.20.2 ACCEPT "$LEAF" "$HOST" --use-bundled-ca
# Node.js 22.23.4 reports chains through the blocked intermediate keys as CERT_REVOKED (nodejs/node#66871).
run_case node22-default "$PATCHED" v22.23.4 REJECT CERT_REVOKED "$HOST"
# --use-openssl-ca switches Node 20 to OpenSSL's default store. node:20-slim
# ships no system CA bundle, so that store is empty. The control shows every
# chain is then rejected, so the second case says nothing about distrust.
run_case node20-openssl-control "$NODE20" v20.20.2 REJECT UNABLE_TO_GET_ISSUER_CERT_LOCALLY "$CONTROL" --use-openssl-ca
run_case node20-openssl "$NODE20" v20.20.2 REJECT UNABLE_TO_GET_ISSUER_CERT_LOCALLY "$HOST" --use-openssl-ca

# Completeness: exactly one record per case, in order, with every check passed.
# A checksum shows the retained bytes are intact; this shows the run is complete.
# shellcheck disable=SC2086
if ! python3 -I - "$OUT/results.jsonl" $CASES << 'PY' | tee -a "$OUT/environment.txt"
import json, sys
path, expected = sys.argv[1], sys.argv[2:]
try:
    rows = [json.loads(line) for line in open(path) if line.strip()]
except ValueError as err:
    print(f"VALIDATION FAILED: results.jsonl is not valid JSON lines ({err})")
    sys.exit(1)
problems = []
labels = [row.get("label") for row in rows]
if labels != expected:
    problems.append(f"recorded cases {labels}, expected {expected}")
for row in rows:
    for key in ("version_match", "outcome_match", "detail_match"):
        if row.get(key) is not True:
            problems.append(f"{row.get('label')}: {key} is {row.get(key)}")
if problems:
    print("VALIDATION FAILED: " + "; ".join(problems))
    sys.exit(1)
print(f"VALIDATION PASSED: all {len(rows)} cases recorded with the expected version, outcome and detail")
PY
then
  ANY_FAILURE=1
fi

seal_evidence
printf '\nEvidence saved in: %s\n' "$OUT"
cat "$OUT/SHA256SUMS"
exit "$ANY_FAILURE"
