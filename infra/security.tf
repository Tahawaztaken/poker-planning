# ECS task security group. With awsvpc networking, each task gets an ENI and
# this security group applies directly to that ENI.
resource "aws_security_group" "ecs_tasks" {
  name        = "${local.name}-ecs-tasks"                         # Security group name for ECS task ENIs.
  description = "Allow ALB to reach Caddy and allow outbound traffic" # Shows purpose in AWS console.
  vpc_id      = var.vpc_id                                       # VPC where the ECS task runs.

  ingress {
    description     = "ALB to Caddy"                  # Human-readable rule purpose.
    from_port       = 8080                            # First allowed destination port.
    to_port         = 8080                            # Last allowed destination port.
    protocol        = "tcp"                           # HTTP traffic from ALB uses TCP.
    security_groups = [var.alb_security_group_id]     # Only the ALB security group can call Caddy.
  }

  # The task needs outbound HTTPS for ECR image pulls, CloudWatch logs, and
  # AWS APIs. If your private subnets do not have NAT, add VPC endpoints for
  # ECR, CloudWatch Logs, S3, and SSM/ECS Exec.
  egress {
    description = "Outbound"      # Human-readable rule purpose.
    from_port   = 0               # Ignored when protocol is -1.
    to_port     = 0               # Ignored when protocol is -1.
    protocol    = "-1"            # Allows all outbound protocols.
    cidr_blocks = ["0.0.0.0/0"]   # Allows outbound traffic to anywhere.
  }
}

# EFS security group allows NFS only from ECS tasks.
resource "aws_security_group" "efs" {
  name        = "${local.name}-efs"       # Security group name for EFS mount targets.
  description = "Allow ECS tasks to mount EFS" # Shows purpose in AWS console.
  vpc_id      = var.vpc_id                # Same VPC as ECS tasks.

  ingress {
    description     = "NFS from ECS tasks"          # Human-readable rule purpose.
    from_port       = 2049                          # NFS port used by EFS.
    to_port         = 2049                          # NFS port used by EFS.
    protocol        = "tcp"                         # EFS/NFS uses TCP.
    security_groups = [aws_security_group.ecs_tasks.id] # Only ECS tasks can mount EFS.
  }

  egress {
    description = "Outbound"      # Human-readable rule purpose.
    from_port   = 0               # Ignored when protocol is -1.
    to_port     = 0               # Ignored when protocol is -1.
    protocol    = "-1"            # Allows all outbound protocols.
    cidr_blocks = ["0.0.0.0/0"]   # Allows outbound traffic to anywhere.
  }
}
