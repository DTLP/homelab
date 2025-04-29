terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "dlapo-homelab"
    workspaces {
      name = "proxmox-k8s"
    }
  }
}
