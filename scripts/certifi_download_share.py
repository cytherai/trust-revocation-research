#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 CytherAI
"""Measure, per day, how many certifi downloads from PyPI selected a release
whose CA bundle contains emSign ECC Root CA - G3.

Usage: python3 -I scripts/certifi_download_share.py <first-date> <last-date> <out_dir>

Download counts come from ClickPy's public ClickHouse endpoint
(table pypi.pypi_downloads_per_day_by_version_by_installer_by_type), excluding
the bandersnatch mirror client. For every version seen, one release file is
fetched from PyPI's JSON API: the wheel if one was published, otherwise the
sdist. Its SHA-256 is checked against PyPI's digest, and its cacert.pem is
searched for the root by the SHA-256 of the root's DER encoding. Archives are
only read; no package code runs.

Writes into <out_dir>, which must not exist yet:
  query.sql                      the exact query sent to ClickPy
  clickpy-daily.tsv              date, version, downloads
  certifi-version-inventory.tsv  version, uploaded, artifact, artifact_sha256, cert_count, emsign_g3
  download-share.tsv             per day: total, affected, affected_latest, affected_older, fixed, share
  affected-by-release-age.tsv    per day: affected downloads by the release's age on that day
  RETRIEVED_AT, SHA256SUMS
Exit status: 0 done, 2 bad arguments or a failed download.
Needs only the Python 3 standard library.
"""
import base64
import datetime
import hashlib
import io
import json
import os
import re
import sys
import tarfile
import urllib.request
import zipfile

G3 = "86a1ecba089c4a8d3bbe2734c612ba341d813e043cf9e8a862cd5c57a36bbe6b"  # emSign ECC Root CA - G3
CLICKPY = "https://sql-clickhouse.clickhouse.com/?user=demo"
QUERY = """SELECT date, version, sum(count)
FROM pypi.pypi_downloads_per_day_by_version_by_installer_by_type
WHERE project = 'certifi' AND date BETWEEN '{first}' AND '{last}' AND installer != 'bandersnatch'
GROUP BY date, version
ORDER BY date, version
FORMAT TSV
"""
PEM = re.compile(rb"-----BEGIN CERTIFICATE-----(.+?)-----END CERTIFICATE-----", re.S)


def fail(message):
    print(f"certifi_download_share.py: {message}", file=sys.stderr)
    sys.exit(2)


def fetch(url, data=None):
    try:
        return urllib.request.urlopen(url, data=data, timeout=120).read()
    except OSError as err:  # URLError, HTTPError and timeouts are all OSError (socket.timeout too on 3.9)
        fail(f"download failed: {url}: {err}")


def key(version):
    return tuple(int(part) for part in version.split("."))


def bundle(name, blob):
    """Return cacert.pem from a wheel or sdist, preferring certifi/cacert.pem."""
    if name.endswith((".whl", ".zip")):
        archive = zipfile.ZipFile(io.BytesIO(blob))
        names = archive.namelist()
        read = archive.read
    else:
        archive = tarfile.open(fileobj=io.BytesIO(blob))
        members = {m.name: m for m in archive.getmembers() if m.isfile()}
        names = list(members)
        read = lambda n: archive.extractfile(members[n]).read()  # noqa: E731
    found = [n for n in names if n.endswith("certifi/cacert.pem")] or [n for n in names if n.endswith("cacert.pem")]
    return read(found[0]) if found else None


def age_bucket(age_days):
    if age_days < 183:
        return "under_6_months"
    if age_days < 365:
        return "6_to_12_months"
    if age_days < 730:
        return "1_to_2_years"
    return "over_2_years"


if len(sys.argv) != 4:
    fail("usage: certifi_download_share.py <first-date> <last-date> <out_dir>")
first, last, out = sys.argv[1:4]
for value in (first, last):
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
        fail(f"not a date (YYYY-MM-DD): {value}")
if first > last:
    fail("the first date is after the last date")
try:
    os.mkdir(out)
except FileExistsError:
    fail(f"{out} already exists; give a new output directory")

query = QUERY.format(first=first, last=last)
retrieved = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
daily = []
for line in fetch(CLICKPY, query.encode()).decode().splitlines():
    date, version, count = line.split("\t")
    daily.append((date, version, int(count)))
if not daily:
    fail("ClickPy returned no rows for this range")

inventory = {}
for version in sorted({v for _, v, _ in daily}, key=key):
    files = json.loads(fetch(f"https://pypi.org/pypi/certifi/{version}/json"))["urls"]
    pick = [f for f in files if f["packagetype"] == "bdist_wheel"] or [f for f in files if f["packagetype"] == "sdist"]
    if not pick:
        fail(f"no wheel or sdist on PyPI for certifi {version}")
    artifact = pick[0]
    blob = fetch(artifact["url"])
    digest = hashlib.sha256(blob).hexdigest()
    if digest != artifact["digests"]["sha256"]:
        fail(f"SHA-256 of {artifact['filename']} differs from PyPI's digest")
    pem = bundle(artifact["filename"], blob)
    blocks = PEM.findall(pem) if pem else []
    fingerprints = {hashlib.sha256(base64.b64decode(re.sub(rb"[^A-Za-z0-9+/=]", b"", b))).hexdigest() for b in blocks}
    status = "no-bundle" if pem is None else ("present" if G3 in fingerprints else "absent")
    uploaded = min(f["upload_time_iso_8601"] for f in files)[:10]
    inventory[version] = (uploaded, artifact["filename"], digest, len(blocks), status)

present = [v for v, row in inventory.items() if row[4] == "present"]
latest_affected = max(present, key=key) if present else None
dates = sorted({d for d, _, _ in daily})
share = {d: dict(total=0, affected=0, latest=0, older=0, fixed=0) for d in dates}
ages = {d: {k: 0 for k in ("latest", "under_6_months", "6_to_12_months", "1_to_2_years", "over_2_years")} for d in dates}
for date, version, count in daily:
    row = share[date]
    row["total"] += count
    if version in present:
        row["affected"] += count
        if version == latest_affected:
            row["latest"] += count
            ages[date]["latest"] += count
        else:
            row["older"] += count
            age = (datetime.date.fromisoformat(date) - datetime.date.fromisoformat(inventory[version][0])).days
            ages[date][age_bucket(age)] += count
    elif latest_affected and key(version) > key(latest_affected):
        row["fixed"] += count


def write(name, text):
    with open(os.path.join(out, name), "w", encoding="utf-8") as f:
        f.write(text)


write("query.sql", query)
write("RETRIEVED_AT", retrieved + "\n")
write("clickpy-daily.tsv", "date\tversion\tdownloads\n" + "".join(f"{d}\t{v}\t{c}\n" for d, v, c in daily))
write("certifi-version-inventory.tsv",
      "version\tuploaded\tartifact\tartifact_sha256\tcert_count\temsign_g3\n"
      + "".join(f"{v}\t{u}\t{a}\t{h}\t{n}\t{s}\n" for v, (u, a, h, n, s) in sorted(inventory.items(), key=lambda kv: key(kv[0]))))
write("download-share.tsv",
      f"date\ttotal\taffected\taffected_latest_{latest_affected}\taffected_older\tfixed\taffected_share_pct\n"
      + "".join(f"{d}\t{r['total']}\t{r['affected']}\t{r['latest']}\t{r['older']}\t{r['fixed']}\t{100 * r['affected'] / r['total']:.2f}\n"
                for d, r in sorted(share.items())))
write("affected-by-release-age.tsv",
      f"date\tlatest_affected_{latest_affected}\tolder_under_6_months\tolder_6_to_12_months\tolder_1_to_2_years\tolder_over_2_years\n"
      + "".join(f"{d}\t{a['latest']}\t{a['under_6_months']}\t{a['6_to_12_months']}\t{a['1_to_2_years']}\t{a['over_2_years']}\n"
                for d, a in sorted(ages.items())))
names = sorted(os.listdir(out))
sums = "".join(f"{hashlib.sha256(open(os.path.join(out, n), 'rb').read()).hexdigest()}  ./{n}\n" for n in names)
write("SHA256SUMS", sums)
print(f"{len(daily)} rows, {len(inventory)} versions ({len(present)} contain the root, latest {latest_affected}); written to {out}")
