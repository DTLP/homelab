variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "The domain name for the email server, e.g., example.com."
  default     = "dtlp.cc"
  type        = string
}

variable "mailserver_hostname" {
  description = "The hostname of the email server, e.g., 'mail'."
  default     = "mail"
  type        = string
}

variable "docker_mailserver_version" {
  description = "Version tag of the docker-mailserver"
  default     = "15.1.0"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH Public Key for the mail server"
  type        = string
}

variable "wg_server_endpoint_port" {
  description = "Port used by the WireGuard server for all client connections"
  default     = "51820"
  type        = string
}

variable "wg_server_private_ip_address" {
  description = "Private IP address assigned to the WireGuard server interface"
  default     = "10.20.30.40"
  type        = string
}

variable "wg_client_private_ip_address" {
  description = "Private IP address assigned to the WireGuard client interface"
  default     = "10.20.30.41"
  type        = string
}

variable "wg_server_private_key" {
  description = "The private key for the WireGuard server"
  type        = string
  sensitive   = true
}

variable "wg_server_public_key" {
  description = "The public key for the WireGuard server"
  type        = string
}

variable "wg_client_private_key" {
  description = "The private key for the WireGuard client"
  type        = string
  sensitive   = true
}

variable "wg_client_public_key" {
  description = "The public key for the WireGuard client"
  type        = string
}
