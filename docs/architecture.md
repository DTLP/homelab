# Homelab Architecture

A Talos Kubernetes cluster running on 5 Proxmox VE hosts, managed as
infrastructure-as-code from this repository via Terraform, Talhelper, and
ArgoCD.

## Infrastructure

Five HP EliteDesk nodes form a single Proxmox VE cluster (`lab`). Each hosts
Talos Kubernetes VMs; an Ubuntu VM provides shared NFS storage. All VMs use
static addresses matched by MAC, with 192.168.0.1 as the gateway.

```mermaid
flowchart TB
    subgraph Phys["5x HP EliteDesk (Proxmox VE cluster 'lab')"]
        direction TB
        P1["pve1<br/>192.168.0.21"]
        P2["pve2<br/>192.168.0.22"]
        P3["pve3<br/>192.168.0.23"]
        P4["pve4<br/>192.168.0.24"]
        P5["pve5<br/>192.168.0.25"]
    end

    subgraph CP["Control plane (Talos)"]
        M0["master-0<br/>192.168.0.30"]
    end

    subgraph WK["Workers (Talos)"]
        W0["worker-0<br/>192.168.0.40"]
        W1["worker-1<br/>192.168.0.41"]
        W2["worker-2<br/>192.168.0.42"]
        W3["worker-3<br/>192.168.0.43"]
    end

    NFS["nfs-0 (Ubuntu)<br/>192.168.0.60<br/>/data"]

    P1 --> M0
    P2 --> W0
    P3 --> W1
    P4 --> W2
    P5 --> W3
    P5 --> NFS
```

## Ingress and TLS

All external traffic arrives as `*.dtlp.cc`, resolves through Cloudflare to the
Traefik LoadBalancer, and is terminated with a wildcard TLS certificate issued
via cert-manager DNS-01.

```mermaid
flowchart LR
    User["You / Browser"] -->|"*.dtlp.cc"| CF["Cloudflare DNS<br/>dtlp.cc"]

    CF -->|"A record → private-ingress.dtlp.cc"| TraefikLB["MetalLB 192.168.0.50<br/>(only LoadBalancer service)"]

    subgraph Cluster["Talos cluster"]
        Traefik["Traefik<br/>ingress-controller"]
        Traefik -->|IngressRoute| Svc["Services / Pods<br/>(argocd, grafana, kafka-ui, ...)"]
    end

    TraefikLB --> Traefik

    ExtDNS["external-dns<br/>domain-filter=dtlp.cc"] -.->|creates A records| CF
    CertMgr["cert-manager<br/>ClusterIssuer letsencrypt<br/>DNS-01"] -.->|wildcard *.dtlp.cc| CF
    CertMgr -->|"dtlp-cc-wildcard cert"| Traefik
```

## Observability

Metrics are scraped by Prometheus, alerts route to Slack, and logs flow
through Loki into Grafana.

```mermaid
flowchart LR
    subgraph Sources["Metrics sources"]
        Node["nodes / kubelet"]
        KSM["kube-state-metrics"]
        NX["node-exporter"]
        PVE["pve-exporter<br/>Proxmox API"]
        SUM["kube-summary-exporter"]
        PUSH["pushgateway"]
    end

    subgraph Collect["monitoring"]
        Prom["Prometheus"]
        Loki["Loki"]
        Grafana["Grafana"]
        AM["Alertmanager"]
    end

    Promtail["Promtail (DaemonSet)<br/>pods + Talos /var/log"] --> Loki

    Node --> Prom
    KSM --> Prom
    NX --> Prom
    PVE --> Prom
    SUM --> Prom
    PUSH --> Prom

    Prom --> Grafana
    Loki --> Grafana
    Prom --> AM -->|alerts| Slack["Slack"]
```

## Storage

Shared storage comes from the nfs-0 VM and is exposed to the cluster through a
dynamic NFS provisioner.

```mermaid
flowchart LR
    NFS["nfs-0<br/>192.168.0.60:/data"]

    Prov["nfs-subdir-external-provisioner<br/>nfs-provisioner"] -->|NFS| NFS

    SC["StorageClass nfs-client<br/>(default)"]
    Prov --> SC

    PVC["PVCs<br/>Prometheus, Grafana, Loki, Kafka, ..."] --> SC
```

## GitOps and provisioning

Infrastructure is bootstrapped and kept in sync from this repository.

```mermaid
flowchart LR
    subgraph IaC["Infrastructure-as-Code"]
        Ansible["Ansible<br/>Proxmox cluster + VMs"]
        TF["Terraform<br/>proxmox-k8s, proxmox-nfs, grafana, hetzner"]
        TH["Talhelper<br/>talconfig.yaml + talenv.yaml"]
    end

    Ansible --> PVE["Proxmox VE"]
    TF --> PVE
    TH -->|machine configs| Cluster

    subgraph GitOps["GitOps"]
        Argo["ArgoCD<br/>server-side apply"]
        Flux["Flux<br/>(sandbox)"]
        Repo["homelab repo<br/>(GitHub main)"]
    end

    Repo --> Argo
    Repo --> Flux
    Argo --> Cluster
    Flux --> Cluster

    Renovate["Renovate"] -.->|dependency PRs| Repo
    TerraformApplier["terraform-applier<br/>Grafana dashboards"] -.-> TF

    Cluster["Talos Kubernetes cluster"]
```

## Key services

| Service                             | Namespace          | Purpose                                                |
| ----------------------------------- | ------------------ | ------------------------------------------------------ |
| Traefik                             | ingress-controller | Ingress controller, only LoadBalancer (192.168.0.50)   |
| ArgoCD                              | argocd             | GitOps deployment of namespaces                        |
| Flux                                | flux-system        | GitOps for the sandbox namespace                       |
| Prometheus + Alertmanager + Grafana | monitoring         | Metrics, alerting (Slack), dashboards                  |
| Loki + Promtail                     | monitoring         | Log aggregation from pods and Talos hosts              |
| cert-manager                        | kube-system        | TLS certificates (Cloudflare DNS-01)                   |
| external-dns                        | kube-system        | DNS records for `*.dtlp.cc`                            |
| MetalLB                             | metallb-system     | LoadBalancer IP allocation                             |
| Kyverno                             | kube-system        | CEL validating policies                                |
| nfs-provisioner                     | nfs-provisioner    | NFS-backed default StorageClass                        |
| Kafka + kafka-ui                    | kafka              | Streaming / message broker                             |
| terraform-applier                   | terraform-applier  | Runs Terraform modules in-cluster (Grafana dashboards) |

## Provisioning

- **Ansible** bootstraps the Proxmox cluster (formation, SSH, NVMe mount) and
  the Ubuntu cloud image for the NFS VM.
- **Terraform** (`terraform/proxmox/k8s`) provisions the Talos VMs on Proxmox
  (disk images, networking, resource sizing) and applies Talos machine configs.
  Talos and Kubernetes versions come from `talos/talenv.yaml`; machine secrets
  are imported from Talhelper via `make import-secrets`.
- **Talhelper** (`talos/`) generates the Talos machine configs from
  `talconfig.yaml` and the strongbox-encrypted `talsecret.yaml`.
- **ArgoCD** watches the repository's `kubernetes-manifests/` and applies each
  namespace's kustomization (server-side apply); **Flux** manages the sandbox
  namespace. Renovate opens dependency update PRs.
