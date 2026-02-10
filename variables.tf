variable "project" {
  description = "The project Name where all resources will be launched."
  type        = string
  default     = "katta"
}

variable "environment" {
  description = "The environment name, defined in environments defined as a environment."
  type        = string
  default     = "development"
}

variable "dns_suffix" {
  description = "DNS suffix."
  type        = string
  default     = "catta.cloud"
}

variable "keycloak_prefix" {
  description = "DNS prefix."
  type        = string
  default     = "keycloak"
}

variable "hub_prefix" {
  description = "DNS prefix."
  type        = string
  default     = "hub"
}

variable "region" {
  description = "The region to create resources."
  type        = string
  default     = "eu-central-1"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
  default     = "10.1.0.0/16"
}

variable "keycloak_db_name" {
  description = "The name of the database snapshot."
  type        = string
}

variable "keycloak_db_username" {
  description = "The username for the database."
  type        = string
}

variable "keycloak_db_password" {
  description = "The password for the database."
  type        = string
}

variable "hub_db_name" {
  description = "The name of the database snapshot."
  type        = string
}

variable "hub_db_username" {
  description = "The username for the database."
  type        = string
}

variable "hub_db_password" {
  description = "The password for the database."
  type        = string
}

variable "keycloak_admin_username" {
  description = "The username for the keycloak admin."
  type        = string
}

variable "keycloak_admin_password" {
  description = "The password for the keycloak admin."
  type        = string
}

variable "HUB_KEYCLOAK_SYSTEM_CLIENT_SECRET" {
  description = ""
  type        = string
}

variable "HUB_KEYCLOAK_OIDC_CRYPTOMATOR_VAULTS_CLIENT_SECRET" {
  description = ""
  type        = string
}

variable "secret_suffix" {
  description = "Use to make secret names unique while there are secrets pending for deletion during minimum grace period (7 days)."
  type        = string
  default     = ""
}

variable "keycloak_action_redirect" {
  description = ""
  type        = string
  default     = "x-katta-action:oauth"
}

