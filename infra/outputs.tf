output "frontend_ecr_repository_url" {
  description = "Push the Next.js frontend image to this ECR repository."
  value       = aws_ecr_repository.frontend.repository_url # ECR URI used in docker tag/push.
}

output "caddy_ecr_repository_url" {
  description = "Push the AWS Caddy image to this ECR repository."
  value       = aws_ecr_repository.caddy.repository_url # ECR URI used in docker tag/push.
}

output "convex_backend_ecr_repository_url" {
  description = "Mirror the Convex backend image to this ECR repository."
  value       = aws_ecr_repository.convex_backend.repository_url # ECR URI used in docker tag/push.
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name # Use this with aws ecs commands.
}

output "ecs_service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.app.name # Use this with aws ecs list-tasks.
}

output "public_site_url" {
  description = "Browser-facing app URL."
  value       = local.public_site_url # Final /scrum URL users open.
}

output "public_convex_url" {
  description = "Browser-facing Convex backend URL."
  value       = local.public_convex_url # URL used by browser Convex client.
}

output "efs_file_system_id" {
  description = "EFS file system that persists Convex /convex/data."
  value       = aws_efs_file_system.convex_data.id # EFS ID for troubleshooting.
}
