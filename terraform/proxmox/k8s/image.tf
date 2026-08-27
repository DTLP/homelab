moved {
  from = proxmox_virtual_environment_download_file.this
  to   = proxmox_download_file.this
}

resource "proxmox_download_file" "this" {
  count                   = length(var.pve.nodes)
  content_type            = "iso"
  datastore_id            = "nvme"
  node_name               = var.pve.nodes[count.index]
  file_name               = "talos-${local.talos_version}-nocloud-amd64.img"
  url                     = "https://factory.talos.dev/image/ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515/${local.talos_version}/nocloud-amd64.raw.gz"
  decompression_algorithm = "gz"
  overwrite               = false
}
