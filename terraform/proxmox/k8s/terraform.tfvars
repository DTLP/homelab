pve = {
  nodes    = ["pve1", "pve2", "pve3", "pve4", "pve5"]
  endpoint = "https://192.168.0.21:8006/api2/json"
  ssh = {
    username         = "root"
    private_key_file = "../secrets/id_ed25519"
  }
  insecure = true
}

cluster = {
  name = "homelab"
  dns = {
    servers = ["1.1.1.1"]
  }
  ipv4 = {
    subnet  = "192.168.0.0/24"
    gateway = "192.168.0.1"
  }
  talos_version = "1.9.5"
  nodes = {
    master-0 = {
      host   = "pve1"
      cores  = 2
      memory = 3072
      type   = "controlplane"
      ipv4 = {
        address = "192.168.0.30"
      }
    }
    master-1 = {
      host   = "pve1"
      cores  = 2
      memory = 3072
      type   = "controlplane"
      ipv4 = {
        address = "192.168.0.31"
      }
    }
    worker-0 = {
      host   = "pve2"
      cores  = 4
      memory = 6144
      type   = "worker"
      ipv4 = {
        address = "192.168.0.40"
      }
    }
    worker-1 = {
      host   = "pve3"
      cores  = 4
      memory = 6144
      type   = "worker"
      ipv4 = {
        address = "192.168.0.41"
      }
    }
    worker-2 = {
      host   = "pve4"
      cores  = 4
      memory = 6144
      type   = "worker"
      ipv4 = {
        address = "192.168.0.42"
      }
    }
  }
}
