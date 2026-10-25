# docker-mailserver on Hetzner

[Docker Mailserver Documentation](https://docker-mailserver.github.io/docker-mailserver/latest/introduction/)

## Initial setup

1. Apply terraform to roll out the server
2. Use the `wg_client.conf` created to connect to VPN
3. SSH to the server
4. Generate DKIM keys
```bash
docker exec -ti mail setup config dkim
```
5. Follow the [Basic Installation guide](https://docker-mailserver.github.io/docker-mailserver/latest/examples/tutorials/basic-installation/) to set up DNS records
6. Enable DNSSEC and DANE/TLSA
7. Create a mailbox and alias
```bash
docker exec -ti mail setup email add example_mailbox@dtlp.cc
docker exec -ti mail setup alias add example_alias@dtlp.cc example_mailbox@dtlp.cc
```
8. Connect to the mailbox using port `993` for IMAP and `465` for SMTP.

Test email here https://internet.nl and here https://www.mail-tester.com

## Telegram alias bot

The server also runs [dms-admin-bot](https://github.com/DTLP/dms-admin-bot)
(image `ghcr.io/dtlp/dms-admin-bot`) behind a `docker-socket-proxy`, so aliases
can be managed from Telegram. It needs `telegram_bot_token` and
`telegram_bot_user_id` set in `terraform.tfvars`. The stack lives in
`/opt/dms-admin-bot/docker-compose.yaml`.

## Notes

- Wireguard tunnel uses `10.20.30.40` address for the `mail` server and
`10.20.30.41` for the client machine.
- SSH is only available via VPN.
- There are make targets available to save/restore backups and create/delete
aliases quickly.
- Certificates are managed by Let's Encrypt.
- Unattended-upgrades installs security updates only; the weekly timer reboots
  when a reboot is required.
- The server is monitored by [UptimeRobot](https://uptimerobot.com).

## Backups

- `email-backup.timer` runs `/usr/local/bin/email-backup` daily at 03:30
  Europe/London.
- It stops `mail`, archives `/mail/config`, `/mail/data`, and `/mail/state` to
  `/var/backups/email/YYYY-MM-DD.tar.gz.pgp`, and encrypts the archive with
  GPG AES256.
- It uploads the archive and its `.sha256` to `dropbox:email-backups` with
  rclone, restarts `mail` even if the backup fails, and deletes archives older
  than `backup_retention_days` (default 7).

To restore, download the archive and decrypt it on the server:

```bash
rclone --config /etc/email-backup/rclone.conf \
  copy dropbox:email-backups/YYYY-MM-DD.tar.gz.pgp /var/backups/email/
systemctl stop mail
gpg --decrypt /var/backups/email/YYYY-MM-DD.tar.gz.pgp | tar -xz -C /
systemctl start mail
```

`make mail-backup` and `make mail-restore` are an alternative way to back up
and restore the mail data to and from the local workstation over SSH.
`mail-backup` pulls `/mail/config`, `/mail/data`, and `/mail/state` to `/tmp`,
and `mail-restore` sends them back, stopping and restarting `mail` around each
operation.

## DANE / TLSA

The `_25._tcp.<mailserver_hostname>.<domain_name>` TLSA record is published
automatically. A certbot deploy hook,
`/etc/letsencrypt/renewal-hooks/deploy/50-publish-tlsa`, recomputes the digests
from `/etc/letsencrypt/live/` after every renewal and writes them to Cloudflare
through the API. Set `cloudflare_api_token` in `terraform.tfvars` to a token with
`Zone:DNS:Edit` on the zone; the hook reads it from
`/etc/letsencrypt/tlsa.env` and stays inert while that file is absent.

One `3 1 1` record is published: usage 3 (DANE-EE), selector 1 (SPKI), and
SHA-256. It pins the end-entity certificate's public key. Certbot renews with
`--reuse-key`, so the key and digest stay stable across renewals. That means
this record needs no manual intervention, but it *is* email, so watch for
renewal-hook failures:

```bash
# republish by hand after fixing a broken hook or rotating the token
/etc/letsencrypt/renewal-hooks/deploy/50-publish-tlsa
```

`external-dns` does not manage this record; it only sources ingress and
service records, so it will not recreate the RRset if it is deleted.

## DANE status monitoring

A daily check, `/usr/local/bin/tlsa-check`, verifies the published TLSA records
still match the certificate the mail server presents (leaf and issuing CA),
that the RRset is DNSSEC-validated, and that the certificate is more than 14
days from expiry. On any failure it emails `postmaster@<domain>` and writes a
`FAILED` status page; otherwise it writes `OK`.

The status pages are served by a small Python HTTP server
(`dane-status.service`) on port `8082`. It is deliberately independent of
Pangolin and carries no digests or secrets.

Monitor URLs:

- `http://mail.dtlp.cc:8082/status`
- `http://mail.dtlp.cc:8082/disk`

UptimeRobot: create a Keyword monitor for the first URL with the keyword
`dane-tlsa: OK`, and a second for the disk URL with the keyword `disk: OK`, both
at 5-minute intervals. `disk-check` runs every 5 minutes and marks the page
`FAILED` at 80% usage. The pages also record the last check time, so a stalled
cron is caught by the next run and reported.

```bash
# run the checks by hand
/usr/local/bin/tlsa-check
/usr/local/bin/disk-check
```
