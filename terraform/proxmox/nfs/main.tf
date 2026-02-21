data "template_file" "nfs" {
  template = file("./resources/nfs.yaml.tmpl")

  vars = {
    hostname      = "nfs-0"
    admin_ssh_key = file("../secrets/id_ed25519.pub")

    root_password = var.root_password
    root_ssh_key  = var.root_ssh_key
    nfs_server_ip = var.nfs_server_ip
  }
}

resource "local_file" "nfs" {
  content  = data.template_file.nfs.rendered
  filename = "./cloud-init-config/nfs.yaml"
}

resource "proxmox_virtual_environment_file" "nfs" {
  node_name    = "pve5"
  datastore_id = "nvme"
  content_type = "snippets"

  source_file {
    path = "./cloud-init-config/nfs.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "nfs_vm" {
  name      = "nfs-0"
  tags      = ["terraform"]
  node_name = "pve5"
  on_boot   = true

  agent {
    enabled = true
  }

  clone {
    vm_id        = 8005
    datastore_id = "nvme"
    full         = true
  }
  cpu {
    cores   = 3
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = 4096
    floating  = 4096
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  disk {
    datastore_id = "nvme"
    interface    = "scsi0"
    size         = 40
  }

  operating_system {
    type = "l26"
  }

  initialization {
    user_data_file_id = proxmox_virtual_environment_file.nfs.id

    ip_config {
      ipv4 {
        address = "${var.nfs_server_ip}/24"
        gateway = "192.168.0.1"
      }
    }

    user_account {
      username = "root"
      password = var.root_password
      keys     = [var.ssh_public_key]
    }
  }
}
