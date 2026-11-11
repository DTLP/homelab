# Forgejo runner

A single Forgejo Actions runner VM on `pve1`.

| Setting | Value |
| ------- | ----- |
| Host | `pve1` |
| Template | `ubuntu-cloud` (VM 8001) |
| Address | `192.168.0.61` |
| vCPU | 2 |
| Memory | 2048MB ceiling, 512MB balloon floor |
| Disk | 20GB on `nvme` |

The runner registers itself on first boot and runs as a systemd service. Jobs
run in Docker containers, with `ubuntu-latest` mapping to
`node:22-bookworm` by default.

## First apply

The registration token is a secret and is not stored in the repository. Create
one in Forgejo under **Site Administration → Actions → Runners**, then:

```
export TF_VAR_runner_token=<token>
terraform init
terraform apply
```

The rendered cloud-init file under `cloud-init-config/` contains the token, so
it is written with mode 0600 and should not be committed.

To change the runner's labels or version, override `runner_labels` or
`runner_version` in `terraform.tfvars`. Labels are only read at registration
time, so changing them means re-registering the runner on the VM.
