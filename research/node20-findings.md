# Official Node 20 Docker Images Still Trust a Compromised eMudhra Certificate Chain — Rebuilding Doesn't Fix It

CytherAI · Malek Alhazmi · Published 23 October 2026 · Evidence retrieved 2026-10-22 21:19 UTC

On 17 October 2026, the private keys of eight eMudhra intermediate CAs were
confirmed compromised (Mozilla Bugzilla 2083449). Browsers blocked them within
days. On 21 October, Node.js released 22.23.4, 24.22.1 and 26.12.1 with two
fixes: root certificates updated to NSS 3.131.1, which removes emSign ECC Root
CA - G3 (nodejs/node#66877), and rejection of chains containing the blocked
public keys (nodejs/node#66871).

Node.js 20 reached end of life on 30 April 2026 and will not get those fixes.
The official images are frozen on Node.js 20.20.2:

| Tag | Index digest | Last pushed |
|---|---|---|
| `node:20` | `sha256:8f693eaa7e0a8e71560c9a82b55fd54c2ae920a2ba5d2cde28bac7d1c01c9ba5` | 2026-04-22 |
| `node:20-slim` | `sha256:2cf067cfed83d5ea958367df9f966191a942351a2df77d6f0193e162b5febfc0` | 2026-04-22 |
| `node:20-alpine` | `sha256:fb4cd12c85ee03686f6af5362a0b0d56d50c58a04632e6c0fb8363f609372293` | 2026-04-15 |

Node.js 20.20.2's built-in root store includes emSign ECC Root CA - G3, and
Node.js 20 uses that store by default. Only starting it with `--use-openssl-ca`
switches it to the OpenSSL store, so patching the operating system's trust
store doesn't change a default Node.js 20 process.

## What we verified

We took the root list from Node.js's source (`src/node_root_certs.h`) at each
release tag and checked it with OpenSSL against two test chains published by
the disclosure site, whose leaves were never logged to Certificate
Transparency:

| Node.js roots | Chain via emSign ECC Root CA - G3 | Chain via AAA Certificate Services cross-sign |
|---|---|---|
| 20.20.2 | accepted | rejected |
| 22.22.0 | accepted | rejected |
| 22.23.4 | rejected | rejected |
| 24.22.1 | rejected | rejected |

The images' Node.js version comes from their published configuration
(`NODE_VERSION=20.20.2`); we did not extract roots from the image binaries.
This shows that the trust store would validate such a chain. It doesn't show
any attack, interception or affected deployment. Images built from `node:22`
or `node:24` before the fixed releases carry older roots too: 22.22.0 accepts
the chain.

## Why rebuilding doesn't help

Node.js 20 has been dropped from the docker-node build matrix, so the `node:20`
tags are no longer rebuilt and `docker build --pull` keeps returning the same
runtime. Upgrading ca-certificates in the image doesn't help either, because a
default Node.js 20 process never reads the OS store. The supported tags
(`node:22`, `node:24`, `node:26`) were rebuilt on the fixed versions by
22 October.

## What to do

Move runtime stages to `node:22` at 22.23.4 or later, `node:24` at 24.22.1 or
later, or `node:26` at 26.12.1 or later. Pin by digest and confirm the Node.js
version in the image you actually ship.

## Evidence

`evidence/node20-trust-evidence.zip` in release v0.1.0, with its SHA-256 in
`evidence/SHA256SUMS`. The README explains how to verify and reproduce it.
Method: [methodology.md](methodology.md). Limits: [limitations.md](limitations.md).
Background: [emudhra-incident.md](emudhra-incident.md).

## Sources

- Mozilla Bugzilla 2083449: https://bugzilla.mozilla.org/show_bug.cgi?id=2083449
- Node.js security releases, 21 October 2026: https://nodejs.org/en/blog/vulnerability/october-2026-security-releases
- Node.js release schedule: https://github.com/nodejs/Release
- docker-node versions: https://github.com/nodejs/docker-node/blob/main/versions.json
- Node.js `--use-openssl-ca`: https://github.com/nodejs/node/blob/v20.20.2/doc/api/cli.md
