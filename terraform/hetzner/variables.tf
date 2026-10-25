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
  default     = "16.0.1"
  type        = string
}

variable "pangolin_server_secret" {
  description = "Pangolin server secret"
  type        = string
  sensitive   = true
}

variable "cloudflare_api_token" {
  description = <<-EOT
    Cloudflare API token used to publish the DANE TLSA records for the mail
    server. Needs Zone:DNS:Edit on the zone; DNS:Read alone is not enough.
  EOT
  type        = string
  sensitive   = true
}

variable "newt_id" {
  description = "Newt client ID for the Pangolin site running on this server"
  type        = string
  sensitive   = true
}

variable "newt_secret" {
  description = "Newt client secret for the Pangolin site running on this server"
  type        = string
  sensitive   = true
}

variable "telegram_bot_token" {
  description = "Telegram bot token for the dms-admin-bot"
  type        = string
  sensitive   = true
}

variable "telegram_bot_user_id" {
  description = "Telegram user id allowed to manage aliases via the dms-admin-bot"
  type        = string
}

variable "dms_admin_bot_version" {
  description = "Image tag of the dms-admin-bot"
  default     = "latest"
  type        = string
}

variable "ente_db_password" {
  description = "Password for the Ente Postgres database"
  type        = string
  sensitive   = true
}

variable "ente_s3_region" {
  description = "Region of the S3 bucket used by Ente for photo storage and backups"
  default     = "auto"
  type        = string
}

variable "ente_s3_endpoint" {
  description = "S3 endpoint used by Ente for photo storage and backups"
  type        = string
  sensitive   = true
}

variable "ente_s3_access_key_id" {
  description = "S3 access key ID used by Ente for photo storage and backups"
  type        = string
  sensitive   = true
}

variable "ente_s3_secret_access_key" {
  description = "S3 secret access key used by Ente for photo storage and backups"
  type        = string
  sensitive   = true
}

variable "ente_s3_bucket" {
  description = "S3 bucket used by Ente for photo storage and backups"
  default     = "ente"
  type        = string
}

variable "ente_s3_prefix" {
  description = "S3 key prefix for the nightly Ente Postgres backups"
  default     = "postgres_backups"
  type        = string
}

variable "ente_key_encryption" {
  description = "Ente museum encryption key"
  type        = string
  sensitive   = true
}

variable "ente_key_hash" {
  description = "Ente museum hash key"
  type        = string
  sensitive   = true
}

variable "ente_jwt_secret" {
  description = "Ente museum JWT secret"
  type        = string
  sensitive   = true
}

variable "ente_internal_admin" {
  description = "Ente internal admin user id"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH Public Key for the mail server"
  type        = string
}

variable "wg_server_endpoint_port" {
  description = "Port used by the WireGuard server for all client connections"
  default     = "51821"
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
  description = "Public key for the WireGuard client"
  type        = string
}

