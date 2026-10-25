#!/usr/bin/env bash
set -euo pipefail
umask 077

readonly BACKUP_DIR="/var/backups/email"
readonly PASSPHRASE_FILE="/etc/email-backup/passphrase"
readonly RCLONE_CONFIG="/etc/email-backup/rclone.conf"
readonly RCLONE_REMOTE="dropbox:email-backups"
readonly RETAIN_DAYS="${BACKUP_RETENTION_DAYS:-7}"
readonly PATHS=(/mail/config /mail/data /mail/state)

log() {
  printf '%s %s\n' "$(date -Is)" "$*"
}

die() {
  log "$*"
  exit 1
}

[[ -r "$PASSPHRASE_FILE" ]] || die "missing passphrase file: $PASSPHRASE_FILE"
[[ -r "$RCLONE_CONFIG" ]] || die "missing rclone config: $RCLONE_CONFIG"

mkdir -p "$BACKUP_DIR"
exec 9>"$BACKUP_DIR/.lock"
flock -n 9 || die "another backup is already running"

needed_kb=$(du -sk /mail | awk '{print $1}')
available_kb=$(df --output=avail "$BACKUP_DIR" | tail -n1 | tr -d ' ')
((available_kb >= needed_kb)) || die "not enough free space in $BACKUP_DIR"

archive="$BACKUP_DIR/$(date +%Y-%m-%d).tar.gz.pgp"
tmp="$archive.part"

restart_mail() {
  rm -f "$tmp"
  systemctl start mail >/dev/null 2>&1 || true
}
trap restart_mail EXIT

systemctl stop mail
tar -cz "${PATHS[@]}" \
  | gpg --batch --yes --symmetric --cipher-algo AES256 \
    --passphrase-file "$PASSPHRASE_FILE" \
    --output "$tmp"
mv "$tmp" "$archive"
sha256sum "$archive" >"$archive.sha256"

rclone --config "$RCLONE_CONFIG" copy "$archive" "$RCLONE_REMOTE/"
rclone --config "$RCLONE_CONFIG" copy "$archive.sha256" "$RCLONE_REMOTE/"

restart_mail
trap - EXIT

rclone --config "$RCLONE_CONFIG" delete --min-age "${RETAIN_DAYS}d" "$RCLONE_REMOTE/"
find "$BACKUP_DIR" -maxdepth 1 -type f \
  \( -name '*.tar.gz.pgp' -o -name '*.tar.gz.pgp.sha256' \) \
  -mtime +"$RETAIN_DAYS" -delete

log "backup complete: $archive"
