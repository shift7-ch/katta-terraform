variable "project" {
  description = "The project Name where all resources will be launched."
  type        = string
  default     = "katta"
}

variable "dns_suffix" {
  description = "DNS suffix."
  type        = string
}

variable "keycloak_prefix" {
  description = "DNS prefix for Keycloak service endpoints."
  type        = string
  default     = "keycloak"
}

variable "hub_prefix" {
  description = "DNS prefix for Hub service endpoints."
  type        = string
  default     = "hub"
}

variable "region" {
  description = "The region to create resources."
  type        = string
  default     = "eu-central-1" # Override with TF_VAR_region or set TF_VAR_region=$AWS_DEFAULT_REGION
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.1.0.0/16"
}

variable "keycloak_db_name" {
  description = "The name of the Keycloak database."
  type        = string
  default     = "keycloak_database"
}

variable "keycloak_db_username" {
  description = "The username for the Keycloak database."
  type        = string
  default     = "keycloak_admin"
}

variable "keycloak_db_password" {
  description = "The password for the Keycloak database."
  type        = string
  sensitive   = true
}

variable "hub_db_name" {
  description = "The name of the Hub database."
  type        = string
  default     = "hub_database"
}

variable "hub_db_username" {
  description = "The username for the Hub database."
  type        = string
  default     = "hub_admin"
}

variable "hub_db_password" {
  description = "The password for the Hub database."
  type        = string
  sensitive   = true
}

variable "keycloak_admin_username" {
  description = "The username for the Keycloak admin user."
  type        = string
  default     = "keycloak_admin"
}

variable "keycloak_admin_password" {
  description = "The password for the Keycloak admin user."
  type        = string
  sensitive   = true
}

variable "keycloak_action_redirect" {
  description = "The custom URL scheme for Keycloak action redirects desktop application."
  type        = string
  default     = "x-katta-action:oauth"
}

variable "github_token" {
  description = "GitHub Personal Access Token for authenticating to GitHub Container Registry (required for both public and private repos)"
  type        = string
  sensitive   = true
}

variable "keycloak_version" {
  description = "Docker image tag for ghcr.io/cryptomator/keycloak."
  type        = string
  default     = "26.4.5"
}

variable "hub_version" {
  description = "Docker image tag for ghcr.io/shift7-ch/katta-server."
  type        = string
  # TODO temporary workaround while waiting for fix https://github.com/shift7-ch/katta-server/pull/107
  default     = "cc8d14c-amd64"
}
