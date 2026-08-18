# talos/talenv.yaml is the single source of truth for the Talos and Kubernetes
# versions (used by Talhelper)
data "local_file" "talenv" {
  filename = "${path.module}/../../../talos/talenv.yaml"
}

locals {
  talos_env          = yamldecode(data.local_file.talenv.content)
  talos_version      = trimprefix(trimspace(local.talos_env.TALOS_VERSION), "v")
  kubernetes_version = trimprefix(trimspace(local.talos_env.KUBERNETES_VERSION), "v")
}

