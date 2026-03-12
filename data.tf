data "aws_availability_zones" "available" {}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_ecs_task_definition" "keycloak" {
  task_definition = aws_ecs_task_definition.keycloak_ecs_task.family
}

data "aws_ecs_task_definition" "katta_server" {
  task_definition = aws_ecs_task_definition.katta_server_ecs_task.family
}

data "aws_caller_identity" "current" {}

data "aws_route53_zone" "parent_zone" {
  name         = var.dns_suffix
  private_zone = false
}
