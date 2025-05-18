module "vms" {
  source                      = "./modules/cloud-init"
  proxmox_host_ipv4_addrs     = var.proxmox_host_ipv4_addrs
  proxmox_user                = var.proxmox_user
  proxmox_user_key_priv       = file("./secrets/id_ed25519")
  admin_ssh_key               = file("./secrets/id_ed25519.pub")
  ssh_public_key              = var.ssh_public_key
  root_password               = var.root_password
  root_ssh_key                = var.root_ssh_key
  cloud_init_virtual_machines = var.cloud_init_virtual_machines
  k8s_master_node_ip          = var.k8s_master_node_ip
  nfs_server_ip               = var.nfs_server_ip

  proxmox_api_url          = var.proxmox_api_url
  proxmox_api_token_id     = var.proxmox_api_token_id
  proxmox_api_token_secret = var.proxmox_api_token_secret
}
