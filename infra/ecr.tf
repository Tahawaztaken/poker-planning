# ECR repositories store the images ECS runs. We keep separate repos because
# frontend, Caddy, and Convex backend are versioned independently.

resource "aws_ecr_repository" "frontend" {
  name = "${local.name}-frontend" # Repository name for the Next.js frontend image.

  # Immutable tags make task definitions reproducible. Push a new unique tag
  # for every release instead of overwriting latest.
  image_tag_mutability = "IMMUTABLE" # Prevents overwriting an existing tag.

  image_scanning_configuration {
    scan_on_push = true # Scans images for known vulnerabilities when pushed.
  }

  encryption_configuration {
    encryption_type = "AES256" # Uses AWS-managed encryption at rest.
    # Alternative: KMS encryption with encryption_type = "KMS" and kms_key.
  }
}

resource "aws_ecr_repository" "caddy" {
  name                 = "${local.name}-caddy" # Repository name for the custom Caddy image.
  image_tag_mutability = "IMMUTABLE"           # Prevents overwriting an existing tag.

  image_scanning_configuration {
    scan_on_push = true # Scans images for known vulnerabilities when pushed.
  }

  encryption_configuration {
    encryption_type = "AES256" # Uses AWS-managed encryption at rest.
  }
}

resource "aws_ecr_repository" "convex_backend" {
  name                 = "${local.name}-convex-backend" # Repository name for the mirrored Convex backend image.
  image_tag_mutability = "IMMUTABLE"                    # Prevents overwriting an existing tag.

  image_scanning_configuration {
    scan_on_push = true # Scans images for known vulnerabilities when pushed.
  }

  encryption_configuration {
    encryption_type = "AES256" # Uses AWS-managed encryption at rest.
  }
}

resource "aws_ecr_lifecycle_policy" "keep_recent" {
  for_each = {
    frontend       = aws_ecr_repository.frontend.name        # Apply policy to the frontend repo.
    caddy          = aws_ecr_repository.caddy.name           # Apply policy to the Caddy repo.
    convex_backend = aws_ecr_repository.convex_backend.name  # Apply policy to the Convex backend repo.
  }

  repository = each.value # Current repository selected by for_each.

  # Keep the last 20 pushed images per repo. Adjust upward if you need a longer
  # rollback window.
  policy = jsonencode({
    rules = [
      {
        rulePriority = 1                                    # First lifecycle rule evaluated.
        description  = "Keep only the most recent 20 images" # Human-readable policy description.
        selection = {
          tagStatus   = "any"                 # Applies to tagged and untagged images.
          countType   = "imageCountMoreThan"  # Expire images after countNumber is exceeded.
          countNumber = 20                    # Keep only the newest 20 images.
        }
        action = {
          type = "expire" # Deletes images matching the selection rule.
        }
      }
    ]
  })
}
