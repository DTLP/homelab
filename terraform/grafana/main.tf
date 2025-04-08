provider "grafana" {
  url  = "http://grafana.lab"
  auth = var.grafana_api_token
}

resource "grafana_dashboard" "dashboards" {
  for_each    = fileset("./dashboards/", "*.json")
  config_json = file("./dashboards/${each.key}")
}
