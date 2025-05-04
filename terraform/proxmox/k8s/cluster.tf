resource "talos_machine_secrets" "this" {}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster.name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = [for node in var.cluster.nodes : node.ipv4.address]
  endpoints            = [for node in var.cluster.nodes : node.ipv4.address if node.type == "controlplane"]
}

data "talos_machine_configuration" "this" {
  for_each         = var.cluster.nodes
  cluster_name     = var.cluster.name
  cluster_endpoint = "https://${data.talos_client_configuration.this.endpoints[0]}:6443"
  machine_type     = each.value.type
  machine_secrets  = talos_machine_secrets.this.machine_secrets
}

resource "talos_machine_configuration_apply" "this" {
  depends_on                  = [proxmox_virtual_environment_vm.this]
  for_each                    = var.cluster.nodes
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.key].machine_configuration
  node                        = each.value.ipv4.address

  config_patches = each.value.type == "controlplane" ? [
    templatefile("./resources/controlplane-node-patch.yaml.tmpl", {
      kube_api_endpoint = var.cluster.kube_api_endpoint
    })
  ] : []
}

resource "talos_machine_bootstrap" "this" {
  depends_on           = [talos_machine_configuration_apply.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = data.talos_client_configuration.this.endpoints[0]
}

data "talos_cluster_health" "this" {
  depends_on           = [talos_machine_configuration_apply.this, talos_machine_bootstrap.this]
  client_configuration = data.talos_client_configuration.this.client_configuration
  control_plane_nodes  = [for node in var.cluster.nodes : node.ipv4.address if node.type == "controlplane"]
  worker_nodes         = [for node in var.cluster.nodes : node.ipv4.address if node.type == "worker"]
  endpoints            = data.talos_client_configuration.this.endpoints
  timeouts = {
    read = "10m"
  }
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on           = [talos_machine_bootstrap.this, data.talos_cluster_health.this]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = data.talos_client_configuration.this.endpoints[0]
  endpoint             = data.talos_client_configuration.this.endpoints[0]
  timeouts = {
    read = "1m"
  }
}

output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = resource.talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive = true
}
