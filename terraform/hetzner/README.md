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
- The server is monitored by [UptimeRobot](https://uptimerobot.com).

## DANE / TLSA

The `_25._tcp.<mailserver_hostname>.<domain_name>` TLSA record is published
automatically. A certbot deploy hook,
`/etc/letsencrypt/renewal-hooks/deploy/50-publish-tlsa`, recomputes the digests
from `/etc/letsencrypt/live/` after every renewal and writes them to Cloudflare
through the API. Set `cloudflare_api_token` in `terraform.tfvars` to a token with
`Zone:DNS:Edit` on the zone; the hook reads it from
`/etc/letsencrypt/tlsa.env` and stays inert while that file is absent.

Two `3 1 1` records are published: one for the end-entity certificate and one
for the CA that issued it. Only the end-entity digest changes on renewal, so
the CA digest is what keeps the RRset matched in the window between a renewal
and the next cache expiry. That also means this record needs no manual
intervention, but it *is* email, so watch for renewal-hook failures:

```bash
# republish by hand after fixing a broken hook or rotating the token
/etc/letsencrypt/renewal-hooks/deploy/50-publish-tlsa
```

`external-dns` does not manage this record; it only sources ingress and
service records, so it will not recreate the RRset if it is deleted.
