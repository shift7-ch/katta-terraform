# Katta: the secure and easy way to work in teams

Katta bring zero-config storage management and zero-knowledge key management for teams and organizations.

## Katta Terraform

### TL;DR;

> [Terraform workflow for provisioning infrastructure](https://developer.hashicorp.com/terraform/cli/run)

Set up Katta Hub in a custom AWS hosted zone. Change terraform workspace to control the infix `<WORKSPACE>`:

* `https://hub.<WORKSPACE>.<DOMAIN>`
* `https://keycloak.<WORKSPACE>.<DOMAIN>`

### Prerequisites

1. Setup AWS CLI and configure credentials in environment
    ```shell
    export AWS_ACCESS_KEY_ID=...
    export AWS_SECRET_ACCESS_KEY=...
    export AWS_SESSION_TOKEN=...
    ```
2. Add hosted zone `DOMAIN`
    ```shell
    aws route53 create-hosted-zone --name <DOMAIN> --caller-reference $(date +%s)
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

4. Deploy environment

    ```shell
    AWS_USE_DUALSTACK_ENDPOINT=false terraform apply --auto-approve 
    ```

## Cleanup

Preconditions from leftovers previous run: Rename secret names, they have a minimum grace period of 7 days before
deletion.

1. Destroy environment
    ```shell
    terraform apply --auto-approve
    ```

## Sources

### Terraform Keycloak ECS

- https://www.dorokhovich.com/blog/deploying-keycloak-aws-ecs-fargate-terraform -> https://github.com/metronom72/keycloak_deployment/tree/main/infra
- https://medium.com/@yakuphanbilgic3/how-to-install-keycloak-on-aws-using-rds-and-ec2-74081dd42457
- https://www.geeksforgeeks.org/devops/create-aws-vpc-using-terraform/
- https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
- https://exchangetuts.com/index.php/terraform-fargate-task-definition-requesting-execution-role-1639735450945343
- https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html
- https://repost.aws/knowledge-center/ecs-task-stopped

### Certs

- https://repost.aws/knowledge-center/acm-certificate-pending-validation
- https://dev.to/aws-builders/how-to-set-up-a-public-hosted-zone-on-amazon-route-53-when-your-domain-is-registered-with-another-584j
- https://stackoverflow.com/questions/68177630/aws-acm-certificate-state-is-pending-validation-and-not-changing-to-issues

### ECR / ECS

- https://dev.to/oncloud7/from-docker-to-aws-step-by-step-guide-push-to-ecr-and-deploy-on-ecs-3l78
- https://dev.to/a-k-0047/understanding-ecs-what-are-clusters-services-and-tasks-38eo

```shell
aws ecr create-repository --repository-name cryptomator-keycloak --region eu-central-1
```

```shell
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin 430118840017.dkr.ecr.eu-central-1.amazonaws.com/cryptomator-keycloak
# force docker to pull all platforms on MacOS:
docker pull --platform linux/arm64 ghcr.io/cryptomator/keycloak:26.4.5
docker pull --platform linux/amd64 ghcr.io/cryptomator/keycloak:26.4.5
docker pull --platform unknown/unknown ghcr.io/cryptomator/keycloak:26.4.5 
docker tag ghcr.io/cryptomator/keycloak:26.4.5 430118840017.dkr.ecr.eu-central-1.amazonaws.com/cryptomator-keycloak:26.4.5
docker manifest create 430118840017.dkr.ecr.eu-central-1.amazonaws.com/cryptomator-keycloak:26.4.5  430118840017.dkr.ecr.eu-central-1.amazonaws.com/cryptomator-keycloak:26.4.5 --amend 
docker push 430118840017.dkr.ecr.eu-central-1.amazonaws.com/cryptomator-keycloak:26.4.5
```

```shell
aws ecr create-repository --repository-name katta-server --region eu-central-1
```

```shell
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin 430118840017.dkr.ecr.eu-central-1.amazonaws.com/katta-server
docker pull ghcr.io/shift7-ch/katta-server:982baf0-amd64 --platform linux/amd64 
docker tag ghcr.io/shift7-ch/katta-server:982baf0-amd64 430118840017.dkr.ecr.eu-central-1.amazonaws.com/katta-server:982baf0-amd64
docker manifest create 430118840017.dkr.ecr.eu-central-1.amazonaws.com/katta-server:982baf0-amd64  430118840017.dkr.ecr.eu-central-1.amazonaws.com/katta-server:982baf0-amd64 --amend 
docker push 430118840017.dkr.ecr.eu-central-1.amazonaws.com/katta-server:982baf0-amd64
```

## TODOs

- [-] try out ghcr.io upstream registry -> needs
  authentication https://docs.aws.amazon.com/AmazonECR/latest/userguide/pull-through-cache-creating-rule.html
- [_] understand/document ECS/ECR model - lb/tg etc.
- [_] costs vpc - is it pulling of images or running idle?
- [ ] hub should wait for keycloak to be ready - need manual re-deployment for now
- [_] test admin cli
- [_] HUB_KEYCLOAK_SYSTEM_CLIENT_SECRET= "TODO"
- [_] HUB_KEYCLOAK_OIDC_CRYPTOMATOR_VAULTS_CLIENT_SECRET= "TODO"

## Differences to k8s setup

- no URL paths `/kc` for Keycloak and `/<realm>/` for hub instances
- non-shared Keycloak
- default realm

## Troubleshooting

```shell
aws secretsmanager list-secrets --region eu-central-1 --output yaml --include-planned-deletion
aws logs tail keycloak-default-hub --region eu-central-1 --output text --since 30s --follow
aws logs tail keycloak-default-keycloak --region eu-central-1 --output text --since 30s --follow
```

