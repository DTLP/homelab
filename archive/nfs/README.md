# NFS storage (archived)

`nfs-0` was an Ubuntu VM that exported `/data` over NFS and backed every
PersistentVolume in the cluster through the `nfs-client` StorageClass. It was
removed in November 2026 after the volumes moved to Longhorn.

The VM was a single point of failure, had no volume size enforcement, and its
data was never backed up. Longhorn replicates each volume across the worker
nodes instead.

## Layout

- `kubernetes-manifests/nfs-provisioner/` holds the ArgoCD Application,
  kustomization, network policies, and the deployment and StorageClass patches
  for `nfs-subdir-external-provisioner`.
- `terraform/` holds the `proxmox-nfs` module that created the VM. It is a copy
  of `terraform/proxmox/nfs` without the generated `.terraform/` cache or
  `cloud-init-config/`.

## Server configuration

`terraform/resources/nfs.yaml.tmpl` is the source of truth for the VM:

- Ubuntu, 2 vCPU, 2 GB RAM, 40 GB disk on the `nvme` datastore of `pve5`.
- Static address `192.168.0.60/24` with gateway `192.168.0.1`.
- Cloned from template `8005`, which `ansible/ubuntu_image.yaml` builds.
- Installs `nfs-kernel-server` and exports the share with:

  ```text
  /data    192.168.0.0/24(rw,sync,no_root_squash,no_subtree_check)
  ```

The live `/etc/exports` matched this rule exactly when the VM was destroyed.

## Client configuration

The provisioner manifests set `NFS_SERVER=192.168.0.60` and `NFS_PATH=/data`,
create the `nfs-client` StorageClass with the `Retain` reclaim policy, and allow
TCP and UDP ports 111, 2049, and 20048 to the server.

The namespace, AppProject entries, and bootstrap line were removed from
`kubernetes-manifests/kube-system/namespaces.yaml`,
`kubernetes-manifests/argocd/argocd-project.yaml`, and `scripts/bootstrap.sh`.

## Recreating

1. Copy `terraform/` back to `terraform/proxmox/nfs`.
2. Create the `proxmox-nfs` workspace in HCP Terraform and run
   `terraform apply`.
3. Copy `kubernetes-manifests/nfs-provisioner/` back under
   `kubernetes-manifests/`.
4. Add the `nfs-provisioner` namespace to `kube-system/namespaces.yaml` and the
   source and destination entries to `argocd-project.yaml`.
5. Add the apply line back to `scripts/bootstrap.sh`.
6. Create the namespace and apply the directory, or run `make bootstrap`.

The module reads `../secrets/token` and `../secrets/id_ed25519`. The archived
`terraform.tfvars` holds no secrets and is stored without strongbox encryption.

## Related configuration

`ansible/ubuntu_image.yaml` still builds the Ubuntu template, which the Forgejo
runner VM uses. When that VM is removed, move the playbook and the
`ubuntu-image` Makefile target here as well.
