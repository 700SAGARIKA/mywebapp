variable "aws_region"         {}
variable "account_id"         {}
variable "cluster_name"       {}
variable "ecr_repo_name"      {}
variable "environment"        {}

variable "node_instance_type" {}
variable "node_desired_size"  {}
variable "node_min_size"      {}
variable "node_max_size"      {}
variable "node_disk_size"     {}
variable "node_capacity_type" { default = "ON_DEMAND" }

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for grafana.ordr.fun HTTPS"
  type        = string
}

variable "smtp_host" {
  description = "SMTP server hostname for Alertmanager email alerts"
  type        = string
  default     = "smtp.vvdntech.in:587"
}

variable "smtp_password" {
  description = "SMTP password for Alertmanager email alerts"
  type        = string
  sensitive   = true
}
