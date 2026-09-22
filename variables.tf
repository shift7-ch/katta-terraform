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

variable "hub_admin_username" {
  description = "The username for the Katta Server admin user in the realm."
  type        = string
  default     = "admin"
}

variable "katta_chart_version" {
  description = "Version or version range of the Katta Server Helm chart to render the Keycloak realm from. Null for the latest version."
  type        = string
  # latest version of major version 1
  default = "^1"
}

variable "hub_admin_password" {
  description = "The initial password for the Katta Server admin user in the realm. It must be changed on first login."
  type        = string
  sensitive   = true
}

variable "github_token" {
  description = "GitHub Personal Access Token for authenticating to GitHub Container Registry (required for both public and private repos)"
  type        = string
  sensitive   = true
}

variable "keycloak_version" {
  description = "Docker image tag for ghcr.io/shift-7/keycloak."
  type        = string
  default     = "26.5.5"
}

variable "hub_version" {
  description = "Docker image tag for ghcr.io/shift7-ch/katta-server."
  type        = string
  default     = "latest-amd64"
}

variable "ecs_enable_execute_command" {
  description = "Enable ExecuteCommand to connecting to ecs services for debugging."
  type        = bool
  default     = false
}

variable "hub_keycloak_system_client_secret" {
  description = "Client secret for client 'cryptomatorhub-system'."
  type        = string
  sensitive   = true
}

variable "hub_keycloak_oidc_cryptomator_vaults_client_secret" {
  description = "Client secret for client 'cryptomatorvaults'."
  type        = string
  sensitive   = true
}

variable "hub_csp_additional_connect_src" {
  description = "Additional connect-src sources for the Content-Security-Policy header, required for the S3 and STS endpoints of storage profiles the browser talks to directly. CSP source expressions are used verbatim, so host wildcards are allowed."
  type        = list(string)
  default     = []
}

variable "hub_initial_license" {
  description = "Initial license token for Katta Server (HUB_INITIAL_LICENSE). Null to start without a license."
  type        = string
  default     = null
  sensitive   = true
}

variable "hub_initial_id" {
  description = "Initial Hub ID matching the license (HUB_INITIAL_ID). Null to start without a license."
  type        = string
  default     = null
}
