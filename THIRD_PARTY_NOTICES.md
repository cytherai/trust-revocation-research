# Third-party notices

The evidence package contains third-party material. It keeps its own terms.
`LICENSE-DOCS` and `LICENSE-CODE` do not apply to it, and CytherAI claims no
ownership of it.

| In `node20-trust-evidence.zip` | Source | Terms |
|---|---|---|
| `chains/*.pem` | Test certificate chains published by https://emudhra.we-have-a-problem.com/ in `chains.zip` (SHA-256 `7b949956955fc501a30f4d98d2f513d34c0bbbe92e29a968194c96e097ce2345`), unmodified | The site publishes no license. The chains are included as certificate data for verification. `chains.zip` and its README are not redistributed; get them from the URL above. |
| `sources/node-v*-node_root_certs.h` | `src/node_root_certs.h` from https://github.com/nodejs/node at the matching release tag, unmodified | Node.js license: https://github.com/nodejs/node/blob/main/LICENSE |
| `stores/node-v*/roots.pem` | The same header at each tag, with each PEM line taken out of its C string quoting and nothing else changed | As above |
| The certificates in the two rows above | Mozilla's NSS root store, `lib/ckfw/builtins/certdata.txt` | Mozilla Public License 2.0: https://mozilla.org/MPL/2.0/ |
| `results/registry-state.txt` | Tag data from the Docker Hub API (hub.docker.com/v2) | Factual records |

`node20-live-tls-2026-10-23.zip` contains only CytherAI's scripts and results.
The certificate fields recorded in its results are factual data from the TLS
connections.
