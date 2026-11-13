<p align="left">
  <a href="https://www.proxmox.com/en/products/proxmox-virtual-environment/overview" target="_blank">
    <picture>
      <source srcset="docs/images/proxmox_light.svg" media="(prefers-color-scheme: dark)">
      <img src="docs/images/proxmox_dark.svg" width="40" height="40" title="Proxmox"/>
    </picture>
  </a>
  <a href="https://docs.ansible.com/ansible/latest/getting_started/index.html" target="_blank">
    <picture>
      <source srcset="docs/images/ansible_light.svg" media="(prefers-color-scheme: dark)">
      <img src="docs/images/ansible_dark.svg" width="40" height="40" title="Ansible"/>
    </picture>
  </a>
  <a href="https://www.debian.org/download" target="_blank">
    <picture>
      <source srcset="docs/images/debian_light.svg" media="(prefers-color-scheme: dark)">
      <img src="docs/images/debian_dark.svg" height="40" alt="Debian" title="Debian"/>
    </picture>
  </a>
  <a href="https://www.talos.dev" target="_blank">
    <picture>
      <source srcset="docs/images/talos_light.svg" media="(prefers-color-scheme: dark)">
      <img src="docs/images/talos_dark.svg" width="40" height="40" title="Talos"/>
    </picture>
  </a>
  <a href="https://kubernetes.io" target="_blank">
    <picture>
      <source srcset="docs/images/kubernetes_light.svg" media="(prefers-color-scheme: dark)">
      <img src="docs/images/kubernetes_dark.svg" width="40" height="40" title="Kubernetes"/>
    </picture>
  </a>
  <a href="https://developer.hashicorp.com/terraform" target="_blank">
    <picture>
      <source srcset="docs/images/terraform_light.svg" media="(prefers-color-scheme: dark)">
      <img src="docs/images/terraform_dark.svg" width="40" height="40" title="Terraform"/>
    </picture>
  </a>
  <a href="https://argo-cd.readthedocs.io" target="_blank">
    <picture>
      <source srcset="docs/images/argo_light.svg" media="(prefers-color-scheme: dark)">
      <img src="docs/images/argo_dark.svg" width="40" height="40" title="ArgoCD"/>
    </picture>
  </a>
  <a href="https://grafana.com" target="_blank">
    <picture>
      <source srcset="docs/images/grafana_light.svg" media="(prefers-color-scheme: dark)">
      <img src="docs/images/grafana_dark.svg" width="40" height="40" title="Grafana"/>
    </picture>
  </a>
  <a href="https://prometheus.io" target="_blank">
    <picture>
      <source srcset="docs/images/prometheus_light.svg" media="(prefers-color-scheme: dark)">
      <img src="docs/images/prometheus_dark.svg" width="40" height="40" title="Prometheus"/>
    </picture>
  </a>
  <a href="https://grafana.com/docs/loki" target="_blank">
    <picture>
      <source srcset="docs/images/loki_light.svg" media="(prefers-color-scheme: dark)">
      <img src="docs/images/loki_dark.svg" width="40" height="40" title="Loki"/>
    </picture>
  </a>
  <a href="https://www.cloudflare.com" target="_blank">
    <picture>
      <source srcset="docs/images/cloudflare_light.svg" media="(prefers-color-scheme: dark)">
      <img src="docs/images/cloudflare_dark.svg" width="40" height="40" title="Cloudflare"/>
    </picture>
  </a>
  <a href="https://doc.traefik.io/traefik" target="_blank">
    <picture>
      <source srcset="docs/images/traefik_light.svg" media="(prefers-color-scheme: dark)">
      <img src="docs/images/traefik_dark.svg" width="40" height="40" title="Traefik"/>
    </picture>
  </a>
  <a href="https://cert-manager.io" target="_blank">
    <picture>
      <source srcset="docs/images/certmanager_light.svg" media="(prefers-color-scheme: dark)">
      <img src="docs/images/certmanager_dark.svg" width="40" height="40" title="cert-manager"/>
    </picture>
  </a>
  <a href="https://github.com/fosrl/pangolin" target="_blank">
    <picture>
      <source srcset="docs/images/pangolin_light.svg" media="(prefers-color-scheme: dark)">
      <img src="docs/images/pangolin_dark.svg" width="40" height="40" title="pangolin"/>
    </picture>
  </a>
</p>

# Homelab

An on-prem Kubernetes cluster where I study infrastructure, break things, and
fix them back up. Everything in this repository is declarative: the cluster,
the applications running on it, and the infrastructure underneath are all
defined as code and tracked in git.

## Hardware

- 1x TP-Link TL-SF1008D 8-Port 10/100Mbps Desktop Switch
- 5x HP EliteDesk 800 G1 Desktop Mini PC
  - Intel Core i5-4570T (4 vCPUs)
  - 8GB RAM
  - 128GB SATA SSD + 128GB M.2 NVMe SSD

The five HP machines form a single Proxmox VE cluster, networked together
through the TP-Link switch.

## Virtual infrastructure

The Proxmox cluster hosts the following virtual machines:

| VM(s)         | Count | OS     | Role                               |
| ------------- | ----- | ------ | ---------------------------------- |
| Control plane | 1     | Talos  | Kubernetes master (master-0)       |
| Worker nodes  | 4     | Talos  | Kubernetes workers                 |
| NFS server    | 1     | Ubuntu | Persistent storage for the cluster |

- Talos version and Kubernetes version are pinned in [`talos/talenv.yaml`](talos/talenv.yaml) and templated via [Talhelper](https://github.com/budimanjojo/talhelper).
- A single control plane node (`master-0`) serves as the API endpoint. Three
  control planes with a VIP were more than this hardware can carry, so a single
  node is a deliberate tradeoff.
- The NFS VM serves cluster PVCs through `nfs-client`, the default `StorageClass`.

### Data and recovery

The NFS VM holds every PersistentVolume and is a single point of failure. It is
not backed up. The data on those volumes (metrics, logs, dashboard state, Kafka
topics) is disposable. Configuration and secrets live in Git, so recovery means
rebuilding the cluster from this repository, not restoring a backup.

## How it's managed

### Proxmox → Ansible

The Proxmox nodes are bootstrapped with Ansible: cluster formation, SSH access,
NVMe mount, and the Ubuntu cloud image are all handled by playbooks in
[`ansible/`](ansible). See [`ansible/README.md`](ansible/README.md) and run
targets via `make`:

```
make start    # cluster + ssh + nvme + ubuntu
make upgrade  # apt dist-upgrade on all nodes
make stop     # shutdown the cluster
```

### Proxmox → Talos → Kubernetes → Terraform

Once the Proxmox cluster exists, Terraform takes over. Each workspace is a
self-contained module with state stored remotely in HCP Terraform:

- [`terraform/proxmox/k8s`](terraform/proxmox/k8s) — creates the Talos VMs,
  applies the machine configuration, boots the cluster and exports the
  kubeconfig.
- [`terraform/proxmox/nfs`](terraform/proxmox/nfs) — the NFS storage VM.
- [`terraform/grafana`](terraform/grafana) — Grafana dashboards.
- [`terraform/hetzner`](terraform/hetzner) — a Hetzner Cloud VM running
  docker-mailserver, Pangolin and Ente Photos, reachable over a WireGuard
  tunnel.

The Talos cluster runs **Calico** for pod networking. A fresh cluster is
provisioned with the default Flannel CNI disabled by the
[`cni-none-patch`](terraform/proxmox/k8s/resources/cni-none-patch.yaml) applied
to every node, so `terraform apply` never installs Flannel. Calico and the
platform services are then installed from `kubernetes-manifests/` by
[`scripts/bootstrap.sh`](scripts/bootstrap.sh):

```
make bootstrap   # install the platform, ArgoCD, Flux, and the workloads
```

The script applies the manifests in dependency order: Calico, the namespaces,
the platform services, ingress and certificates, ArgoCD, Flux, and finally the
workloads. ArgoCD and Flux are installed by the script, so a fresh cluster needs
no manual steps before GitOps takes over.

See [Delivery model](#delivery-model) for how each controller is used after
bootstrap.

### Kubernetes manifests

All workloads live in [`kubernetes-manifests/`](kubernetes-manifests), composed
with Kustomize and version-pinned per directory. Infrastructure deployed today:

- **Networking** — Calico CNI, MetalLB, Traefik ingress, external-dns
- **Certificates** — cert-manager with Cloudflare DNS-01 challenges
- **Monitoring** — Prometheus, Grafana, Alertmanager, Loki, Promtail,
  kube-state-metrics, node-exporter, pushgateway, pve-exporter
- **Storage** — NFS client provisioner
- **Registry** — a pull-through cache for `docker.io`. Images from `quay.io`
  and `ghcr.io` pull directly.
- **Experiments** — Kafka, and a `sandbox/` namespace for play apps (Homer,
  Excalidraw, IT-Tools, asciip)

### Delivery model

Delivery is split by what each tool owns:

- **ArgoCD** is the main tool for Kubernetes resources. Each directory under
  `kubernetes-manifests/` carries an `Application`, and ArgoCD reconciles every
  namespace with server-side apply and automated prune and self-heal.
- **terraform-applier** owns the Terraform workspaces, such as the Grafana
  dashboards module, and applies them on a schedule.
- **Flux** manages only the `sandbox` namespace. It is a deliberate exception to
  ArgoCD, kept to preserve hands-on experience with an alternative controller.

Kustomizations do not set `namespace`. The namespace comes from the ArgoCD
Application destination, and `scripts/bootstrap.sh` passes `-n` when it applies
a directory directly.

This is a lab, so the split is chosen for learning value as much as for
convenience.

### Secrets

All secrets are [age](https://github.com/FiloSottile/age) encrypted with
[Strongbox](https://github.com/uw-labs/strongbox). A git filter encrypts
secret files on commit and decrypts them on checkout, so the repository
only ever contains encrypted blobs. A pre-commit hook
([`scripts/pre-commit`](scripts/pre-commit)) refuses to stage an unencrypted
secret.

A fresh clone needs [Strongbox](https://github.com/uw-labs/strongbox) installed
and the `filter.strongbox` clean and smudge commands configured in Git, plus the
age identity. Without them, checkout and commit fail. The identity is kept in a
password manager and is not in the repository.

### Keeping things fresh

- [Renovate](https://github.com/renovatebot/renovate) is configured but
  currently disabled (`"enabled": false` in [`renovate.json`](renovate.json))
  to stop the PR noise. The configuration is kept in place so it can be
  re-enabled.
- A CI workflow ([`.github/workflows/manifest-diff.yaml`](.github/workflows/manifest-diff.yaml))
  renders Kustomize diffs of changed manifests on every pull request.

## Repository layout

```
ansible/                   Initial Proxmox cluster setup playbooks
archive/                   Previously used configs, kept for reference
docs/                      Documentation and logos
kubernetes-manifests/      Kustomize app manifests, grouped by namespace
scripts/                   Local tooling (pre-commit hook)
talos/                     Talos cluster configuration (Talhelper)
terraform/                 Terraform workspaces (Proxmox, Grafana, Hetzner)
```
