# Cloud-Init config taken from:
# https://codingpackets.com/blog/proxmox-cloud-init-with-terraform-and-saltstack

data "template_file" "cloud_init" {
  for_each = var.cloud_init_virtual_machines

  template = file("${path.module}/scripts/${each.value.cloud_init_file}")

  vars = {
    hostname           = each.value.hostname
    admin_ssh_key      = var.admin_ssh_key
    root_password      = var.root_password
    root_ssh_key       = var.root_ssh_key
    k8s_master_node_ip = var.k8s_master_node_ip
  }
}

# Create a local copy of the file, to transfer to Proxmox
resource "local_file" "cloud_init" {
  for_each = var.cloud_init_virtual_machines

  content  = data.template_file.cloud_init[each.key].rendered
  filename = "./cloud-init-config/user_data_cloud_init_${each.value.hostname}.cfg"
}

# Transfer the file to the Proxmox Host
resource "null_resource" "cloud_init" {
  for_each = var.cloud_init_virtual_machines

  connection {
    type        = "ssh"
    user        = var.proxmox_user
    private_key = var.proxmox_user_key_priv
    host        = var.proxmox_host_ipv4_addrs[each.value.target_node]
  }

  provisioner "file" {
    source      = local_file.cloud_init[each.key].filename
    destination = "/mnt/pve/nvme/snippets/cloud_init_${each.value.hostname}.yaml"
  }
}

resource "proxmox_vm_qemu" "vms" {
  for_each = { for key, value in var.cloud_init_virtual_machines : key => value if startswith(value.vm_template, "ubuntu-cloud") == true }

  name        = each.value.hostname
  target_node = each.value.target_node
  clone       = each.value.vm_template
  agent       = 1
  os_type     = "cloud-init"
  cores       = each.value.cpu_cores
  sockets     = each.value.cpu_sockets
  cpu         = "host"
  memory      = each.value.memory
  qemu_os     = each.value.qemu_os
  onboot      = each.value.onboot

  cloudinit_cdrom_storage = each.value.hdd_storage
  scsihw                  = "virtio-scsi-single"
  bootdisk                = "scsi0"

  disks {
    scsi {
      scsi0 {
        disk {
          storage    = each.value.hdd_storage
          size       = 20
          emulatessd = true
        }
      }
    }
  }

  network {
    bridge = "vmbr0"
    model  = "virtio"
  }

  # Cloud Init
  ipconfig0 = "ip=${each.value.ip_address},gw=${each.value.gateway}"
  ciuser    = "root"
  cicustom  = "user=nvme:snippets/cloud_init_${each.value.hostname}.yaml"
  sshkeys   = <<EOF
  ${var.ssh_public_key}
  EOF
}
