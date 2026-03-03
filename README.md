# Katta: the secure and easy way to work in teams

Katta bring zero-config storage management and zero-knowledge key management for teams and organizations.

## Katta Terraform

### TL;DR;

> [Terraform workflow for provisioning infrastructure](https://developer.hashicorp.com/terraform/cli/run)

Set up Katta Hub in a custom AWS hosted zone. Change terraform workspace to control the infix `<workspace>`:

* `https://hub.<workspace>.<dns_suffix>`
* `https://keycloak.<workspace>.<dns_suffix>`

### Prerequisites

1. Install Docker

2. Setup AWS CLI and configure credentials in environment
    ```shell
    export AWS_ACCESS_KEY_ID=
    export AWS_SECRET_ACCESS_KEY=
    export AWS_SESSION_TOKEN=
    export AWS_DEFAULT_REGION=

## Deployment

1. Setup Terraform Workspace
    ```shell
    terraform workspace new katta
    ```

2. Override default Terraform configuration

   Defaults can be found in `terraform.tfvars` and can be overridden by environment variables:

    ```shell
    export TF_VAR_region=$AWS_DEFAULT_REGION
    export TF_VAR_dns_suffix=example.net
    export TF_VAR_keycloak_db_password=
    export TF_VAR_keycloak_admin_password=
    export TF_VAR_hub_db_password=
    ```
3. Add hosted zone for domain in AWS Route53

    ```shell
    aws route53 create-hosted-zone --name $TF_VAR_dns_suffix --caller-reference $(date +%s)
    ```

## Deployment

1. Setup Terraform Workspace
    ```shell
    terraform workspace new katta
    ```
2. Edit default configuration
    ```shell
    cp terraform.tfvars{.template,}
    vi terraform.tfvars # enter <DOMAIN> and passwords
    ```

3. Validate environment

    ```shell
    terraform init
    terraform validate
    AWS_USE_DUALSTACK_ENDPOINT=false terraform plan
    ```

4. Create Container Registry for Keycloak

   ```shell
   export KEYCLOAK_REGISTRY_ID=$(aws ecr create-repository --repository-name cryptomator-keycloak --region eu-central-1 --output json | jq -r '.repository.registryId')
   ```

5. Push Keycloak Image to ECR from GitHub Container Registry

   ```shell
   docker pull --platform linux/amd64 ghcr.io/cryptomator/keycloak:26.4.5
   aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin $KEYCLOAK_REGISTRY_ID.dkr.ecr.eu-central-1.amazonaws.com/cryptomator-keycloak
   docker push $KEYCLOAK_REGISTRY_ID.dkr.ecr.eu-central-1.amazonaws.com/cryptomator-keycloak:26.4.5
   ```

6. Create Container Registry for Katta Hub

   ```shell
   export HUB_REGISTRY_ID=$(aws ecr create-repository --repository-name katta-server --region eu-central-1 --output json | jq -r '.repository.registryId')
   ```

7. Push Katta Hub Image to ECR from GitHub Container Registry

   ```shell
   docker pull ghcr.io/shift7-ch/katta-server:982baf0-amd64 --platform linux/amd64 
   aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin $HUB_REGISTRY_ID.dkr.ecr.eu-central-1.amazonaws.com/katta-server
   docker push $HUB_REGISTRY_ID.dkr.ecr.eu-central-1.amazonaws.com/katta-server:982baf0-amd64
   ```

8. Deploy environment

    ```shell
    AWS_USE_DUALSTACK_ENDPOINT=false terraform apply --auto-approve 
    ```

## Cleanup

Preconditions from leftovers previous run: Rename secret names, they have a minimum grace period of 7 days before
deletion.

1. Destroy environment
    ```shell
    AWS_USE_DUALSTACK_ENDPOINT=false terraform destroy --auto-approve
    ```

## Background

### ECR Pull-Through Cache

Container images are automatically pulled from GitHub Container Registry (ghcr.io) via Amazon ECR pull-through cache rules. This eliminates the need to manually pull and push images to ECR.

- Keycloak: `ghcr.io/cryptomator/keycloak:26.4.5`
- Katta Hub: `ghcr.io/shift7-ch/katta-server:982baf0-amd64`

Images are cached in ECR with the prefix `<workspace>-ghcr/` and pulled automatically when ECS tasks start.

## TODOs

- [_] understand/document ECS/ECR model - lb/tg etc.
- [_] costs vpc - is it pulling of images or running idle?
- [ ] hub should wait for keycloak to be ready - need manual re-deployment for now
- [_] test admin cli
- [_] hub_keycloak_system_client_secret= "TODO"
- [_] hub_keycloak_oidc_cryptomator_vaults_client_secret= "TODO"

## Differences to k8s setup

- no URL paths `/kc` for Keycloak and `/<realm>/` for hub instances
- non-shared Keycloak
- default realm

## Troubleshooting

```shell
aws logs tail keycloak-default-hub --output text --since 30s --follow
aws logs tail keycloak-default-keycloak --output text --since 30s --follow
```

