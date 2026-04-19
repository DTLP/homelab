data "template_file" "wg_client_config" {
  template = file("./resources/wg_client.conf.tmpl")

  vars = {
    wg_server_endpoint_address   = hcloud_server.mail.ipv4_address
    wg_server_endpoint_port      = var.wg_server_endpoint_port
    wg_server_private_ip_address = var.wg_server_private_ip_address
    wg_server_public_key         = var.wg_server_public_key
    wg_client_private_ip_address = var.wg_client_private_ip_address
    wg_client_private_key        = var.wg_client_private_key
  }

  depends_on = [
    hcloud_network_subnet.mail
  ]
}

resource "local_sensitive_file" "wg_client_config" {
  content  = data.template_file.wg_client_config.rendered
  filename = "./secrets/wg_client.conf"
}
