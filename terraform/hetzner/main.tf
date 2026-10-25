data "template_file" "cloud_init" {
  template = file("./resources/user_data.yaml.tmpl")

  vars = {
    domain_name                  = var.domain_name
    mailserver_hostname          = var.mailserver_hostname
    pangolin_server_secret       = var.pangolin_server_secret
    newt_id                      = var.newt_id
    newt_secret                  = var.newt_secret
    cloudflare_api_token         = var.cloudflare_api_token
    traefik_config_b64           = base64encode(file("${path.module}/resources/traefik_config.yaml"))
    traefik_dynamic_config_b64   = base64encode(file("${path.module}/resources/traefik_dynamic_config.yaml"))
    tlsa_publish_b64             = base64encode(file("${path.module}/resources/tlsa_publish.sh"))
    tlsa_check_b64               = base64encode(file("${path.module}/resources/tlsa_check.sh"))
    dane_status_server_b64       = base64encode(file("${path.module}/resources/dane_status_server.py"))
    wg_server_endpoint_port      = var.wg_server_endpoint_port
    wg_server_private_ip_address = var.wg_server_private_ip_address
    wg_client_private_ip_address = var.wg_client_private_ip_address
    wg_server_private_key        = var.wg_server_private_key
    wg_client_public_key         = var.wg_client_public_key
    docker_mailserver_version    = var.docker_mailserver_version
    telegram_bot_token           = var.telegram_bot_token
    telegram_bot_user_id         = var.telegram_bot_user_id
    dms_admin_bot_version        = var.dms_admin_bot_version
    ente_compose_b64 = base64encode(templatefile("${path.module}/resources/ente_compose.yaml.tmpl", {
      ente_db_password          = var.ente_db_password
      ente_s3_region            = var.ente_s3_region
      ente_s3_endpoint          = var.ente_s3_endpoint
      ente_s3_access_key_id     = var.ente_s3_access_key_id
      ente_s3_secret_access_key = var.ente_s3_secret_access_key
      ente_s3_bucket            = var.ente_s3_bucket
      ente_s3_prefix            = var.ente_s3_prefix
    }))
    ente_museum_b64 = base64encode(templatefile("${path.module}/resources/ente_museum.yaml.tmpl", {
      ente_db_password          = var.ente_db_password
      ente_s3_region            = var.ente_s3_region
      ente_s3_endpoint          = var.ente_s3_endpoint
      ente_s3_access_key_id     = var.ente_s3_access_key_id
      ente_s3_secret_access_key = var.ente_s3_secret_access_key
      ente_s3_bucket            = var.ente_s3_bucket
      ente_key_encryption       = var.ente_key_encryption
      ente_key_hash             = var.ente_key_hash
      ente_jwt_secret           = var.ente_jwt_secret
      ente_internal_admin       = var.ente_internal_admin
    }))
    email_backup_b64          = base64encode(file("${path.module}/resources/email_backup.sh"))
    email_backup_password_b64 = base64encode(trimspace(var.email_backup_password))
    backup_retention_days     = tostring(var.backup_retention_days)
    rclone_config_b64 = base64encode(join("\n", [
      "[dropbox]",
      "type = dropbox",
      "token = ${replace(replace(trimspace(var.dropbox_token), "\r", ""), "\n", "")}",
    ]))
  }
}

resource "local_sensitive_file" "cloud_init" {
  content  = data.template_file.cloud_init.rendered
  filename = "./secrets/user_data.yaml"
}

resource "hcloud_ssh_key" "mail" {
  name       = "mail"
  public_key = var.ssh_public_key
}

resource "hcloud_network" "mail" {
  name     = "mail"
  ip_range = "10.20.0.0/16"
}

resource "hcloud_network_subnet" "mail" {
  type         = "cloud"
  network_id   = hcloud_network.mail.id
  network_zone = "eu-central"
  ip_range     = "10.20.30.0/24"
}

resource "hcloud_primary_ip" "mail" {
  name        = "mail"
  location    = "nbg1" # DE Nuremberg 1
  type        = "ipv4"
  auto_delete = false
}

resource "hcloud_server" "mail" {
  name        = "mail"
  location    = "nbg1" # DE Nuremberg 1
  server_type = "cx22" # 2 vCPU, 4GB RAM, 40GB SSD, € 0.006/h
  image       = "ubuntu-24.04"

  ssh_keys  = [hcloud_ssh_key.mail.id]
  user_data = local_sensitive_file.cloud_init.content

  public_net {
    ipv4_enabled = true
    ipv4         = hcloud_primary_ip.mail.id
    ipv6_enabled = false
  }

  network {
    network_id = hcloud_network.mail.id
    ip         = "10.20.30.40"
  }

  depends_on = [
    hcloud_network_subnet.mail
  ]

  lifecycle {
    ignore_changes = [
      user_data
    ]
  }
}

resource "hcloud_rdns" "mail" {
  primary_ip_id = hcloud_primary_ip.mail.id
  ip_address    = hcloud_primary_ip.mail.ip_address
  dns_ptr       = "${var.mailserver_hostname}.${var.domain_name}"
}

resource "hcloud_firewall" "mail" {
  name = var.mailserver_hostname

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "25" # SMTP
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80" # Let’s Encrypt webserver & Pangolin
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443" # Pangolin web dashboard
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "465" # SMTP over SSL/TLS
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "993" # IMAP over SSL/TLS
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "8082" # DANE TLSA status page for UptimeRobot
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "21820" # Pangolin - WireGuard - Client connections
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "51820" # Pangolin - WireGuard - Newt connectons
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "udp"
    port       = "51821" # WireGuard Admin tunnel
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_firewall_attachment" "mail" {
  firewall_id = hcloud_firewall.mail.id
  server_ids  = [hcloud_server.mail.id]
}
