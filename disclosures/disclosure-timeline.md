# Disclosure timeline

Times are UTC. Each entry is added after the event happens.

| When | Event | Record |
|---|---|---|
| 2026-10-22 21:19 | Evidence snapshot retrieved (zip SHA-256 `6f5f468885c921d9b4be8b3ca881d568384d8c2097caef6b822e10724648435c`) | `RETRIEVED_AT` |
| 2026-10-23 06:13–06:16 | Live HTTPS test of `node:20-slim` and `node:22.23.4-bookworm-slim` against the disclosure site's test endpoint, on linux/arm64 and linux/amd64 | `evidence/node20-live-tls-2026-10-23.zip` |
| 2026-10-23 11:48 | Release v0.1.0 published, with the Node.js evidence | https://github.com/cytherai/trust-revocation-research/releases/tag/v0.1.0 |
| 2026-10-23 13:20 | certifi download counts for 13–22 October retrieved from ClickPy, and the 77 certifi versions downloaded in that period checked for the root | `evidence/certifi-download-share-2026-10-22.zip` |
