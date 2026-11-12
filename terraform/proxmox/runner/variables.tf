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

variable "runner_token" {
  type        = string
  description = "Forgejo Actions registration token."
  sensitive   = true
}

variable "runner_ip" {
  type    = string
  default = "192.168.0.61"
}

variable "forgejo_url" {
  type    = string
  default = "https://git.dtlp.cc"
}

variable "runner_version" {
  type        = string
  default     = "13.2.1"
  description = "Forgejo runner release, without the leading v."
}

variable "runner_name" {
  type    = string
  default = "forgejo-runner"
}

variable "runner_labels" {
  type    = string
  default = "ubuntu-latest:docker://node:22-bookworm,host:host"
}
