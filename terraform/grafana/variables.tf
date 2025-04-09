variable "grafana_api_token" {
  description = "The API token for Grafana"
  type        = string
}

variable "grafana_url" {
  description = "The URL of the Grafana service"
  type        = string
  default     = "http://grafana.lab"
}

