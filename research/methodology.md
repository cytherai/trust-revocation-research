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

`openssl verify` (OpenSSL 3) with the store as the only trust anchors
(`-CAfile`), the rest of the chain as untrusted intermediates (`-untrusted`),
purpose `sslserver` and the test host name (`-verify_hostname`). The 2026-10-22
run used the current time. `scripts/verify_stores.sh` verifies as of the
evidence's `RETRIEVED_AT` (`-attime`), so it reproduces the same results after
the test leaves expire.

No revocation and no Certificate Transparency checks are made. This matches
clients that rely on their trust store alone, as Node.js does by default.

Each result is ACCEPTED, or rejected with OpenSSL's reason.

## Integrity

- Every file in the evidence package is listed in its `SHA256SUMS`, and the
  package's own hash is in `evidence/SHA256SUMS`.
- Apart from its README and checksum list, the package is an unmodified subset
  of a larger snapshot whose hash is published in the README. Anyone can check
  the subset when that snapshot is released.
- `scripts/check_provenance.sh` re-derives the Node.js stores from their tags,
  checks the test chains against chains.zip, and compares the `node:20` tags
  with the recorded digests.

## What a result means

ACCEPTED means the trust store would validate the chain. It does not establish
that an application uses that store, that any deployment runs the artifact, or
that any interception occurred. See [limitations.md](limitations.md).
