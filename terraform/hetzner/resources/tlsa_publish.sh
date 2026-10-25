#!/bin/sh
#
# Publishes the "3 1 1" TLSA record for the mail server after a certbot
# renewal.
#
# Usage 3 (DANE-EE) with selector 1 (SPKI) and matching type 1 (SHA-256)
# pins the end-entity certificate's public key. Certbot renews with
# --reuse-key, so the public key and digest stay stable across renewals.
#
# certbot runs this from /etc/letsencrypt/renewal-hooks/deploy/ with
# RENEWED_LINEAGE pointing at the lineage that was just renewed.

set -eu

readonly CONFIG=/etc/letsencrypt/tlsa.env

# Exit quietly when no credentials are present, so that a host which does not
# manage the TLSA RRset does not report renewals as failed.
[ -r "${CONFIG}" ] || exit 0

# Export the settings for the embedded Python below.
set -a
# shellcheck source=/dev/null
. "${CONFIG}"
set +a

: "${CF_API_TOKEN:?CF_API_TOKEN is not set in ${CONFIG}}"
: "${CF_DNS_ZONE:?CF_DNS_ZONE is not set in ${CONFIG}}"
: "${CF_TLSA_HOST:?CF_TLSA_HOST is not set in ${CONFIG}}"
: "${CF_TLSA_PORT:?CF_TLSA_PORT is not set in ${CONFIG}}"

readonly LINEAGE="${RENEWED_LINEAGE:-/etc/letsencrypt/live/${CF_TLSA_HOST}}"

# Selector 1 hashes the SubjectPublicKeyInfo (SPKI), not the whole
# certificate. RFC 6698 section 2.1.1 requires upper case hex.
digest_spki() {
  openssl x509 -in "$1" -pubkey -noout |
    openssl pkey -pubin -outform DER |
    openssl dgst -sha256 -hex |
    sed 's/^.*= //' |
    tr '[:lower:]' '[:upper:]'
}

leaf_digest="$(digest_spki "${LINEAGE}/cert.pem")"

# The record is updated in place rather than deleted and recreated, which
# keeps the RRset resolvable throughout the rollover instead of briefly
# answering with no TLSA at all. A missing RRset on a signed zone makes
# senders treat delivery as a temporary failure, so the gap is worth avoiding.
python3 - "${leaf_digest}" <<'PYTHON'
import json
import os
import sys
import urllib.parse
import urllib.request

API = "https://api.cloudflare.com/client/v4"
TOKEN = os.environ["CF_API_TOKEN"]
ZONE_NAME = os.environ["CF_DNS_ZONE"]
HOST = os.environ["CF_TLSA_HOST"]
PORT = os.environ["CF_TLSA_PORT"]
TTL = 300
NAME = f"_{PORT}._tcp.{HOST}"


def request(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        f"{API}{path}",
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {TOKEN}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            payload = json.load(response)
    except urllib.error.HTTPError as error:
        # Cloudflare puts the actionable part of a rejection in the body, not
        # in the status line, so surface it rather than just the 4xx code.
        detail = error.read().decode(errors="replace")
        raise SystemExit(f"cloudflare {method} {path} failed: {error.code} {detail}")
    if not payload.get("success"):
        raise SystemExit(f"cloudflare {method} {path} failed: {payload.get('errors')}")
    return payload


zones = request(
    "GET", "/zones?" + urllib.parse.urlencode({"name": ZONE_NAME, "status": "active"})
)["result"]
if len(zones) != 1:
    raise SystemExit(f"expected one active zone named {ZONE_NAME}, got {len(zones)}")
zone_id = zones[0]["id"]

existing = request(
    "GET",
    f"/zones/{zone_id}/dns_records?"
    + urllib.parse.urlencode({"type": "TLSA", "name": NAME}),
)["result"]

def record_body(digest):
    return {
        "type": "TLSA",
        "name": NAME,
        "port": int(PORT),
        "proto": "tcp",
        "ttl": TTL,
        # Cloudflare rejects TLSA writes that carry the flat
        # "3 1 1 <hex>" string, and asks for these four fields instead.
        "data": {
            "usage": 3,
            "selector": 1,
            "matching_type": 1,
            "certificate": digest,
        },
    }


digests = [d.upper() for d in sys.argv[1:]]
# Cloudflare answers a write that would change nothing with "An identical
# record already exists", so writing unconditionally turns a no-op run into a
# non-zero exit and certbot reports the renewal as failed. Only write where the
# published state actually differs.
by_digest = {r["data"]["certificate"].upper(): r for r in existing}
surplus = [r for r in existing if r["data"]["certificate"].upper() not in digests]

for digest in digests:
    current = by_digest.get(digest)
    if current is not None:
        if current["ttl"] == TTL:
            continue
        request("PUT", f"/zones/{zone_id}/dns_records/{current['id']}",
                record_body(digest))
    elif surplus:
        # Repurpose a record that no longer matches rather than deleting it
        # first, so a rollover never answers with a one-record RRset.
        request("PUT", f"/zones/{zone_id}/dns_records/{surplus.pop(0)['id']}",
                record_body(digest))
    else:
        request("POST", f"/zones/{zone_id}/dns_records", record_body(digest))

for stale in surplus:
    request("DELETE", f"/zones/{zone_id}/dns_records/{stale['id']}")

print(f"published {len(digests)} TLSA records for {NAME}")
PYTHON
