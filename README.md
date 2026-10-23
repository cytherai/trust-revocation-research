# CytherAI Trust Revocation Research

When a root program distrusts a certificate authority, do published software
artifacts stop trusting it? This repository records our measurements, the
evidence behind them, and scripts to reproduce them.

## Finding: Node.js 20 and the eMudhra intermediate CA compromise

On 17 October 2026 the private keys of eight eMudhra intermediate CAs were
confirmed compromised (Mozilla Bugzilla 2083449). On 21 October, Node.js fixed
its supported lines in 22.23.4, 24.22.1 and 26.12.1. Node.js 20 reached end of
life on 30 April 2026 and did not get the fix.

**Finding:** the official `node:20`, `node:20-slim` and `node:20-alpine` images
run Node.js 20.20.2, whose built-in root store still accepts a certificate
chain from one of the compromised intermediates. Rebuilding does not change
that. In a live HTTPS test, the runtime in `node:20-slim` completed a
certificate-verified connection to the disclosure site's test endpoint, and
the runtime in `node:22.23.4` rejected it. Report:
[research/node20-findings.md](research/node20-findings.md).

This shows that the runtime trusts a chain through a compromised intermediate.
It does not show an attack, an interception or an affected deployment.

## Finding: certifi downloads after the fix

certifi, the CA bundle that Python's requests uses by default, removed emSign
ECC Root CA - G3 in 2026.10.18 on 18 October. **From 20 to 22 October, 30.7% of
certifi downloads from PyPI were still of releases that contain the root**:
59.3 million of 193.0 million, excluding the bandersnatch mirror client. 44.5%
of those affected downloads were of releases more than six months old, which
is consistent with pinned versions that an upstream fix does not move. Report:
[research/certifi-download-share.md](research/certifi-download-share.md).

Download counts measure installation activity, not deployments.

## Verify it yourself

You need bash, curl, python3 and OpenSSL 3 or later. On macOS, `/usr/bin/openssl`
is LibreSSL, which cannot run these checks: install OpenSSL
(`brew install openssl@3`) and put it first in `PATH`.

    (cd evidence && sha256sum -c SHA256SUMS)      # or: shasum -a 256 -c SHA256SUMS
    unzip -oq evidence/node20-trust-evidence.zip -d /tmp/ev
    (cd /tmp/ev/node20-trust-evidence && sha256sum -c SHA256SUMS)
    bash scripts/verify_stores.sh /tmp/ev/node20-trust-evidence
    bash scripts/check_isolation.sh /tmp/ev/node20-trust-evidence
    bash scripts/check_provenance.sh /tmp/ev/node20-trust-evidence
    unzip -oq evidence/node20-live-tls-2026-10-23.zip -d /tmp/ev
    (cd /tmp/ev/node20-live-tls-2026-10-23 && sha256sum -c SHA256SUMS)
    unzip -oq evidence/certifi-download-share-2026-10-22.zip -d /tmp/ev
    (cd /tmp/ev/certifi-download-share-2026-10-22 && sha256sum -c SHA256SUMS)

What each script should show:
- `verify_stores.sh` reports the chain through emSign ECC Root CA - G3 as
  ACCEPTED by the Node.js 20.20.2 and 22.22.0 roots, and rejected by 22.23.4
  and 24.22.1. It trusts only the store under test.
- `check_isolation.sh` confirms that the results don't change when OpenSSL's
  default trust locations hold the emSign root.
- `check_provenance.sh` runs three checks against the live sources: it
  re-derives each Node.js root store from its release tag, checks the test
  chains against the disclosure site's chains.zip, and checks that the
  `node:20` tags still point at the recorded digests. It exits 1 if any
  evidence differs from its source.

The live HTTPS test's results are in `runs/*/results.jsonl` in
`node20-live-tls-2026-10-23.zip`. To repeat the test you need Docker. Run it
from the repository, giving an output directory that doesn't exist yet, for
example `bash scripts/run_node_tls_probe.sh /tmp/tls-run`. Set
`DOCKER_PLATFORM=linux/amd64` for amd64.

To repeat the certifi measurement you need only Python 3, and an output
directory that doesn't exist yet:

    python3 -I scripts/certifi_download_share.py 2026-10-13 2026-10-22 /tmp/certifi-run

The new `clickpy-daily.tsv` should match the archived one unless ClickPy has
revised its counts, and the same 42 of 77 versions should contain the root.

## Evidence and timing

The evidence in `node20-trust-evidence.zip` was retrieved on 2026-10-22 at
21:19 UTC (`RETRIEVED_AT` in the package), before this repository was
published. The live HTTPS test ran on 2026-10-23 between 06:13 and 06:17 UTC,
and `node20-live-tls-2026-10-23.zip` holds both runs unmodified. The certifi
download counts in `certifi-download-share-2026-10-22.zip` cover 13 to
22 October and were retrieved on 2026-10-23 at 13:20 UTC.

The two Node.js packages contain only the Node.js material. Apart from its
README and checksum list, every file in `node20-trust-evidence.zip` is
unmodified from CytherAI's full evidence snapshot, or, under `results/`, made
of unmodified lines from it. The full snapshot (zip SHA-256
`6f5f468885c921d9b4be8b3ca881d568384d8c2097caef6b822e10724648435c`) also covers
a finding under coordinated disclosure, and will be published once that
disclosure ends.

## Layout

- `research/`: the report, methodology, incident background and limitations
- `evidence/`: the evidence packages and their checksums
- `scripts/`: reproduction scripts
- `disclosures/`: the disclosure timeline

## Licensing

- Research documents and original results: CC BY 4.0 (`LICENSE-DOCS`).
- Original scripts: Apache-2.0 (`LICENSE-CODE`), marked with SPDX headers.
- Third-party certificates, trust stores and Node.js source files keep their
  own terms (`THIRD_PARTY_NOTICES.md`); neither license above applies to them.
- CytherAI's verification software is not part of this repository.

## Credit

Wayne reported the key compromise, and the Chrome Root Program forwarded it to
Mozilla. Mozilla confirmed it and recovered the keys independently. The test
chains and the offline check come from https://emudhra.we-have-a-problem.com/
(Dennis Jackson and contributors). The certifi download counts are PyPI's
public download statistics, served by ClickHouse's ClickPy.

Research by Malek Alhazmi, CytherAI. To cite this work, use
`CITATION.cff`. To report a problem, see `SECURITY.md`.
