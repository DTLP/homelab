# Relative path from this directory to the Talos secrets file.
SECRETS_FILE := ../../../talos/talsecret.yaml

.PHONY: import-secrets
# Import Talos machine secrets from Talhelper's talsecret.yaml.
#
# Why: Terraform's talos_machine_secrets resource generates its own random
# cluster CA, which cannot authenticate to nodes bootstrapped by Talhelper.
# Every terraform->node API call (apply, cluster_health, kubeconfig) then
# fails TLS and hangs. Importing the same secrets Talhelper uses makes the
# two tools agree on the cluster identity.
#
# How: the secrets file is plaintext in the working tree (strongbox decrypts
# it via the git smudge filter), so copy it to a private, random temp file,
# drop the resource from state if present, then import. The temp file is
# removed on success or failure (trap on EXIT).
import-secrets:
	@set -euo pipefail; \
	tmp=$$(mktemp); \
	trap 'rm -f "$$tmp"' EXIT; \
	umask 077; \
	cp $(SECRETS_FILE) "$$tmp"; \
	terraform state rm talos_machine_secrets.this >/dev/null 2>&1 || true; \
	terraform import talos_machine_secrets.this "$$tmp"