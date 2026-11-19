#!/usr/bin/env bash
set -euo pipefail
umask 077

readonly TOKEN_FILE="/etc/backup-alert/token"
readonly CHAT_FILE="/etc/backup-alert/chat-id"

log() {
  printf '%s %s\n' "$(date -Is)" "$*"
}

die() {
  log "$*"
  exit 1
}

if (( $# < 1 )); then
  die "usage: backup-alert SUBJECT"
fi

subject=$1
[[ -r "$TOKEN_FILE" ]] || die "missing token file: $TOKEN_FILE"
[[ -r "$CHAT_FILE" ]] || die "missing chat id file: $CHAT_FILE"

token=$(<"$TOKEN_FILE")
chat_id=$(<"$CHAT_FILE")
[[ -n "$token" && -n "$chat_id" ]] || die "empty token or chat id"

message="Backup failed: ${subject} on $(hostname) at $(date -Is)"

curl --fail --silent --show-error --max-time 30 --config - \
  --data-urlencode "chat_id=${chat_id}" \
  --data-urlencode "text=${message}" >/dev/null <<EOF
url = "https://api.telegram.org/bot${token}/sendMessage"
EOF

log "alert sent: $subject"
