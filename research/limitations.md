# Limitations

- Acceptance is by the trust store, verified offline with OpenSSL. Nothing here
  shows an attack, an interception or an affected running deployment.
- No revocation or Certificate Transparency checks were made. Clients that
  check revocation or enforce CT may reject these chains whatever their trust
  store holds. Node.js does neither by default.
- Node.js root stores come from `src/node_root_certs.h` at each release tag,
  not from the image binaries. The images' Node.js version comes from their
  published configuration.
- Node.js 22.23.4 and later also reject chains containing the blocked public
  keys directly (nodejs/node#66871). This test checks only the root store, so
  it understates how fully the fixed versions reject these chains.
- A Dockerfile that uses `node:20` shows what an image built from it would
  contain, not that a vulnerable deployment exists.
- Docker Hub tags change. The recorded state is as of `RETRIEVED_AT`;
  `scripts/check_provenance.sh` reports the current state.
- The test leaves expire on 2027-05-05. `scripts/verify_stores.sh` verifies as
  of `RETRIEVED_AT`, so its results stay reproducible after that.
- The scripts need OpenSSL 3 or later. LibreSSL, which is macOS's
  /usr/bin/openssl, lacks the options used, and the scripts refuse to run with
  it.
