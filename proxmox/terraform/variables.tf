variable "proxmox_api_url" {
  type    = string
  default = "http://192.168.1.21:8006/api2/json"
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
    pve1 = "192.168.1.21"
    pve2 = "192.168.1.22"
    pve3 = "192.168.1.23"
  }
}

variable "proxmox_user" {
  type    = string
  default = "root"
}

variable "ssh_public_key" {
  type    = string
  default = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDBsaLb2viVHwuZEe3VyeSjzmWFuWIcPHfvme0qJJ2xbDC+FgmYb5Wc8a/ZXPV9y25Xbyznh+Tw1v1B+v6XdqUfthUjcpmbwDZxtznAsl5U/97kxS/CTR5shLgFrEhGwte/MBYr2IBsKHc2bGpSJ5Ypx80X31tmW6/9S2IM7ZIkH0aCtBJU01i3ZlMk0TLPLL17fA5VduLOAL5Ps9AoUnYjLVGpf+rSkdIJ0U3rwn3MBv4FScRJmwjEw6bxr/0fogvEp6E4l7+JP6qTp+/KJ6vdzSd2P3lwXSPtdtstAbpV5H8PjN281Yilu5jLmSLOOH5A5MPBEobVshQZFLjLEi0vX+M7K9xdfS1AvkKicihQVodZ9GEOFNupwJBKijs/3sKsu2O9p2qiEXdODuYKC8gzIUxNYyxxwIM0MXztKOYbHDwZr9AhyWBlm5x4ArpFgFyMR/JDRGB5UECq1sdEqNpkvCPwTs+l9TXmBe85XjYmkYgKuqJacowgU/Gpoco8k8RsXfvdvH+eINvF1kwwt6wnOnW2cVuPcOSHG6TCi4UlqsVfrUix+NjjySd+nTvGkOJLFLFMe0wukiq8pi4AielbjtfYczKKPMgZKoNbnCf5OXI3YS3HR5NJyR1yNKFLy+oMJSFTUlboNrD2M8tvbKPTdZnLpppljSvu9zNzvaLWkQ== root@pve1"
}

variable "root_password" {
  type = string
}

variable "cloud_init_virtual_machines" {
  default = {

    "master-0" = {
      hostname        = "master-0"
      ip_address      = "192.168.1.30/24"
      gateway         = "192.168.1.254"
      target_node     = "pve1"
      cpu_cores       = 3
      cpu_sockets     = 1
      memory          = "6144"
      qemu_os         = "l26"
      hdd_size        = "20G"
      hdd_storage     = "local-lvm"
      onboot          = true
      vm_template     = "ubuntu-cloud"
      cloud_init_file = "master.yaml"
    }

    # "worker-0" = {
    #   hostname   = "worker-0"
    #   ip_address = "192.168.1.40/24"
    #   gateway    = "192.168.1.254"
    #   target_node     = "pve2"
    #   cpu_cores       = 3
    #   cpu_sockets     = 1
    #   memory          = "6144"
    #   qemu_os         = "l26"
    #   hdd_size        = "20G"
    #   hdd_storage     = "local-lvm"
    #   onboot          = true
    #   vm_template     = "ubuntu-cloud"
    #   cloud_init_file = "worker.yaml"
    # }
  }
}
