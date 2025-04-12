<p align="left">
  <img width="40" src="docs/images/proxmox_dark.svg#gh-light-mode-only" title="Proxmox"/>
  <img width="40" src="docs/images/proxmox_light.svg#gh-dark-mode-only" title="Proxmox"/>
  <img width="40" src="docs/images/ansible_dark.svg#gh-light-mode-only" title="Ansible"/>
  <img width="40" src="docs/images/ansible_light.svg#gh-dark-mode-only" title="Ansible"/>
  <img width="40" src="docs/images/ubuntu_dark.svg#gh-light-mode-only" title="Ubuntu"/>
  <img width="40" src="docs/images/ubuntu_light.svg#gh-dark-mode-only" title="Ubuntu"/>
  <img width="40" src="docs/images/kubernetes_dark.svg#gh-light-mode-only" title="Kubernetes"/>
  <img width="40" src="docs/images/kubernetes_light.svg#gh-dark-mode-only" title="Kubernetes"/>
  <img width="40" src="docs/images/terraform_dark.svg#gh-light-mode-only" title="Terraform"/>
  <img width="40" src="docs/images/terraform_light.svg#gh-dark-mode-only" title="Terraform"/>
  <img width="40" src="docs/images/argo_dark.svg#gh-light-mode-only" title="ArgoCD"/>
  <img width="40" src="docs/images/argo_light.svg#gh-dark-mode-only" title="ArgoCD"/>
  <img width="40" src="docs/images/grafana_dark.svg#gh-light-mode-only" title="Grafana"/>
  <img width="40" src="docs/images/grafana_light.svg#gh-dark-mode-only" title="Grafana"/>
  <img width="40" src="docs/images/prometheus_dark.svg#gh-light-mode-only" title="Prometheus"/>
  <img width="40" src="docs/images/prometheus_light.svg#gh-dark-mode-only" title="Prometheus"/>
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
together with that tiny TP-Link switch.

### Software
Each Proxmox node is running one Ubuntu guest VM. So far these VM roles are:
- 1 kubernetes master node
- 3 kubernetes worker nodes
- 1 NFS server for persistent storage
Proxmox resources are managed via [Terraform](https://github.com/DTLP/homelab/tree/main/terraform),
but the initial setup is done using [Ansible](https://github.com/DTLP/homelab/tree/main/ansible). I used to use Vagrant for this before I moved to Proxmox, but I no
longer maintain that config. You could still find it [here](https://github.com/DTLP/homelab/tree/main/vagrant).

My kubernetes manifests are located in [kubernetes-manifests](https://github.com/DTLP/homelab/tree/main/kubernetes-manifests).  
All secrets are encrypted using [Strongbox](https://github.com/uw-labs/strongbox).
