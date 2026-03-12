resource "aws_ecr_pull_through_cache_rule" "github" {
  ecr_repository_prefix = "${terraform.workspace}-ghcr"
  upstream_registry_url = "ghcr.io"
  credential_arn        = aws_secretsmanager_secret.github_token.arn

  depends_on = [aws_secretsmanager_secret_version.github_token]
}

# Pre-populate ECR pull through cache to ensure images are available before ECS service starts
resource "null_resource" "prepopulate_ecr_cache" {
  # Trigger on changes to image versions or cache rule
  triggers = {
    keycloak_image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${terraform.workspace}-ghcr/cryptomator/keycloak:${var.keycloak_version}"
    hub_image      = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${terraform.workspace}-ghcr/shift7-ch/katta-server:${var.hub_version}"
    cache_rule     = aws_ecr_pull_through_cache_rule.github.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Authenticating with ECR..."
      aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com

      echo "Pre-pulling Keycloak image to populate ECR cache..."
      docker pull ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${terraform.workspace}-ghcr/cryptomator/keycloak:${var.keycloak_version} || echo "Failed to pull Keycloak image, cache may populate on first ECS task start"

      echo "Pre-pulling Hub image to populate ECR cache..."
      docker pull ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${terraform.workspace}-ghcr/shift7-ch/katta-server:${var.hub_version} || echo "Failed to pull Hub image, cache may populate on first ECS task start"

      echo "ECR cache pre-population complete"
    EOT
  }

  depends_on = [
    aws_ecr_pull_through_cache_rule.github,
    aws_secretsmanager_secret_version.github_token
  ]
}

resource "aws_security_group" "ecs_cluster_sg" {
  name        = "${terraform.workspace}-ecs_cluster_sg"
  description = "Security group for ECS cluster in private subnets"
  vpc_id      = aws_vpc.katta.id

  ingress {
    description = "Allow communication within ECS tasks"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${terraform.workspace}-ecs_cluster_sg"
    Project     = var.project
    Environment = terraform.workspace
  }
}

resource "aws_ecs_cluster" "katta_ecs_cluster" {
  name = "${terraform.workspace}-cluster"

  tags = {
    Name        = "${terraform.workspace}-ecs-cluster"
    Project     = var.project
    Environment = terraform.workspace
  }
}

resource "aws_cloudwatch_log_group" "keycloak_log_group" {
  name = "${terraform.workspace}-${var.keycloak_prefix}-log-group"

  tags = {
    Name        = "${terraform.workspace}-${var.keycloak_prefix}-log-group"
    Project     = var.project
    Environment = terraform.workspace
  }
}

resource "aws_cloudwatch_log_group" "hub_log_group" {
  name = "${terraform.workspace}-${var.hub_prefix}-log-group"

  tags = {
    Name        = "${terraform.workspace}-${var.hub_prefix}-log-group"
    Project     = var.project
    Environment = terraform.workspace
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition
resource "aws_ecs_task_definition" "keycloak_ecs_task" {
  family = "${var.keycloak_prefix}-task"

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = "2048"
  cpu                      = "1024"
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
  task_role_arn            = aws_iam_role.ecsTaskExecutionRole.arn

  container_definitions = jsonencode([
    {
      name       = "${terraform.workspace}-container-${var.keycloak_prefix}",
      image      = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${terraform.workspace}-ghcr/cryptomator/keycloak:${var.keycloak_version}"
      entryPoint = ["/bin/sh"]
      command = [
        "-c",
        join("", [
          "mkdir -p /opt/keycloak/data/import/ && ",
          "echo $CRYPTOMATOR_REALM_JSON | base64 -d > /opt/keycloak/data/import/cryptomator-realm.json && ",
          "/opt/keycloak/bin/kc.sh start --http-access-log-enabled=true --log-level=DEBUG --import-realm"
        ])
      ]
      # requests:
      # cpu: 25m
      # memory: 256Mi
      # limits:
      # cpu: 1000m
      # memory: 1024Mi
      memory    = 2048
      cpu       = 1024
      essential = true
      portMappings = [
        {
          containerPort = 8443
          protocol      = "tcp"
        },
        {
          containerPort = 8080
          protocol      = "tcp"
        },
        {
          containerPort = 9000
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "CRYPTOMATOR_REALM_JSON"
          value = local.cryptomator_realm_base64
        },
        {
          name  = "KC_DB"
          value = "postgres"
        },
        {
          name  = "KC_DB_URL"
          value = "jdbc:postgresql://${aws_db_instance.postgres.endpoint}/${var.keycloak_db_name}"
        },
        {
          name  = "DB_DATABASE"
          value = var.keycloak_db_name
        },
        {
          name  = "KC_HEALTH_ENABLED"
          value = "true"
        },
        {
          name  = "KC_METRICS_ENABLED"
          value = "true"
        },
        {
          name  = "KC_HOSTNAME"
          value = "${var.keycloak_prefix}.${terraform.workspace}.${var.dns_suffix}"
        },
        {
          name  = "KC_HTTP_ENABLED"
          value = "true"
        },
        {
          name  = "KC_PROXY_HEADERS"
          value = "xforwarded"
        }
      ]
      secrets = [
        {
          name      = "KEYCLOAK_ADMIN"
          valueFrom = "${aws_secretsmanager_secret.keycloak_admin.arn}:username::"
        },
        {
          name      = "KEYCLOAK_ADMIN_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.keycloak_admin.arn}:password::"
        },
        {
          name      = "KC_DB_USERNAME"
          valueFrom = "${aws_secretsmanager_secret.keycloak_db_credentials.arn}:username::"
        },
        {
          name      = "KC_DB_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.keycloak_db_credentials.arn}:password::"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.keycloak_log_group.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "keycloak"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "curl -v --fail http://localhost:9000/health"]
        interval    = 30
        timeout     = 5
        retries     = 5
        startPeriod = 120
      },
      linuxParameters = {
        initProcessEnabled = var.ecs_enable_execute_command
      }
    }
  ])

  tags = {
    Name        = "${terraform.workspace}-ecs-task"
    Project     = var.project
    Environment = terraform.workspace
  }

  depends_on = [null_resource.prepopulate_ecr_cache]
}

resource "aws_ecs_service" "keycloak_ecs_service" {
  name                   = "${terraform.workspace}-${var.keycloak_prefix}-ecs-service"
  cluster                = aws_ecs_cluster.katta_ecs_cluster.id
  task_definition        = "${aws_ecs_task_definition.keycloak_ecs_task.family}:${max(aws_ecs_task_definition.keycloak_ecs_task.revision, data.aws_ecs_task_definition.keycloak.revision)}"
  launch_type            = "FARGATE"
  scheduling_strategy    = "REPLICA"
  desired_count          = 1
  force_new_deployment   = true
  enable_execute_command = var.ecs_enable_execute_command
  wait_for_steady_state  = true

  health_check_grace_period_seconds = 300

  availability_zone_rebalancing = "ENABLED"
  propagate_tags                = "TASK_DEFINITION"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets = aws_subnet.private.*.id
    // public ip required to reach github via public DNS/IP to download realm
    assign_public_ip = true
    security_groups = [
      aws_security_group.ecs_cluster_sg.id,
    ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.keycloak_ecs_target_group.arn
    container_name   = "${terraform.workspace}-container-${var.keycloak_prefix}"
    container_port   = 8080
  }

  tags = {
    Name        = "${terraform.workspace}-ecs-task"
    Project     = var.project
    Environment = terraform.workspace
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition
resource "aws_ecs_task_definition" "katta_server_ecs_task" {
  family = "${var.hub_prefix}-task"

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  # https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html
  # resources:
  #   requests:
  #   cpu: 25m
  # memory: 128Mi
  # limits:
  # cpu: 1000m
  # memory: 512Mi
  memory             = "512"
  cpu                = "256"
  execution_role_arn = aws_iam_role.ecsTaskExecutionRole.arn
  task_role_arn      = aws_iam_role.ecsTaskExecutionRole.arn

  container_definitions = jsonencode([
    {
      name  = "${terraform.workspace}-container-${var.hub_prefix}",
      image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${terraform.workspace}-ghcr/shift7-ch/katta-server:${var.hub_version}"
      # command = ["start", "--http-access-log-enabled=true", "--log-level=DEBUG"]
      memory    = 512
      cpu       = 256
      essential = true
      portMappings = [
        {
          containerPort = 8280
          protocol      = "tcp"
        },
      ]
      environment = [
        {
          name  = "HUB_KEYCLOAK_LOCAL_URL"
          value = "https://${var.keycloak_prefix}.${terraform.workspace}.${var.dns_suffix}"
        },
        {
          name  = "HUB_KEYCLOAK_PUBLIC_URL"
          value = "https://${var.keycloak_prefix}.${terraform.workspace}.${var.dns_suffix}"
        },
        {
          name  = "HUB_KEYCLOAK_REALM"
          value = "cryptomator"
        },
        {
          name  = "HUB_KEYCLOAK_SYSTEM_CLIENT_ID"
          value = "cryptomatorhub-system"
        },
        {
          name  = "HUB_KEYCLOAK_SYNCER_PERIOD"
          value = "30s"
        },
        {
          name  = "HUB_KEYCLOAK_OIDC_CRYPTOMATOR_CLIENT_ID"
          value = "cryptomator"
        },
        {
          name  = "HUB_PUBLIC_ROOT_PATH"
          value = "/"
        },
        {
          name  = "QUARKUS_HTTP_PORT"
          value = "8280"
        },
        {
          name  = "QUARKUS_OIDC_AUTH_SERVER_URL"
          value = "https://${var.keycloak_prefix}.${terraform.workspace}.${var.dns_suffix}/realms/cryptomator"
        },
        {
          name  = "QUARKUS_OIDC_TOKEN_ISSUER"
          value = "https://${var.keycloak_prefix}.${terraform.workspace}.${var.dns_suffix}/realms/cryptomator"
        },
        {
          name  = "QUARKUS_OIDC_CLIENT_ID"
          value = "cryptomatorhub"
        },
        {
          name  = "QUARKUS_DATASOURCE_JDBC_URL"
          value = "jdbc:postgresql://${aws_db_instance.hub_db.endpoint}/${var.hub_db_name}"
        },
        {
          name  = "QUARKUS_HTTP_HEADER__CONTENT_SECURITY_POLICY__VALUE"
          value = "value: default-src 'self'; connect-src 'self' *.amazonaws.com https://${var.keycloak_prefix}.${terraform.workspace}.${var.dns_suffix}/; object-src 'none'; child-src 'self'; img-src * data:; frame-ancestors 'none'"
        },
      ]
      secrets = [
        {
          name      = "QUARKUS_DATASOURCE_USERNAME"
          valueFrom = "${aws_secretsmanager_secret.hub_db_credentials.arn}:username::"
        },
        {
          name      = "QUARKUS_DATASOURCE_PASSWORD"
          valueFrom = "${aws_secretsmanager_secret.hub_db_credentials.arn}:password::"
        },
        {
          name      = "hub_keycloak_system_client_secret"
          valueFrom = "${aws_secretsmanager_secret.hub_oidc_client_secrets_credentials.arn}:hub_keycloak_system_client_secret::"
        },
        {
          name      = "hub_keycloak_oidc_cryptomator_vaults_client_secret"
          valueFrom = "${aws_secretsmanager_secret.hub_oidc_client_secrets_credentials.arn}:hub_keycloak_oidc_cryptomator_vaults_client_secret::"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.hub_log_group.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "hub"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "curl -v --fail http://localhost:8280/q/health/ready"]
        interval    = 10
        timeout     = 5
        retries     = 3
        startPeriod = 30
      },
      linuxParameters = {
        initProcessEnabled = var.ecs_enable_execute_command
      }
    }
  ])

  tags = {
    Name        = "${terraform.workspace}-ecs-task"
    Project     = var.project
    Environment = terraform.workspace
  }
  depends_on = [
    null_resource.prepopulate_ecr_cache,
    aws_ecs_service.keycloak_ecs_service
  ]
}

resource "aws_ecs_service" "katta_server_ecs_service" {
  name                   = "${terraform.workspace}-${var.hub_prefix}-ecs-service"
  cluster                = aws_ecs_cluster.katta_ecs_cluster.id
  task_definition        = "${aws_ecs_task_definition.katta_server_ecs_task.family}:${max(aws_ecs_task_definition.katta_server_ecs_task.revision, data.aws_ecs_task_definition.katta_server.revision)}"
  launch_type            = "FARGATE"
  scheduling_strategy    = "REPLICA"
  desired_count          = 1
  force_new_deployment   = true
  enable_execute_command = var.ecs_enable_execute_command
  wait_for_steady_state  = true

  health_check_grace_period_seconds = 60

  availability_zone_rebalancing = "ENABLED"
  propagate_tags                = "TASK_DEFINITION"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets = aws_subnet.private.*.id
    // public ip required to reach keycloak via public DNS/IP
    assign_public_ip = true
    security_groups = [
      aws_security_group.ecs_cluster_sg.id,
    ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.hub_ecs_target_group.arn
    container_name   = "${terraform.workspace}-container-${var.hub_prefix}"
    container_port   = 8280
  }

  tags = {
    Name        = "${terraform.workspace}-ecs-task"
    Project     = var.project
    Environment = terraform.workspace
  }

  depends_on = [aws_ecs_service.keycloak_ecs_service]
}

resource "aws_security_group" "vpc_endpoint_sg" {
  name   = "${terraform.workspace}-vpc-endpoint-sg"
  vpc_id = aws_vpc.katta.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_cluster_sg.id]
  }

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_cluster_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${terraform.workspace}-vpc-endpoint-sg"
    Project     = var.project
    Environment = terraform.workspace
  }
}

resource "aws_appautoscaling_target" "ecs_autoscaling_target" {
  min_capacity       = 1
  max_capacity       = 12
  resource_id        = "service/${aws_ecs_cluster.katta_ecs_cluster.name}/${aws_ecs_service.keycloak_ecs_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  role_arn = aws_iam_role.app_autoscaling_role.arn
}

resource "aws_appautoscaling_policy" "cpu_scaling_policy" {
  name               = "cpu-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_autoscaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_autoscaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_autoscaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = 60.0 # Target CPU utilization percentage
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "memory_scaling_policy" {
  name               = "memory-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_autoscaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_autoscaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_autoscaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value       = 70.0 # Target Memory utilization percentage
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}

resource "aws_appautoscaling_policy" "request_scaling_policy" {
  name               = "request-scaling-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_autoscaling_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_autoscaling_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_autoscaling_target.service_namespace

  target_tracking_scaling_policy_configuration {
    customized_metric_specification {
      metric_name = "RequestCountPerTarget"
      namespace   = "AWS/ApplicationELB"
      statistic   = "Sum"
      dimensions {
        name  = "LoadBalancer"
        value = aws_lb.keycloak_public_alb.name
      }

      dimensions {
        name  = "TargetGroup"
        value = aws_lb_target_group.keycloak_ecs_target_group.name
      }
      unit = "Count"
    }

    target_value       = 300
    scale_in_cooldown  = 60
    scale_out_cooldown = 60
  }
}
