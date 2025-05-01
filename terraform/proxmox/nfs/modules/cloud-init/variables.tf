variable "proxmox_api_url" {
  type = string
}

variable "proxmox_api_token_id" {
  type      = string
  sensitive = true
}

variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
}

variable "proxmox_host_ipv4_addrs" {
  type = map(string)
}

variable "proxmox_user" {
  type = string
}

variable "proxmox_user_key_priv" {
  type = string
}

variable "admin_ssh_key" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "root_password" {
  type = string
}

variable "root_ssh_key" {
  type = string
}

variable "nfs_server_ip" {
  type = string
}

variable "cloud_init_virtual_machines" {
  type = map(object({
    hostname        = string
    ip_address      = string
    gateway         = string
    target_node     = string
    cpu_cores       = number
    cpu_sockets     = number
    memory          = string
    qemu_os         = string
    hdd_size        = string
    hdd_storage     = string
    onboot          = bool
    vm_template     = string
    cloud_init_file = string
  }))
}
