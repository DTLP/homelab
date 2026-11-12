locals {
  admin_ssh_key = file("../secrets/id_ed25519.pub")
}

data "template_file" "runner" {
  template = file("./resources/runner.yaml.tmpl")

  vars = {
    hostname       = var.runner_name
    admin_ssh_key  = local.admin_ssh_key
    forgejo_url    = var.forgejo_url
    forgejo_host   = replace(replace(var.forgejo_url, "https://", ""), "http://", "")
    runner_token   = var.runner_token
    runner_version = var.runner_version
    runner_labels  = var.runner_labels
  }
}

resource "local_file" "runner" {
  content  = data.template_file.runner.rendered
  filename = "./cloud-init-config/runner.yaml"

  # The rendered file contains the runner registration token.
  file_permission = "0600"
}

resource "proxmox_virtual_environment_file" "runner" {
  node_name    = "pve1"
  datastore_id = "nvme"
  content_type = "snippets"

  source_file {
    path     = local_file.runner.filename
    checksum = filesha256(local_file.runner.filename)
  }
}

resource "proxmox_virtual_environment_vm" "runner" {
  name      = var.runner_name
  tags      = ["terraform", "forgejo"]
  node_name = "pve1"
  on_boot   = true

  # Disabled: the Terraform provider blocks VM creation until the guest agent
  # answers, which adds a long wait and fails if cloud-init is slow.
  agent {
    enabled = false
  }

  clone {
    vm_id        = 8001
    datastore_id = "nvme"
    full         = true
  }

  cpu {
    cores   = 2
    sockets = 1
    type    = "host"
  }

  # 2GB ceiling, but the balloon lets the host reclaim down to 512MB.
  memory {
    dedicated = 2048
    floating  = 512
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  disk {
    datastore_id = "nvme"
    interface    = "scsi0"
    size         = 20
  }

  operating_system {
    type = "l26"
  }

  initialization {
    user_data_file_id = proxmox_virtual_environment_file.runner.id

    ip_config {
      ipv4 {
        address = "${var.runner_ip}/24"
        gateway = "192.168.0.1"
      }
    }

    user_account {
      username = "root"
      keys     = [local.admin_ssh_key]
    }
  }

  # The cloud-init snippet changes whenever it is regenerated, which would
  # otherwise force the VM to be recreated. Ignore it so in-place updates win.
  lifecycle {
    ignore_changes = [
      initialization[0].user_data_file_id,
    ]
  }
}
