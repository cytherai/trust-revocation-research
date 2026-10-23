# The eMudhra intermediate CA key compromise, October 2026

A summary from primary sources, for context. The discovery and the root
programs' response are other people's work; see Credit.

| When (UTC) | Event | Source |
|---|---|---|
| 2026-10-17 20:06 | Mozilla receives a report from Wayne, forwarded by the Chrome Root Program, that the private keys of eight eMudhra intermediate CA certificates are compromised, with proof of key control. Six are TLS intermediates trusted by the Chrome, Mozilla, Microsoft and Apple root programs; two are code-signing intermediates trusted by Microsoft. | Bugzilla 2083449 |
| 2026-10-17 21:48 | Mozilla independently recovers the private keys. | Bugzilla 2083449 |
| 2026-10-17 | Firefox and Chrome block the certificates. | Bugzilla 2083449; disclosure site |
| 2026-10-18 09:38 | eMudhra marks the eight certificates revoked, reason caCompromise. | Bugzilla 2083449 |
| 2026-10-18 | certifi 2026.10.18 removes the emSign roots (advisory GHSA-6q48-6c7w-9gw2, published 2026-10-20). | PyPI; GitHub advisory |
| By 2026-10-21 | Mozilla removes emSign ECC Root CA - G3 from NSS as an emergency measure (Bugzilla 2084101), but keeps emSign Root CA - G1. NSS 3.131.1 no longer contains the G3 root. | Bugzilla 2083449; Node.js 22.23.4 roots |
| 2026-10-20 | Microsoft platforms begin blocking the certificates. | Disclosure site |
| 2026-10-21 | Node.js 22.23.4, 24.22.1 and 26.12.1 update root certificates to NSS 3.131.1 and reject chains containing the blocked public keys. | Node.js security releases |
| 2026-10-22 | Apple begins blocking the certificates. The disclosure site adds test chains whose leaves were never logged to CT. | Disclosure site |

The disclosure site attributes the compromise to the CA generating the keys
incorrectly.

## Credit

Wayne reported the compromise, and the Chrome Root Program forwarded the report
to Mozilla. Mozilla confirmed it and recovered the keys independently. The
disclosure site, its test chains and its downstream patch list are by Dennis
Jackson and contributors.

## Sources

- https://bugzilla.mozilla.org/show_bug.cgi?id=2083449
- https://emudhra.we-have-a-problem.com/
- https://github.com/certifi/python-certifi/security/advisories/GHSA-6q48-6c7w-9gw2
- https://nodejs.org/en/blog/vulnerability/october-2026-security-releases
