# Existing ALB integration. This module does not create the ALB or certificate;
# it adds a target group and a path rule to an existing HTTPS listener.

resource "aws_lb_target_group" "app" {
  name = substr("${local.name}-tg", 0, 32) # Target group names have a 32-character limit.

  vpc_id = var.vpc_id # VPC where ECS task IP targets live.

  # ALB forwards to the Caddy container. Caddy then routes to frontend/Convex.
  port     = 8080  # Caddy container port receiving ALB traffic.
  protocol = "HTTP" # ALB terminates HTTPS before forwarding HTTP to ECS.

  # Fargate tasks use awsvpc ENIs, so target type must be ip.
  target_type = "ip" # Required for Fargate/awsvpc tasks.

  health_check {
    enabled = true       # Enables ALB health checks.
    path    = "/healthz" # Caddy health endpoint.

    # Alternatives: use /scrum for an end-to-end frontend health check, but
    # that makes ALB health depend on Next.js rendering. /healthz isolates
    # target health to the Caddy gateway being alive.
    matcher             = "200" # HTTP status code considered healthy.
    interval            = 30    # Seconds between health checks.
    timeout             = 5     # Seconds to wait before a check times out.
    healthy_threshold   = 2     # Consecutive passes before target is healthy.
    unhealthy_threshold = 3     # Consecutive failures before target is unhealthy.
  }
}

resource "aws_lb_listener_rule" "scrum" {
  listener_arn = var.alb_listener_arn      # Existing ALB HTTPS listener to attach this rule to.
  priority     = var.listener_rule_priority # Must be unique on the listener.

  action {
    type             = "forward"                 # Forward matching requests to the target group.
    target_group_arn = aws_lb_target_group.app.arn # Target group containing ECS Caddy tasks.
  }

  condition {
    path_pattern {
      values = [
        var.path_prefix,       # Matches /scrum exactly.
        "${var.path_prefix}/*", # Matches /scrum/... paths.
      ]
    }
  }
}
