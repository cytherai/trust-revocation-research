// SPDX-License-Identifier: Apache-2.0
// Real HTTPS transaction through the Node executable being evaluated.
'use strict';
const https = require('node:https');

const target = process.argv[2] || 'https://dv-g3b-noct-emudhra.we-have-a-problem.com/';
const expectedVersion = process.env.EXPECT_NODE_VERSION || '';
const expectedOutcome = process.env.EXPECT_OUTCOME || '';
const label = process.env.PROBE_LABEL || '';
const started = new Date().toISOString();
const startMs = Date.now();
const certErrors = new Set([
  'UNABLE_TO_VERIFY_LEAF_SIGNATURE','UNABLE_TO_GET_ISSUER_CERT',
  'UNABLE_TO_GET_ISSUER_CERT_LOCALLY','SELF_SIGNED_CERT_IN_CHAIN',
  'DEPTH_ZERO_SELF_SIGNED_CERT','CERT_SIGNATURE_FAILURE',
  'CERT_HAS_EXPIRED','CERT_NOT_YET_VALID','CERT_REVOKED',
  'INVALID_PURPOSE','ERR_TLS_CERT_ALTNAME_INVALID','UNABLE_TO_VERIFY_FIRST_CERT',
  'ERR_TLS_CERT_ALTNAME_FORMAT'
]);
let finished = false;
function finish(outcome, details = {}) {
  if (finished) return;
  finished = true;
  const result = {
    timestamp_utc: started, elapsed_ms: Date.now() - startMs,
    label, target, node_version: process.version, platform: process.platform,
    arch: process.arch, openssl_version: process.versions.openssl,
    expected_node_version: expectedVersion || null,
    expected_outcome: expectedOutcome || null,
    outcome, ...details
  };
  result.version_match = !expectedVersion || process.version === expectedVersion;
  result.outcome_match = !expectedOutcome || outcome === expectedOutcome;
  process.stdout.write(JSON.stringify(result) + '\n');
  if (!result.version_match || !result.outcome_match || outcome === 'ERROR') process.exitCode = 1;
}
let url;
try { url = new URL(target); if (url.protocol !== 'https:') throw new Error('HTTPS only'); }
catch (err) { finish('ERROR',{error:err.message}); process.exit(1); }
const req = https.request(url, {
  method: 'GET', rejectUnauthorized: true, timeout: 15000,
  agent: false,
  headers: { 'User-Agent': 'CytherAI-NodeTLS-Repro/1.0', 'Connection':'close' }
}, (res) => {
  // Reaching HTTP proves the certificate-verified TLS handshake completed.
  const sock = res.socket;
  const peer = sock.getPeerCertificate();
  const info = {
    http_status: res.statusCode, tls_authorized: sock.authorized,
    authorization_error: sock.authorizationError || null,
    tls_protocol: sock.getProtocol(),
    server_ip: sock.remoteAddress,
    peer_subject: peer.subject || null,
    peer_issuer: peer.issuer || null,
    peer_fingerprint256: peer.fingerprint256 || null
  };
  res.resume();
  finish(sock.authorized ? 'ACCEPT' : 'ERROR', info);
});
req.on('timeout', () => req.destroy(Object.assign(new Error('Connection timed out'), {code:'TIMEOUT'})));
req.on('error', (err) => {
  const code = err.code || null;
  finish(certErrors.has(code) ? 'REJECT' : 'ERROR', {
    error_code: code, error_message: err.message
  });
});
req.end();
