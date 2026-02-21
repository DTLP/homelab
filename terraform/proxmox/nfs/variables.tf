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

variable "ssh_public_key" {
  type    = string
  default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBjvENWo/NJ0+qQSGIffxcAJmtZE4K03JzB59xC1mtGQ root@pve"
}

variable "root_password" {
  type = string
}

variable "root_ssh_key" {
  type = string
}

variable "nfs_server_ip" {
  type    = string
  default = "192.168.0.60"
}
