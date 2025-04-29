locals {
  token = file("../secrets/token")
}

provider "proxmox" {
  endpoint  = var.pve.endpoint
  api_token = local.token
  ssh {
    agent       = true
    username    = var.pve.ssh.username
    private_key = file(var.pve.ssh.private_key_file)
  }
  insecure = var.pve.insecure
}
