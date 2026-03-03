resource "aws_ecr_pull_through_cache_rule" "quay" {
  ecr_repository_prefix = "${var.project}-${terraform.workspace}-quay"
  upstream_registry_url = "quay.io"
}

resource "aws_ecr_pull_through_cache_rule" "github" {
  ecr_repository_prefix = "${var.project}-${terraform.workspace}-ghcr"
  upstream_registry_url = "ghcr.io"
  credential_arn        = aws_secretsmanager_secret.github_token.arn
}

resource "aws_security_group" "ecs_cluster_sg" {
  name        = "${var.project}-${terraform.workspace}-ecs_cluster_sg"
  description = "Security group for ECS cluster in private subnets"
  vpc_id      = aws_vpc.keycloak.id

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
    Name        = "${var.project}-${terraform.workspace}-ecs_cluster_sg"
    Project     = var.project
    Environment = terraform.workspace
  }
}

resource "aws_ecs_cluster" "katta_ecs_cluster" {
  name = "${var.project}-${terraform.workspace}-cluster"

  tags = {
    Name        = "${var.project}-${terraform.workspace}-ecs-cluster"
    Project     = var.project
    Environment = terraform.workspace
  }
}

resource "aws_cloudwatch_log_group" "keycloak_log_group" {
  name = "${var.project}-${terraform.workspace}-${var.keycloak_prefix}-log-group"

  tags = {
    Name        = "${var.project}-${terraform.workspace}-${var.keycloak_prefix}-log-group"
    Project     = var.project
    Environment = terraform.workspace
  }
}

resource "aws_cloudwatch_log_group" "hub_log_group" {
  name = "${var.project}-${terraform.workspace}-${var.hub_prefix}-log-group"

  tags = {
    Name        = "${var.project}-${terraform.workspace}-${var.hub_prefix}-log-group"
    Project     = var.project
    Environment = terraform.workspace
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition
resource "aws_ecs_task_definition" "keycloak_ecs_task" {
  family = "${var.keycloak_prefix}-task"

  requires_compatibilities = ["FARGATE"]
  network_mode       = "awsvpc"
  memory             = "2048"
  cpu                = "1024"
  execution_role_arn = aws_iam_role.ecsTaskExecutionRole.arn
  task_role_arn      = aws_iam_role.ecsTaskExecutionRole.arn

  container_definitions = jsonencode([
    {
      name  = "${var.project}-${terraform.workspace}-container-${var.keycloak_prefix}",
      image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.project}-${terraform.workspace}-ghcr/cryptomator/keycloak:26.4.5"
      entryPoint = ["/bin/sh"]
      command = [
        "-c",
        join("", [
          "mkdir -p /opt/keycloak/data/import/  && ",
          "curl https://raw.githubusercontent.com/shift7-ch/katta-server/refs/heads/feature/cipherduck-uvf/backend/src/main/resources/cryptomator-realm.json -o  /opt/keycloak/data/import/cryptomator-realm.json  && ",
          "sed -i 's|\"redirectUris\": \\[|\"redirectUris\": \\[\"${var.keycloak_action_redirect}\",\"https://${var.hub_prefix}.${terraform.workspace}.${var.dns_suffix}/*\",|g' /opt/keycloak/data/import/cryptomator-realm.json && ",
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
        command = ["CMD-SHELL", "curl --head -fsS https://localhost:9000/health >> /var/log/keycloak-health.log 2>&1 || exit 0"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 240
      }
    }
  ])

  tags = {
    Name        = "${var.project}-${terraform.workspace}-ecs-task"
    Project     = var.project
    Environment = terraform.workspace
  }
}

resource "aws_ecs_service" "keycloak_ecs_service" {
  name                 = "${var.project}-${terraform.workspace}-${var.keycloak_prefix}-ecs-service"
  cluster              = aws_ecs_cluster.katta_ecs_cluster.id
  task_definition      = "${aws_ecs_task_definition.keycloak_ecs_task.family}:${max(aws_ecs_task_definition.keycloak_ecs_task.revision, data.aws_ecs_task_definition.keycloak.revision)}"
  launch_type          = "FARGATE"
  scheduling_strategy  = "REPLICA"
  desired_count        = 1
  force_new_deployment = true

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
    container_name   = "${var.project}-${terraform.workspace}-container-${var.keycloak_prefix}"
    container_port   = 8080
  }

  tags = {
    Name        = "${var.project}-${terraform.workspace}-ecs-task"
    Project     = var.project
    Environment = terraform.workspace
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition
resource "aws_ecs_task_definition" "katta_server_ecs_task" {
  family = "${var.hub_prefix}-task"

  requires_compatibilities = ["FARGATE"]
  network_mode       = "awsvpc"
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
      name      = "${var.project}-${terraform.workspace}-container-${var.hub_prefix}",
      image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.project}-${terraform.workspace}-ghcr/shift7-ch/katta-server:982baf0-amd64"
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
          awslogs-stream-prefix = "keycloak"
        }
      }
      healthCheck = {
        command = ["CMD-SHELL", "curl --head -fsS http://localhost:8280/api/config >> /var/log/katta-server-health.log 2>&1 || exit 0"]
        interval    = 5
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }
    }
  ])

  tags = {
    Name        = "${var.project}-${terraform.workspace}-ecs-task"
    Project     = var.project
    Environment = terraform.workspace
  }
}

resource "aws_ecs_service" "katta_server_ecs_service" {
  name                 = "${var.project}-${terraform.workspace}-${var.hub_prefix}-ecs-service"
  cluster              = aws_ecs_cluster.katta_ecs_cluster.id
  task_definition      = "${aws_ecs_task_definition.katta_server_ecs_task.family}:${max(aws_ecs_task_definition.katta_server_ecs_task.revision, data.aws_ecs_task_definition.katta_server.revision)}"
  launch_type          = "FARGATE"
  scheduling_strategy  = "REPLICA"
  desired_count        = 1
  force_new_deployment = true

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
    container_name   = "${var.project}-${terraform.workspace}-container-${var.hub_prefix}"
    container_port   = 8280
  }

  tags = {
    Name        = "${var.project}-${terraform.workspace}-ecs-task"
    Project     = var.project
    Environment = terraform.workspace
  }
}

resource "aws_security_group" "vpc_endpoint_sg" {
  name   = "${var.project}-${terraform.workspace}-vpc-endpoint-sg"
  vpc_id = aws_vpc.keycloak.id

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    security_groups = [aws_security_group.ecs_cluster_sg.id]
  }

  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    security_groups = [aws_security_group.ecs_cluster_sg.id]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${terraform.workspace}-vpc-endpoint-sg"
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

  role_arn = aws_iam_role.appAutoscalingRole.arn
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

    target_value = 60.0  # Target CPU utilization percentage
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

    target_value = 70.0  # Target Memory utilization percentage
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