resource "aws_secretsmanager_secret" "keycloak_db_credentials" {
  name                    = "${var.project}-${terraform.workspace}-keycloak-db-credentials20260229"
  description             = "Database credentials for ${var.project} in ${terraform.workspace}"
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
  name                    = "${var.project}-${terraform.workspace}-keycloak-admin20260229"
  description             = "Keycloak admin credentials for ${var.project} in ${terraform.workspace}"
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
  name                    = "${var.project}-${terraform.workspace}-hub-db-credentials20260229"
  description             = "Database credentials for ${var.project} in ${terraform.workspace}"
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

resource "aws_secretsmanager_secret" "hub_keycloak_credentials" {
  name                    = "${var.project}-${terraform.workspace}-hub-keycloak-credentials20260229"
  description             = "Database credentials for ${var.project} in ${terraform.workspace}"
  recovery_window_in_days = 7

  tags = {
    Project     = var.project
    Environment = terraform.workspace
  }
}

resource "aws_secretsmanager_secret_version" "hub_keycloak_credentials_version" {
  secret_id = aws_secretsmanager_secret.hub_keycloak_credentials.id
  secret_string = jsonencode({
    HUB_KEYCLOAK_SYSTEM_CLIENT_SECRET = var.HUB_KEYCLOAK_SYSTEM_CLIENT_SECRET
    HUB_KEYCLOAK_OIDC_CRYPTOMATOR_VAULTS_CLIENT_SECRET = var.HUB_KEYCLOAK_OIDC_CRYPTOMATOR_VAULTS_CLIENT_SECRET
  })
}



