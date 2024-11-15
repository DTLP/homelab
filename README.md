# <img align="left" width="40px" src="https://upload.wikimedia.org/wikipedia/commons/thumb/3/39/Kubernetes_logo_without_workmark.svg/1200px-Kubernetes_logo_without_workmark.svg.png" alt="awesome-ebitengine" title="kubernetes" /> Kubernetes cluster lab

A collection of templates, manifests and scripts to quickly roll out a kubernetes cluster to study in a homelab environment.

## Prerequisites
- A beefy PC that can run multiple VMs with [Vagrant](https://github.com/DTLP/homelab/tree/main/vagrant)  
OR
- Some other hardware running [Proxmox](https://github.com/DTLP/homelab/tree/main/proxmox)

## My Hardware
This is what I currently use to run my Proxmox lab:
- TP-Link TL-SF1005D V15 5-Port 10/100Mbps Desktop Switch
- x5 HP EliteDesk 800 G1 Desktop Mini PC
  - Intel core i5-4570T processor (4 vCPUs)
  - 8GB RAM
  - 128GB SATA SSD
  - 128GB M.2 NVMe SSD

## How to use
Choose where to host your lab and utilise the scripts provided to build your kubernetes cluster:
  - Use [Vagrant](https://github.com/DTLP/homelab/tree/main/vagrant) to host on your local PC
  - Or [Proxmox](https://github.com/DTLP/homelab/tree/main/proxmox) to deploy to another computer

Then jump to [kubernetes-manifests](https://github.com/DTLP/homelab/tree/main/kubernetes-manifests) to deploy things to your cluster.

Note: All secrets are encrypted using Strongbox (https://github.com/uw-labs/strongbox)
