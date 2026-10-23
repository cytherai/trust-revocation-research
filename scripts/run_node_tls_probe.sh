#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 CytherAI
#
# Live HTTPS test of the Node.js runtime in the official images against the
# disclosure site's test endpoint, with certificate verification on. Each case
# runs scripts/node_tls_probe.js in a container and appends one JSON line to
# results.jsonl. The output directory is sealed with SHA256SUMS.
# Needs Docker. Run it from outside the repository, or give an output directory.
# Usage: run_node_tls_probe.sh [<output_dir>]
#   DOCKER_PLATFORM=linux/amd64 matches the amd64 digests recorded in the
#   evidence; the default is linux/arm64.
set -euo pipefail

HOST='https://dv-g3b-noct-emudhra.we-have-a-problem.com/'
CONTROL='https://example.com/'
# Both images are pinned by index digest. The node:20-slim digest is the one
# recorded in node20-trust-evidence.zip (results/registry-state.txt).
NODE20='node:20-slim@sha256:2cf067cfed83d5ea958367df9f966191a942351a2df77d6f0193e162b5febfc0'
PATCHED='node:22.23.4-bookworm-slim@sha256:de170b39439eb0e5a3444ad7d60b015614a381e10fecae2e30ec9e735122f38d'
ARCH="${DOCKER_PLATFORM:-linux/arm64}"
OUT="${1:-tls-node-runtime-$(date -u +%Y%m%dT%H%M%SZ)}"
if command -v sha256sum > /dev/null 2>&1; then SHA256="sha256sum"; else SHA256="shasum -a 256"; fi
# Check Docker before creating any output, so a run that cannot start leaves
# no sealed directory behind.
if ! docker info > /dev/null 2>&1; then
  echo "run_node_tls_probe.sh: the Docker daemon is not running. Start Docker and wait until 'docker info' succeeds." >&2
  exit 2
fi
mkdir -p "$OUT"
cp "$(dirname "$0")/node_tls_probe.js" "$OUT/node_tls_probe.js"
: > "$OUT/results.jsonl"
ANY_FAILURE=0
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
  local label="$1" image="$2" expected_ver="$3" expected_outcome="$4" target="$5"; shift 5
  printf '\n### %s ###\n' "$label" | tee -a "$OUT/environment.txt"
  # Clear NODE_* switches and leave SSL_CERT_FILE / SSL_CERT_DIR unset, so
  # --use-openssl-ca loads OpenSSL's own default store.
  set +e
  docker run --rm --platform "$ARCH" --network bridge \
    --mount "type=bind,src=$(cd "$OUT" && pwd),dst=/probe,readonly" \
    -e PROBE_LABEL="$label" -e EXPECT_NODE_VERSION="$expected_ver" -e EXPECT_OUTCOME="$expected_outcome" \
    -e NODE_OPTIONS= -e NODE_EXTRA_CA_CERTS= -e NODE_USE_SYSTEM_CA= \
    "$image" node "$@" /probe/node_tls_probe.js "$target" | tee -a "$OUT/results.jsonl"
  local status=${PIPESTATUS[0]}
  set -e
  if [[ "$status" -ne 0 ]]; then
    printf "CASE_FAILED %s exit=%s\n" "$label" "$status" | tee -a "$OUT/environment.txt"
    ANY_FAILURE=1
  fi
}

# Both images must complete an ordinary HTTPS request: network and client control.
run_case node20-control "$NODE20" v20.20.2 ACCEPT "$CONTROL"
run_case node22-control "$PATCHED" v22.23.4 ACCEPT "$CONTROL"
# Main comparison: an HTTPS GET with Node's default certificate verification.
run_case node20-default "$NODE20" v20.20.2 ACCEPT "$HOST"
run_case node20-forced-bundled "$NODE20" v20.20.2 ACCEPT "$HOST" --use-bundled-ca
run_case node22-default "$PATCHED" v22.23.4 REJECT "$HOST"
# --use-openssl-ca switches Node 20 to OpenSSL's default store. node:20-slim
# ships no system CA bundle, so that store is empty. The control shows every
# chain is then rejected, so the second case says nothing about distrust.
run_case node20-openssl-control "$NODE20" v20.20.2 REJECT "$CONTROL" --use-openssl-ca
run_case node20-openssl "$NODE20" v20.20.2 REJECT "$HOST" --use-openssl-ca

seal_evidence
printf '\nEvidence saved in: %s\n' "$OUT"
cat "$OUT/SHA256SUMS"
exit "$ANY_FAILURE"
