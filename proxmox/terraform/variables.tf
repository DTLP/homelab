variable "proxmox_api_url" {
  type    = string
  default = "http://192.168.0.21:8006/api2/json"
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
  default = {
    pve1 = "192.168.0.21"
    pve2 = "192.168.0.22"
    pve3 = "192.168.0.23"
    pve4 = "192.168.0.24"
    pve5 = "192.168.0.25"
  }
}

variable "proxmox_user" {
  type    = string
  default = "root"
}

variable "ssh_public_key" {
  type    = string
  default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBjvENWo/NJ0+qQSGIffxcAJmtZE4K03JzB59xC1mtGQ root@pve"
}

variable "root_password" {
  type = string
}

variable "root_ssh_key" {
  type = string
}

variable "k8s_master_node_ip" {
  type    = string
  default = "192.168.0.30"
}

variable "cloud_init_virtual_machines" {
  default = {

    "master-0" = {
      hostname        = "master-0"
      ip_address      = "192.168.0.30/24"
      gateway         = "192.168.0.1"
      target_node     = "pve1"
      cpu_cores       = 3
      cpu_sockets     = 1
      memory          = "6144"
      qemu_os         = "l26"
      hdd_size        = "20G"
      hdd_storage     = "nvme"
      onboot          = true
      vm_template     = "ubuntu-cloud"
      cloud_init_file = "master.yaml"
    }

    "worker-0" = {
      hostname        = "worker-0"
      ip_address      = "192.168.0.40/24"
      gateway         = "192.168.0.1"
      target_node     = "pve2"
      cpu_cores       = 3
      cpu_sockets     = 1
      memory          = "6144"
      qemu_os         = "l26"
      hdd_size        = "20G"
      hdd_storage     = "nvme"
      onboot          = true
      vm_template     = "ubuntu-cloud"
      cloud_init_file = "worker.yaml"
    }

    "worker-1" = {
      hostname        = "worker-1"
      ip_address      = "192.168.0.41/24"
      gateway         = "192.168.0.1"
      target_node     = "pve3"
      cpu_cores       = 3
      cpu_sockets     = 1
      memory          = "6144"
      qemu_os         = "l26"
      hdd_size        = "20G"
      hdd_storage     = "nvme"
      onboot          = true
      vm_template     = "ubuntu-cloud"
      cloud_init_file = "worker.yaml"
    }

    "worker-2" = {
      hostname        = "worker-2"
      ip_address      = "192.168.0.42/24"
      gateway         = "192.168.0.1"
      target_node     = "pve4"
      cpu_cores       = 3
      cpu_sockets     = 1
      memory          = "6144"
      qemu_os         = "l26"
      hdd_size        = "20G"
      hdd_storage     = "nvme"
      onboot          = true
      vm_template     = "ubuntu-cloud"
      cloud_init_file = "worker.yaml"
    }

    "worker-3" = {
      hostname        = "worker-3"
      ip_address      = "192.168.0.60/24"
      gateway         = "192.168.0.1"
      target_node     = "pve5"
      cpu_cores       = 3
      cpu_sockets     = 1
      memory          = "6144"
      qemu_os         = "l26"
      hdd_size        = "20G"
      hdd_storage     = "nvme"
      onboot          = true
      vm_template     = "ubuntu-cloud"
      cloud_init_file = "worker.yaml"
    }
  }
}
