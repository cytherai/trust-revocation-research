# Methodology

Question: after a root program distrusts a certificate authority, does a given
published software artifact still accept certificate chains from it?

## Test chains

The disclosure site publishes certificate chains for offline testing in
https://emudhra.we-have-a-problem.com/chains.zip. We use two of them, whose
leaves were never logged to Certificate Transparency:

- `dv-g3b-noct`: leaf, the compromised EM DV TLS CA - G3B intermediate, and
  emSign Root TLS CA - G3 cross-signed by emSign ECC Root CA - G3
- `dv-g3b-aaa-noct`: leaf and the same intermediate cross-signed by AAA
  Certificate Services

## Trust stores

Each store is taken from the artifact's own published source. For Node.js,
that is `src/node_root_certs.h` at the release tag, with each PEM line taken
out of its C string quoting and nothing else changed.
`scripts/check_provenance.sh` repeats this conversion and compares the result.

Which Node.js version an image runs is read from the image's published
configuration on Docker Hub (`NODE_VERSION`), together with the image digests
and push dates.

## Verification

`scripts/verify_stores.sh` runs `openssl verify` (OpenSSL 3) with:
- the store as the only trust anchors: `-CAfile`, plus `-no-CApath` and
  `-no-CAstore`, which stop OpenSSL's default directory and store from adding
  anchors;
- the rest of the chain as untrusted intermediates (`-untrusted`);
- purpose `sslserver` and the test host name (`-verify_hostname`);
- the evidence's `RETRIEVED_AT` as the verification time (`-attime`), so the
  results reproduce after the test leaves expire.

`scripts/check_isolation.sh` checks the isolation. It runs `verify_stores.sh`
again with emSign ECC Root CA - G3 placed in OpenSSL's default trust
locations, and requires the results to be unchanged.

The 2026-10-22 run used the current time and `-CAfile` only. Its results are
unaffected. Default trust locations can only add trust anchors, and in that run
the 22.23.4 and 24.22.1 stores rejected both chains. That could not have
happened if the host's default locations had held either root the chains need.
An isolated re-verification gives the same results, and is recorded in
`evidence/node20-trust-evidence-isolated-check-2026-10-23.txt`.

No revocation and no Certificate Transparency checks are made. This matches
clients that rely on their trust store alone, as Node.js does by default.

Each result is ACCEPTED, or rejected with OpenSSL's reason.

## Live HTTPS test

`scripts/run_node_tls_probe.sh` runs `scripts/node_tls_probe.js` inside each
official image, pinned by index digest, on a chosen platform. The probe makes
one HTTPS GET with Node.js's `https` module and certificate verification on
(`rejectUnauthorized: true`). It records the Node.js version, the
architecture, the TLS version, the peer certificate and the HTTP status, or
the error code.

- ACCEPT means the TLS handshake completed with a verified chain and an HTTP
  response arrived, whatever its status.
- REJECT means a certificate verification error.
- ERROR is anything else: timeouts, DNS or network failures, unknown error
  codes, or no result within 30 seconds.

Each case also states what it expects:
- the Node.js version;
- the outcome;
- a detail: for a REJECT, the error code; for an ACCEPT of the test endpoint,
  the SHA-256 fingerprint of the leaf in the evidence's test chain.

The probe records `version_match`, `outcome_match` and `detail_match`. A
mismatch means the runtime, the endpoint or the reason for a rejection has
changed, and the result needs review before any conclusion is drawn. After all
cases have run, the script fails the run unless `results.jsonl` holds exactly
one record per case, in order, with every check passed. It then seals the
output with `SHA256SUMS`. It refuses to reuse an existing output directory, so
a retry never overwrites an earlier run.

Each image must accept example.com as a control. `--use-openssl-ca` is tested
against example.com too, so that a rejection caused by an empty store can't be
mistaken for distrust.

The 2026-10-23 runs used the earlier version of the probe and runner; both are
archived in `evidence/node20-live-tls-2026-10-23.zip`. That version recorded
the outcome and version checks but not the detail check. The archived results
contain the expected error code and leaf fingerprint for every case.

## Integrity

- Every file in the evidence package is listed in its `SHA256SUMS`, and the
  package's own hash is in `evidence/SHA256SUMS`.
- Apart from its README and checksum list, the package is an unmodified subset
  of a larger snapshot whose hash is published in the README. Anyone can check
  the subset when that snapshot is released.
- `scripts/check_provenance.sh` re-derives the Node.js stores from their tags,
  checks the test chains against chains.zip, and compares the `node:20` tags
  with the recorded digests. It exits 1 if any evidence differs from its
  source, and 2 if it could not complete. A moved image tag is reported as
  CHANGED and does not affect the archived evidence.

## What a result means

An ACCEPTED result means different things in the two tests:
- In the offline check, the trust store would validate the chain.
- In the live test, the runtime completed a verified HTTPS connection through
  it.

Neither result establishes that any deployment runs the artifact, or that any
interception occurred. See [limitations.md](limitations.md).
