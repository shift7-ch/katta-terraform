resource "random_id" "secret_suffix" {
  byte_length = 8
}

resource "aws_secretsmanager_secret" "keycloak_db_credentials" {
  name                    = "${terraform.workspace}-${var.keycloak_prefix}-db-credentials__${random_id.secret_suffix.hex}"
  description             = "Database credentials in ${terraform.workspace}"
  recovery_window_in_days = 7

  tags = {
    Project     = var.project
    Environment = terraform.workspace
  }
}

resource "aws_secretsmanager_secret_version" "keycloak_db_credentials_version" {
  secret_id = aws_secretsmanager_secret.keycloak_db_credentials.id
  secret_string = jsonencode({
    username = var.keycloak_db_username
    password = var.keycloak_db_password
  })
}

resource "aws_secretsmanager_secret" "keycloak_admin" {
  name                    = "${terraform.workspace}-${var.keycloak_prefix}-admin__${random_id.secret_suffix.hex}"
  description             = "Keycloak admin credentials in ${terraform.workspace}"
  recovery_window_in_days = 7

  tags = {
    Project     = var.project
    Environment = terraform.workspace
  }
}

resource "aws_secretsmanager_secret_version" "keycloak_admin_version" {
  secret_id = aws_secretsmanager_secret.keycloak_admin.id
  secret_string = jsonencode({
    username = var.keycloak_admin_username
    password = var.keycloak_admin_password
  })
}


resource "aws_secretsmanager_secret" "hub_db_credentials" {
  name                    = "${terraform.workspace}-${var.hub_prefix}-db-credentials__${random_id.secret_suffix.hex}"
  description             = "Database credentials in ${terraform.workspace}"
  recovery_window_in_days = 7

  tags = {
    Project     = var.project
    Environment = terraform.workspace
  }
}

resource "aws_secretsmanager_secret_version" "hub_db_credentials_version" {
  secret_id = aws_secretsmanager_secret.hub_db_credentials.id
  secret_string = jsonencode({
    username = var.hub_db_username
    password = var.hub_db_password
  })
}

resource "aws_secretsmanager_secret" "hub_oidc_client_secrets_credentials" {
  name                    = "${terraform.workspace}-${var.hub_prefix}-oidc-client-secrets__${random_id.secret_suffix.hex}"
  description             = "OIDC client secrets in ${terraform.workspace}"
  recovery_window_in_days = 7

  tags = {
    Project     = var.project
    Environment = terraform.workspace
  }
}

# Download cryptomator-realm.json if it doesn't exist
resource "null_resource" "download_cryptomator_realm" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = "curl -fsSL https://raw.githubusercontent.com/shift7-ch/katta-server/refs/heads/feature/cipherduck-uvf/backend/src/main/resources/cryptomator-realm.json -o ${path.module}/cryptomator-realm.json"
  }
}

# Extract client secrets from cryptomator-realm.json
data "local_file" "cryptomator_realm" {
  filename   = "${path.module}/cryptomator-realm.json"
  depends_on = [null_resource.download_cryptomator_realm]
}

locals {
  cryptomator_realm = jsondecode(data.local_file.cryptomator_realm.content)


  # Modified realm JSON with updated redirectUris for cryptomatorhub client
  # Care needs to be taken to prevent "The true and false result expressions must have consistent types."
  cryptomator_realm_modified = merge(local.cryptomator_realm, {
    clients = [
      for client in local.cryptomator_realm.clients :
      client.clientId == "cryptomatorhub" ? merge(client, {
        redirectUris = toset(concat(
          [var.keycloak_action_redirect, "https://${var.hub_prefix}.${terraform.workspace}.${var.dns_suffix}/*"],
          client.redirectUris
        )),
        secret = try(client.secret, null),
      }) :
      client.clientId == "cryptomator" ? merge(client, {
        redirectUris = toset(concat(
          [var.keycloak_action_redirect, "https://${var.hub_prefix}.${terraform.workspace}.${var.dns_suffix}/*"],
          client.redirectUris
        )),
        secret = try(client.secret, null),
      }) :
      client.clientId == "cryptomatorvaults" ? merge(client, {
        secret       = var.hub_keycloak_oidc_cryptomator_vaults_client_secret,
        redirectUris = try(toset(client.redirectUris), null),
      }) :
      client.clientId == "cryptomatorhub-system" ? merge(client, {
        secret       = var.hub_keycloak_system_client_secret,
        redirectUris = try(toset(client.redirectUris), null),
      }) :
      merge(client, {
        secret       = try(client.secret, null),
        redirectUris = try(toset(client.redirectUris), null),
      })
    ]
  })

  # Base64-encoded realm JSON for environment variable
  cryptomator_realm_base64 = base64encode(jsonencode(local.cryptomator_realm_modified))
}

resource "aws_secretsmanager_secret_version" "hub_oidc_client_secrets_credentials_version" {
  secret_id = aws_secretsmanager_secret.hub_oidc_client_secrets_credentials.id
  secret_string = jsonencode({
    hub_keycloak_system_client_secret                  = var.hub_keycloak_system_client_secret
    hub_keycloak_oidc_cryptomator_vaults_client_secret = var.hub_keycloak_oidc_cryptomator_vaults_client_secret
  })
}

resource "aws_secretsmanager_secret" "github_token" {
  name                    = "ecr-pullthroughcache/${terraform.workspace}-ghcr"
  recovery_window_in_days = 0

  tags = {
    Project     = var.project
    Environment = terraform.workspace
  }
}

resource "aws_secretsmanager_secret_version" "github_token" {
  secret_id = aws_secretsmanager_secret.github_token.id
  secret_string = jsonencode({
    username    = "oauth2"
    accessToken = var.github_token
  })
}
