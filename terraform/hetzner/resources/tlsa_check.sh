#!/bin/sh
#
# Verifies that the published DANE TLSA records still match the certificate
# the mail server actually presents.
#
# Two things happen on every run. A status file is rewritten for the external
# monitor to fetch, and a failure is mailed to postmaster@. The status file is
# the primary signal: an external monitor reading it keeps alerting even when
# this script's own mail path is broken, which is the failure the mail copy
# cannot cover.
#
# Because the monitor can only test for the presence of a keyword, the status
# file is also how a stalled run gets noticed: if the previous run was longer
# ago than expected, that is itself reported as a failure.
#
# This checks the published end state rather than the exit status of the script
# that publishes it, so it also catches a TLSA record deleted by hand, a
# Cloudflare token that was revoked, and a certbot renewal that failed to run.
# Installed by Terraform; runs daily from cron.

set -eu

# The zone and host come from the same file the publish hook writes for, so the
# check cannot end up testing a different name from the one being published.
readonly CONFIG="/etc/letsencrypt/tlsa.env"
if [ ! -r "${CONFIG}" ]; then
  printf 'cannot read %s, so there is no zone and host to check\n' "${CONFIG}" >&2
  exit 1
fi
set -a
# shellcheck source=/dev/null
. "${CONFIG}"
set +a

: "${CF_DNS_ZONE:?CF_DNS_ZONE is not set in ${CONFIG}}"
: "${CF_TLSA_HOST:?CF_TLSA_HOST is not set in ${CONFIG}}"

readonly DOMAIN="${CF_DNS_ZONE}"
readonly MAIL_HOST="${CF_TLSA_HOST}"
readonly ALERT_TO="postmaster@${DOMAIN}"
readonly ALERT_FROM="tlsa-check@${DOMAIN}"

# A validating resolver, because a sender's verdict depends on the TLSA RRset
# validating under DNSSEC, not merely on the record being present.
readonly RESOLVER="1.1.1.1"

# How long before expiry to start complaining, so a failed renewal has time to
# be noticed and fixed. certbot renews at roughly 30 days out.
readonly MIN_VALID_DAYS=14

# Served over HTTP for the external monitor to fetch. A tiny systemd unit runs
# a static file server on port 8082 rooted at STATUS_DIR, so the monitor URL
# is http://mail.dtlp.cc:8082/status. No container or reverse proxy involved.
readonly STATUS_DIR="/opt/dane-status"
readonly STATUS_FILE="${STATUS_DIR}/status"

# A run further apart than this means cron did not fire as expected. The
# monitor cannot see that on its own, so it is reported as a failure here.
readonly MAX_GAP_HOURS=26

# The marker the external monitor watches for. The file must never contain it
# unless the check actually passed, and it carries no digests or other detail
# worth keeping off the public internet.
readonly HEALTHY_MARKER="dane-tlsa: OK"

FAILURES=""

warn() {
  printf '%s\n' "$*"
}

fail() {
  FAILURES="${FAILURES}${FAILURES:+; }$*"
}

record_name="_25._tcp.${MAIL_HOST}"

# dig emits the certificate hex of a "3 1 1" record as everything after the
# third field, and inserts a space in the middle of that hex once it is long
# enough. The hex is therefore reassembled from fields four onwards, and any
# continuation line is appended, so either rendering produces one digest.
#
# Deliberately not "+dnssec": that would make dig also print the RRSIG, whose
# text then runs onto the end of the preceding record's digest.
tlsa_digests() {
  dig "@${RESOLVER}" +short TLSA "${record_name}" |
    awk '
      /^[0-9]+ [0-9]+ [0-9]+ / {
        if (seen) print digest
        digest = ""
        for (i = 4; i <= NF; i++) digest = digest $i
        seen = 1
        next
      }
      { gsub(/[ \t]/, ""); digest = digest $0 }
      END { if (seen) print digest }
    ' |
    tr '[:lower:]' '[:upper:]'
}

# Prints the index'th certificate of a PEM bundle to stdout. openssl writes a
# CONNECTED banner ahead of the bundle, so the file cannot be indexed by
# splitting on position; only a real certificate boundary is dependable.
extract_cert() {
  awk -v want="$1" '
    /-----BEGIN CERTIFICATE-----/ { n++ }
    n == want + 1 { print }
  ' "$2"
}

# SHA-256 of the DER encoding of a PEM file. Selector 1 hashes the whole
# certificate, so the DER form is what gets digested. The pipeline is kept in
# binary form rather than through a shell variable, which cannot hold NULs.
digest_cert() {
  openssl x509 -in "$1" -outform DER 2>/dev/null |
    openssl dgst -sha256 -hex 2>/dev/null |
    sed 's/^.*= //' |
    tr '[:lower:]' '[:upper:]'
}

# The record must validate. An unsigned or insecure RRset is a different
# problem from a digest mismatch, because a validating sender ignores it
# entirely rather than rejecting the certificate.
case "$(dig "@${RESOLVER}" +dnssec TLSA "${record_name}" |
  grep -m1 '^;; flags:')" in
  *" ad;"*)
    warn "TLSA RRset is DNSSEC-validated."
    ;;
  *)
    fail "TLSA RRset is not DNSSEC-validated, so senders ignore it"
    ;;
esac

published="$(tlsa_digests)"
record_count="$(printf '%s' "${published}" | grep -c . || true)"
if [ "${record_count}" -eq 0 ]; then
  fail "no TLSA records are published for _25._tcp.${MAIL_HOST}"
else
  warn "TLSA RRset holds ${record_count} record(s)."
fi

workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT

# Ask the server for the chain it presents, rather than reading the files on
# disk, so the check covers what a real sender would actually see.
if ! openssl s_client -starttls smtp -connect 127.0.0.1:25 \
  -servername "${MAIL_HOST}" -showcerts </dev/null >"${workdir}/chain.pem" 2>/dev/null
then
  fail "could not complete an SMTP handshake on port 25"
fi

extract_cert 0 "${workdir}/chain.pem" >"${workdir}/leaf.pem"
leaf_digest=""
if ! openssl x509 -in "${workdir}/leaf.pem" -noout >/dev/null 2>&1; then
  fail "could not read the end-entity certificate from the chain on port 25"
else
  leaf_digest="$(digest_cert "${workdir}/leaf.pem")"

  # DANE-EE is only satisfied when the end-entity certificate itself matches.
  # A match on a CA higher up the chain is a weaker, different condition.
  if printf '%s\n' "${published}" | grep -qxF "${leaf_digest}"; then
    warn "end-entity certificate matches a published TLSA record."
  else
    fail "end-entity certificate ${leaf_digest} matches no published TLSA record"
  fi

  extract_cert 1 "${workdir}/chain.pem" >"${workdir}/ca.pem"
  ca_digest=""
  if openssl x509 -in "${workdir}/ca.pem" -noout >/dev/null 2>&1; then
    ca_digest="$(digest_cert "${workdir}/ca.pem")"
    if printf '%s\n' "${published}" | grep -qxF "${ca_digest}"; then
      warn "issuing CA also matches a published TLSA record."
    else
      fail "issuing CA matches no published TLSA record, so the '3 1 1'"\
" pair is incomplete and a renewal has no gap-free rollover"
    fi
  else
    fail "could not read the issuing CA from the chain on port 25"
  fi

  not_after="$(openssl x509 -in "${workdir}/leaf.pem" -noout -enddate |
    cut -d= -f2)"
  # strptime leaves the result naive even when it parses a zone name, so "now"
  # is made naive too; mixing the two raises a TypeError rather than returning
  # a wrong number, which is easy to miss behind a quiet stderr.
  days_left="$(python3 -c "
import datetime, sys
expiry = datetime.datetime.strptime(sys.argv[1].strip(), '%b %d %H:%M:%S %Y %Z')
now = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
print((expiry - now).days)
" "${not_after}" 2>/dev/null || true)"
  if [ -z "${days_left}" ]; then
    fail "could not determine the certificate expiry date"
  elif [ "${days_left}" -lt "${MIN_VALID_DAYS}" ]; then
    fail "certificate expires in ${days_left} day(s), on ${not_after},"\
" under the ${MIN_VALID_DAYS} day threshold; check certbot is renewing"
  else
    warn "certificate is valid for another ${days_left} day(s), until ${not_after}."
  fi
fi

# A run that arrives long after the previous one means cron stopped firing.
# Reported before anything else, because a monitor reading an unchanged status
# file would otherwise stay green indefinitely.
if [ -r "${STATUS_FILE}" ]; then
  previous="$(sed -n 's/^checked: //p' "${STATUS_FILE}" | head -1)"
  if [ -n "${previous}" ]; then
    hours_since="$(python3 -c "
import datetime, sys
try:
    then = datetime.datetime.fromisoformat(sys.argv[1])
    now = datetime.datetime.now(then.tzinfo)
    print(round((now - then).total_seconds() / 3600, 1))
except Exception:
    pass
" "${previous}" 2>/dev/null || true)"
    if [ -z "${hours_since}" ]; then
      fail "cannot read the previous run time from ${STATUS_FILE}"
    elif [ "$(python3 -c "print(1 if ${hours_since} > ${MAX_GAP_HOURS} else 0)")" -eq 1 ]; then
      fail "the previous run was ${hours_since} hours ago, so the daily check"\
" has not been running as expected"
    fi
  fi
fi

if [ -z "${FAILURES}" ]; then
  warn "DANE TLSA check passed."
else
  warn "DANE TLSA check FAILED: ${FAILURES}"
fi

# Rewritten on every run, pass or fail, so the monitor reflects reality either
# way. Written atomically via a temporary file so the monitor can never read a
# half-written page and treat it as a failure.
mkdir -p "${STATUS_DIR}"
status_tmp="$(mktemp "${STATUS_DIR}/.index.XXXXXX")"
{
  printf '<!doctype html>\n'
  printf '<meta charset="utf-8">\n'
  printf '<title>DANE TLSA status for %s</title>\n' "${MAIL_HOST}"
  printf '<pre>\n'
  if [ -z "${FAILURES}" ]; then
    printf '%s\n' "${HEALTHY_MARKER}"
  else
    printf 'dane-tlsa: FAILED\n'
  fi
  printf 'checked: %s\n' "$(date --iso-8601=seconds)"
  printf 'host: %s\n' "${MAIL_HOST}"
  printf '</pre>\n'
} >"${status_tmp}"
chmod 0644 "${status_tmp}"
mv -f "${status_tmp}" "${STATUS_FILE}"
warn "status written to ${STATUS_FILE}"

[ -z "${FAILURES}" ] && exit 0

# Deliberately addressed to a local mailbox. The failure this guards against is
# inbound DANE rejection, and locally submitted mail never traverses DANE, so
# the alert still arrives when every external sender is being refused.
{
  printf 'From: %s\n' "${ALERT_FROM}"
  printf 'To: %s\n' "${ALERT_TO}"
  printf 'Subject: %s: DANE TLSA check failed\n' "${MAIL_HOST}"
  printf 'Date: %s\n' "$(date -R)"
  printf '\n'
  printf 'The daily DANE TLSA check on %s reported a problem.\n\n' "${MAIL_HOST}"
  printf 'Problem:\n  %s\n\n' "${FAILURES}"
  printf 'Findings:\n'
  printf '  leaf digest: %s\n' "${leaf_digest:-unavailable}"
  printf '  published digests:\n'
  printf '%s\n' "${published}" | grep . | sed 's/^/    /'
  printf '\nTo republish the records:\n'
  printf '  /etc/letsencrypt/renewal-hooks/deploy/50-publish-tlsa\n'
  printf '\nSurvey: https://stats.dnssec-tools.org/explore/?%s\n' "${DOMAIN}"
} | docker exec -i mail sendmail -oi -f "${ALERT_FROM}" "${ALERT_TO}"

warn "alert sent to ${ALERT_TO}"
exit 1
