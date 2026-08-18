# talos/talenv.yaml is the single source of truth for the Talos and Kubernetes
# versions (used by Talhelper)
data "local_file" "talenv" {
  filename = "${path.module}/../../../talos/talenv.yaml"
}

locals {
  talos_version = trimprefix(trimspace(yamldecode(data.local_file.talenv.content).TALOS_VERSION), "v")
}

