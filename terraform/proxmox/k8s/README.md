The initial config taken from https://github.com/lewishazell/proxmox-talos-terraform

## Talos secrets

This Terraform config manages the Proxmox VMs and applies Talos machine
configs, but the cluster is bootstrapped with the same secrets Talhelper
uses (`talos/talsecret.yaml`).

To keep Terraform and Talhelper on the same cluster identity, import the
Talos secrets into Terraform state:

```
make import-secrets
```

The secrets file is plaintext in the working tree (strongbox decrypts it via
the git smudge filter). This copies `talos/talsecret.yaml`, drops any existing
`talos_machine_secrets` resource from state, imports the secrets, and removes
the temp file. Re-run it whenever the state is recreated (e.g. after
`terraform destroy`).

The Talos and Kubernetes versions come from `talos/talenv.yaml` (the single
source of truth used by Talhelper and the `talos/Makefile`), so version bumps
only need to happen there.
