# ECS runs the three containers that docker-compose runs locally:
# Caddy gateway, Next.js frontend, and Convex backend.

resource "aws_ecs_cluster" "this" {
  name = local.name # ECS cluster name.

  setting {
    # Container Insights adds useful CPU/memory/network metrics. Disable if you
    # want to reduce CloudWatch costs.
    name  = "containerInsights" # ECS setting key.
    value = "enabled"           # Enables CloudWatch Container Insights.
  }
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${local.name}"     # Log group used by all app containers.
  retention_in_days = var.log_retention_days   # Automatically deletes older logs.
}

resource "aws_ecs_task_definition" "app" {
  family = local.name # Task definition family name.

  # Fargate requires awsvpc networking. Each task gets its own elastic network
  # interface and security groups.
  network_mode = "awsvpc" # Required for Fargate; each task gets its own ENI.

  # Fargate is the serverless ECS launch type. Alternative: EC2 launch type if
  # you want to manage instances and use EBS directly.
  requires_compatibilities = ["FARGATE"] # Restricts task definition to Fargate.

  cpu    = var.ecs_cpu    # Fargate CPU units for the whole task.
  memory = var.ecs_memory # Fargate memory in MiB for the whole task.

  execution_role_arn = aws_iam_role.task_execution.arn # Lets ECS pull images and write logs.
  task_role_arn      = aws_iam_role.task.arn           # Runtime role available to containers.

  # This named volume is mounted into only the Convex backend container.
  volume {
    name = "convex-data" # Volume name referenced by backend mountPoints.

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.convex_data.id # EFS filesystem backing the volume.
      transit_encryption = "ENABLED"                          # Encrypts NFS traffic in transit.

      authorization_config {
        access_point_id = aws_efs_access_point.convex_data.id # Restricts mount to the Convex data path.
        iam             = "ENABLED"                           # Requires task IAM permission to mount.
      }
    }
  }

  container_definitions = jsonencode([
    {
      name      = "caddy"       # Container name referenced by ECS service load_balancer block.
      image     = var.caddy_image # ECR image URI for custom Caddy image.
      essential = true          # If Caddy exits, ECS replaces the task.

      # ALB targets this container port. In ECS task definitions this is not
      # written as 8080:8080 like Compose; containerPort is what ALB reaches.
      portMappings = [
        {
          containerPort = 8080 # Caddy listens here; ALB forwards here.
          protocol      = "tcp" # HTTP runs over TCP.
        }
      ]

      logConfiguration = {
        logDriver = "awslogs" # Sends container logs to CloudWatch Logs.
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name # Destination log group.
          awslogs-region        = var.aws_region                    # Log group region.
          awslogs-stream-prefix = "caddy"                           # Prefix for log stream names.
        }
      }
    },
    {
      name      = "frontend"       # Next.js app container name.
      image     = var.frontend_image # ECR image URI for frontend image.
      essential = true             # If frontend exits, ECS replaces the task.

      portMappings = [
        {
          containerPort = 3000 # Next.js standalone server port.
          protocol      = "tcp" # HTTP runs over TCP.
        }
      ]

      environment = [
        { name = "NODE_ENV", value = "production" },                                      # Runs Next.js in production mode.
        { name = "CONVEX_URL_INTERNAL", value = "http://127.0.0.1:3210" },                # Server-side frontend calls Convex backend inside the task.
        { name = "CONVEX_SITE_URL_INTERNAL", value = "http://127.0.0.1:3211" },           # Server-side frontend calls Convex site/auth inside the task.
        { name = "NEXT_PUBLIC_SITE_URL", value = local.public_site_url },                 # Browser-facing app URL.
        { name = "NEXT_PUBLIC_CONVEX_URL", value = local.public_convex_url },             # Browser-facing Convex API/websocket URL.
        { name = "NEXT_PUBLIC_CONVEX_SITE_URL", value = local.public_convex_site_url },   # Browser-facing Convex site URL.
        { name = "NEXT_PUBLIC_AUTH_URL", value = local.public_auth_url }                  # Browser-facing BetterAuth base URL.
      ]

      logConfiguration = {
        logDriver = "awslogs" # Sends container logs to CloudWatch Logs.
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name # Destination log group.
          awslogs-region        = var.aws_region                    # Log group region.
          awslogs-stream-prefix = "frontend"                        # Prefix for log stream names.
        }
      }
    },
    {
      name      = "backend"       # Convex backend container name.
      image     = var.convex_backend_image # ECR image URI for mirrored Convex backend.
      essential = true            # If Convex exits, ECS replaces the task.

      portMappings = [
        {
          containerPort = 3210 # Convex backend API/websocket port.
          protocol      = "tcp" # HTTP/websocket runs over TCP.
        },
        {
          containerPort = 3211 # Convex site/auth HTTP actions port.
          protocol      = "tcp" # HTTP runs over TCP.
        }
      ]

      environment = [
        { name = "CONVEX_CLOUD_ORIGIN", value = local.public_convex_url },     # Public URL Convex advertises for client/backend traffic.
        { name = "CONVEX_SITE_ORIGIN", value = "http://127.0.0.1:3211" },      # Internal site URL Convex uses for auth/JWKS.
        { name = "DISABLE_METRICS_ENDPOINT", value = "true" },                 # Disables Convex metrics endpoint exposure.
        # Keep this true while TLS terminates at ALB and HTTP is used inside the
        # task. Revisit only after confirming Convex behavior behind proxy TLS.
        { name = "DO_NOT_REQUIRE_SSL", value = "true" },                       # Allows HTTP inside the ALB-terminated TLS boundary.
        { name = "RUST_LOG", value = "info" }                                  # Convex backend log verbosity.
      ]

      mountPoints = [
        {
          sourceVolume  = "convex-data" # Task volume name defined above.
          containerPath = "/convex/data" # Convex data/deployment state path.
          readOnly      = false          # Convex must write data, env, and deployed functions.
        }
      ]

      logConfiguration = {
        logDriver = "awslogs" # Sends container logs to CloudWatch Logs.
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs.name # Destination log group.
          awslogs-region        = var.aws_region                    # Log group region.
          awslogs-stream-prefix = "backend"                         # Prefix for log stream names.
        }
      }
    }
  ])

  depends_on = [
    aws_efs_mount_target.convex_data # Ensures EFS mount targets exist before task registration/use.
  ]
}

resource "aws_ecs_service" "app" {
  name            = local.name                    # ECS service name.
  cluster         = aws_ecs_cluster.this.id       # Cluster this service runs in.
  task_definition = aws_ecs_task_definition.app.arn # Task definition revision to run.
  desired_count   = var.desired_count             # Number of running tasks; keep 1 for Convex.
  launch_type     = "FARGATE"                     # Serverless ECS compute.

  # Allows `aws ecs execute-command` for admin key generation and debugging.
  enable_execute_command = var.enable_ecs_exec # Enables ECS Exec when true.

  # Self-hosted Convex is single-node here. Avoid running old and new tasks at
  # the same time against separate local state during deployments.
  deployment_minimum_healthy_percent = 0   # Allows stopping old task before starting new one.
  deployment_maximum_percent         = 100 # Prevents extra concurrent replacement task.

  network_configuration {
    subnets          = var.private_subnet_ids          # Private subnets for task ENIs.
    security_groups  = [aws_security_group.ecs_tasks.id] # Security group attached to task ENIs.
    assign_public_ip = false                           # Keeps tasks private behind ALB.
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn # ALB target group for this service.
    container_name   = "caddy"                     # Container receiving ALB traffic.
    container_port   = 8080                        # Caddy port registered as ALB target.
  }

  depends_on = [
    aws_lb_listener_rule.scrum # Ensures listener rule exists before service registration.
  ]
}
