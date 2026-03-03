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
}

variable "keycloak_db_username" {
  description = "The username for the Keycloak database."
  type        = string
}

variable "keycloak_db_password" {
  description = "The password for the Keycloak database."
  type        = string
  sensitive   = true
}

variable "hub_db_name" {
  description = "The name of the Hub database."
  type        = string
}

variable "hub_db_username" {
  description = "The username for the Hub database."
  type        = string
}

variable "hub_db_password" {
  description = "The password for the Hub database."
  type        = string
  sensitive   = true
}

variable "keycloak_admin_username" {
  description = "The username for the Keycloak admin user."
  type        = string
}

variable "keycloak_admin_password" {
  description = "The password for the Keycloak admin user."
  type        = string
  sensitive   = true
}

variable "hub_keycloak_system_client_secret" {
  description = "The client secret for Hub's Keycloak system client. Must match the value in cryptomator-realm.json."
  type        = string
  sensitive   = true
}

variable "hub_keycloak_oidc_cryptomator_vaults_client_secret" {
  description = "The client secret for Hub's Keycloak OIDC Cryptomator Vaults client. Must match the value in cryptomator-realm.json."
  type        = string
  sensitive   = true
}

variable "keycloak_action_redirect" {
  description = "The custom URL scheme for Keycloak action redirects desktop application."
  type        = string
  default     = "x-katta-action:oauth"
}

variable "github_token" {
  description = "GitHub Personal Access Token for accessing private container registry (optional for public repos)"
  type        = string
  sensitive   = true
  default     = ""
}

