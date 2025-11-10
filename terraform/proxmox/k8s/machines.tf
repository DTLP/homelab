resource "proxmox_virtual_environment_vm" "this" {
  for_each    = var.cluster.nodes
  name        = each.key
  description = "Managed by Terraform"
  tags        = ["terraform"]
  node_name   = each.value.host
  on_boot     = true

  cpu {
    cores = each.value.cores
    type  = "host"
    units = 1024

  }

  memory {
    dedicated = each.value.memory
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = "vmbr0"
  }

  disk {
    datastore_id = "nvme"
    file_id      = one([for image in proxmox_virtual_environment_download_file.this : image if image.node_name == each.value.host]).id
    file_format  = "raw"
    interface    = "virtio0"
    size         = 50
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = "nvme"
    ip_config {
      ipv4 {
        address = "${each.value.ipv4.address}/${split("/", var.cluster.ipv4.subnet)[1]}"
        gateway = var.cluster.ipv4.gateway
      }
    }

    dns {
      servers = var.cluster.dns.servers
    }
  }
}
