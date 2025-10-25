data "template_file" "cloud_init" {
  template = file("./resources/user_data.yaml.tmpl")

  vars = {
    domain_name                  = var.domain_name
    mailserver_hostname          = var.mailserver_hostname
    wg_server_endpoint_port      = var.wg_server_endpoint_port
    wg_server_private_ip_address = var.wg_server_private_ip_address
    wg_client_private_ip_address = var.wg_client_private_ip_address
    wg_server_private_key        = var.wg_server_private_key
    wg_client_public_key         = var.wg_client_public_key
    docker_mailserver_version    = var.docker_mailserver_version
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
  name          = "mail"
  datacenter    = "nbg1-dc3" # DE Nuremberg 1 Virtual DC 3
  type          = "ipv4"
  assignee_type = "server"
  auto_delete   = false
}

resource "hcloud_server" "mail" {
  name        = "mail"
  datacenter  = "nbg1-dc3" # DE Nuremberg 1 Virtual DC 3
  server_type = "cx22"     # 2 vCPU, 4GB RAM, 40GB SSD, € 0.006/h
  image       = "ubuntu-24.04"

  ssh_keys  = [hcloud_ssh_key.mail.id]
  user_data = file(local_sensitive_file.cloud_init.filename)

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
    port       = "80" # Let’s Encrypt webserver
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
    protocol   = "udp"
    port       = "51820" # WireGuard
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_firewall_attachment" "mail" {
  firewall_id = hcloud_firewall.mail.id
  server_ids  = [hcloud_server.mail.id]
}
