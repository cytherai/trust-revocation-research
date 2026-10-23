# Limitations

- Acceptance is by the trust store, verified offline with OpenSSL. Nothing here
  shows an attack, an interception or an affected running deployment.
- No revocation or Certificate Transparency checks were made. Clients that
  check revocation or enforce CT may reject these chains whatever their trust
  store holds. Node.js does neither by default.
- In the offline check, the Node.js root stores come from
  `src/node_root_certs.h` at each release tag. The live test exercised the
  binaries in `node:20-slim` and `node:22.23.4-bookworm-slim`. `node:20` and
  `node:20-alpine` run the same Node.js 20.20.2, but were not tested live.
- The offline check models only the root store. Node.js 22.23.4 and later also
  reject chains through the compromised intermediates directly, by their
  public keys (nodejs/node#66871). In the live test, that check is what
  rejected the endpoint (`CERT_REVOKED`).
- The live test is a point-in-time record of one test endpoint run by the
  disclosure site. That endpoint serves a chain through one of the eight
  compromised intermediates, EM DV TLS CA - G3B. The test ran on 2026-10-23
  on linux/arm64, and on linux/amd64 under emulation.
- In the linux/amd64 run, `environment.txt`'s `PLATFORM` field shows Docker's
  default platform for the image (linux/arm64), not the variant that ran. The
  `arch` field of each result records the architecture that ran (`x64`).
- A Dockerfile that uses `node:20` shows what an image built from it would
  contain, not that a vulnerable deployment exists.
- Docker Hub tags change. The recorded state is as of `RETRIEVED_AT`;
  `scripts/check_provenance.sh` reports the current state.
- The test leaves expire on 2027-05-05. `scripts/verify_stores.sh` verifies as
  of `RETRIEVED_AT`, so its results stay reproducible after that.
- The scripts need OpenSSL 3 or later. LibreSSL, which is macOS's
  /usr/bin/openssl, lacks the options used, and the scripts refuse to run with
  it.
