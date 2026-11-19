#!/usr/bin/env bash
set -euo pipefail
umask 077

readonly BACKUP_DIR="/var/backups/email"
readonly PASSPHRASE_FILE="/etc/email-backup/passphrase"
readonly RCLONE_CONFIG="/etc/email-backup/rclone.conf"
readonly RCLONE_REMOTE="dropbox:email-backups"
readonly RETAIN_DAYS="${BACKUP_RETENTION_DAYS:-7}"
readonly RETAIN_MONTHS="${BACKUP_MONTHLY_RETENTION_MONTHS:-6}"
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

chmod 0600 /mail/config/postfix-accounts.cf 2>/dev/null || true

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

prune_archives() {
  local cutoff first_month name date month
  local -A keep
  local -A month_kept
  local -a archives

  cutoff=$(date -d "-${RETAIN_DAYS} days" +%F)
  first_month=$(date -d "$(date +%Y-%m-01) -$((RETAIN_MONTHS - 1)) months" +%Y-%m)

  mapfile -t archives < <(
    {
      rclone --config "$RCLONE_CONFIG" lsf --files-only "$RCLONE_REMOTE/"
      find "$BACKUP_DIR" -maxdepth 1 -type f -name '*.tar.gz.pgp' -printf '%f\n'
    } | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}\.tar\.gz\.pgp$' | sort -u
  )

  for name in "${archives[@]}"; do
    date=${name:0:10}
    month=${name:0:7}
    if [[ $date > $cutoff || $date == $cutoff ]]; then
      keep[$name]=1
    elif [[ ( $month > $first_month || $month == $first_month ) &&
      -z ${month_kept[$month]:-} ]]; then
      keep[$name]=1
      month_kept[$month]=1
    fi
  done

  for name in "${archives[@]}"; do
    if [[ -n ${keep[$name]:-} ]]; then
      continue
    fi
    log "pruning $name"
    rclone --config "$RCLONE_CONFIG" deletefile "$RCLONE_REMOTE/$name" 2>/dev/null || true
    rclone --config "$RCLONE_CONFIG" deletefile "$RCLONE_REMOTE/$name.sha256" 2>/dev/null || true
    rm -f "$BACKUP_DIR/$name" "$BACKUP_DIR/$name.sha256"
  done
}

prune_archives

log "backup complete: $archive"
