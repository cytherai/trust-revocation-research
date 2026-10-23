# After the Fix, 30% of certifi Downloads Were Still Releases That Trust the Compromised eMudhra Root

CytherAI · Malek Alhazmi · Published 23 October 2026 · Evidence retrieved 2026-10-23 13:20 UTC

certifi packages Mozilla's CA bundle for Python, and requests uses it by
default. Every certifi release from 2019.3.9 through 2026.7.22 contains emSign
ECC Root CA - G3. That is the root the compromised eMudhra TLS intermediates
chain to (Mozilla Bugzilla 2083449). certifi 2026.10.18 removed it on
18 October, along with the other emSign roots, and 2026.10.19 restored the
unaffected ones (GHSA-6q48-6c7w-9gw2).

## Finding

From 20 to 22 October, with a fixed release available throughout, **30.7%
of certifi downloads from PyPI were of a release that contains the root**:
59.3 million of 193.0 million, excluding the bandersnatch mirror client. The
daily share fell slowly, while the fixed releases took over most new
downloads:

| Date | Downloads | Affected | Affected share | Fixed releases |
|---|---|---|---|---|
| 13 Oct | 55.4M | 55.4M | 99.97% | — |
| 18 Oct | 37.5M | 27.9M | 74.39% | 9.6M |
| 19 Oct | 61.1M | 21.1M | 34.48% | 40.0M |
| 20 Oct | 64.8M | 22.1M | 34.09% | 42.7M |
| 21 Oct | 64.1M | 19.4M | 30.25% | 44.7M |
| 22 Oct | 64.1M | 17.8M | 27.78% | 46.2M |

Before the fix, essentially every download carried the root, because every
release since 2019 did. On 22 October the fixed releases made up 72.1% of
downloads.

## Who is still downloading affected releases

The affected downloads on 20–22 October broke down by release:

- **36.3%** were 2026.7.22, the last release before the fix.
- 19.2% were other releases less than six months old on the day of download.
- **44.5%** were releases more than six months old, and **20.6%** were more
  than a year old.

The two groups moved very differently. Daily downloads of 2026.7.22 fell from
41.5 million on 13 October to 6.2 million on 22 October, as resolvers moved
to the fix. Downloads of older affected releases stayed close to their pre-fix
level: 13.9 million on 13 October, and 11.6 million on 22 October. This is
consistent with pinned versions, lockfiles and constraints, which an upstream
fix does not move.

## What to do

- Check the certifi version that your lockfiles, constraints and images
  actually install, not only what your requirements allow.
- Upgrade to certifi 2026.10.19 or later, and rebuild images that bundle it.

## How it was measured

The download counts come from ClickPy's public PyPI download statistics, per
day and version. For each of the 77 versions downloaded in the period, we
fetched the release file from PyPI, checked its SHA-256 against PyPI's digest,
and looked for the root in its `cacert.pem` by the root's SHA-256
fingerprint. 42 versions contain it, exactly 2019.3.9 through 2026.7.22. None
of the other 35 does, including 2026.10.18 and 2026.10.19. Details:
[methodology.md](methodology.md).

## Limits

- Downloads measure installation activity, not the installed population.
  Cached dependencies, private mirrors and existing images make no new
  downloads, and CI systems can download the same version many times.
- Only the bandersnatch mirror client is excluded. Downloads through other
  proxies, such as Nexus, are counted.
- Downloading an affected release doesn't show that an application relies on
  the root. That depends on its TLS client and configuration.
- The counts are those ClickPy returned at retrieval.

See also [limitations.md](limitations.md).

## Evidence

The evidence package is `evidence/certifi-download-share-2026-10-22.zip`,
attached to release v0.2.0, with its SHA-256 in `evidence/SHA256SUMS`. Its
README describes each file. To repeat the measurement:

    python3 -I scripts/certifi_download_share.py 2026-10-13 2026-10-22 <new_dir>

## Sources

- ClickPy (ClickHouse) public PyPI download data: https://clickpy.clickhouse.com
- PyPI JSON API: https://pypi.org/pypi/certifi/json
- certifi advisory: https://github.com/certifi/python-certifi/security/advisories/GHSA-6q48-6c7w-9gw2
- Mozilla Bugzilla 2083449: https://bugzilla.mozilla.org/show_bug.cgi?id=2083449
