locals {
  # Public URLs used by frontend build/runtime and Convex origins.
  public_site_url        = "https://${var.domain_name}${var.path_prefix}"               # Browser URL for the Next.js app.
  public_convex_url      = "https://${var.domain_name}${var.path_prefix}/api"           # Browser URL for Convex websocket/API traffic.
  public_convex_site_url = "https://${var.domain_name}${var.path_prefix}/site"          # Browser URL for Convex site/auth routes.
  public_auth_url        = "https://${var.domain_name}${var.path_prefix}/site/api/auth" # BetterAuth base URL.

  # Names are kept short because several AWS resources have length limits.
  name = "${var.name_prefix}-${var.environment}" # Shared prefix for AWS resource names.

  common_tags = {
    Application = var.name_prefix  # Groups resources by app.
    Environment = var.environment  # Distinguishes prod/stage/dev resources.
    ManagedBy   = "terraform"      # Makes ownership clear in AWS console.
  }
}
