variable "pve" {
  type = object({
    endpoint = string
    token    = optional(string)
    nodes    = list(string)
    ssh = object({
      username         = string
      private_key_file = string
    })
    insecure = bool,
  })
}

variable "nfs_server_ip" {
  type    = string
  default = "192.168.0.60"
}
