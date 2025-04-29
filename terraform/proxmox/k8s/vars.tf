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

variable "cluster" {
  type = object({
    name = string
    dns = object({
      servers = list(string)
    })
    ipv4 = object({
      gateway = string
      subnet  = string
    })
    talos_version = string
    nodes = map(object({
      host   = string
      cores  = number
      memory = number
      type   = string
      ipv4 = object({
        address = string
      })
    }))
  })
}
