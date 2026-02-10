# katta-terraform

## TL;DR;

https://developer.hashicorp.com/terraform/cli/run

Sets up hub under the following URLs - change terraform workspace to control the infix `<your-workspace>`:
* `https://hub.<your-workspace> .catta.cloud/`
* `https://keycloak.<your-workspace> .catta.cloud/`


```shell
cp terraform.tfvars{.template,}
vi terraform.tfvars # enter passwords

terraform workspace list
# terraform workspace new <your-workspace> 

terraform init
terraform validate
terraform plan

export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...

terraform apply --auto-approve 
# preconditions from leftovers previous run: 
# - rename secret names (they have a minimum grace period of 7 days before deletion)
terraform destroy --auto-approve 
```

## Sources

#### Terraform Keycloak ECS

https://www.dorokhovich.com/blog/deploying-keycloak-aws-ecs-fargate-terraform -> https://github.com/metronom72/keycloak_deployment/tree/main/infra

https://medium.com/@yakuphanbilgic3/how-to-install-keycloak-on-aws-using-rds-and-ec2-74081dd42457

https://www.geeksforgeeks.org/devops/create-aws-vpc-using-terraform/
https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest

https://exchangetuts.com/index.php/terraform-fargate-task-definition-requesting-execution-role-1639735450945343

https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html

https://repost.aws/knowledge-center/ecs-task-stopped

#### Certs

https://repost.aws/knowledge-center/acm-certificate-pending-validation
https://dev.to/aws-builders/how-to-set-up-a-public-hosted-zone-on-amazon-route-53-when-your-domain-is-registered-with-another-584j
https://stackoverflow.com/questions/68177630/aws-acm-certificate-state-is-pending-validation-and-not-changing-to-issues

```shell
dig NS default keycloak.default.catta.cloud
dig keycloak.default.catta.cloud @8.8.4.4  
nc .... 5432

# https://apple.stackexchange.com/questions/472013/how-to-check-status-of-dns-resolution-service-and-or-restart-in-macos
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

#### ECR / ECS

https://dev.to/oncloud7/from-docker-to-aws-step-by-step-guide-push-to-ecr-and-deploy-on-ecs-3l78
https://dev.to/a-k-0047/understanding-ecs-what-are-clusters-services-and-tasks-38eo

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

- [-] try out ghcr.io upstream registry -> needs authentication https://docs.aws.amazon.com/AmazonECR/latest/userguide/pull-through-cache-creating-rule.html
- [_] understand/document ECS/ECR model - lb/tg etc.
- [_] costs vpc - is it pulling of images or running idle?
- [ ] hub should wait for keycloak to be ready - need manual re-deployment for now
- [_] test admin cli

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

