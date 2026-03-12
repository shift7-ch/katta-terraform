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
    export AWS_USE_DUALSTACK_ENDPOINT=false
    ```

## Deployment

1. Setup Terraform Workspace
    ```shell
    terraform workspace new katta
    ```

2. Override default Terraform configuration

   Defaults can be found in `terraform.tfvars.template`. Either copy to `terraform.tfvars` (not under version control) or overridden by environment variables:

    ```shell
    export TF_VAR_region=$AWS_DEFAULT_REGION
    export TF_VAR_dns_suffix=example.net
    export TF_VAR_keycloak_db_password=
    export TF_VAR_keycloak_admin_password=
    export TF_VAR_hub_db_password=
    export TF_VAR_hub_keycloak_system_client_secret=top-secret
    export TF_VAR_hub_keycloak_oidc_cryptomator_vaults_client_secret=top-secret
    ```
3. Add hosted zone for domain in AWS Route53 if missing:

    ```shell
    aws route53 create-hosted-zone --name $TF_VAR_dns_suffix --caller-reference $(date +%s)
    ```

   **Warning**: For domain validation to work in AWS Certificate Manager you must ensure the name servers set in the
   hosted zone match the name servers set in the domain registrar. This also applies to domains managed in Route53.

4. Add GitHub Personal Access Token

    - AWS ECR pull-through cache requires authentication even for public GitHub Container Registry repositories.
    - Create a GitHub Personal Access Token with `read:packages` permission using `gh` CLI:

   ```shell
   # Create a new token specifically for this:
   gh auth login --scopes read:packages
   ```

    - Then add the token to environment:

   ```shell
   export TF_VAR_github_token=$(gh auth token)
   ```

   Alternatively, create manually via GitHub web UI:
    - Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
    - Generate new token with `read:packages` scope
    - Add to `terraform.tfvars`: `github_token = "ghp_your_token_here"`

5. Validate environment

    ```shell
    terraform init
    terraform validate
    terraform plan
    ```

6. Deploy environment

    ```shell
    terraform apply --auto-approve
    ```

7.Login in Web Browser

* Open `https://hub.<workspace>.<dns_suffix>` in browser to login to _Katta Hub_ with
  the [default credentials](https://github.com/shift7-ch/katta-clientlib?tab=readme-ov-file#users) with `admin` role.
* Open `https://keycloak.<workspace>.<dns_suffix>` in browser to login to _Katta Keycloak_ with the admin user (default
  `keycloak_admin`) and password as `$TF_VAR_keycloak_admin_password`.

## Cleanup

Preconditions from leftovers previous run: Rename secret names, they have a minimum grace period of 7 days before
deletion.

1. Destroy environment
    ```shell
    terraform destroy --auto-approve
    ```

## Background

### ECR Pull-Through Cache

Container images are automatically pulled from GitHub Container Registry (ghcr.io) via Amazon ECR pull-through cache
rules. This eliminates the need to manually pull and push images to ECR.

- Keycloak: `ghcr.io/cryptomator/keycloak:26.4.5`
- Katta Hub: `ghcr.io/shift7-ch/katta-server:982baf0-amd64`

Images are cached in ECR with the prefix `<workspace>-ghcr/` and pulled automatically when ECS tasks start.

## Differences to k8s setup

- no URL paths `/kc` for Keycloak and `/<realm>/` for hub instances
- non-shared Keycloak
- default realm

## Troubleshooting

```shell
aws logs tail `terraform workspace show`-hub-log-group --output text --since 30s --follow
aws logs tail `terraform workspace show`-keycloak-log-group --output text --since 30s --follow
```

## Debugging

Enable execute command with variable `ecs_enable_execute_command`.

```shell
# TF_VAR_region
WORKSPACE=$(terraform workspace show)
# inspect services
aws ecs describe-services --region ${TF_VAR_region} --cluster ${WORKSPACE}-cluster --service ${WORKSPACE}-keycloak-ecs-service
aws ecs describe-services --region ${TF_VAR_region} --cluster ${WORKSPACE}-cluster --service ${WORKSPACE}-hub-ecs-service
# list task
aws ecs list-tasks --region ${TF_VAR_region} --cluster ${WORKSPACE}-cluster
#{
#    "taskArns": [
#        "arn:aws:ecs:eu-central-1:430118840017:task/che-cluster/8bd3030e916a47e08cd579bc70009737",
#        "arn:aws:ecs:eu-central-1:430118840017:task/che-cluster/fb33d05b480f4cc19cb4299190b916d5"
#    ]
#}
# inspect tasks
aws ecs describe-tasks --region ${TF_VAR_region} --cluster ${WORKSPACE}-cluster --task 8bd3030e916a47e08cd579bc70009737 
aws ecs describe-tasks --region ${TF_VAR_region} --cluster ${WORKSPACE}-cluster --task fb33d05b480f4cc19cb4299190b916d5 
# debug containers:
aws ecs execute-command \
--region ${TF_VAR_region} \
--cluster ${WORKSPACE}-cluster \
--task fb33d05b480f4cc19cb4299190b916d5 \
--container che-container-keycloak \
--interactive \
--command "/bin/sh"
aws ecs execute-command \
--region ${TF_VAR_region} \
--cluster che-cluster \
--task 8bd3030e916a47e08cd579bc70009737 \
--container ${WORKSPACE}-container-hub \
--interactive \
--command "/bin/sh"
```