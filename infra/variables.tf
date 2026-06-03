variable "aws_region" {
  description = "AWS region for all resources, for example us-east-1."
  type        = string # Enforces a single string value.
}

variable "name_prefix" {
  description = "Short name prefix used for resource names."
  type        = string       # Enforces a single string value.
  default     = "scrum-tool" # Default app/resource prefix.
}

variable "environment" {
  description = "Environment label used in names and tags."
  type        = string # Enforces a single string value.
  default     = "prod" # Default environment label.
}

variable "vpc_id" {
  description = "Existing VPC where ECS tasks, ALB target group, and EFS live."
  type        = string # VPC ID, for example vpc-abc123.
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks and EFS mount targets. Use at least two subnets across AZs for normal production resilience."
  type        = list(string) # List of subnet IDs.
}

variable "alb_listener_arn" {
  description = "Existing HTTPS ALB listener ARN. Terraform adds a /scrum* path rule to this listener."
  type        = string # ALB listener ARN.
}

variable "alb_security_group_id" {
  description = "Security group attached to the existing ALB. ECS allows inbound traffic from this group."
  type        = string # Security group ID, for example sg-abc123.
}

variable "domain_name" {
  description = "Browser-facing domain, without scheme. Example: app.example.com."
  type        = string # Hostname without https://.
}

variable "path_prefix" {
  description = "Public base path for this app. The Next.js app is currently configured for /scrum."
  type        = string   # Path prefix string.
  default     = "/scrum" # Must match next.config.ts basePath.

  validation {
    condition     = startswith(var.path_prefix, "/") && !endswith(var.path_prefix, "/") # Requires /scrum, not scrum or /scrum/.
    error_message = "path_prefix must start with / and must not end with /."             # Message shown on invalid input.
  }
}

variable "listener_rule_priority" {
  description = "Priority for the ALB listener rule. Must not conflict with existing listener rules."
  type        = number # ALB rule priority integer.
}

variable "frontend_image" {
  description = "Fully qualified ECR image URI for the built Next.js frontend image."
  type        = string # Example: account.dkr.ecr.region.amazonaws.com/repo:tag.
}

variable "caddy_image" {
  description = "Fully qualified ECR image URI for the custom Caddy image containing infra/aws-caddy/Caddyfile."
  type        = string # Example: account.dkr.ecr.region.amazonaws.com/repo:tag.
}

variable "convex_backend_image" {
  description = "Fully qualified ECR image URI for the mirrored ghcr.io/get-convex/convex-backend image."
  type        = string # Example: account.dkr.ecr.region.amazonaws.com/repo:tag.
}

variable "ecs_cpu" {
  description = "Fargate task CPU units. 1024 = 1 vCPU. Other common options: 512, 2048, 4096."
  type        = number # CPU units for the whole task.
  default     = 1024   # 1 vCPU starting point.
}

variable "ecs_memory" {
  description = "Fargate task memory in MiB. Must be valid for ecs_cpu. 2048 is a practical starting point."
  type        = number # Memory in MiB for the whole task.
  default     = 2048   # 2 GiB starting point.
}

variable "desired_count" {
  description = "Number of ECS tasks. Keep at 1 for this single-node self-hosted Convex setup."
  type        = number # Desired running task count.
  default     = 1      # Single-node Convex.
}

variable "efs_transition_to_ia" {
  description = "Optional EFS lifecycle policy. AFTER_30_DAYS moves cold files to Infrequent Access. Set null to disable."
  type        = string          # EFS lifecycle policy value.
  default     = "AFTER_30_DAYS" # Reduces cost for cold files.
}

variable "log_retention_days" {
  description = "CloudWatch log retention. Alternatives: 7 for cheaper dev logs, 90+ for longer audit history."
  type        = number # Retention in days.
  default     = 30     # Balanced default for production-ish logs.
}

variable "enable_ecs_exec" {
  description = "Enable ECS Exec for manual Convex admin key generation and troubleshooting."
  type        = bool # Boolean feature flag.
  default     = true # Needed for aws ecs execute-command bootstrap flow.
}
