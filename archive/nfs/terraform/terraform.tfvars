pve = {
  nodes    = ["pve1", "pve2", "pve3", "pve4", "pve5"]
  endpoint = "https://192.168.0.21:8006/api2/json"
  ssh = {
    username         = "root"
    private_key_file = "../secrets/id_ed25519"
  }
  insecure = true
}
