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
  <a href="https://ubuntu.com/download" target="_blank">
    <picture>
      <source srcset="docs/images/ubuntu_light.svg" media="(prefers-color-scheme: dark)">
      <img src="docs/images/ubuntu_dark.svg" width="40" height="40" title="Ubuntu"/>
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
| Control plane | 3     | Talos  | Kubernetes masters                 |
| Worker nodes  | 4     | Talos  | Kubernetes workers                 |
| NFS server    | 1     | Ubuntu | Persistent storage for the cluster |

- Talos version and Kubernetes version are pinned in [`talos/talenv.yaml`](talos/talenv.yaml) and templated via [Talhelper](https://github.com/budimanjojo/talhelper).
- A VIP backed by kube-vip provides a stable API endpoint for the control plane.
- The NFS VM serves cluster PVCs through `nfs-client`, the default `StorageClass`.

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
- [`terraform/hetzner`](terraform/hetzner) — a docker-mailserver VM on Hetzner
  Cloud, reachable over a WireGuard tunnel.

### Kubernetes manifests

All workloads live in [`kubernetes-manifests/`](kubernetes-manifests), composed
with Kustomize and version-pinned per directory. Infrastructure deployed today:

- **Networking** — Calico CNI, MetalLB, Traefik ingress, external-dns
- **Certificates** — cert-manager with Cloudflare DNS-01 challenges
- **Monitoring** — Prometheus, Grafana, Alertmanager, Loki, Promtail,
  kube-state-metrics, node-exporter, pushgateway, pve-exporter
- **Storage** — NFS client provisioner
- **Experiments** — Kafka, and a `sandbox/` namespace for play apps (Homer,
  Excalidraw, IT-Tools, asciip)

GitOps delivery is split by concern:

- **terraform-applier** applies the Terraform workspaces (e.g. the Grafana
  dashboards module) on a schedule.
- **Flux** is being trialed for application manifests, currently managing the
  `sandbox` namespace.
- **ArgoCD** is installed but currently manages only its own manifests.

### Secrets

All secrets are [age](https://github.com/FiloSottile/age) encrypted with
[Strongbox](https://github.com/uw-labs/strongbox). A git filter encrypts
secret files on commit and decrypts them on checkout, so the repository
only ever contains encrypted blobs. A pre-commit hook
([`scripts/pre-commit`](scripts/pre-commit)) refuses to stage an unencrypted
secret.

### Keeping things fresh

- [Renovate](https://github.com/renovatebot/renovate) watches Kubernetes
  images, Kustomize bases, Terraform providers, GitHub Actions and custom
  version pins, and opens dependency PRs automatically.
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
