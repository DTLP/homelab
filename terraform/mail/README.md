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

## Notes

- Wireguard tunnel uses `10.20.30.40` address for the `mail` server and
`10.20.30.41` for the client machine.
- SSH is only available via VPN.
- There are make targets available to save/restore backups and create/delete
aliases quickly.
- Certificates are managed by Let's Encrypt.
