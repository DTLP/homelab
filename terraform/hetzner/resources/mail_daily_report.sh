#!/usr/bin/env bash
#
# Mail a daily summary of the docker-mailserver container to the admin mailbox.
#
# Run by mail-daily-report.timer at 03:00, before the 03:30 backup stops and
# recreates the container. This keeps the fail2ban log, which lives inside the
# container, covering almost the full reporting window.

set -euo pipefail

readonly CONTAINER="mail"
readonly RECIPIENT="admin@example.com"
readonly SENDER="postmaster@example.com"
readonly WINDOW_HOURS=24
readonly LOG_LIMIT=25
readonly NOISE_RE='TLS library problem|SSL_accept error|SSL_accept\(\) failed|non-SMTP command|disconnected during TLS handshake|tls_handshake_not_finished|hostname .* does not resolve'

log() {
  printf '%s %s\n' "$(date -Is)" "$*"
}

die() {
  log "$*"
  exit 1
}

# Convert DMS ISO 8601 log lines to the classic syslog format pflogsumm expects.
to_syslog() {
  awk '
    BEGIN { split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", months, " ") }
    /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T/ {
      month = substr($0, 6, 2) + 0
      day = substr($0, 9, 2)
      time = substr($0, 12, 8)
      rest = substr($0, 20)
      sub(/^\.[0-9]+[+-][0-9][0-9]:[0-9][0-9] /, "", rest)
      print months[month] " " day " " time " " rest
      next
    }
    { print }
  '
}

# Print the first numeric value for a pflogsumm category, or 0 when absent.
pflogsumm_count() {
  awk -v key="$1" '$2 == key { print $1; exit }' "$2"
}

command -v docker >/dev/null 2>&1 || die "docker not found"
docker inspect "${CONTAINER}" >/dev/null 2>&1 \
  || die "container ${CONTAINER} is not running"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

readonly raw_log="${tmp_dir}/journal.log"
readonly summary="${tmp_dir}/pflogsumm.txt"
readonly iso_since="$(date -u -d "-${WINDOW_HOURS} hours" '+%Y-%m-%d %H:%M:%S')"
readonly since_human="$(date -u -d "-${WINDOW_HOURS} hours" '+%Y-%m-%d %H:%M UTC')"
readonly now_human="$(date -u '+%Y-%m-%d %H:%M UTC')"

journalctl CONTAINER_NAME="${CONTAINER}" --since "${iso_since}" \
  -o cat --no-pager >"${raw_log}" 2>/dev/null || true

to_syslog <"${raw_log}" \
  | docker exec -i "${CONTAINER}" pflogsumm --problems-first >"${summary}" \
  || true

received="$(pflogsumm_count received "${summary}")"
delivered="$(pflogsumm_count delivered "${summary}")"
rejected="$(pflogsumm_count rejected "${summary}")"
banned="$(docker exec "${CONTAINER}" awk -v since="${iso_since}" \
  'substr($0, 1, 19) >= since && (/ Ban / || / Unban /)' \
  /var/log/mail/fail2ban.log 2>/dev/null | wc -l)"

subject="[mail] daily ${now_human%% *}: ${received:-0} in, ${delivered:-0} out, ${rejected:-0} rejected, ${banned:-0} banned"

{
  printf 'From: %s\n' "${SENDER}"
  printf 'To: %s\n' "${RECIPIENT}"
  printf 'Subject: %s\n' "${subject}"
  printf 'Date: %s\n' "$(date -R)"
  printf 'MIME-Version: 1.0\n'
  printf 'Content-Type: text/plain; charset=UTF-8\n'
  printf 'Content-Transfer-Encoding: 8bit\n'
  printf '\n'
  printf 'Mailserver daily report\n'
  printf 'Window: %s to %s\n' "${since_human}" "${now_human}"
  printf '\n'

  printf '== Postfix summary ==\n\n'
  if [[ -s "${summary}" ]]; then
    cat "${summary}"
  else
    printf 'No Postfix log data in the window.\n'
  fi

  printf '\n== Mail server log highlights ==\n\n'
  tls_count="$(grep -icE 'SSL_accept error|Login aborted.*SSL_accept\(\) failed' "${raw_log}" || true)"
  nonsmtp_count="$(grep -icE 'non-SMTP command' "${raw_log}" || true)"
  dns_count="$(grep -icE 'hostname .* does not resolve' "${raw_log}" || true)"
  highlight_count="$(grep -iE 'error|fatal|panic|warning|failed|failure' "${raw_log}" \
    | grep -ivE "${NOISE_RE}" | wc -l)"
  printf 'Scanner noise: %s TLS handshake failures, %s non-SMTP commands, %s reverse-DNS mismatches.\n' \
    "${tls_count:-0}" "${nonsmtp_count:-0}" "${dns_count:-0}"
  printf 'Other warnings and errors: %s\n\n' "${highlight_count:-0}"
  matches="$(grep -iE 'error|fatal|panic|warning|failed|failure' "${raw_log}" \
    | grep -ivE "${NOISE_RE}" | tail -n "${LOG_LIMIT}" || true)"
  if [[ -n "${matches}" ]]; then
    printf '%s\n' "${matches}"
  else
    printf 'None.\n'
  fi

  printf '\n== fail2ban ==\n\n'
  jails="$(docker exec "${CONTAINER}" fail2ban-client status \
    | sed -n 's/.*Jail list:[[:space:]]*//p' || true)"
  if [[ -n "${jails}" ]]; then
    printf 'Jails: %s\n\n' "${jails}"
    IFS=',' read -r -a jail_names <<<"${jails}"
    for jail in "${jail_names[@]}"; do
      jail="$(printf '%s' "${jail}" | tr -d '[:space:]')"
      docker exec "${CONTAINER}" fail2ban-client status "${jail}" 2>/dev/null \
        | grep -E 'Status for the jail|Currently failed|Currently banned|Total failed|Total banned' \
        | sed 's/^[[:space:]]*//' \
        || true
      printf '\n'
    done
  else
    printf 'Could not read fail2ban status.\n\n'
  fi

  printf 'Bans in the window: %s\n\n' "${banned:-0}"
  ban_lines="$(docker exec "${CONTAINER}" awk -v since="${iso_since}" \
    'substr($0, 1, 19) >= since && (/ Ban / || / Unban /)' \
    /var/log/mail/fail2ban.log 2>/dev/null | tail -n "${LOG_LIMIT}" || true)"
  if [[ -n "${ban_lines}" ]]; then
    printf '%s\n' "${ban_lines}"
  else
    printf 'No ban or unban events.\n'
  fi
} | docker exec -i "${CONTAINER}" sendmail -t

log "daily report sent to ${RECIPIENT}"
