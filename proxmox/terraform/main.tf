module "vms" {
  source                      = "./modules/cloud-init"
  proxmox_host_ipv4_addrs     = var.proxmox_host_ipv4_addrs
  proxmox_user                = var.proxmox_user
  proxmox_user_key_priv       = file("~/.ssh/id_rsa_proxmox")
  admin_ssh_key               = file("~/.ssh/id_rsa_proxmox.pub")
  ssh_public_key              = var.ssh_public_key
  root_password               = var.root_password
  cloud_init_virtual_machines = var.cloud_init_virtual_machines

  proxmox_api_url          = var.proxmox_api_url
  proxmox_api_token_id     = var.proxmox_api_token_id
  proxmox_api_token_secret = var.proxmox_api_token_secret
}
