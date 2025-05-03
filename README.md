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
</p>

# Homelab

A place where I experiment with my own on-prem Kubernetes cluster. Here I study
things, break things and fix them back up.

## What do I use?
### Hardware
- TP-Link TL-SF1008D 8-Port 10/100Mbps Desktop Switch
- x5 HP EliteDesk 800 G1 Desktop Mini PC
  - Intel core i5-4570T processor (4 vCPUs)
  - 8GB RAM
  - 128GB SATA SSD
  - 128GB M.2 NVMe SSD

Each HP machine is running Proxmox Virtual Environment and they're all connected
together with that tiny TP-Link switch making one Proxmox cluster.

### Software
So far my Proxmox nodes host the following things:
- 3 kubernetes master nodes on Talos
- 3 kubernetes worker nodes on Talos
- 1 NFS server for persistent storage on Ubuntu
- An AdGuard Home LXC 

Proxmox resources are managed via [Terraform](https://github.com/DTLP/homelab/tree/main/terraform),
but the initial setup is done using [Ansible](https://github.com/DTLP/homelab/tree/main/ansible). I used to use Vagrant for this before I moved to Proxmox, but I no
longer maintain that config. You could still find it [here](https://github.com/DTLP/homelab/tree/main/archive/vagrant).

My kubernetes manifests are located in [kubernetes-manifests](https://github.com/DTLP/homelab/tree/main/kubernetes-manifests).  
All secrets are encrypted using [Strongbox](https://github.com/uw-labs/strongbox).
