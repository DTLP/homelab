#!/usr/bin/env bash
set -u

exec > /root/debian-test-report.txt 2>&1

printf 'host: %s\n' "$(hostname)"
printf 'kernel: %s\n' "$(uname -r)"
printf 'os: %s\n' "$(. /etc/os-release && printf '%s' "$PRETTY_NAME")"
printf 'docker: %s\n' "$(docker --version 2>&1)"
printf 'compose: %s\n' "$(docker compose version 2>&1)"
printf 'nftables: %s\n' "$(nft --version 2>&1)"
printf 'needrestart: %s\n' \
  "$(apt-cache policy needrestart | awk '/Installed:/{print $2}')"
printf 'mptcp: %s\n' "$(sysctl -n net.mptcp.enabled 2>&1)"
printf 'cve rule chains: %s\n' \
  "$(nft list table inet cve_2026_98432 2>/dev/null | grep -c hdrlength)"
printf 'reboot pending: %s\n' \
  "$(needrestart -b -r l 2>/dev/null | grep -E '^NEEDRESTART-KSTA:' || true)"
